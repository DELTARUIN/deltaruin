class_name NameInputView
extends Control
## 新建存档名字输入覆盖层：A–Z 网格 + 退格 / 决定 +「这就是你的名字」确认页。
## 状态逻辑在 NameInputState；本脚本只做输入分派与状态到视图的同步。

#region 信号

signal completed(slot: int, player_name: String) ## 确认页选「是」，请求建档
signal cancelled                                ## 输入页取消，丢弃输入

#endregion

#region 常量

const INPUT_COOLDOWN := 0.15

const TITLE_ENTRY := "输入你自己的名字。"
const TITLE_CONFIRM := "这就是你的名字。"

const COLOR_SELECTED := Color("ffff00") ## 选中态（Deltarune 黄）
const COLOR_NORMAL := Color.WHITE

const FONT_NAME := 24

## 网格布局（640×480 逻辑坐标，由录屏换算）
const GRID_ORIGIN := Vector2(136, 148)
const CELL_STEP := Vector2(40, 36)
const CELL_SIZE := Vector2(36, 32)
const ROW3_OFFSETS: Array[float] = [0.0, 40.0, 80.0, 120.0, 160.0, 200.0, 250.0, 330.0]
const HEART_SIZE := Vector2(18, 18)
const HEART_GAP := 16.0
#const CONFIRM_HEART_GAP := 22.0

#endregion

#region 节点引用

@onready var _title: Label = $Title
@onready var _entered_name: Label = $EnteredName
@onready var _grid: Control = $Grid
@onready var _confirm_name: Label = $ConfirmName
@onready var _confirm_no: Label = $ConfirmNo
@onready var _confirm_yes: Label = $ConfirmYes
@onready var _heart: TextureRect = $Heart

@export var snd_move: AudioStreamPlayer
@export var snd_ok: AudioStreamPlayer
@export var snd_cancel: AudioStreamPlayer

#endregion

var state := NameInputState.new()

var _cells: Array[Label] = [] ## 网格格子（行优先展开）
var _slot := 0                ## 当前建档槽
var _cooldown := 0.0          ## 输入去抖剩余时间


func _ready() -> void:
	_build_grid()
	_refresh()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


#region 对外接口

## 打开覆盖层：重置输入并绑定槽号
func open(slot: int) -> void:
	_slot = slot
	state.reset()
	visible = true
	_cooldown = INPUT_COOLDOWN
	_refresh()

#endregion

#region 输入

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _cooldown > 0.0:
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		_move(state.move_up)
	elif event.is_action_pressed("move_down"):
		_move(state.move_down)
	elif event.is_action_pressed("move_left"):
		_move(state.move_left)
	elif event.is_action_pressed("move_right"):
		_move(state.move_right)
	elif event.is_action_pressed("menu_ok"):
		_ok()
	elif event.is_action_pressed("menu_cancel"):
		_cancel()
	elif event.physical_keycode == KEY_F:
		GameLogger.debug(state.debug_text())
		return
	else:
		return
	get_viewport().set_input_as_handled()


## 移动：焦点真正变化才播音效
func _move(action: Callable) -> void:
	var before := _signature()
	action.call()
	if _signature() != before:
		snd_move.play()
	_refresh()


## 确认：录入 / 进确认页 / 确认「是」都算一次有效操作
func _ok() -> void:
	var before := _signature()
	var action := state.press_ok()
	if _signature() != before or action != NameInputState.Action.NONE:
		snd_ok.play()
	if action == NameInputState.Action.START:
		completed.emit(_slot, state.name)
	_refresh()


## 取消：确认页退回输入页；输入页发 cancelled 由父菜单关闭
func _cancel() -> void:
	var action := state.press_cancel()
	snd_cancel.play()
	if action == NameInputState.Action.EXIT:
		cancelled.emit()
	_refresh()


## 焦点签名：状态 / 行列 / 名字 / 是或否，用于判断一次操作是否生效
func _signature() -> String:
	return "%d|%d|%d|%s|%s" % [state.mode, state.row, state.col, state.name, state.confirm_yes]

#endregion

#region 状态到视图

func _build_grid() -> void:
	for r: int in NameInputState.GRID.size():
		var row_cells: Array = NameInputState.GRID[r]
		for c: int in row_cells.size():
			var cell := Label.new()
			cell.name = "Label_" + row_cells[c]
			cell.text = row_cells[c]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.position = _cell_position(r, c)
			cell.size = CELL_SIZE
			_grid.add_child(cell)
			_cells.append(cell)


func _refresh() -> void:
	var entry := state.mode == NameInputState.Mode.ENTRY
	_title.text = TITLE_ENTRY if entry else TITLE_CONFIRM
	_entered_name.visible = entry
	_grid.visible = entry
	_confirm_name.visible = not entry
	_confirm_no.visible = not entry
	_confirm_yes.visible = not entry

	_entered_name.text = state.name
	_entered_name.add_theme_color_override("font_color",
		COLOR_SELECTED if state.name.length() >= NameInputState.MAX_NAME else COLOR_NORMAL)

	if entry:
		for cell: Label in _cells:
			cell.add_theme_color_override("font_color", COLOR_NORMAL)
		var selected := _cells[_cell_index(state.row, state.col)] as Label
		selected.add_theme_color_override("font_color", COLOR_SELECTED)
		_heart.position = selected.position \
			+ Vector2((selected.size.x - HEART_SIZE.x) / 2, (selected.size.y - HEART_SIZE.y) / 2.0)
		return

	_confirm_name.text = state.name
	_confirm_yes.add_theme_color_override("font_color",
		COLOR_SELECTED if state.confirm_yes else COLOR_NORMAL)
	_confirm_no.add_theme_color_override("font_color",
		COLOR_NORMAL if state.confirm_yes else COLOR_SELECTED)
	var target: Label = _confirm_yes if state.confirm_yes else _confirm_no
	_heart.position = target.position \
		+ Vector2((target.size.x - HEART_SIZE.x) / 2, (target.size.y - HEART_SIZE.y) / 2.0)


func _cell_position(r: int, c: int) -> Vector2:
	var x := CELL_STEP.x * c
	if r == NameInputState.GRID.size() - 1:
		x = ROW3_OFFSETS[c]
	return GRID_ORIGIN + Vector2(x, CELL_STEP.y * r)


## 行优先展开后的下标（第三行长度不同，不能直接用 row * 10 + col）
func _cell_index(r: int, c: int) -> int:
	var index := 0
	for i: int in r:
		index += (NameInputState.GRID[i] as Array).size()
	return index + c

#endregion
