; Inno Setup script for Timer Counter.
; Compile manually with: ISCC.exe /DMyAppVersion=1.0.6 inno_setup.iss

#define MyAppName "Timer Counter"
#ifndef MyAppVersion
#define MyAppVersion "1.0.6"
#endif
#define MyAppPublisher "Timer Counter"
#define MyAppExeName "timer_counter.exe"
#define MyAppBuildDir "build\windows\x64\runner\Release"
#define MyAppIcon "assets\icons\app_icon.ico"

[Setup]
; Unique application identifier for Timer Counter.
AppId={{9A2EAD3D-4B64-4C3C-8C54-D81F6E0C7DD4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=setup-Timer-Counter-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Clean up old runtime/plugin files that may be left by previous Flutter builds.
Type: files; Name: "{app}\msvcp140.dll"
Type: files; Name: "{app}\msvcp140_1.dll"
Type: files; Name: "{app}\msvcp140_2.dll"
Type: files; Name: "{app}\msvcp140_atomic_wait.dll"
Type: files; Name: "{app}\msvcp140_codecvt_ids.dll"
Type: files; Name: "{app}\vcruntime140.dll"
Type: files; Name: "{app}\vcruntime140_1.dll"
Type: files; Name: "{app}\vcruntime140d.dll"
Type: files; Name: "{app}\vcruntime140_1d.dll"
Type: files; Name: "{app}\vccorlib140.dll"
Type: files; Name: "{app}\vccorlib140d.dll"
Type: files; Name: "{app}\ucrtbase.dll"
Type: files; Name: "{app}\ucrtbased.dll"
Type: files; Name: "{app}\concrt140.dll"
Type: files; Name: "{app}\api-ms-win-*.dll"
Type: files; Name: "{app}\screen_retriever_plugin.dll"
Type: files; Name: "{app}\libc++.dll"

[Files]
Source: "{#MyAppBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent