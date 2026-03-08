; =============================================================================
; Exanor Store Partner - Inno Setup Script
; App:     Exanor Store Partner (Flutter Windows Desktop)
; Binary:  exanor_user_new.exe
; Version: 1.0.1
; =============================================================================

#define MyAppName      "Exanor Store Partner"
#define MyAppVersion   "1.0.1"
#define MyAppPublisher "Exanor"
#define MyAppURL       "https://exanor.com"
#define MyAppExeName   "exanor_user_new.exe"
#define MyAppId        "{B3F4A2C1-7E8D-4F9A-B1C2-D3E4F5A6B7C8}"

[Setup]
; ---- Identity ---------------------------------------------------------------
AppId={{#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/support
AppUpdatesURL={#MyAppURL}/updates
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}. All rights reserved.

; ---- Install Paths ----------------------------------------------------------
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; ---- Icons & Uninstall ------------------------------------------------------
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; ---- Output -----------------------------------------------------------------
OutputDir=installer_output
OutputBaseFilename=ExanorStorePartner-Setup-{#MyAppVersion}

; ---- Compression ------------------------------------------------------------
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; ---- Architecture -----------------------------------------------------------
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; ---- Privileges -------------------------------------------------------------
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; ---- Wizard -----------------------------------------------------------------
WizardStyle=modern
DisableWelcomePage=no
DisableDirPage=no
DisableReadyPage=no

; ---- Minimum Windows Version (Windows 10) -----------------------------------
MinVersion=10.0

; ---- Misc -------------------------------------------------------------------
; Allow user to re-run the app after install
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application bundle (exe + all DLLs + flutter_assets + data)
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll";            DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*";           DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcut
Name: "{group}\{#MyAppName}";      Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
; Desktop shortcut (only if the task is selected)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Launch the app after installation (optional, skippable)
Filename: "{app}\{#MyAppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent; \
  WorkingDir: "{app}"

[UninstallDelete]
; Remove any leftover files/folders created by the app during runtime
Type: filesandordirs; Name: "{app}"
