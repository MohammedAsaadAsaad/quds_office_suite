; Inno Setup 6 script: installer and uninstaller for Quds Report Studio.
;
;   iscc /DAppVersion=1.1.0 /DSourceDir=<Release dir> /DOutputDir=<dist> quds_report_studio.iss
;
; Installs per user by default (no admin); the dialog offers "all users".
; Registers .qrep files (QudsReportStudio.qrep ProgID); the uninstaller removes
; them, including the per-user keys the studio writes on its first run.

#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\dist"
#endif
#define AppExe "quds_report_studio.exe"
#define ProgId "QudsReportStudio.qrep"

[Setup]
AppId={{8C1B6E0A-5D2F-4B7E-9A3C-1F0D2E4B6A71}
AppName=Quds Report Studio
AppVersion={#AppVersion}
AppVerName=Quds Report Studio {#AppVersion}
AppPublisher=Mohammed Asaad Asaad
AppPublisherURL=https://github.com/MohammedAsaadAsaad/quds_office_suite
AppSupportURL=https://github.com/MohammedAsaadAsaad/quds_office_suite/issues
AppUpdatesURL=https://github.com/MohammedAsaadAsaad/quds_office_suite/releases
DefaultDirName={autopf}\Quds Report Studio
DefaultGroupName=Quds Report Studio
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=QudsReportStudio-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName=Quds Report Studio
LicenseFile=..\..\..\..\packages\quds_office_engine\LICENSE
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
CloseApplications=yes
VersionInfoVersion={#AppVersion}
VersionInfoProductName=Quds Report Studio

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
#if FileExists(AddBackslash(CompilerPath) + "Languages\Arabic.isl")
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "qrep"; Description: "Open .qrep files with Quds Report Studio"; GroupDescription: "File types:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Quds Report Studio"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\Quds Report Studio"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\.qrep"; ValueType: string; ValueName: ""; ValueData: "{#ProgId}"; Flags: uninsdeletevalue; Tasks: qrep
Root: HKA; Subkey: "Software\Classes\.qrep"; ValueType: string; ValueName: "Content Type"; ValueData: "application/vnd.quds.qrep+zip"; Flags: uninsdeletevalue; Tasks: qrep
Root: HKA; Subkey: "Software\Classes\.qrep\OpenWithProgids"; ValueType: none; ValueName: "{#ProgId}"; Flags: uninsdeletevalue; Tasks: qrep
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "Quds report"; Flags: uninsdeletekey; Tasks: qrep
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"",1"; Tasks: qrep
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: qrep
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".qrep"; ValueData: ""; Flags: uninsdeletekey

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,Quds Report Studio}"; Flags: nowait postinstall skipifsilent

[Code]
procedure RemoveUserAssociation();
var
  Current: String;
begin
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\{#ProgId}');
  if RegQueryStringValue(HKCU, 'Software\Classes\.qrep', '', Current) and
     (Current = '{#ProgId}') then
  begin
    RegDeleteValue(HKCU, 'Software\Classes\.qrep', '');
    RegDeleteValue(HKCU, 'Software\Classes\.qrep', 'Content Type');
  end;
  RegDeleteValue(HKCU, 'Software\Classes\.qrep\OpenWithProgids', '{#ProgId}');
  RegDeleteKeyIfEmpty(HKCU, 'Software\Classes\.qrep\OpenWithProgids');
  RegDeleteKeyIfEmpty(HKCU, 'Software\Classes\.qrep');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveUserAssociation();
end;
