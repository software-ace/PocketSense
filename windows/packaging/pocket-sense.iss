; The EXE installer (Inno Setup 6). Built by the release workflow from the
; Flutter bundle; paths here are relative to this file.
;   iscc /DAppVersion=2.4.2 /DSourceDir=<bundle> /DOutputDir=<dir> /DOutputName=<name> pocket-sense.iss
; Uninstalling keeps your data in %LOCALAPPDATA%\pocket_sense, as the
; Linux packages keep ~/.local/share/pocket_sense.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Fixed: later versions find and upgrade this install by it.
AppId={{b2ffafaf-6f02-424d-bd1e-dcfb6caa9180}
AppName=Pocket Sense
AppVersion={#AppVersion}
AppPublisher=software-ace
AppPublisherURL=https://github.com/software-ace/PocketSense
DefaultDirName={autopf}\Pocket Sense
DisableProgramGroupPage=yes
; Installs for just you without admin rights, or for everyone if you choose.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\pocket_sense.exe
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; The same AppUserModelID the app gives Windows for its reminder notifications.
Name: "{autoprograms}\Pocket Sense"; Filename: "{app}\pocket_sense.exe"; AppUserModelID: "ace.software.pocketsense"
Name: "{autodesktop}\Pocket Sense"; Filename: "{app}\pocket_sense.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\pocket_sense.exe"; Description: "{cm:LaunchProgram,Pocket Sense}"; Flags: nowait postinstall skipifsilent
