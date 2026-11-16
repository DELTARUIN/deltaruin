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
const HEART_SPEED := 1200.0           ## 红心光标移动速度（像素/秒，move_toward）

const EMPTY_NAME := "[空白]"          ## 空槽玩家名占位（与场景默认文案一致）
const EMPTY_TIME := "--:--"           ## 空槽游玩时间占位
const EMPTY_POSITION := "----------"  ## 空槽地图位置占位

const TITLE_SELECT := "请选择一个存档。"
const TITLE_CLEAR := "选择要消除的对象。"
const TITLE_COPY_SOURCE := "选择要复制的存档。"
const TITLE_COPY_TARGET := "选择粘贴的目标。"

const STATUS_CLEAR := "消除成功。"
const STATUS_COPY := "复制成功。"
const STATUS_NO_CLEAR := "没有可以消除的对象。"
const STATUS_NO_COPY := "没有可以复制的对象。"

#endregion

#region 节点引用（场景节点，@onready 绑定）

@onready var _archives: Control = $Archives
@onready var _title_label: Label = $SelectFile
@onready var _action_bar: Control = $Actions
@onready var _action_cancel: Label = $ActionCancel
@onready var _name_input: NameInputView = $NameInput
@onready var _heart: TextureRect = $HeartCursor

@export var snd_move: AudioStreamPlayer
@export var snd_ok: AudioStreamPlayer
@export var snd_cancel: AudioStreamPlayer

var state := ArchiveSelectState.new()

var _slots: Array[ArchiveSlot] = []        ## 三个槽组件（顺序即槽号）

var _cooldown := 0.0                       ## 输入去抖剩余时间
var _status := ""                          ## 操作成功提示（栏态覆盖标题，下次输入清除）
var _exit_requested := false               ## 退出已受理（等待音效期间防重复触发）

#endregion


func _ready() -> void:
	for child: Node in _archives.get_children():
		_slots.append(child as ArchiveSlot)
	_name_input.completed.connect(_on_name_completed)
	_name_input.cancelled.connect(_on_name_cancelled)
	_refresh_slots()
	_apply_focus()


#region 输入

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_move_heart(delta)


## 键盘输入入口：按动作映射分派
func _unhandled_input(event: InputEvent) -> void:
	# 名字输入覆盖层显示时由它接管输入
	if _name_input.visible:
		return
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
		snd_move.play()
		_after_state_change()


## 应用确认键：状态变化播 snd_ok；随后按动作执行加载/消除/复制/退出
func _apply_ok() -> void:
	var old_state := state.state
	var action := state.press_ok()
	if state.state != old_state:
		snd_ok.play()
		_after_state_change()
	match action:
		ArchiveSelectState.Action.SELECT:
			snd_ok.play()
			if state.occupied[state.selected_slot]:
				# 已有存档：加载并通知外部（是否继续由 file_selected 监听者判断）
				var data := GameManager.load_game(state.selected_slot)
				if data == null:
					GameLogger.warn("槽 %d 为空或已损坏，无法加载" % state.selected_slot, "Save")
				file_selected.emit(state.selected_slot)
			else:
				_open_name_input(state.selected_slot)
		ArchiveSelectState.Action.CLEAR:
			_do_clear()
		ArchiveSelectState.Action.NO_TARGET:
			_status = STATUS_NO_CLEAR if state.bar_index == ArchiveSelectState.BAR_CLEAR else STATUS_NO_COPY
			_apply_focus()
		ArchiveSelectState.Action.COPY:
			_do_copy()
		ArchiveSelectState.Action.QUIT:
			if _exit_requested:
				return
			_exit_requested = true
			snd_ok.play()
			# 稍等让音效出声再切场景（切场景会立刻停掉本节点的声音）
			await get_tree().create_timer(0.15).timeout
			GameManager.exit_game()


## 应用取消键：状态变化播 snd_cancel；选槽态取消播 snd_cancel 并发返回信号
func _apply_cancel() -> void:
	var old_state := state.state
	var action := state.press_cancel()
	if state.state != old_state:
		snd_cancel.play()
		_after_state_change()
	if action == ArchiveSelectState.Action.EXIT:
		snd_cancel.play()
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


#region 新建存档

## 打开名字输入覆盖层：隐藏列表 / 标题 / 操作栏，避免与覆盖层争输入
func _open_name_input(slot: int) -> void:
	_status = ""
	_archives.visible = false
	_title_label.visible = false
	_action_bar.visible = false
	_action_cancel.visible = false
	_name_input.open(slot)
	_cooldown = INPUT_COOLDOWN


## 关闭覆盖层并恢复列表（_apply_focus 负责操作栏与取消提示的显隐）
func _close_name_input() -> void:
	_name_input.visible = false
	_archives.visible = true
	_title_label.visible = true
	_cooldown = INPUT_COOLDOWN
	_apply_focus()


## 确认页「是」：建档 → 刷新槽 → 回列表并聚焦该槽
func _on_name_completed(slot: int, player_name: String) -> void:
	if not GameManager.init_save(slot, player_name):
		GameLogger.warn("槽 %d 新建存档失败" % slot, "Save")
	_refresh_slots()
	state.state = ArchiveSelectState.State.SLOT_SELECTED
	state.cursor = slot
	_close_name_input()


## 输入页取消：不建档，回列表
func _on_name_cancelled() -> void:
	state.state = ArchiveSelectState.State.SLOT_SELECTED
	_close_name_input()

#endregion


#region 状态到视图

## 红心光标每帧向状态锚点逼近（move_toward，帧率无关）；重新出现时直接就位不跨屏滑行
func _move_heart(delta: float) -> void:
	if _name_input.visible:
		_heart.visible = false
		return
	var target := _heart_anchor()
	if not _heart.visible:
		_heart.visible = true
		_heart.global_position = target
		return
	_heart.global_position = _heart.global_position.move_toward(target, HEART_SPEED * delta)


## 红心光标的目标锚点（全局坐标，18×18 左上角）：
## 槽区→槽左缘；操作栏→项文本左侧；槽内确认→所选项（开始/返回 或 是/否）
func _heart_anchor() -> Vector2:
	var slot: ArchiveSlot = _slots[state.cursor]
	if state.is_slot_cursor():
		return slot.heart_anchor(false)
	if state.state == ArchiveSelectState.State.BAR_SELECTED:
		return _bar_heart_anchor(state.bar_index)
	var first: bool = state.confirm_yes if state.is_yes_no() \
		else state.confirm_item == ArchiveSelectState.ConfirmItem.START
	return slot.heart_anchor(first)


## 操作栏第 i 项锚点：项文本左侧竖直居中
func _bar_heart_anchor(i: int) -> Vector2:
	var label: Label = _action_bar.get_node("Item%d/Label" % i)
	var rect := label.get_global_rect()
	return Vector2(rect.position.x - ArchiveSlot.HEART_SIZE - ArchiveSlot.HEART_GAP, \
		rect.position.y + rect.size.y * 0.5 - ArchiveSlot.HEART_SIZE * 0.5)


## 每次状态变更的统一出口：刷新视图 + 重置去抖
func _after_state_change() -> void:
	_apply_focus()
	_cooldown = INPUT_COOLDOWN


## 焦点签名：状态/光标/栏位/确认项的合成值，用于判断一次移动是否生效
func _focus_signature() -> String:
	return "%d|%d|%d|%d|%s" % [state.state, state.cursor, state.bar_index, \
		state.confirm_item, state.confirm_yes]


## 用存档数据刷新三槽内容与占用状态；空槽保留占位文案
func _refresh_slots() -> void:
	var slots := GameManager.get_all_slots()
	var occupied: Array[bool] = []
	for i: int in ArchiveSelectState.SLOT_COUNT:
		var data: SaveData = slots[i]
		occupied.append(data != null)
		_slots[i].set_content(
			EMPTY_NAME if data == null else data.player_name,
			EMPTY_TIME if data == null else _format_playtime(data.playtime_sec),
			_position_text_for(data))
	state.occupied = occupied


## 游玩时间（秒）格式化为 时:分:秒
func _format_playtime(sec: float) -> String:
	var hours := floori(sec / 3600.0)
	var minutes := floori(sec / 60.0) - hours * 60
	var seconds := floori(sec) - hours * 3600 - minutes * 60
	return "%d:%02d:%02d" % [hours, minutes, seconds]


## 槽位位置文案：地图名优先，其次地图标识，都没有（新建档）用占位
func _position_text_for(data: SaveData) -> String:
	if data == null or (data.map_name == "" and data.map_id == ""):
		return EMPTY_POSITION
	return data.map_name if data.map_name != "" else data.map_id


## 标题文案：成功提示在栏态覆盖标题，其余按状态映射
func _title_text() -> String:
	if state.is_clear_flow():
		return TITLE_CLEAR
	match state.state:
		ArchiveSelectState.State.COPY_SELECT_SOURCE:
			return TITLE_COPY_SOURCE
		ArchiveSelectState.State.BAR_SELECTED:
			return _status if _status != "" else TITLE_SELECT
	if state.is_copy_target_stage():
		return TITLE_COPY_TARGET
	return TITLE_SELECT


## 把状态机焦点映射到视图：标题/操作栏/取消提示 + 每槽的灰框、问句与槽内确认。
## 红心光标为场景级唯一 HeartCursor，坐标由 _move_heart 按状态锚点平滑逼近。
func _apply_focus() -> void:
	var current := state.state
	var confirm_open := current == ArchiveSelectState.State.CONFIRM_OPEN
	var yes_no := state.is_yes_no()
	# 子流程（消除/复制）隐藏操作栏、显示「取消」提示；选槽与栏态都展示操作栏
	var in_flow := state.is_in_flow()

	_title_label.text = _title_text()
	_action_bar.visible = not in_flow
	_action_cancel.visible = in_flow

	for i: int in ArchiveSelectState.SLOT_COUNT:
		var slot: ArchiveSlot = _slots[i]
		var cursor_here := state.cursor == i
		var in_confirm: bool = (confirm_open or yes_no) and cursor_here
		var danger := current == ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN and cursor_here
		var question: String = state.question_text() if yes_no and cursor_here else ""

		slot.set_focused(cursor_here)
		slot.set_highlight(state.is_copy_target_stage() and state.copy_source == i)
		slot.clear_overlay()
		if not in_confirm:
			continue
		var first_text := "开始"
		var second_text := "返回"
		if danger:
			first_text = "消除！"
			second_text = "不要！"
		elif yes_no:
			first_text = "是"
			second_text = "否"
		slot.show_confirm(first_text, second_text, question, danger)

#endregion
