[Setup]
AppName=Exanor Store Partner
AppVersion=2.0.0
AppPublisher=Exanor
DefaultDirName={autopf}\Exanor Store Partner
DefaultGroupName=Exanor Store Partner
UninstallDisplayIcon={app}\exanor_user_new.exe
OutputDir=..\
OutputBaseFilename=ExanorStorePartner-Setup
Compression=lzma2/ultra64
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Exanor Store Partner"; Filename: "{app}\exanor_user_new.exe"
Name: "{autodesktop}\Exanor Store Partner"; Filename: "{app}\exanor_user_new.exe"

[Run]
Filename: "{app}\exanor_user_new.exe"; Description: "Launch Exanor Store Partner"; Flags: nowait postinstall skipifsilent
