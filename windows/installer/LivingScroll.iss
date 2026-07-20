; Inno Setup script for Living Scroll (Windows installer).
;
; Normally compiled by ..\..\build_windows.ps1, which passes the /D defines
; below (MyAppVersion, SourceDir, OutputDir). It can also be compiled standalone
; in the Inno Setup IDE after a `flutter build windows --release` — the defaults
; point at the standard release output.
;
; Requires Inno Setup 6 (https://jrsoftware.org/isdl.php).

#ifndef MyAppName
  #define MyAppName "Living Scroll"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "net.livingscroll"
#endif
#ifndef MyAppURL
  #define MyAppURL "https://livingscroll.net"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "living_scroll.exe"
#endif
; Folder produced by `flutter build windows --release` (relative to this .iss).
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
; Where the finished installer is written (relative to this .iss).
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
; Installer + Add/Remove Programs icon (the app's generated .ico).
#ifndef SetupIcon
  #define SetupIcon "..\runner\resources\app_icon.ico"
#endif

[Setup]
; A stable, unique GUID identifies this product across versions. Keep it fixed.
AppId={{B7E5B3B1-9C2A-4D1E-A6F4-2E9D7C0A5F38}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#OutputDir}
OutputBaseFilename=LivingScroll-{#MyAppVersion}-windows-x64-setup
SetupIconFile={#SetupIcon}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Flutter Windows desktop is x64-only.
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Package the ENTIRE release folder: the .exe, all DLLs (Flutter engine, plugins
; and the app-local MSVC runtime copied in by build_windows.ps1) and the data\
; directory (flutter_assets, icudtl.dat). Everything needed to run is included.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
