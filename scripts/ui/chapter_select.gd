extends Control
## 章节选择菜单（Undertale/Deltarune 风格红心光标菜单原型）。
## 节点结构在 chapter_menu.tscn 中编排；本脚本只负责输入处理与状态到视图的同步。
## 状态逻辑在 ChapterSelectState（纯逻辑类，可单测）。

#region 配置：章节数据与语言

## 各章节行锁定状态（与场景 Rows/RowN 一一对应；文案走 assets/locales/translations.csv）
const LOCKED_ROWS: Array[bool] = [false, false, false, false, false, false, true]

## 状态机 language 索引 → locale 代码
const LOCALES: Array[String] = ["zh", "ja"]

#endregion

#region 配置：配色与动态布局

const COLOR_WHITE := Color.WHITE      ## 未选中文字/图标
const COLOR_YELLOW := Color("ffff00") ## 选中态（Deltarune 黄）
const COLOR_GRAY := Color("7F7F7F")   ## 锁定行

const INPUT_COOLDOWN := 0.15          ## 输入去抖（秒）

## 各行中心 y（对应场景行边界 0/62/122/.../422）
const ROW_CENTERS: Array[float] = [31.0, 92.0, 152.0, 212.0, 272.0, 332.0, 392.0]
const X_HEART_ROW := 30.0             ## 行选中态红心 x（该行没有锚定 Label，固定值）
const HEART_GAP_X := 26.0             ## 红心右缘与所锚定文字左缘的间距
const HEART_FOOTER_DY := 6.0          ## 页脚态红心相对文字 y 偏移

#endregion

#region 节点引用（场景节点，@onready 绑定）

@onready var _rows: Array[Node] = $Rows.get_children()  ## Row1..Row7，顺序即章节顺序
@onready var _exit_label: Label = $ExitLabel
@onready var _heart: TextureRect = $Heart
@onready var _fade_rect: ColorRect = $Fade
@onready var _loading_label: Label = $LoadingLabel
@onready var _snd_move: AudioStreamPlayer = $SndMove
@onready var _snd_ok: AudioStreamPlayer = $SndOk
@onready var _snd_cancel: AudioStreamPlayer = $SndCancel

var state: ChapterSelectState
var _chapter_labels: Array[Label] = []  ## 各行「第N章」
var _name_labels: Array[Label] = []     ## 各行章节名（子菜单展开时隐藏）
var _play_labels: Array[Label] = []     ## 各行子菜单「游玩」（场景内定位，脚本只显隐）
var _back_labels: Array[Label] = []     ## 各行子菜单「返回」
var _star_lists: Array[Array] = []      ## 各行星列（TextureRect 数组）
var _icons: Array[TextureRect] = []     ## 各行章节图标

var _cooldown := 0.0                    ## 输入去抖剩余时间
var _fading := false                    ## 渐隐 Tween 进行中（期间屏蔽输入）

#endregion


func _ready() -> void:
	state = ChapterSelectState.new(LOCKED_ROWS)
	## 按行缓存子节点引用（容器布局不改变节点路径）
	for row: Node in _rows:
		_chapter_labels.append(row.get_node("Margin/Line/ChapterLabel"))
		_name_labels.append(row.get_node("NameLabel"))
		_play_labels.append(row.get_node("RowPlay"))
		_back_labels.append(row.get_node("RowBack"))
		_icons.append(row.get_node("Margin/Line/Icon"))
		_star_lists.append(row.get_node("Margin/Line/Stars").get_children())
	#_apply_language()
	_apply_focus()


#region 输入

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## 键盘输入入口：FADE_OUT 态只接受「任意键返回菜单」，其余状态走动作映射
func _unhandled_input(event: InputEvent) -> void:
	## FADE_OUT(PLAY)：加载字样显示后任意键返回菜单
	if state.state == ChapterSelectState.State.FADE_OUT:
		if _fading or state.pending != ChapterSelectState.Pending.PLAY:
			return
		if event is InputEventKey and event.is_pressed():
			_return_from_loading()
		return

	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if _cooldown > 0.0:
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
		print(state.debug_text())


## 应用一次移动：状态机变更成功才播音效并刷新视图（无效移动静默）
func _apply_move(action: Callable) -> void:
	var before := _focus_signature()
	action.call()
	if _focus_signature() != before:
		_snd_move.play()
		_after_state_change()


## 应用确认键：语言切换单独处理（需重翻文案）；进入 FADE_OUT 时启动渐隐 Tween
func _apply_ok() -> void:
	var old_state := state.state
	state.press_ok()
	if state.state != old_state:
		_snd_ok.play()
		_after_state_change()
		if state.state == ChapterSelectState.State.FADE_OUT:
			_start_fade_tween()


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


## 焦点签名：cursor 与子菜单项的合成值，用于判断一次移动是否生效
func _focus_signature() -> int:
	return state.cursor * 4 + state.sub_item


## 把状态机焦点映射到视图：行配色、子菜单显隐与配色、红心位置、页脚配色。
## 子菜单「游玩/返回」已按行在场景内定位，这里只做显隐与着色，不做位置计算。
func _apply_focus() -> void:
	var sub_open := state.state == ChapterSelectState.State.SUBMENU_OPEN
	var on_footer := not state.on_row()

	for i: int in ChapterSelectState.ROW_COUNT:
		var locked: bool = LOCKED_ROWS[i]
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
		_heart.position.y = ROW_CENTERS[state.cursor] - _heart.size.y / 2.0
	elif on_footer:
		_heart.position.x = (_exit_label.position.x) - HEART_GAP_X
		_heart.position.y = _exit_label.position.y + HEART_FOOTER_DY
		_setup_label_selected(_exit_label, state.cursor == ChapterSelectState.FOOTER_EXIT)
	else:
		_heart.position.x = X_HEART_ROW
		_heart.position.y = ROW_CENTERS[state.cursor] - _heart.size.y / 2.0
		_setup_label_selected(_exit_label, false)

func _setup_label_selected(node: Control, selected: bool) -> void:
	node.add_theme_color_override("font_color", COLOR_YELLOW if selected else COLOR_WHITE)

## 行选中态配色：选中=黄，锁定=灰，普通=白
func _apply_row_colors(i: int, color: Color) -> void:
	_chapter_labels[i].add_theme_color_override("font_color", color)
	_name_labels[i].add_theme_color_override("font_color", color)
	for star: TextureRect in _star_lists[i]:
		star.modulate = color
	_icons[i].modulate = color

#endregion


#region 渐隐过渡


## 渐入纯黑（1.5s）：游玩加载与退出共用
func _start_fade_tween() -> void:
	_fading = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 1.5)
	tween.finished.connect(_on_fade_in_done)


## 渐隐完成：游玩→按行设加载字样 key（自动翻译）并等待任意键；退出→结束程序
func _on_fade_in_done() -> void:
	_fading = false
	if state.pending == ChapterSelectState.Pending.PLAY:
		_loading_label.text = "LOADING_CHAPTER_%d" % (state.loading_row + 1)
		_loading_label.visible = true
	else:
		get_tree().quit()


## 加载字样下按任意键：淡出黑幕回菜单（0.3s），状态机回到 ROW_SELECTED
func _return_from_loading() -> void:
	_loading_label.visible = false
	state.finish_fade()
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.3)
	tween.finished.connect(_after_state_change)
	_cooldown = INPUT_COOLDOWN

#endregion
