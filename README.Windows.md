# Building LivingScroll on Windows

How to build the Windows desktop app **and** produce a single-file installer
that bundles everything needed to install and run it.

> **Windows only.** Flutter cannot cross-compile a Windows binary from Linux or
> macOS — the Windows toolchain (MSVC) must run on Windows. Do all of the below
> on a Windows 10/11 (x64) machine.

The end result is:

```
dist\LivingScroll-<version>-windows-x64-setup.exe
```

an installer containing the `.exe`, the Flutter engine + plugin DLLs (including
the media_kit audio backend), the bundled MSVC runtime, and the `data\` folder
(`flutter_assets`, `icudtl.dat`).

---

## 1. Prerequisites

### a) Flutter SDK
Either add `flutter` to your `PATH`, or use the SDK checked into this repo at
`.\flutter` (the build script finds it automatically).

### b) Visual Studio 2022 — "Desktop development with C++"
This provides the MSVC compiler, CMake, the Windows SDK and the C++ runtime that
a Flutter Windows app links against.

```powershell
winget install --id Microsoft.VisualStudio.2022.Community --override "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"
```

> VS Code alone is **not** enough — you need the actual MSVC toolchain.

### c) Inno Setup 6 (builds the installer)
```powershell
winget install JRSoftware.InnoSetup
```
or download from <https://jrsoftware.org/isdl.php>.

### d) Verify the toolchain
```powershell
flutter doctor
```
The **Visual Studio** entry must be a green check before you continue.

---

## 2. One-command build (recommended)

From the project root in **PowerShell**:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
```

The script (`build_windows.ps1`) does everything:

1. reads the version from `pubspec.yaml`,
2. runs `flutter pub get`,
3. runs `flutter build windows --release`,
4. copies the **MSVC runtime DLLs** next to the `.exe` (app-local deployment, so
   the app runs even on machines without the "Visual C++ Redistributable"),
5. compiles `windows\installer\LivingScroll.iss` with Inno Setup into
   `dist\LivingScroll-<version>-windows-x64-setup.exe`.

### Options

| Command | Effect |
|---|---|
| `.\build_windows.ps1` | Full build + installer. |
| `.\build_windows.ps1 -SkipBuild` | Package an already-built `Release` folder (skip `flutter build`). |
| `.\build_windows.ps1 -Iscc "C:\path\to\ISCC.exe"` | Point at a specific Inno Setup compiler. |

---

## 3. Manual build (without the script)

If you prefer to run the steps yourself:

```powershell
flutter config --enable-windows-desktop   # once; usually already enabled
flutter pub get
flutter build windows --release
```

The runnable app is then the **whole folder**:

```
build\windows\x64\runner\Release\
```

To run it directly, launch `living_scroll.exe` from inside that folder (the
`.exe` needs the sibling DLLs and `data\` directory — copying just the `.exe`
elsewhere will not work).

To build the installer manually afterwards, open
`windows\installer\LivingScroll.iss` in the Inno Setup IDE and click **Compile**,
or from the command line:

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" `
  "/DMyAppVersion=1.0.0" `
  "/DSourceDir=$(Resolve-Path build\windows\x64\runner\Release)" `
  "/DOutputDir=$(Resolve-Path .)\dist" `
  windows\installer\LivingScroll.iss
```

> Doing it manually skips step 4 of the script (bundling the MSVC runtime), so
> the app may then require the **Microsoft Visual C++ Redistributable (x64)** on
> the target machine. Prefer the script for distributable builds.

---

## 4. What the installer does

- Installs to `C:\Program Files\Living Scroll` (admin rights requested).
- Creates a Start Menu shortcut (and an optional desktop shortcut).
- Registers an entry in **Apps & features / Add-Remove Programs** with the app
  icon and an uninstaller.
- Offers to launch the app at the end.

The app/window title is **"Living Scroll - Weave every thread"**; the icon comes
from `windows\runner\resources\app_icon.ico`.

---

## 5. Audio on Windows

Soundtrack playback uses `just_audio` with the **media_kit** backend on desktop.
The native audio library is provided by `media_kit_libs_windows_audio` (declared
in `pubspec.yaml`) and is initialised for Windows in `lib/main.dart`. Its DLL
(`libmpv-2.dll`) is produced into the `Release` folder by `flutter build windows`
and therefore packaged into the installer automatically — no extra step needed.

---

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter doctor` shows Visual Studio missing/incomplete | Install VS 2022 with the **Desktop development with C++** workload (§1b). |
| Script error: *"Inno Setup compiler (ISCC.exe) not found"* | Install Inno Setup 6 (§1c), or pass `-Iscc "C:\...\ISCC.exe"`. |
| *"running scripts is disabled on this system"* | Launch with `powershell -ExecutionPolicy Bypass -File .\build_windows.ps1`. |
| App starts then crashes about a missing `VCRUNTIME140*.dll` / `MSVCP140.dll` | Use `build_windows.ps1` (bundles them), or install the **VC++ Redistributable (x64)** on the target PC. |
| Build fails to find `flutter` | Add it to `PATH` or place the SDK at `.\flutter`. |
| Installer must target a different version/name | Bump `version:` in `pubspec.yaml`; edit the defaults (name, publisher) in `windows\installer\LivingScroll.iss`. |

> **Architecture:** the build is x64 only; ARM64 Windows is not targeted.
