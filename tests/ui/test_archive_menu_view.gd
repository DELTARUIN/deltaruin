extends GutTest
## 存档界面视图同步冒烟：状态机状态 → 节点显隐/文案（守护节点路径与映射）

const MENU_SCENE := "res://scenes/ui/archive_menu.tscn"
const TEST_SAVE_DIR := "user://saves_gut_view_test"

var menu: CanvasLayer
var select: Node ## archive_select.gd（无 class_name，用无类型变量以便调用内部方法）
var state: ArchiveSelectState
var _original_dir := "" ## 真实存档目录（用后还原）


func before_each() -> void:
	# 读写都隔离到临时目录，不碰真实 user://saves
	_original_dir = GameManager._save_system.save_dir
	GameManager._save_system.save_dir = TEST_SAVE_DIR
	_wipe_test_dir()
	menu = load(MENU_SCENE).instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	select = menu.get_node("ArchiveSelect")
	state = select.state


func after_each() -> void:
	_wipe_test_dir()
	GameManager._save_system.save_dir = _original_dir
	DirAccess.remove_absolute(TEST_SAVE_DIR)


func _wipe_test_dir() -> void:
	var dir := DirAccess.open(TEST_SAVE_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)


func _make_save(slot: int, save_name: String) -> void:
	var data := SaveData.new()
	data.player_name = save_name
	GameManager.save_game(slot, data)


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


func test_clear_second_confirm_turns_red_and_renames_choices() -> void:
	var vbox := "Archives/Archive/MarginContainer/VBoxContainer"
	state.state = ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN
	state.cursor = 0
	select._apply_focus()
	assert_eq(select.get_node("SelectFile").text, "选择要消除的对象。")
	assert_eq(select.get_node(vbox + "/PositionLabel").text, "真的要消除吗？")
	assert_eq(select.get_node(vbox + "/PositionLabel").get_theme_color("font_color"), Color(1, 0, 0), "问句染红")
	assert_eq(select.get_node("Archives/Archive/Box").modulate, Color(1, 0, 0), "边框染红")
	assert_eq(select.get_node("Archives/Archive2/Box").modulate, Color.WHITE, "其他槽边框不变")
	assert_eq(select.get_node(vbox + "/Confirm/ConfirmStart").text, "消除！")
	assert_eq(select.get_node(vbox + "/Confirm/ConfirmBack").text, "不要！")
	assert_false(select.get_node(vbox + "/Control").visible, "隐藏姓名/时间行")


func test_clear_with_no_saves_shows_no_target_message() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_CLEAR
	select._apply_ok()
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED, "全空不进选槽")
	assert_eq(select.get_node("SelectFile").text, "没有可以消除的对象。")


func test_name_input_grid_uses_container_layout() -> void:
	var input: NameInputView = select.get_node("NameInput")
	input.open(0)
	await wait_frames(2) # 容器可见后下一帧才完成排序
	input.state.row = 2
	input.state.col = 6
	input._refresh()
	var grid: VBoxContainer = input.get_node("Grid")
	assert_eq(grid.get_child_count(), 3, "三行 HBox")
	var row3: HBoxContainer = grid.get_child(2)
	assert_eq(row3.get_child_count(), 8, "6 字母 + 退格 + 决定")
	assert_eq((row3.get_child(6) as Label).text, "退格")
	assert_eq((row3.get_child(7) as Label).text, "决定")
	assert_eq((row3.get_child(6) as Label).get_theme_color("font_color"), Color("ffff00"), "选中黄字")
	# 布局钉死录屏换算值：格 36×32、sep 4（列距 40 / 行距 36）、宽格 76
	assert_eq((row3.get_child(6) as Control).position.x, 240.0, "退格 x（行内坐标）")
	assert_eq((row3.get_child(7) as Control).position.x, 320.0, "决定 x（行内坐标）")
	assert_eq(row3.position.y, 72.0, "行距 36 × 2")
	# 红心 = Grid 实际位置 + 行位置 + 行内坐标 + 格内居中（不钉死场景偏移，防布局挪动后误报）
	var back: Control = row3.get_child(6)
	var expected := (input.get_node("Grid") as Control).position + row3.position + back.position \
		+ Vector2((back.size.x - 18.0) / 2, (back.size.y - 18.0) / 2)
	assert_eq(input.get_node("Heart").position, expected, "红心居中退格")


func test_name_input_full_name_turns_yellow() -> void:
	var input: NameInputView = select.get_node("NameInput")
	input.open(0)
	input.state.name = "ABCDEFGHIJK"
	input._refresh()
	assert_eq(input.get_node("EnteredName").get_theme_color("font_color"), Color.WHITE)
	input.state.name = "ABCDEFGHIJKL"
	input._refresh()
	assert_eq(input.get_node("EnteredName").get_theme_color("font_color"), Color("ffff00"), "满 12 字变黄")


func test_name_input_confirm_page_shows_name_and_yes_no() -> void:
	var input: NameInputView = select.get_node("NameInput")
	input.open(0)
	input.state.name = "ABC"
	input.state.mode = NameInputState.Mode.CONFIRM
	input.state.confirm_yes = true
	input._refresh()
	assert_eq(input.get_node("Title").text, "这就是你的名字。")
	assert_false(input.get_node("Grid").visible, "确认页隐藏网格")
	assert_true(input.get_node("ConfirmBox/ConfirmName").visible)
	assert_eq(input.get_node("ConfirmBox/ConfirmName").text, "ABC")
	assert_eq(input.get_node("ConfirmYes").get_theme_color("font_color"), Color("ffff00"), "默认为是")
	assert_eq(input.get_node("ConfirmNo").get_theme_color("font_color"), Color.WHITE)
	input.state.confirm_yes = false
	input._refresh()
	assert_eq(input.get_node("ConfirmNo").get_theme_color("font_color"), Color("ffff00"))


func test_empty_slot_start_opens_name_input() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.CONFIRM_OPEN
	state.confirm_item = ArchiveSelectState.ConfirmItem.START
	state.cursor = 2
	select._apply_ok()
	var input: NameInputView = select.get_node("NameInput")
	assert_eq(state.selected_slot, 2)
	assert_true(input.visible)
	assert_false(select.get_node("Archives").visible, "名字输入时隐藏存档列表")
	assert_false(select.get_node("SelectFile").visible)
	assert_false(select.get_node("Actions").visible)
	assert_false(select.get_node("ActionCancel").visible)
	assert_eq(input.get_node("Title").text, "输入你自己的名字。")


func test_occupied_slot_start_keeps_load_path() -> void:
	state.occupied = [true, false, false]
	state.state = ArchiveSelectState.State.CONFIRM_OPEN
	state.confirm_item = ArchiveSelectState.ConfirmItem.START
	state.cursor = 0
	watch_signals(select)
	select._apply_ok()
	assert_false(select.get_node("NameInput").visible, "有档槽不进名字输入")
	assert_signal_emitted(select, "file_selected")


func test_name_input_cancel_returns_to_list() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.CONFIRM_OPEN
	state.confirm_item = ArchiveSelectState.ConfirmItem.START
	state.cursor = 2
	select._apply_ok()
	var input: NameInputView = select.get_node("NameInput")
	input.state.name = "ABC"
	input._cancel()
	assert_false(input.visible)
	assert_true(select.get_node("Archives").visible)
	assert_true(select.get_node("SelectFile").visible)
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED)
	assert_eq(state.cursor, 2)


func test_playtime_formats_hours_minutes_seconds() -> void:
	assert_eq(select._format_playtime(120658.0), "33:30:58")
	assert_eq(select._format_playtime(0.0), "0:00:00")
	assert_eq(select._format_playtime(59.0), "0:00:59")


func test_position_text_placeholder_for_new_save() -> void:
	var data := SaveData.new()
	data.player_name = "KRIS"
	assert_eq(select._position_text_for(data), "----------", "新建存档没有地图")
	data.map_id = "castle"
	assert_eq(select._position_text_for(data), "castle")
	data.map_name = "城堡"
	assert_eq(select._position_text_for(data), "城堡")


func test_confirm_yes_creates_save_and_returns_to_list() -> void:
	# 目录隔离由 before_each/after_each 统一处理
	var sys: SaveSystem = GameManager._save_system
	var input: NameInputView = select.get_node("NameInput")
	input.open(2)
	input.state.name = "KRIS"
	input.state.mode = NameInputState.Mode.CONFIRM
	input.state.confirm_yes = true
	input._ok()
	var loaded := sys.load_game(2)
	assert_not_null(loaded, "确认页是：写入存档")
	if loaded != null:
		assert_eq(loaded.player_name, "KRIS")
	assert_false(input.visible, "建档后关闭覆盖层")
	assert_true(select.get_node("Archives").visible)
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED)
	assert_eq(state.cursor, 2)
	var vbox := "Archives/Archive3/MarginContainer/VBoxContainer"
	assert_eq(select.get_node(vbox + "/Control/NameLabel").text, "KRIS")
	assert_eq(select.get_node(vbox + "/Control/TimeLabel").text, "0:00:00")
	assert_eq(select.get_node(vbox + "/PositionLabel").text, "----------")


func test_do_clear_clears_slot_and_refreshes() -> void:
	_make_save(0, "A")
	select._refresh_slots()
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_CLEAR
	state.cursor = 0
	select._do_clear()
	assert_null(GameManager.load_game(0))
	assert_false(state.occupied[0])
	var vbox := "Archives/Archive/MarginContainer/VBoxContainer"
	assert_eq(select.get_node(vbox + "/Control/NameLabel").text, "[空白]")
	assert_eq(select.get_node(vbox + "/Control/TimeLabel").text, "--:--")
	assert_eq(select.get_node("SelectFile").text, "消除成功。")


func test_do_copy_copies_into_target() -> void:
	_make_save(0, "A")
	_make_save(1, "B")
	select._refresh_slots()
	state.copy_source = 0
	state.copy_target = 1
	select._do_copy()
	assert_eq(GameManager.load_game(1).player_name, "A")
	assert_eq(select.get_node("Archives/Archive2/MarginContainer/VBoxContainer/Control/NameLabel").text, "A")


func test_start_confirm_keeps_position_labels_of_other_slots() -> void:
	state.press_ok()
	select._apply_focus()
	assert_false(select.get_node("Archives/Archive/MarginContainer/VBoxContainer/PositionLabel").visible, "光标槽位置文本隐藏")
	assert_true(select.get_node("Archives/Archive2/MarginContainer/VBoxContainer/PositionLabel").visible, "其他槽位置文本保留")
	assert_true(select.get_node("Archives/Archive/MarginContainer/VBoxContainer/Control").visible, "开始/返回确认保留姓名行")
