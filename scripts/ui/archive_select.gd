extends Control
## 存档选择菜单（Undertale/Deltarune 风格红心光标选档）。
## 节点结构在 archive_menu.tscn 中编排；本脚本只负责输入处理与状态到视图的同步。
## 状态逻辑在 ArchiveSelectState（纯逻辑类，可单测）。

#region 信号

signal file_selected(slot: int) ## 确认「开始」：slot 为存档槽索引（0 起）
signal exit_requested           ## 选档界面请求返回

#endregion

#region 常量：交互参数

const INPUT_COOLDOWN := 0.15          ## 输入去抖（秒）

const EMPTY_NAME := "[空白]"          ## 空槽玩家名占位（与场景默认文案一致）
const EMPTY_TIME := "--:--"           ## 空槽游玩时间占位
const EMPTY_POSITION := "----------"  ## 空槽地图位置占位

const TITLE_SELECT := "请选择一个存档。"
const TITLE_CLEAR := "选择要消除的对象。"
const TITLE_COPY_SOURCE := "选择要复制的存档。"
const TITLE_COPY_TARGET := "选择粘贴的目标。"

const QUESTION_CLEAR := "消除这份存档吗？"
const QUESTION_CLEAR_AGAIN := "真的要消除吗？"
const QUESTION_COPY := "覆盖这份存档吗？"
const STATUS_CLEAR := "消除成功。"
const STATUS_COPY := "复制成功。"
const STATUS_NO_CLEAR := "没有可以消除的对象。"
const STATUS_NO_COPY := "没有可以复制的对象。"

const COLOR_DANGER := Color(1, 0, 0)  ## 二次确认的红色边框/问句

#endregion

#region 节点引用（场景节点，@onready 绑定）

@onready var _slots: Array[Node] = $Archives.get_children() ## Control1..3，顺序即槽号
@onready var _title_label: Label = $SelectFile
@onready var _action_bar: Control = $Actions
@onready var _action_cancel: Label = $ActionCancel
@onready var _snd_move: AudioStreamPlayer = $SndMove
@onready var _snd_ok: AudioStreamPlayer = $SndOk
@onready var _snd_cancel: AudioStreamPlayer = $SndCancel

var state := ArchiveSelectState.new()
var _cursors: Array[TextureRect] = []      ## 各槽红心光标
var _boxes: Array[TextureRect] = []        ## 各槽边框贴图（二次确认时染红）
var _dodulates: Array[Panel] = []      ## 各槽变暗层（未选中槽叠加）
var _confirm_boxes: Array[Control] = []    ## 各槽确认区（Confirm HBox）
var _confirm_starts: Array[Label] = []     ## 各槽「开始/是」
var _confirm_backs: Array[Label] = []      ## 各槽「返回/否」
var _select_starts: Array[TextureRect] = [] ## 各槽确认态「开始/是」红心（z_index 切换）
var _select_backs: Array[TextureRect] = []  ## 各槽确认态「返回/否」红心（z_index 切换）
var _position_labels: Array[Label] = []    ## 各槽位置/提问文本
var _position_label_home: Array[bool] = [] ## 各槽位置文本的场景默认显隐（收起确认时还原）
var _position_text: Array[String] = []     ## 各槽位置文本（提问时临时替换，需还原）
var _name_labels: Array[Label] = []        ## 各槽玩家名文本
var _time_labels: Array[Label] = []        ## 各槽游玩时间文本
var _name_rows: Array[Control] = []        ## 各槽姓名/时间行（是/否确认时隐藏，给问句腾行高）
var _source_highlights: Array[Panel] = []  ## 各槽复制源黄框
var _bar_hearts: Array[TextureRect] = []   ## 操作栏各项红心

var _cooldown := 0.0                       ## 输入去抖剩余时间
var _status := ""                          ## 操作成功提示（栏态覆盖标题，下次输入清除）

#endregion


func _ready() -> void:
	## 按槽缓存子节点引用（容器布局不改变节点路径）
	_position_text.resize(ArchiveSelectState.SLOT_COUNT)
	for slot: Node in _slots:
		_cursors.append(slot.get_node("SelectCursor"))
		_boxes.append(slot.get_node("Box"))
		_dodulates.append(slot.get_node("DisableDodulate"))
		_source_highlights.append(slot.get_node("SourceHighlight"))
		var vbox: Node = slot.get_node("MarginContainer/VBoxContainer")
		_confirm_boxes.append(vbox.get_node("Confirm"))
		_confirm_starts.append(vbox.get_node("Confirm/ConfirmStart"))
		_confirm_backs.append(vbox.get_node("Confirm/ConfirmBack"))
		_select_starts.append(vbox.get_node("Confirm/SelectStart"))
		_select_backs.append(vbox.get_node("Confirm/SelectBack"))
		var position_label: Label = vbox.get_node("PositionLabel")
		_position_labels.append(position_label)
		_position_label_home.append(position_label.visible)
		_name_labels.append(vbox.get_node("Control/NameLabel"))
		_time_labels.append(vbox.get_node("Control/TimeLabel"))
		_name_rows.append(vbox.get_node("Control"))
	for i: int in ArchiveSelectState.BAR_COUNT:
		_bar_hearts.append(_action_bar.get_node("Item%d/Heart" % i))
	_refresh_slots()
	_apply_focus()


#region 输入

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## 键盘输入入口：按动作映射分派
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if _cooldown > 0.0:
		return
	if _status != "":
		_status = ""
		_apply_focus()

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


## 应用确认键：状态变化播 snd_ok；随后按动作执行加载/消除/复制/退出
func _apply_ok() -> void:
	var old_state := state.state
	var action := state.press_ok()
	if state.state != old_state:
		_snd_ok.play()
		_after_state_change()
	match action:
		ArchiveSelectState.Action.SELECT:
			_snd_ok.play()
			# 加载入口：空槽/坏档仅告警（load_game 返回 null）；是否继续由 file_selected 监听者自行判断
			var data := GameManager.load_game(state.selected_slot)
			if data == null:
				GameLogger.warn("槽 %d 为空或已损坏，无法加载" % state.selected_slot, "Save")
			file_selected.emit(state.selected_slot)
		ArchiveSelectState.Action.CLEAR:
			_do_clear()
		ArchiveSelectState.Action.NO_TARGET:
			_status = STATUS_NO_CLEAR if state.bar_index == ArchiveSelectState.BAR_CLEAR else STATUS_NO_COPY
			_apply_focus()
		ArchiveSelectState.Action.COPY:
			_do_copy()
		ArchiveSelectState.Action.QUIT:
			GameManager.exit_game()


## 应用取消键：状态变化播 snd_cancel；选槽态取消播 snd_cancel 并发返回信号
func _apply_cancel() -> void:
	var old_state := state.state
	var action := state.press_cancel()
	if state.state != old_state:
		_snd_cancel.play()
		_after_state_change()
	if action == ArchiveSelectState.Action.EXIT:
		_snd_cancel.play()
		GameLogger.debug("exit_requested")
		exit_requested.emit()

#endregion


#region 存档操作

## 消除当前光标槽，并在栏态显示结果
func _do_clear() -> void:
	var slot := state.cursor
	if GameManager.clear_slot(slot):
		_status = STATUS_CLEAR
	else:
		GameLogger.warn("槽 %d 消除失败" % slot, "Save")
	_refresh_slots()
	_apply_focus()


## 复制源槽到目标槽（目标已被确认可覆盖），并在栏态显示结果
func _do_copy() -> void:
	if GameManager.copy_slot(state.copy_source, state.copy_target):
		_status = STATUS_COPY
	else:
		GameLogger.warn("槽 %d → %d 复制失败" % [state.copy_source, state.copy_target], "Save")
	_refresh_slots()
	_apply_focus()

#endregion


#region 状态到视图

## 每次状态变更的统一出口：刷新视图 + 重置去抖
func _after_state_change() -> void:
	_apply_focus()
	_cooldown = INPUT_COOLDOWN


## 焦点签名：状态/光标/栏位/确认项的合成值，用于判断一次移动是否生效
## 十进制拼装假设 SLOT_COUNT 与 BAR_COUNT 均 < 10（各自占一位，互不进位）
func _focus_signature() -> int:
	return state.state * 1000 + state.cursor * 100 + state.bar_index * 10 \
		+ state.confirm_item + (2 if state.confirm_yes else 0)


## 用存档数据刷新三槽文本与占用状态；空槽保留占位文案
func _refresh_slots() -> void:
	var slots := GameManager.get_all_slots()
	var occupied: Array[bool] = []
	for i: int in ArchiveSelectState.SLOT_COUNT:
		var data: SaveData = slots[i]
		occupied.append(data != null)
		(_name_labels[i] as Label).text = EMPTY_NAME if data == null else data.player_name
		(_time_labels[i] as Label).text = EMPTY_TIME if data == null else _format_playtime(data.playtime_sec)
		if data == null:
			_position_text[i] = EMPTY_POSITION
		else:
			# 位置优先显示地图名称，未设置时回退地图标识
			_position_text[i] = data.map_name if data.map_name != "" else data.map_id
		(_position_labels[i] as Label).text = _position_text[i]
	state.occupied = occupied


## 游玩时间（秒）格式化为 时:分
func _format_playtime(sec: float) -> String:
	var hours := floori(sec / 3600.0)
	var minutes := floori(sec / 60.0) - hours * 60
	return "%d:%02d" % [hours, minutes]


## 标题文案：成功提示在栏态覆盖标题，其余按状态映射
func _title_text() -> String:
	match state.state:
		ArchiveSelectState.State.CLEAR_SELECT, ArchiveSelectState.State.CLEAR_CONFIRM, \
			ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN:
			return TITLE_CLEAR
		ArchiveSelectState.State.COPY_SELECT_SOURCE:
			return TITLE_COPY_SOURCE
		ArchiveSelectState.State.COPY_SELECT_TARGET, ArchiveSelectState.State.COPY_CONFIRM:
			return TITLE_COPY_TARGET
		ArchiveSelectState.State.BAR_SELECTED:
			return _status if _status != "" else TITLE_SELECT
	return TITLE_SELECT


## 是否处于复制选目标阶段（此时源槽显示黄框）
func _is_copy_target_stage() -> bool:
	return state.state == ArchiveSelectState.State.COPY_SELECT_TARGET \
		or state.state == ArchiveSelectState.State.COPY_CONFIRM


## 把状态机焦点映射到视图：确认区显隐、变暗层、红心、操作栏与源槽高亮。
## 选槽态：选中槽显示红心、关闭变暗层。
## 确认态：隐藏槽红心，展开「开始/返回」或「是/否」，用 z_index 切换确认红心——
## 所选项的心 z=0 显示在 Box 贴图上，另一颗 z=-1 藏到贴图后面。
## 位置文本确认态临时隐藏，提问时临时替换为问句。
func _apply_focus() -> void:
	var current := state.state
	var confirm_open := current == ArchiveSelectState.State.CONFIRM_OPEN
	var yes_no := current == ArchiveSelectState.State.CLEAR_CONFIRM \
		or current == ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN \
		or current == ArchiveSelectState.State.COPY_CONFIRM
	var in_bar := current == ArchiveSelectState.State.BAR_SELECTED
	# 子流程（消除/复制）隐藏操作栏、显示「取消」提示；选槽与栏态都展示操作栏
	var in_flow := current == ArchiveSelectState.State.CLEAR_SELECT \
		or current == ArchiveSelectState.State.CLEAR_CONFIRM \
		or current == ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN \
		or current == ArchiveSelectState.State.COPY_SELECT_SOURCE \
		or current == ArchiveSelectState.State.COPY_SELECT_TARGET \
		or current == ArchiveSelectState.State.COPY_CONFIRM
	var slot_cursor := current == ArchiveSelectState.State.SLOT_SELECTED \
		or current == ArchiveSelectState.State.CLEAR_SELECT \
		or current == ArchiveSelectState.State.COPY_SELECT_SOURCE \
		or current == ArchiveSelectState.State.COPY_SELECT_TARGET

	_title_label.text = _title_text()
	_action_bar.visible = not in_flow
	_action_cancel.visible = in_flow
	# 栏项常驻布局，焦点用透明度切换（visible 会挤掉红心宽度导致文字跳动）
	for i: int in ArchiveSelectState.BAR_COUNT:
		(_bar_hearts[i] as TextureRect).modulate.a = 1.0 if in_bar and state.bar_index == i else 0.0

	for i: int in ArchiveSelectState.SLOT_COUNT:
		var in_confirm: bool = (confirm_open or yes_no) and state.cursor == i
		var danger := current == ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN and state.cursor == i
		var question := ""
		if yes_no and state.cursor == i:
			match current:
				ArchiveSelectState.State.CLEAR_CONFIRM:
					question = QUESTION_CLEAR
				ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN:
					question = QUESTION_CLEAR_AGAIN
				ArchiveSelectState.State.COPY_CONFIRM:
					question = QUESTION_COPY

		var position_label := _position_labels[i] as Label
		position_label.text = question if question != "" else _position_text[i]
		position_label.visible = question != "" or (_position_label_home[i] and not in_confirm)
		# 二次确认：边框与问句染红，其余状态还原主题色
		(_boxes[i] as TextureRect).modulate = COLOR_DANGER if danger else Color.WHITE
		if danger:
			position_label.add_theme_color_override("font_color", COLOR_DANGER)
		else:
			position_label.remove_theme_color_override("font_color")
		# 是/否确认占两行（问句 + 是/否），槽高放不下三行：隐藏姓名/时间行
		(_name_rows[i] as Control).visible = not (yes_no and state.cursor == i)

		(_confirm_boxes[i] as Control).visible = in_confirm
		var first_text := "开始"
		var second_text := "返回"
		if danger:
			first_text = "消除！"
			second_text = "不要！"
		elif yes_no:
			first_text = "是"
			second_text = "否"
		(_confirm_starts[i] as Label).text = first_text
		(_confirm_backs[i] as Label).text = second_text
		var first_selected: bool = state.confirm_yes if yes_no \
			else state.confirm_item == ArchiveSelectState.ConfirmItem.START
		(_select_starts[i] as TextureRect).z_index = 0 if first_selected else -1
		(_select_backs[i] as TextureRect).z_index = -1 if first_selected else 0
		(_dodulates[i] as Panel).visible = state.cursor != i
		(_cursors[i] as TextureRect).visible = slot_cursor and state.cursor == i
		(_source_highlights[i] as Panel).visible = _is_copy_target_stage() and state.copy_source == i

#endregion
