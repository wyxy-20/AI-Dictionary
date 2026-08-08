# AI Dictionary（AI 时代词典）

面向 AI 学习者的专业 AI 术语词典 —— Windows 桌面应用。

基于 **Flutter Desktop + Dart + SQLite** 构建，内置 **319 个 AI 术语**（英文 / 中文 / 分类 / 难度 / 简介 / 详细解释 / 应用场景 / 相关词条），支持实时搜索、A-Z 字母导航、收藏与浏览历史，数据全部本地保存、可离线使用。

## 功能一览

- 三栏式现代界面（字母导航 / 词条列表 / 词条详情），可调整窗口大小
- 顶部实时搜索：英文、中文、关键词、模糊搜索（编辑距离容错）
- A-Z 首字母分组浏览，点击字母快速过滤
- 词条详情：难度星级、一句话解释、详细解释、应用场景、相关词条跳转
- 我的收藏：一键收藏 / 取消收藏，收藏列表
- 最近浏览：自动记录并去重，最多保留 100 条
- 设置：浅色 / 深色 / 跟随系统主题、界面语言（预留）、数据管理（导出备份、清空历史、重置词库）、关于
- AI 功能架构预留：`AiService` 接口 + 占位实现，后续接入 OpenAI / DeepSeek 即可

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
│   └── app_settings.dart      # 设置模型
├── services/
│   ├── seed_service.dart      # 首次启动导入 JSON 词库
│   ├── search_service.dart    # 高级搜索（中英 / 关键词 / 模糊）
│   ├── data_export_service.dart # 词库 JSON 备份导出
│   └── ai/ai_service.dart     # AI 功能预留接口 + Stub 实现
├── providers/
│   ├── dictionary_provider.dart # 词库、搜索、视图、收藏、历史状态
│   └── settings_provider.dart   # 主题 / 语言状态
├── screens/
│   ├── home_screen.dart       # 主界面（顶栏 + 三栏）
│   └── settings_dialog.dart   # 设置对话框
├── widgets/                   # 左侧导航、词条列表、详情、搜索框等组件
└── utils/string_utils.dart    # 编辑距离、搜索高亮等工具

assets/data/terms/             # 26 个字母 JSON 词库（319 个词条）
test/                          # 单元测试 + 组件测试（27 个用例）
tool/generate_icon.py          # 应用图标生成脚本
```

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
