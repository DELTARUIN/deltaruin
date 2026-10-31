extends Node
## 存档选择菜单（Undertale/Deltarune 风格红心光标选档）。
## 节点结构在 archive_menu.tscn 中编排；本脚本只负责输入处理与状态到视图的同步。
## 状态逻辑在 ArchiveSelectState（纯逻辑类，可单测）。

#region 信号

signal file_selected(slot: int) ## 确认「开始」：slot 为存档槽索引（0 起）
signal exit_requested           ## 选档界面请求返回

#endregion

#region 常量：交互参数

const INPUT_COOLDOWN := 0.15          ## 输入去抖（秒）

#endregion

#region 节点引用（场景节点，@onready 绑定）

@onready var _slots: Array[Node] = $CanvasLayer/ArchiveSelect/Archives.get_children() ## Control1..3，顺序即槽号
@onready var _snd_move: AudioStreamPlayer = $SndMove
@onready var _snd_ok: AudioStreamPlayer = $SndOk
@onready var _snd_cancel: AudioStreamPlayer = $SndCancel

var state := ArchiveSelectState.new()
var _cursors: Array[TextureRect] = []    ## 各槽红心光标
var _confirm_starts: Array[Label] = []   ## 各槽「开始」
var _confirm_backs: Array[Label] = []    ## 各槽「返回」
var _info_label_lists: Array[Array] = [] ## 各槽信息文本（名字/时间/章节）

var _cooldown := 0.0                     ## 输入去抖剩余时间

#endregion


func _ready() -> void:
	## 按槽缓存子节点引用（容器布局不改变节点路径）
	for slot: Node in _slots:
		_cursors.append(slot.get_node("SelectCursor"))
		_confirm_starts.append(slot.get_node("ConfirmStart"))
		_confirm_backs.append(slot.get_node("ConfirmBack"))
		var vbox: Node = slot.get_node("MarginContainer/VBoxContainer")
		_info_label_lists.append([
			vbox.get_node("Control/Label"),
			vbox.get_node("Control/Label2"),
			vbox.get_node("Label3"),
		])
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
		GameLogger.debug("file_selected: %d" % state.selected_slot)
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


## 把状态机焦点映射到视图：确认区显隐与红心显隐。
## 红心固定在各槽左侧原位不移动；确认态就地展开「开始/返回」替换槽内信息文本。
func _apply_focus() -> void:
	var confirm_open := state.state == ArchiveSelectState.State.CONFIRM_OPEN

	for i: int in ArchiveSelectState.SLOT_COUNT:
		var in_confirm: bool = confirm_open and state.cursor == i

		for label: Label in _info_label_lists[i]:
			label.visible = not in_confirm

		(_confirm_starts[i] as Label).visible = in_confirm
		(_confirm_backs[i] as Label).visible = in_confirm
		(_cursors[i] as TextureRect).visible = state.cursor == i

#endregion
