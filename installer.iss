; ==========================================================================
; Exanor Store Partner — Inno Setup Installer Script
; Version : 1.0.12+13
; Updated : 2026-05-27
; ==========================================================================

#define MyAppName      "Exanor Store App"
#define MyAppVersion   "1.0.12"
#define MyAppBuild     "13"
#define MyAppPublisher "Exanor"
#define MyAppURL       "https://exanor.store"
#define MyAppExeName   "exanor_user_new.exe"
#define MyAppMutex     "exanor_store_app_mutex"

[Setup]
; Unique Application ID — do NOT reuse for other Exanor products
AppId={{DA354CCF-D90D-47C2-9BEA-7256FF8B0CE2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Prevent launching a second instance while one is already running
AppMutex={#MyAppMutex}

; Installation paths
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes

; Installer output
OutputDir=installer_output
OutputBaseFilename=ExanorStorePartner-Setup-{#MyAppVersion}

; Visuals
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern

; Compression
Compression=lzma2/ultra64
SolidCompression=yes

; Architecture — 64-bit only
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Privileges (install for current user by default, admin if available)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Misc
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}.{#MyAppBuild}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; ---- Main Executable ----
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; ---- All DLLs (Flutter engine + plugin DLLs) ----
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; ---- Data folder (Flutter assets, ICU data, etc.) ----
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}";  Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any runtime-generated files in the install directory
Type: filesandordirs; Name: "{app}\data"
