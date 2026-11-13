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
## 场景 Grid 是 VBoxContainer（行距 36 = 格 32 + sep 4），行内 HBox 由脚本按 GRID 生成
const CELL_SIZE := Vector2(36, 32)  ## 普通字母格
const CELL_WIDE := Vector2(76, 32)  ## 退格 / 决定（更宽）
const CELL_SEPARATION := 4          ## 行内格间距（列距 40 = 36 + 4）
const HEART_SIZE := Vector2(18, 18)
const HEART_GAP := 16.0
#const CONFIRM_HEART_GAP := 22.0

#endregion

#region 节点引用

@onready var _title: Label = $Title
@onready var _entered_name: Label = $EnteredName
@onready var _grid: VBoxContainer = $Grid
@onready var _confirm_box: Control = $ConfirmBox
@onready var _confirm_name: Label = $ConfirmBox/ConfirmName
@onready var _confirm_no: Label = $ConfirmNo
@onready var _confirm_yes: Label = $ConfirmYes
@onready var _heart: TextureRect = $Heart
@onready var _confirm_tween: Tween

@onready var _confirm_box_position = _confirm_box.position
@onready var _confirm_box_rotation = _confirm_box.rotation
@onready var _confirm_box_scale = _confirm_box.scale

@export var snd_move: AudioStreamPlayer
@export var snd_ok: AudioStreamPlayer
@export var snd_cancel: AudioStreamPlayer

#endregion

var state := NameInputState.new()

var _cells: Array = []       ## 每行一个数组：_cells[r][c] → 格子 Label（与 GRID 同形）
var _slot := 0                ## 当前建档槽
var _cooldown := 0.0          ## 输入去抖剩余时间

func _ready() -> void:
	_build_grid()
	_refresh()
	var tween:= get_tree().create_tween().bind_node(self).set_loops()
	tween.tween_property(_confirm_name, "rotation_degrees", -1, 0.1).from(1)

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
	# GridContainer 可见后下一帧才完成排序，再刷一次让红心贴准格子
	await get_tree().process_frame
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
	var last_row := NameInputState.GRID.size() - 1
	for r: int in NameInputState.GRID.size():
		var row := HBoxContainer.new()
		row.name = "Row%d" % (r + 1)
		row.add_theme_constant_override("separation", CELL_SEPARATION)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(row)
		var row_cells: Array = NameInputState.GRID[r]
		var row_labels: Array = []
		for c: int in row_cells.size():
			var cell := Label.new()
			cell.name = "Label_" + row_cells[c]
			cell.text = row_cells[c]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# 末行末两格（退格 / 决定）更宽，其余 36×32
			cell.custom_minimum_size = CELL_WIDE if c >= row_cells.size() - 2 and r == last_row \
				else CELL_SIZE
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(cell)
			row_labels.append(cell)
		_cells.append(row_labels)


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
		if _confirm_tween:
			_confirm_tween.stop();
			_confirm_tween = null
		for row: Array in _cells:
			for cell: Label in row:
				cell.add_theme_color_override("font_color", COLOR_NORMAL)
		var selected := _cells[state.row][state.col] as Label
		var row: Control = selected.get_parent()
		selected.add_theme_color_override("font_color", COLOR_SELECTED)
		_heart.position = _grid.position + row.position + selected.position \
			+ Vector2((selected.size.x - HEART_SIZE.x) / 2, (selected.size.y - HEART_SIZE.y) / 2.0)
		return

	_confirm_name.text = state.name
	_confirm_yes.add_theme_color_override("font_color",
		COLOR_SELECTED if state.confirm_yes else COLOR_NORMAL)
	_confirm_no.add_theme_color_override("font_color",
		COLOR_NORMAL if state.confirm_yes else COLOR_SELECTED)

	if not _confirm_tween:
		_confirm_tween = get_tree().create_tween().bind_node(self).set_parallel()
		_confirm_tween.tween_property(_confirm_box, "position", _confirm_box_position, 3).from(_entered_name.position)
		_confirm_tween.tween_property(_confirm_box, "rotation", _confirm_box_rotation, 3).from(_entered_name.rotation)
		_confirm_tween.tween_property(_confirm_box, "scale", _confirm_box_scale, 3).from(_entered_name.scale)
		
	var target: Label = _confirm_yes if state.confirm_yes else _confirm_no
	_heart.position = target.position \
		+ Vector2((target.size.x - HEART_SIZE.x) / 2, (target.size.y - HEART_SIZE.y) / 2.0)

#endregion
