extends GutTest
## 存档界面视图同步冒烟：状态机状态 → 节点显隐/文案（守护节点路径与映射）

const MENU_SCENE := "res://scenes/ui/archive_menu.tscn"

var menu: CanvasLayer
var select: Node ## archive_select.gd（无 class_name，用无类型变量以便调用内部方法）
var state: ArchiveSelectState


func before_each() -> void:
	menu = load(MENU_SCENE).instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	select = menu.get_node("ArchiveSelect")
	state = select.state


func test_initial_view_shows_slots_and_actions() -> void:
	assert_true(select.get_node("Actions").visible, "操作栏默认展示")
	assert_false(select.get_node("ActionCancel").visible)
	assert_eq(select.get_node("SelectFile").text, "请选择一个存档。")


func test_bar_state_fades_heart_on_focus() -> void:
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_CLEAR
	select._apply_focus()
	assert_true(select.get_node("Actions").visible)
	assert_false(select.get_node("ActionCancel").visible)
	assert_eq(select.get_node("Actions/Item0/Heart").modulate.a, 0.0, "焦点不在复制：透明但仍占位")
	assert_eq(select.get_node("Actions/Item1/Heart").modulate.a, 1.0, "焦点在消除")
	assert_true(select.get_node("Actions/Item1/Heart").visible, "不靠 visible 隐藏，避免容器重排")


func test_copy_target_state_highlights_source() -> void:
	state.state = ArchiveSelectState.State.COPY_SELECT_TARGET
	state.copy_source = 1
	select._apply_focus()
	assert_eq(select.get_node("SelectFile").text, "选择粘贴的目标。")
	assert_false(select.get_node("Archives/Archive/SourceHighlight").visible)
	assert_true(select.get_node("Archives/Archive2/SourceHighlight").visible, "源槽显示黄框")
	assert_true(select.get_node("ActionCancel").visible, "子流程显示取消提示")
	assert_false(select.get_node("Actions").visible, "子流程隐藏操作栏")


func test_clear_confirm_shows_question_and_yes_no() -> void:
	var vbox := "Archives/Archive/MarginContainer/VBoxContainer"
	state.state = ArchiveSelectState.State.CLEAR_CONFIRM
	state.cursor = 0
	select._apply_focus()
	assert_eq(select.get_node("SelectFile").text, "选择要消除的对象。")
	assert_true(select.get_node(vbox + "/Confirm").visible)
	assert_eq(select.get_node(vbox + "/PositionLabel").text, "消除这份存档吗？")
	assert_eq(select.get_node(vbox + "/Confirm/ConfirmStart").text, "是")
	assert_eq(select.get_node(vbox + "/Confirm/ConfirmBack").text, "否")
	assert_eq(select.get_node(vbox + "/Confirm/SelectStart").z_index, -1, "默认光标在否")
	assert_eq(select.get_node(vbox + "/Confirm/SelectBack").z_index, 0)
	assert_false(select.get_node(vbox + "/Control").visible, "是/否确认隐藏姓名/时间行，避免三行溢出槽高")


func test_start_confirm_keeps_position_labels_of_other_slots() -> void:
	state.press_ok()
	select._apply_focus()
	assert_false(select.get_node("Archives/Archive/MarginContainer/VBoxContainer/PositionLabel").visible, "光标槽位置文本隐藏")
	assert_true(select.get_node("Archives/Archive2/MarginContainer/VBoxContainer/PositionLabel").visible, "其他槽位置文本保留")
	assert_true(select.get_node("Archives/Archive/MarginContainer/VBoxContainer/Control").visible, "开始/返回确认保留姓名行")
