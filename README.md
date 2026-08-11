# AI Dictionary（AI 时代词典）

面向 AI 学习者的专业 AI 术语词典 —— Windows 桌面应用。

基于 **Flutter Desktop + Dart + SQLite** 构建，内置 **319 个 AI 术语**（英文 / 中文 / 分类 / 难度 / 简介 / 详细解释 / 应用场景 / 相关词条），支持实时搜索、A-Z 字母导航、收藏与浏览历史、**启动自动同步远程词库**，数据全部本地保存、可离线使用。

## 功能一览

- 三栏式现代界面（字母导航 / 词条列表 / 词条详情），可调整窗口大小
- 顶部实时搜索：英文、中文、关键词、模糊搜索（编辑距离容错）
- A-Z 首字母分组浏览，点击字母快速过滤
- 词条详情：难度星级、一句话解释、详细解释、应用场景、相关词条跳转
- 我的收藏：一键收藏 / 取消收藏，收藏列表
- 最近浏览：自动记录并去重，最多保留 100 条
- 设置：浅色 / 深色 / 跟随系统主题、界面语言（预留）、数据管理（导出备份、清空历史、重置词库）、关于
- 启动自动同步：打开软件即检查远程词库，自动增量下载新增词条，无需手动更新
- AI 智能解释：点击词条详情中的 AI 解释，自动调用大模型生成小白友好解释，SQLite 缓存、词条更新自动失效
- AI 服务设置：设置页可配置 OpenAI 兼容接口（地址 / API Key / 模型），兼容 OpenAI、DeepSeek、Qwen、本地模型

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
│   └── ai/ai_service.dart     # AI 功能预留接口 + Stub 实现
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

assets/data/terms/             # 26 个字母 JSON 词库（319 个词条）
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
- **无网络或远程不可达**时静默降级到本地 SQLite 词库，正常进入软件，不弹错误；
- 本地版本记录在 `dictionary_version` 表（version / update_time / terms_count / last_check_time）。

### 如何发布新的在线词库

项目已附带了可直接上传的远程词库目录 [AI-Terms-Database](AI-Terms-Database/)：
包含 `version.json`（1.1.0，1094 条）与 `terms.json`，字段与客户端完全兼容。

1. 在 GitHub 创建公开仓库 `AI-Terms-Database`（或任意名称）；
2. 把本项目的 `AI-Terms-Database/` 目录内容（`version.json`、`terms.json`、`README.md`）上传到仓库；

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
   `remoteDictionaryBaseUrl`，指向你的 GitHub Raw 地址；
4. 重新构建发布。已安装的用户下次打开软件（或超过 24 小时后）会自动同步，无需重新安装。

> 每次发布新版本时把 `version.json` 的版本号调高（如 1.2.0），
> 软件会在下次检查时自动下载并增量添加新增词条。

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

- Flutter 3.44+（Dart 3.12+）
- Visual Studio 2022 Build Tools（含「使用 C++ 的桌面开发」工作负载）
- Windows 11 / 10

### 开发运行

```powershell
flutter pub get
flutter test          # 运行全部测试
cd <build-dir>
flutter run -d windows
```

> 与构建同理，`flutter run` 也需要在 ASCII 联接目录中执行。

### 构建 Release

> 注意：由于当前项目目录包含中文（`AI词典`），MSVC 构建管线会破坏非 ASCII 路径，
> 请通过 ASCII 名称的目录联接（junction）执行构建，脚本已自动处理：

```powershell
.\tool\build_windows.ps1
```

产物位置：`build\windows\x64\runner\Release\ai_dictionary.exe`

### 数据位置

- 数据库：`%APPDATA%\com.aidictionary\AI Dictionary\ai_dictionary.db`
- 备份导出：`文档\AIDictionary\backups\ai_dictionary_backup_*.json`

首次启动自动从 `assets/data/terms/*.json` 导入词库；后续在设置中可重置为初始数据。

## 如何继续扩展

### 1. 新增 / 修改词条

直接编辑 `assets/data/terms/<字母>.json`（JSON 数组），随后在设置中选择
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
设置）、JSON 词库完整性（319 条、无重复、必备词条齐全）、主界面三栏交互与收藏流程。

## 版本备份与恢复

项目已纳入 Git 版本管理，当前稳定版基线为 **v1.0.0**，并已生成独立 ZIP 快照，
未来任何时候都可以恢复到当前状态。

### 日常开发建议

```powershell
git add -A
git commit -m "描述本次改动"
```

每次完成一个稳定功能后提交一次；出了问题可以随时回退。

### 恢复到 v1.0.0（当前版本）

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

基线快照：`<backup-dir>\`

- `source-v1.0.0-20260808.zip` —— 全部源码（85 个文件）
- `app-v1.0.0-20260808.zip` —— 可运行 Release 程序（含图标、SQLite、资源）

> 提示：备份目录在项目文件夹之外，即使项目目录被误删，也能用 ZIP 完整恢复。
