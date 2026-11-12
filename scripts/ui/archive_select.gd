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

#endregion

#region 节点引用（场景节点，@onready 绑定）

@onready var _slots: Array[Node] = $Archives.get_children() ## Control1..3，顺序即槽号
@onready var _snd_move: AudioStreamPlayer = $SndMove
@onready var _snd_ok: AudioStreamPlayer = $SndOk
@onready var _snd_cancel: AudioStreamPlayer = $SndCancel

var state := ArchiveSelectState.new()
var _cursors: Array[TextureRect] = []      ## 各槽红心光标
var _dodulates: Array[Panel] = []      ## 各槽变暗层（未选中槽叠加）
var _confirm_boxes: Array[Control] = []    ## 各槽确认区（Confirm HBox）
var _confirm_starts: Array[Label] = []     ## 各槽「开始」
var _confirm_backs: Array[Label] = []      ## 各槽「返回」
var _select_starts: Array[TextureRect] = [] ## 各槽确认态「开始」红心（z_index 切换）
var _select_backs: Array[TextureRect] = []  ## 各槽确认态「返回」红心（z_index 切换）
var _position_labels: Array[Label] = []    ## 各槽位置文本
var _position_label_home: Array[bool] = [] ## 各槽位置文本的场景默认显隐（收起确认时还原）
var _name_labels: Array[Label] = []        ## 各槽玩家名文本
var _time_labels: Array[Label] = []        ## 各槽游玩时间文本

var _cooldown := 0.0                       ## 输入去抖剩余时间

#endregion


func _ready() -> void:
	## 按槽缓存子节点引用（容器布局不改变节点路径）
	for slot: Node in _slots:
		_cursors.append(slot.get_node("SelectCursor"))
		_dodulates.append(slot.get_node("DisableDodulate"))
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
	_apply_focus()
	_refresh_slots()


#region 输入

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## 键盘输入入口：按动作映射分派
func _unhandled_input(event: InputEvent) -> void:
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
		GameLogger.debug(state.debug_text())


## 应用一次移动：状态机变更成功才播音效并刷新视图（无效移动静默）
func _apply_move(action: Callable) -> void:
	var before := _focus_signature()
	action.call()
	if _focus_signature() != before:
		_snd_move.play()
		_after_state_change()


## 应用确认键：状态变化（展开/收起确认）播 snd_ok；确认「开始」播 snd_ok 并发信号
func _apply_ok() -> void:
	var old_state := state.state
	var action := state.press_ok()
	if state.state != old_state:
		_snd_ok.play()
		_after_state_change()
	if action == ArchiveSelectState.Action.SELECT:
		_snd_ok.play()
		# 加载入口：空槽/坏档仅告警（load_game 返回 null）；是否继续由 file_selected 监听者自行判断
		var data := GameManager.load_game(state.selected_slot)
		if data == null:
			GameLogger.warn("槽 %d 为空或已损坏，无法加载" % state.selected_slot, "Save")
		file_selected.emit(state.selected_slot)


## 应用取消键：收起确认播 snd_cancel；选槽态取消播 snd_cancel 并发返回信号
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


#region 状态到视图

## 每次状态变更的统一出口：刷新视图 + 重置去抖
func _after_state_change() -> void:
	_apply_focus()
	_cooldown = INPUT_COOLDOWN


## 焦点签名：光标槽与确认项的合成值，用于判断一次移动是否生效
func _focus_signature() -> int:
	return state.cursor * 4 + state.confirm_item


## 用存档数据刷新三槽文本；空槽保留占位文案
func _refresh_slots() -> void:
	var slots := GameManager.get_all_slots()
	for i: int in ArchiveSelectState.SLOT_COUNT:
		var data: SaveData = slots[i]
		(_name_labels[i] as Label).text = EMPTY_NAME if data == null else data.player_name
		(_time_labels[i] as Label).text = EMPTY_TIME if data == null else _format_playtime(data.playtime_sec)
		if data == null:
			(_position_labels[i] as Label).text = EMPTY_POSITION
		else:
			# 位置优先显示地图名称，未设置时回退地图标识
			(_position_labels[i] as Label).text = data.map_name if data.map_name != "" else data.map_id


## 游玩时间（秒）格式化为 时:分
func _format_playtime(sec: float) -> String:
	var hours := floori(sec / 3600.0)
	var minutes := floori(sec / 60.0) - hours * 60
	return "%d:%02d" % [hours, minutes]


## 把状态机焦点映射到视图：确认区显隐、变暗层与红心显隐。
## 选槽态：选中槽显示红心、关闭变暗层。
## 确认态：隐藏槽红心，展开「开始/返回」，用 z_index 切换确认红心——
## 所选项的心 z=0 显示在 Box 贴图上，另一颗 z=-1 藏到贴图后面。
## 位置文本确认态临时隐藏，收起后还原场景默认显隐。
func _apply_focus() -> void:
	var confirm_open := state.state == ArchiveSelectState.State.CONFIRM_OPEN

	for i: int in ArchiveSelectState.SLOT_COUNT:
		var in_confirm: bool = confirm_open and state.cursor == i

		(_position_labels[i] as Label).visible = _position_label_home[i] and not in_confirm

		(_confirm_boxes[i] as Control).visible = in_confirm
		(_confirm_starts[i] as Label).visible = true
		(_confirm_backs[i] as Label).visible = true
		(_select_starts[i] as TextureRect).z_index = 0 if state.confirm_item == ArchiveSelectState.ConfirmItem.START else -1
		(_select_backs[i] as TextureRect).z_index = 0 if state.confirm_item == ArchiveSelectState.ConfirmItem.BACK else -1
		(_dodulates[i] as Panel).visible = state.cursor != i
		(_cursors[i] as TextureRect).visible = not in_confirm and state.cursor == i

#endregion
