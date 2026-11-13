extends Control
## 章节选择菜单（Undertale/Deltarune 风格红心光标菜单原型）。
## 节点结构在 chapter_menu.tscn 中编排；本脚本只负责输入处理与状态到视图的同步。
## 状态逻辑在 ChapterSelectState（纯逻辑类，可单测）。

#region 配置：章节数据

const CHAPTER_SHEET := preload("res://assets/graphics/ui/chapter.png")

## 子菜单「游玩/返回」默认几何：行内垂直居中（高 32），游玩 x=252；例外行用数据键覆盖
const SUB_DEFAULT := {"height": 32.0, "play_left": 252.0}

## 各章内容与规则：文案 / 锁定 / 图标（chapter.png 区域）/ 子菜单几何例外
const CHAPTERS: Array[Dictionary] = [
	{"chapter": "第1章", "name": "开端", "locked": true, "icon": Rect2(27, 14, 28, 25)},
	{"chapter": "第2章", "name": "赛博世界", "locked": true, "icon": Rect2(54, 14, 28, 25)},
	{"chapter": "第3章", "name": "深夜", "locked": true, "icon": Rect2(216, 14, 28, 25)},
	{"chapter": "第4章", "name": "预言", "locked": true, "icon": Rect2(108, 14, 28, 25)},
	{"chapter": "第?章", "name": "???", "locked": false, "icon": Rect2(243, 14, 28, 25),
		"sub_height": 42.0, "sub_play_left": 244.0},
	{"chapter": "第5章", "name": "庆典日", "locked": true, "icon": Rect2(135, 14, 28, 25)},
	{"chapter": "第6章", "name": "--", "locked": true, "icon": Rect2(0, 14, 28, 25)},
]

#endregion

#region 配置：配色与动态布局

const COLOR_WHITE := Color.WHITE      ## 未选中文字/图标
const COLOR_YELLOW := Color("ffff00") ## 选中态（Deltarune 黄）
const COLOR_GRAY := Color("7F7F7F")   ## 锁定行

const INPUT_COOLDOWN := 0.15          ## 输入去抖（秒）
const TRANSITION_SCALE_DUR := 3.0     ## 游玩转场：横向压缩时长（秒）
const TRANSITION_FADE_DUR := 2.0      ## 游玩转场：淡出时长（秒）
const TRANSITION_END_SCALE := Vector2(0.0, 0.8) ## 游玩转场终态缩放（原版横向收拢）

## 各行红心 x（该行没有锚定 Label，固定值）
const X_HEART_ROW := 30.0
const HEART_GAP_X := 26.0             ## 红心右缘与所锚定文字左缘的间距
const HEART_FOOTER_DY := 6.0          ## 页脚态红心相对文字 y 偏移

#endregion

#region 节点引用（场景节点，@onready 绑定）

@onready var _rows: Array[Node] = $Rows.get_children()  ## Row1..Row7，顺序即章节顺序
@onready var _exit_label: Label = $ExitLabel
@onready var _heart: TextureRect = $Heart
@onready var _snd_move: AudioStreamPlayer = $SndMove
@onready var _snd_ok: AudioStreamPlayer = $SndOk
@onready var _snd_cancel: AudioStreamPlayer = $SndCancel
@onready var _snd_begin: AudioStreamPlayer = $SndBegin
@onready var _snd_bg: AudioStreamPlayer = $SndBg

var state: ChapterSelectState
var _chapter_labels: Array[Label] = []  ## 各行「第N章」
var _name_labels: Array[Label] = []     ## 各行章节名（子菜单展开时隐藏）
var _play_labels: Array[Label] = []     ## 各行子菜单「游玩」（场景内定位，脚本只显隐）
var _back_labels: Array[Label] = []     ## 各行子菜单「返回」
var _stars: Array[TextureRect] = []     ## 各行星星（单节点，随行配色）
var _icons: Array[TextureRect] = []     ## 各行章节图标

var _cooldown := 0.0                    ## 输入去抖剩余时间
var _transitioning := false             ## 转场 Tween 进行中（期间屏蔽输入）
var _row_centers: Array[float] = []     ## 各行中心 y（由场景行高派生，行高只在场景维护）

#endregion


func _ready() -> void:
	## 按行缓存子节点引用并填充章节数据（容器布局不改变节点路径）
	var locked: Array[bool] = []
	var top := 0.0
	for i: int in _rows.size():
		var row: Node = _rows[i]
		_chapter_labels.append(row.get_node("Margin/Line/ChapterLabel"))
		_name_labels.append(row.get_node("NameLabel"))
		_play_labels.append(row.get_node("RowPlay"))
		_back_labels.append(row.get_node("RowBack"))
		_icons.append(row.get_node("Margin/Line/Icon"))
		_stars.append(row.get_node("Margin/Line/Stars"))
		_apply_row_content(i, row)
		locked.append(CHAPTERS[i]["locked"])
		var height := (row as Control).custom_minimum_size.y
		_row_centers.append(top + height / 2.0)
		top += height
	state = ChapterSelectState.new(locked)
	#_apply_language()
	_apply_focus()
	_apply_move(func() -> void: state.move_down())


#region 章节数据填充

## 把章节数据填进行内节点：文案、图标、子菜单标签几何（锁定派生在 _ready）
func _apply_row_content(i: int, row: Node) -> void:
	var data := CHAPTERS[i]
	(_chapter_labels[i] as Label).text = data["chapter"]
	(_name_labels[i] as Label).text = data["name"]
	var icon := AtlasTexture.new()
	icon.atlas = CHAPTER_SHEET
	icon.region = data["icon"]
	(_icons[i] as TextureRect).texture = icon
	var height: float = data.get("sub_height", SUB_DEFAULT["height"])
	var play_left: float = data.get("sub_play_left", SUB_DEFAULT["play_left"])
	var top := ((row as Control).custom_minimum_size.y - height) / 2.0
	for label: Label in [_play_labels[i], _back_labels[i]]:
		label.offset_top = top
		label.offset_bottom = top + height
	(_play_labels[i] as Label).offset_left = play_left
	(_play_labels[i] as Label).offset_right = play_left + 168.0

#endregion


#region 输入

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## 键盘输入入口：按动作映射分派
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if _transitioning or _cooldown > 0.0:
		return

	if event.is_action_pressed("move_up"):
		_apply_move(func() -> void: state.move_up())
	elif event.is_action_pressed("move_down"):
		_apply_move(func() -> void: state.move_down())
	elif event.is_action_pressed("move_left"):
		_apply_move(func() -> void: state.move_left())
	elif event.is_action_pressed("move_right"):
		_apply_move(func() -> void: state.move_right())
	elif event.is_action_pressed("menu_ok"):
		_apply_ok()
	elif event.is_action_pressed("menu_cancel"):
		_apply_cancel()
	elif event.physical_keycode == KEY_F:
		GameLogger.debug(state.debug_text())


## 应用一次移动：状态机变更成功才播音效并刷新视图（无效移动静默）
func _apply_move(action: Callable) -> void:
	var before := _focus_signature()
	action.call()
	if _focus_signature() != before:
		_snd_move.play()
		_after_state_change()


## 应用确认键：状态变化播 snd_ok；确认产生动作时播 snd_ok 并发对应信号
func _apply_ok() -> void:
	var old_state := state.state
	var action := state.press_ok()
	if state.state != old_state:
		_snd_ok.play()
		_after_state_change()
	match action:
		ChapterSelectState.Action.PLAY:
			_snd_ok.play()
			_start_play_transition(state.play_row)
		ChapterSelectState.Action.EXIT:
			_snd_ok.play()
			GameManager.exit_game()


## 应用取消键：状态实际变化才播音效刷新
func _apply_cancel() -> void:
	var old_state := state.state
	state.press_cancel()
	if state.state != old_state:
		_snd_cancel.play()
		_after_state_change()

#endregion


#region 状态到视图

## 每次状态变更的统一出口：刷新视图 + 重置去抖
func _after_state_change() -> void:
	_apply_focus()
	_cooldown = INPUT_COOLDOWN


## 焦点签名：cursor 与子菜单项的合成值（sub_item 占低位，cursor * 4 不进位），
## 用于判断一次移动是否生效
func _focus_signature() -> int:
	return state.cursor * 4 + state.sub_item


## 把状态机焦点映射到视图：行配色、子菜单显隐与配色、红心位置、页脚配色。
## 子菜单「游玩/返回」已按行在场景内定位，这里只做显隐与着色，不做位置计算。
func _apply_focus() -> void:
	var sub_open := state.state == ChapterSelectState.State.SUBMENU_OPEN
	var on_footer := not state.on_row()

	for i: int in ChapterSelectState.ROW_COUNT:
		var locked: bool = state.locked[i]
		var selected: bool = not locked and not on_footer and state.cursor == i
		_apply_row_colors(i, COLOR_YELLOW if selected else (COLOR_GRAY if locked else COLOR_WHITE))
		var in_row: bool = sub_open and state.cursor == i
		_name_labels[i].visible = not in_row
		_play_labels[i].visible = in_row
		_back_labels[i].visible = in_row
		if in_row:
			_setup_label_selected(_play_labels[i], state.sub_item == ChapterSelectState.SubItem.PLAY)
			_setup_label_selected(_back_labels[i], state.sub_item == ChapterSelectState.SubItem.BACK)

	if sub_open:
		_heart.position.x = (_play_labels[state.cursor].global_position.x
			if state.sub_item == ChapterSelectState.SubItem.PLAY
			else _back_labels[state.cursor].global_position.x) - HEART_GAP_X
		_heart.position.y = _row_centers[state.cursor] - _heart.size.y / 2.0
	elif on_footer:
		_heart.position.x = (_exit_label.position.x) - HEART_GAP_X
		_heart.position.y = _exit_label.position.y + HEART_FOOTER_DY
		_setup_label_selected(_exit_label, state.cursor == ChapterSelectState.FOOTER_EXIT)
	else:
		_heart.position.x = X_HEART_ROW
		_heart.position.y = _row_centers[state.cursor] - _heart.size.y / 2.0
		_setup_label_selected(_exit_label, false)

func _setup_label_selected(node: Control, selected: bool) -> void:
	node.add_theme_color_override("font_color", COLOR_YELLOW if selected else COLOR_WHITE)

## 行选中态配色：选中=黄，锁定=灰，普通=白
func _apply_row_colors(i: int, color: Color) -> void:
	_chapter_labels[i].add_theme_color_override("font_color", color)
	_name_labels[i].add_theme_color_override("font_color", color)
	(_stars[i] as TextureRect).modulate = color
	_icons[i].modulate = color

#endregion


#region 转场

## 游玩转场：菜单横向压缩并淡出，结束后再切换场景
func _start_play_transition(row: int) -> void:
	_transitioning = true
	## 音效跨场景播放：挂到根节点，避免随菜单释放被截断
	_snd_bg.stop()
	_snd_begin.play()
	var tween := create_tween()
	tween.tween_property(self, "scale", TRANSITION_END_SCALE, TRANSITION_SCALE_DUR)
	tween.parallel().tween_property(self, "modulate:a", 0.0, TRANSITION_FADE_DUR)
	await tween.finished
	await _snd_begin.finished
	GameManager.play_chapter(row)

#endregion
