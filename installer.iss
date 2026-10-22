; Inno Setup script -> produces Output\SysMon-Setup.exe
; Run build_release.bat first, then open this file in Inno Setup (https://jrsoftware.org/isinfo.php) and press Compile.

[Setup]
; AppId باید همیشه ثابت بمونه تا نسخه‌ی جدید روی نسخه‌ی قبلی نصب بشه (آپدیت)، نه کنارش
AppId={{AFFD5EC7-BA14-452F-901F-CC170F899ABF}
AppName=SysMon
AppVersion=1.0.1
AppPublisher=SysMon
DefaultDirName={autopf}\SysMon
DefaultGroupName=SysMon
OutputBaseFilename=SysMon-Setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\sysmon_flutter.exe
SetupIconFile=windows\runner\resources\app_icon.ico

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\SysMon"; Filename: "{app}\sysmon_flutter.exe"
Name: "{autodesktop}\SysMon"; Filename: "{app}\sysmon_flutter.exe"

[Run]
Filename: "{app}\sysmon_flutter.exe"; Description: "Launch SysMon"; Flags: nowait postinstall skipifsilent
; بعد از آپدیت خودکار (نصب بی‌صدا) برنامه دوباره باز بشه
Filename: "{app}\sysmon_flutter.exe"; Flags: nowait; Check: WizardSilent
