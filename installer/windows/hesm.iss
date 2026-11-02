#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef AppFileVersion
  #error AppFileVersion is required
#endif
#ifndef BundleDir
  #error BundleDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif

[Setup]
AppId={{D2B90FA1-E61A-46F3-9C25-368B47BDA773}
AppName=HESM - Gestión RRHH
AppVersion={#AppVersion}
AppPublisher=HESM
AppPublisherURL=https://github.com/gabyboan/hesm-gestion-rrhh
VersionInfoVersion={#AppFileVersion}
DefaultDirName={localappdata}\Programs\HESM-Gestion-RRHH
DefaultGroupName=HESM - Gestión RRHH
UninstallDisplayIcon={app}\app_horas.exe
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
OutputDir={#OutputDir}
OutputBaseFilename=HESM-Gestion-RRHH-{#AppFileVersion}-Setup
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
PrivilegesRequired=lowest
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Languages]
Name: spanish; MessagesFile: compiler:Languages\Spanish.isl

[Tasks]
Name: desktopicon; Description: Crear un acceso directo en el escritorio; GroupDescription: Accesos directos:; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\HESM - Gestión RRHH"; Filename: "{app}\app_horas.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\HESM - Gestión RRHH"; Filename: "{app}\app_horas.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\app_horas.exe"; Description: Abrir HESM - Gestión RRHH; Flags: nowait postinstall skipifsilent
Filename: "{app}\app_horas.exe"; Flags: nowait skipifnotsilent runasoriginaluser
