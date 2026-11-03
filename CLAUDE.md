# AGENTS.md

## 项目概览

- Godot 4.6（GDScript）2D 游戏《DELTARUIN》，三角符号风格（Deltarune 致敬）。GL Compatibility 渲染器；像素风：640×480 视口（stretch=viewport + 整数缩放）、纹理过滤 nearest（`default_texture_filter=0`）。
- 目录职责：`scripts/`（代码，按 `autoload/`、`player/`、`ui/` 分子目录）、`scenes/`（场景）、`resources/`（.tres 资源）、`assets/`（美术/音频/字体）、`addons/`（第三方插件）。
- `demo/`（LimboAI 官方 demo）和 `docs/` 是**第三方参考资料，不是游戏代码**，勿在其中实现功能或随意修改。
- 主场景：`scenes/game_main.tscn`。

## 常用命令

- GUT 测试已安装（`addons/gut`），测试在 `tests/` 下。运行全部：
  `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  （本机 godot 可执行文件：`D:\Program Files\Godot\Godot_v4.6.3-stable_win64_console.exe`）
- 跑单个测试：`-gdir=res://tests` 换成 `-gtest=<测试类名或路径>`。
- 新增 `class_name` 后 headless GUT 立刻跑会报「type not found」：全局类缓存未重建。先 `godot --headless --editor --quit --path .` 扫一遍，再跑测试。

## 插件与 Autoload（避免命名冲突）

- **已启用插件**：GUT、script-ide、dialogic、scene_manager。
- 当前唯一 autoload：`GameLogger`（`scripts/autoload/game_logger.gd`）。**打日志用 `GameLogger.info/warn/error/debug(...)`，不要用裸 `print`**（支持 tag、等级过滤、写文件轮转，详见该文件头部注释）。
- 新建全局单例时避开 `GameLogger` 及各插件的autoload 名；如需场景切换/音频能力，注意 dialogic、limboai 等已装未启用，先启用再评估，不要重复造轮子。

## 代码规范

### 基础格式

- 编码 UTF-8（无 BOM），文件末尾必须有换行符，行尾统一 LF（`.gitattributes` 强制 `* text=auto eol=lf`）。
- 缩进使用 Tab，不用空格。
- 续行代码块使用两个缩进级别；数组、字典、枚举的换行可例外。
- **代码注释用中文**。

### 命名

- 变量、信号与函数：`snake_case`，如 `var move_speed`、`signal health_changed`、`func take_damage()`。
- 类名：`PascalCase`，如 `class_name PlayerController`。
- 常量：全大写 `SNAKE_CASE`，如 `const MAX_HEALTH := 100`。
- 私有成员：前缀下划线，如 `var _is_moving`、`func _die()`。

### 类型与函数

- 必须使用静态类型标注（利于可读性与自动补全），返回值用箭头声明：`func heal(amount: int) -> void:`。
- 引擎生命周期函数保持原名：`_ready()`、`_process()`、`_physics_process()`，勿改名或手写变体。

### 代码组织

- 用 `#region` / `#endregion` 区域注释分组代码（见 `scripts/ui/chapter_select.gd`）。
- 文件顶部放置常量、类定义、信号；节点引用统一用 `@onready` 获取，保持脚本整洁。
- 可单测的纯逻辑拆成独立类（如 `ChapterSelectState`），与场景脚本分离。

### 场景与脚本的分工

- **节点结构一律在 `.tscn` 场景文件中编排**（节点、布局、纹理、字体、音效等静态属性），禁止在脚本 `_ready()` 里批量 `new` + `add_child` 构建节点——否则场景文件失去意义。场景可在编辑器中可视化调整，代码构建的节点不能。
- 脚本只负责**行为**：输入处理、状态逻辑、以及少量动态同步（改文本、显隐、着色、位置、Tween 过渡）。
- 重复结构的节点（如列表行）在场景里复制编排；数据驱动的差异（文案、锁定状态等）放脚本常量数组，用 `@onready` 缓存节点引用后同步。
- 例外：纯运行时对象（Tween、AtlasTexture 等临时资源、一次性特效）可以在代码中创建。

### 文件命名

- 场景与 GDScript：`snake_case`，如 `player_character.tscn`、`player_controller.gd`。

## 已知坑与经验（实测踩过的）

### 文件编码（本机系统代码页 GBK，PowerShell 5.1）

- **不要用 `Get-Content` / `Set-Content` 轮转含中文的 UTF-8 文件**（.tscn/.gd/.md）：PS 会按 GBK 读入再写出，中文全部乱码。改文件用编辑器或 Write/Edit 类工具；批量修改优先此类工具，实在要用 PS 就 `[System.IO.File]::ReadAllText/WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))`。
- PS 5.1 的 `-Encoding UTF8` 写出**带 BOM**，违反本项目「无 BOM」约定（.tscn 含中文，同样适用）。

### Godot / GDScript

- `for x in dict` 迭代字典得到的是**键**，不是值；要值用 `dict.values()` 或键值对数组。
- HBox/VBoxContainer 默认 `separation = 4`。像素级对齐布局时显式设 `separation = 0`，否则子元素被顶开 4px 还很难看出来。
- 编辑器重新保存手写的 `.tscn` 时会补 uid、加 `unique_id`、调整属性顺序，属正常现象，不要当作冲突回退。

### 既有噪音（headless 运行时过滤，不是回归）

- `SCRIPT ERROR: Invalid access to property or key 'scene_file_path'` 来自 GUT 插件，任何 headless `-s` 运行都报。
- limboai 缺 `liblimboai.windows.editor.x86_64.dll`，`--editor --quit` 扫描时报错，仓库既有问题（demo 附带）。

### 字体

- `assets/fonts/normal.ttf` 覆盖中日文但**缺 ASCII 数字、`-`、`©`、`v`**。数字/拉丁混排（如「第1章」、版权行）需挂 `assets/fonts/8bit.ttf` 做 fallback，参考 `scripts/ui/chapter_select.gd` 的字体构建。新 UI 先用 FontFile `has_char()` 验证覆盖再动手。

### 本地技能

- `.claude/skills/` 内置 `godot-docs`（Godot 4.6 本地 API 文档）与 `gdmcp`（gdmcp CLI 检查/运行 Godot 项目），Godot API 问题优先查本地文档而非记忆。
