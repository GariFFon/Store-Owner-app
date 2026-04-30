[Setup]
; App Details
AppId={DA354CCF-D90D-47C2-9BEA-7256FF8B0CE2}
AppName=Exanor Store App
AppVersion=1.0.8
AppPublisher=Exanor
AppPublisherURL=https://exanor.store
AppSupportURL=https://exanor.store
AppUpdatesURL=https://exanor.store

; Executable Name
AppMutex=exanor_store_app_mutex

; Output Installer Settings
DefaultDirName={autopf}\Exanor Store App
DisableProgramGroupPage=yes
OutputDir=installer_output
OutputBaseFilename=ExanorStorePartner-Setup-1.0.8
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; Icons & Visuals
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\exanor_user_new.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Executable
Source: "build\windows\x64\runner\Release\exanor_user_new.exe"; DestDir: "{app}"; Flags: ignoreversion

; Libraries (.dll) & Dependencies
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\Exanor Store App"; Filename: "{app}\exanor_user_new.exe"
Name: "{autodesktop}\Exanor Store App"; Filename: "{app}\exanor_user_new.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\exanor_user_new.exe"; Description: "{cm:LaunchProgram,Exanor Store App}"; Flags: nowait postinstall skipifsilent
