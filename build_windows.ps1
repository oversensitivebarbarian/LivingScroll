<#
.SYNOPSIS
  Builds Living Scroll for Windows (release) and packages a single-file installer.

.DESCRIPTION
  Run this on a Windows machine that has the Flutter Windows toolchain
  (Visual Studio 2022 with the "Desktop development with C++" workload) and
  Inno Setup 6. The script:
    1. flutter pub get
    2. flutter build windows --release
    3. Copies the MSVC runtime DLLs next to the .exe (app-local deployment) so
       the app runs even on machines without the VC++ Redistributable installed.
    4. Compiles windows\installer\LivingScroll.iss with Inno Setup (ISCC) into
       dist\LivingScroll-<version>-windows-x64-setup.exe

  The resulting installer contains EVERYTHING required to install and run the
  app (exe, Flutter engine + plugin DLLs, the MSVC runtime, and the data\
  folder with flutter_assets / icudtl.dat).

.PARAMETER SkipBuild
  Skip flutter build and package an already-built Release folder.

.PARAMETER Iscc
  Full path to ISCC.exe (Inno Setup compiler). Auto-detected if omitted.

.EXAMPLE
  .\build_windows.ps1

.EXAMPLE
  .\build_windows.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
  [switch]$SkipBuild,
  [string]$Iscc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot   = $PSScriptRoot
$ReleaseDir = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
$IssFile    = Join-Path $RepoRoot 'windows\installer\LivingScroll.iss'
$OutputDir  = Join-Path $RepoRoot 'dist'
$ExeName    = 'living_scroll.exe'

function Write-Step([string]$Message) {
  Write-Host "==> $Message" -ForegroundColor Cyan
}

# --- App version from pubspec.yaml (e.g. "1.0.0+1" -> "1.0.0") -----------------
$pubspecText = Get-Content (Join-Path $RepoRoot 'pubspec.yaml') -Raw
if ($pubspecText -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Could not read 'version:' from pubspec.yaml"
}
$AppVersion = $Matches[1]
Write-Step "App version: $AppVersion"

# --- Locate the Flutter SDK ----------------------------------------------------
# Prefer the bundled .\flutter ONLY when it is fully bootstrapped (its dart-sdk
# has been downloaded). A bare checkout with no bin\cache\dart-sdk\bin\dart.exe
# sends `flutter pub get` into an endless "pub upgrade" retry loop, so in that
# case fall back to a working `flutter` on PATH.
function Resolve-Flutter {
  $bundled     = Join-Path $RepoRoot 'flutter\bin\flutter.bat'
  $bundledDart = Join-Path $RepoRoot 'flutter\bin\cache\dart-sdk\bin\dart.exe'
  if ((Test-Path $bundled) -and (Test-Path $bundledDart)) { return $bundled }

  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) {
    if (Test-Path $bundled) {
      Write-Warning ("Bundled .\flutter is not bootstrapped (no dart-sdk); " +
        "using Flutter from PATH instead: $($cmd.Source)")
    }
    return $cmd.Source
  }

  # No PATH flutter: fall back to the bundled SDK and let it bootstrap itself.
  if (Test-Path $bundled) { return $bundled }
  throw "Flutter not found. Add it to PATH or place the SDK at .\flutter"
}

# --- Build ---------------------------------------------------------------------
if (-not $SkipBuild) {
  $flutter = Resolve-Flutter
  Write-Step "Using Flutter: $flutter"

  Write-Step 'flutter pub get'
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

  Write-Step 'flutter build windows --release'
  & $flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }
}

$ExePath = Join-Path $ReleaseDir $ExeName
if (-not (Test-Path $ExePath)) {
  throw "Built binary not found: $ExePath (run without -SkipBuild first)"
}

# --- Bundle the MSVC runtime next to the exe (app-local deployment) -------------
# Flutter does not copy these; without them the app fails to start on a machine
# that lacks the "Microsoft Visual C++ Redistributable (x64)".
function Copy-VcRuntime {
  $needed = @(
    'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
    'msvcp140_1.dll', 'msvcp140_2.dll'
  )

  # Find the VC CRT redist folder(s) via vswhere.
  $crtDirs = New-Object System.Collections.Generic.List[string]
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products * -property installationPath 2>$null
    if ($vsPath) {
      $redistRoot = Join-Path $vsPath 'VC\Redist\MSVC'
      if (Test-Path $redistRoot) {
        Get-ChildItem $redistRoot -Directory | ForEach-Object {
          $x64 = Join-Path $_.FullName 'x64'
          if (Test-Path $x64) {
            Get-ChildItem $x64 -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
              ForEach-Object { $crtDirs.Add($_.FullName) }
          }
        }
      }
    }
  }

  $copied = 0
  foreach ($dll in $needed) {
    if (Test-Path (Join-Path $ReleaseDir $dll)) { $copied++; continue }

    $src = $null
    foreach ($dir in $crtDirs) {
      $candidate = Join-Path $dir $dll
      if (Test-Path $candidate) { $src = $candidate; break }
    }
    if (-not $src) {
      $sys = Join-Path $env:WINDIR "System32\$dll"
      if (Test-Path $sys) { $src = $sys }
    }
    if ($src) {
      Copy-Item $src $ReleaseDir -Force
      Write-Host "    + $dll" -ForegroundColor DarkGray
      $copied++
    }
  }
  return $copied
}

Write-Step 'Bundling MSVC runtime (app-local)'
$runtimeCount = Copy-VcRuntime
if ($runtimeCount -lt 3) {
  Write-Warning ("Could not bundle the full MSVC runtime. Target machines may " +
    "need the 'Microsoft Visual C++ Redistributable (x64)' installed.")
}

# --- Locate the Inno Setup compiler --------------------------------------------
function Resolve-Iscc {
  if ($Iscc) {
    if (Test-Path $Iscc) { return $Iscc }
    throw "ISCC.exe not found at: $Iscc"
  }
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    # winget installs the per-user package here (no admin), not under Program Files.
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  throw @'
Inno Setup compiler (ISCC.exe) not found.
Install Inno Setup 6, e.g.:
    winget install JRSoftware.InnoSetup
or download it from https://jrsoftware.org/isdl.php
Then re-run this script (or pass -Iscc "C:\path\to\ISCC.exe").
'@
}

$isccPath = Resolve-Iscc
Write-Step "Using Inno Setup: $isccPath"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# --- Compile the installer -----------------------------------------------------
Write-Step 'Compiling installer'
& $isccPath `
  "/DMyAppVersion=$AppVersion" `
  "/DSourceDir=$ReleaseDir" `
  "/DOutputDir=$OutputDir" `
  $IssFile
if ($LASTEXITCODE -ne 0) { throw 'ISCC compilation failed' }

$setupExe = Join-Path $OutputDir "LivingScroll-$AppVersion-windows-x64-setup.exe"
Write-Host ''
Write-Step "Done: $setupExe"
