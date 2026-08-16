# AI Dictionary（AI 时代词典）

面向 AI 学习者的专业 AI 术语词典 —— Windows 桌面应用。

基于 **Flutter Desktop + Dart + SQLite** 构建，内置 **1125 个 AI 术语**（随安装包内置完整词库，启动后自动检查远程更新），支持实时搜索、A-Z 字母导航、收藏与浏览历史、**启动自动同步远程词库**，数据全部本地保存、可离线使用。

本项目基于 [MIT License](LICENSE) 开源。

## 下载即用（普通用户）

到 [Releases](../../releases) 下载最新版，二选一：

| 版本 | 说明 |
|---|---|
| **安装版** `*-setup.exe`（推荐） | 标准安装程序：开始菜单快捷方式、控制面板「程序和功能」可卸载，安装无需管理员权限 |
| **便携版** `*-windows.zip` | 解压后运行 `ai_dictionary.exe` 即可，无需安装（卸载 = 删除文件夹） |

- **SmartScreen 提示**：当前版本尚未代码签名，Windows 首次运行可能提示"未知发布者"，点击"更多信息 → 仍要运行"即可；
- **数据本地存储**：词条、收藏、历史全部保存在本机，不上传任何服务器；
- **词库自动同步**：启动时自动从远程词库增量更新，无需手动操作；
- **AI 解释**：需要自备模型服务 API Key（支持 DeepSeek、OpenAI 及本地模型），在软件"设置 → AI 服务"中配置。

### 卸载

- **安装版**：控制面板「程序和功能」→ 卸载 AI Dictionary；或在开始菜单选择「卸载 AI Dictionary」；
  卸载时会询问是否**同时删除用户数据**（词条、收藏、历史、AI 设置与运行日志），
  默认仅卸载程序、保留数据（重装后可继续使用）；
- **便携版**：删除解压目录即可；如需清除用户数据，见下方「数据位置」。
- 卸载/删除后**系统层无残留**（不写注册表运行项、无后台服务；全局热键与托盘图标随程序退出自动释放）。

## 功能一览

- 三栏式现代界面（字母导航 / 词条列表 / 词条详情），可调整窗口大小
- 顶部实时搜索：英文、中文、关键词、模糊搜索（编辑距离容错）
- A-Z 首字母分组浏览，点击字母快速过滤
- 词条详情：难度星级、一句话解释、详细解释、应用场景、相关词条跳转
- 我的收藏：一键收藏 / 取消收藏，收藏列表
- 最近浏览：自动记录并去重，最多保留 100 条
- 设置：浅色 / 深色 / 跟随系统主题、界面语言（简体中文 / English，即时切换）、数据管理（导出备份、清空历史、重置词库）、关于
- 启动自动同步：打开软件即检查远程词库，自动增量下载新增词条，无需手动更新
- AI 智能解释：点击词条详情中的 AI 解释，自动调用大模型生成小白友好解释，SQLite 缓存、词条更新自动失效
- AI 服务设置：设置页可配置 OpenAI 兼容接口（地址 / API Key / 模型），兼容 OpenAI、DeepSeek、Qwen、本地模型
- 全局快捷搜索：设置页可自定义任意快捷键组合（如 Ctrl+K、Ctrl+Shift+K、F8），按下后在任何应用（如看视频时）上方弹出置顶悬浮搜索窗，实时搜索词条并一键跳转详情；Esc 关闭
- 单实例 + 系统托盘：再次点击桌面图标只会唤起已有窗口；关闭窗口后最小化到右下角托盘，快捷键搜索仍然可用；托盘菜单可显示主界面 / 快捷搜索 / 退出

## 项目结构

```text
lib/
├── main.dart                  # 应用入口：窗口、数据库、Provider 装配
├── core/
│   ├── config/app_config.dart # 应用名称、版本、数据库与种子数据配置
│   ├── constants/             # UI 常量（难度、主题、语言选项）
│   └── theme/app_theme.dart   # 浅色 / 深色主题
├── config/                    # （配置集中于 core/config，保持模块入口清晰）
├── database/
│   ├── app_database.dart      # SQLite 初始化、建表、迁移
│   ├── term_dao.dart          # terms 表数据访问
│   ├── history_dao.dart       # history 表数据访问
│   └── settings_dao.dart      # settings 表数据访问
├── models/
│   ├── term.dart              # 词条模型（JSON / DB 双向转换）
│   ├── dictionary_version.dart # 词库版本模型（本地 / 远程）
│   └── app_settings.dart      # 设置模型
├── services/
│   ├── seed_service.dart      # 首次启动导入 JSON 词库
│   ├── search_service.dart    # 高级搜索（中英 / 关键词 / 模糊）
│   ├── data_export_service.dart # 词库 JSON 备份导出
│   ├── update_service.dart     # 启动自动同步词库（检查版本/下载/增量更新）
│   └── ai/ai_service.dart     # OpenAI 兼容 AI 服务（解释生成 + SQLite 缓存）
├── providers/
│   ├── dictionary_provider.dart # 词库、搜索、视图、收藏、历史状态
│   └── settings_provider.dart   # 主题 / 语言状态
├── screens/
│   ├── home_screen.dart       # 主界面（顶栏 + 三栏）
│   ├── splash_screen.dart     # 启动加载页（同步状态展示）
│   └── settings_dialog.dart   # 设置对话框
├── widgets/                   # 左侧导航、词条列表、详情、搜索框等组件
└── utils/string_utils.dart    # 编辑距离、搜索高亮等工具
utils/version_utils.dart       # 语义化版本号比较

assets/data/terms/             # 内置完整词库（terms.json，1125 条，随版本内置）
test/                          # 单元测试 + 组件测试（40 个用例）
tool/generate_icon.py          # 应用图标生成脚本
```

## 启动自动同步词库

软件每次启动会短暂显示加载页，并自动执行：

```text
初始化数据库
  ↓
检查远程 version.json
  ↓
比较本地 / 远程版本（本地 >= 远程则跳过）
  ↓
下载最新 terms.json
  ↓
增量插入本地不存在的词条（不删除、不覆盖，收藏与历史不受影响）
  ↓
进入主界面
```

规则：

- **24 小时内已成功检查过**则直接跳过，避免每次启动重复下载；
- **多源回退**：按顺序尝试 jsDelivr CDN → GitHub Raw，国内网络环境也能正常同步；
- **无网络或远程不可达**时静默降级到本地 SQLite 词库，正常进入软件，不弹错误；
- 本地版本记录在 `dictionary_version` 表（version / update_time / terms_count / last_check_time）。

### 如何发布新的在线词库

远程词库维护在独立仓库 [AI-Terms-Database](https://github.com/wyxy-20/AI-Terms-Database)：
包含 `version.json` 与 `terms.json`，字段与客户端完全兼容。

1. 在 GitHub 公开仓库 `AI-Terms-Database` 中更新词条；
2. 把 `version.json` 的版本号调高（如 1.2.0 → 1.3.0），软件会在下次检查时自动下载并增量添加新增词条；

   `version.json`：

   ```json
   {
     "version": "1.1.0",
     "update_time": "2026-08-08",
     "terms_count": 500
   }
   ```

   `terms.json`（数组，或 `{"terms": [...]}` 均可）：

   ```json
   [
     {
       "english_name": "NewTerm",
       "chinese_name": "新术语",
       "category": "分类",
       "difficulty": 1,
       "short_description": "一句话解释",
       "detail_description": "详细解释",
       "application": ["场景一"],
       "related_terms": ["AI"]
     }
   ]
   ```

3. 修改 [app_config.dart](lib/core/config/app_config.dart) 中的
   `remoteDictionaryBaseUrls`（多源回退列表），指向你的词库地址；
4. 重新构建发布。已安装的用户下次打开软件（或超过 24 小时后）会自动同步，无需重新安装。

> 每次发布新版本时把 `version.json` 的版本号调高（如 1.2.0），
> 软件会在下次检查时自动下载并增量添加新增词条。

> **同步源说明（多源回退）**：客户端按顺序尝试 `jsDelivr CDN → GitHub Raw`，
> 第一个可达的源生效，`version.json` 与 `terms.json` 始终来自同一源。
> jsDelivr 对 `@main` 分支内容有最长 12 小时缓存——对每周更新的词库节奏无感；
> 若要立即生效，可在 AI-Terms-Database 仓库打 tag（如 `v1.5.0`）并在 URL 中使用该 tag。

> **质量门禁**：发布词库前请运行 `python tool/validate_terms.py`（校验字段完整性、
> 重复词条、难度范围），也建议在 AI-Terms-Database 仓库的 CI 中作为门禁。

## AI 智能解释系统

### 使用前提

在「设置 → AI 服务设置」中填写：

- AI 服务地址（Base URL）：如 OpenAI `https://api.openai.com/v1`、DeepSeek `https://api.deepseek.com/v1`、Qwen DashScope 兼容地址、本地 Ollama 地址；
- API Key；
- 模型名称：如 `gpt-4o-mini`、`deepseek-chat`、`qwen-plus`、本地模型名。

### 使用方式

打开任意词条 → 点击右上角或底部的「AI 解释」→ 在**右侧 AI 解释侧边栏**中分模块展示
（一句话理解 / 详细解释 / 实际应用 / 为什么重要 / 相关概念），支持一键复制、重新生成。
侧边栏可通过顶部工具栏的 ✨ 按钮随时显示 / 隐藏。

### 缓存机制

- AI 解释缓存保存在 SQLite 的 `ai_explanation_cache` 表；
- 缓存按「词条 + 词条版本 + 模型名称」校验：重复查看不重复调用 API；
- 远程词库同步后若词条内容变化，词条 `version` 自动 +1，旧解释缓存自动失效并重新生成；
- 未配置 API Key / 网络失败 / 超时 / 空响应均有友好提示，不影响软件使用。

## 如何运行

### 环境要求

- Flutter 3.44+（Dart 3.12+），建议使用 [FVM](https://fvm.app/) 锁定版本（仓库已附 `.fvmrc`，`fvm use` 即可）
- Visual Studio 2022 Build Tools（含「使用 C++ 的桌面开发」工作负载）
- Windows 11 / 10

### 开发运行

```powershell
fvm use            # 使用 .fvmrc 锁定的 Flutter 版本（或直接使用已安装的 flutter）
fvm flutter pub get
fvm flutter test   # 运行全部测试
cd ..\ai-dict-build   # 目录联接（junction），可由 tool\build_windows.ps1 自动创建
fvm flutter run -d windows
```

> **国内网络提示**：测试依赖 `sqlite3` 包，首次运行会尝试从 GitHub 下载
> 预编译 DLL（`raw.githubusercontent.com` 在国内可能超时）。若 `flutter test`
> 报 "Building native assets failed"，执行：
>
> ```powershell
> $env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
> $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
> Invoke-WebRequest -Uri "https://ghfast.top/https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.1/sqlite3.x64.windows.dll" -OutFile "$env:TEMP\sqlite3.dll"
> New-Item -ItemType Directory -Force -Path ".dart_tool\hooks_runner\shared\sqlite3\build\download-e6ebc264" | Out-Null
> Copy-Item "$env:TEMP\sqlite3.dll" ".dart_tool\hooks_runner\shared\sqlite3\build\download-e6ebc264\sqlite3.dll" -Force
> flutter test   # 重新运行即可
> ```

> 与构建同理，`flutter run` 也需要在 ASCII 联接目录中执行。

### 构建 Release

> 注意：由于当前项目目录包含中文（`AI词典`），MSVC 构建管线会破坏非 ASCII 路径，
> 请通过 ASCII 名称的目录联接（junction）执行构建，脚本已自动处理：

```powershell
.\tool\build_windows.ps1
```

脚本会自动完成：构建 Release → 生成便携版 zip → 生成安装版 Setup.exe（需已安装
[Inno Setup 6](https://jrsoftware.org/isinfo.php)，或通过环境变量 `ISCC` 指定
`ISCC.exe` 路径）。

产物位置：
- `build\windows\x64\runner\Release\ai_dictionary.exe`（原始构建）
- `dist\AI-Dictionary-vX.Y.Z-windows.zip`（便携版）
- `dist\AI-Dictionary-vX.Y.Z-setup.exe`（安装版，含卸载程序）

### 数据位置

- 数据库：`%APPDATA%\com.aidictionary\AI Dictionary\ai_dictionary.db`
- 备份导出：`文档\AIDictionary\backups\ai_dictionary_backup_*.json`

首次启动自动从 `assets/data/terms/terms.json` 导入词库；后续在设置中可重置为初始数据。

## 如何继续扩展

### 1. 新增 / 修改词条

直接编辑 `assets/data/terms/terms.json`（JSON 数组），随后在设置中选择
「重置为初始数据」，或删除数据库后重启应用重新导入。

每个词条字段：

```json
{
  "english_name": "Agent",
  "chinese_name": "智能体",
  "category": "AI Agent",
  "difficulty": 2,
  "short_description": "一句话解释",
  "detail_description": "详细解释",
  "application": ["应用场景一", "应用场景二"],
  "related_terms": ["LLM", "RAG", "Memory"]
}
```

### 2. 接入 AI 功能（解释 / 问答 / 学习路径）

实现 `lib/services/ai/ai_service.dart` 中的 `AiService` 接口（调用 OpenAI /
DeepSeek API），然后在 `DictionaryProvider` 注入时替换 `StubAiService` 即可，
UI 层无需改动。设置对话框中的「AI 功能」区已预留入口。

### 3. 增加新设置项

- 在 `models/app_settings.dart` 增加字段；
- 在 `database/settings_dao.dart` 增加读写方法（或升级数据库版本迁移）；
- 在 `lib/screens/settings_dialog.dart` 增加 UI。

### 4. 数据库升级

修改 `AppConfig.databaseVersion`，并在 `AppDatabase` 中补充 `onUpgrade` 分支。

### 5. 图标与品牌

```powershell
python tool\generate_icon.py   # 重新生成 PNG + ICO
```

## 测试

```powershell
flutter test
```

覆盖：词条模型、搜索服务（中英 / 模糊 / 关键词）、SQLite DAO（排序、收藏、历史去重与上限、
设置）、JSON 词库完整性（1125 条、无重复、必备词条齐全）、主界面三栏交互与收藏流程、
远程同步（多源回退 / 24h 节流 / 增量更新保用户数据 / 网络降级）、自动备份、运行日志、
应用更新检查、版本一致性（50+ 个用例）。CI 同时运行 `dart analyze` 与 Windows Release 构建。

## Roadmap（规划中，尚未实现）

以下功能在设置页「AI 功能」中已预留入口，但**当前版本未实现**：

- **AI 问答**：就 AI 概念自由提问
- **学习路径**：输入目标自动生成学习路线
- **术语对比**：对比两个术语的异同
- **知识库连接**：对接 Obsidian / Markdown / 个人笔记

## 性能说明

- 词库当前全量加载到内存（约 1200 条，占内存 < 10MB），查询在内存中完成；
- 搜索框带 200ms 防抖，避免逐键全量重算；
- 词库规模在 **5000 条以内**无需任何改动；超过后建议引入 SQLite 分页查询
  （`terms` 表已建索引，DAO 层已预留按字母过滤的能力）。

## 词库内容授权

- **代码**：MIT License（见 [LICENSE](LICENSE)）；
- **词条内容**（`assets/data/terms/terms.json` 与远程词库）：采用
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.zh) 授权，
  可自由使用、修改与分发，需署名「AI Dictionary 词库」。

## 版本备份与恢复

项目已纳入 Git 版本管理，v1.0.0 为历史基线（已生成独立 ZIP 快照），
当前版本见 [CHANGELOG.md](CHANGELOG.md) 与 GitHub Releases。

### 日常开发建议

```powershell
git add -A
git commit -m "描述本次改动"
```

每次完成一个稳定功能后提交一次；出了问题可以随时回退。

### 恢复到历史版本

```powershell
git checkout v1.0.0 -- .
```

或放弃未提交改动：

```powershell
git checkout -- .
```

### 一键备份 / 一键恢复

```powershell
.\tool\backup.ps1      # 生成源码 + 程序 ZIP 到 "文档\AI词典备份"
.\tool\restore.ps1     # 从备份列表选择并恢复
```

基线快照：项目同级目录 `AI词典备份`（例如 `文档\AI词典备份`）

- `source-v1.0.0-20260808.zip` —— 全部源码（85 个文件）
- `app-v1.0.0-20260808.zip` —— 可运行 Release 程序（含图标、SQLite、资源）

> 提示：备份目录在项目文件夹之外，即使项目目录被误删，也能用 ZIP 完整恢复。

## 隐私与安全

- **数据本地存储**：词条、收藏、历史、设置与 AI 解释缓存全部保存在本机 SQLite（Windows 路径：`%APPDATA%\com.aidictionary\AI Dictionary\ai_dictionary.db`），不会上传到任何服务器。
- **启动同步**：仅从 `jsDelivr CDN`（主）与 `raw.githubusercontent.com`（备）读取 `version.json` / `terms.json`（多源回退），不发送任何个人数据。
- **AI 解释**：点击 AI 解释时，会把该词条的公开内容（名称 / 分类 / 描述 / 应用 / 相关词条）发送到你配置的模型服务（如 DeepSeek、OpenAI 或本地 Ollama / LM Studio）。请选择信任的服务商；使用本地模型时数据不会离开本机。
- **API Key 保护**：AI 服务 API Key 使用 Windows DPAPI 加密后存入本地数据库，仅当前 Windows 用户可解密（v1.8.0 起），旧版本明文会自动迁移。注意：DPAPI 绑定当前用户与机器，重装系统或更换电脑后需在设置中重新填写 API Key。
- **全局快捷键**：启用全局快捷搜索后，应用会在系统层面监听你设置的热键组合，仅用于触发搜索窗口，不记录其他按键。
- **杀软误报说明**：由于未代码签名 + 全局热键监听，部分杀毒软件可能误报。请从
  [官方 Releases](https://github.com/wyxy-20/AI-Dictionary/releases) 下载，
  并将软件加入信任区。应用不包含任何遥测、统计或广告 SDK。
- **运行日志**：运行日志写入 `%APPDATA%\com.aidictionary\AI Dictionary\logs\app.log`
  （仅本地，不上传）；设置页可一键复制日志用于反馈问题。
