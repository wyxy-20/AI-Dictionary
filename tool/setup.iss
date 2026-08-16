; AI Dictionary 安装脚本（Inno Setup 6）
; 编译前请先执行 flutter build windows --release，
; 然后在项目根目录运行：
;   ISCC.exe tool\setup.iss /DMyAppVersion=1.9.0
; 产物：dist\AI-Dictionary-v1.9.0-setup.exe

#ifndef MyAppVersion
  #define MyAppVersion "1.9.0"
#endif
#define MyAppName "AI Dictionary"
#define MyAppNameZh "AI时代词典"
#define MyAppExeName "ai_dictionary.exe"
#define MyAppPublisher "AI Dictionary Contributors"
; 注意：Inno Setup 的 AppId 需以双花括号 {{ 转义开头
#define MyAppId "{{129C9DBB-4582-44A1-B9ED-C908750A60F4}"

[Setup]
; 固定 AppId：保证升级 / 卸载注册表项一致
AppId={#MyAppId}
AppName={#MyAppName}（{#MyAppNameZh}）
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} - {#MyAppNameZh}

; 用户级安装（无需管理员权限，写入 HKCU 卸载项）
DefaultDirName={localappdata}\Programs\AI Dictionary
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
DefaultGroupName=AI Dictionary

; 卸载体验
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
CloseApplications=yes
AppMutex=Local\AI_Dictionary_SingleInstance

; 安装包外观
SetupIconFile=..\assets\branding\app_icon.ico
WizardStyle=modern
WizardSizePercent=110
OutputDir=..\dist
OutputBaseFilename=AI-Dictionary-v{#MyAppVersion}-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DeleteUserData: Boolean;

// 卸载时询问是否删除用户数据（词条、收藏、历史、AI 设置与日志）
procedure CurUninstallStepChanged(CurStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurStep = usUninstall then
  begin
    DeleteUserData :=
      (MsgBox(
        '是否同时删除词典数据（词条、收藏、历史、AI 设置与运行日志）？' #13#13 +
        'Also delete dictionary data (terms, favorites, history, AI settings and logs)?' #13#13 +
        '选择"是"将永久删除用户数据目录，此操作不可恢复；选择"否"仅卸载程序，重装后可继续使用数据。',
        mbConfirmation, MB_YESNO) = IDYES);
  end
  else if (CurStep = usPostUninstall) and (DeleteUserData) then
  begin
    DataDir := ExpandConstant('{userappdata}\com.aidictionary');
    if DirExists(DataDir) then
      DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userdocs}\AIDictionary');
    if DirExists(DataDir) then
      DelTree(DataDir, True, True, True);
  end;
end;
