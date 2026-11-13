extends GutTest
## 名字输入状态机测试：录入 / 退格 / 上限 / 决定与确认页 / 取消 / 导航

var state: NameInputState


func before_each() -> void:
	state = NameInputState.new()


func _find_cell(ch: String) -> Array:
	for r: int in NameInputState.GRID.size():
		var row_cells: Array = NameInputState.GRID[r]
		for c: int in row_cells.size():
			if row_cells[c] == ch:
				return [r, c]
	return [-1, -1]


## 直接定位格子并按确认，模拟逐字录入
func _type(text: String) -> void:
	for ch: String in text:
		var cell := _find_cell(ch)
		state.row = cell[0]
		state.col = cell[1]
		state.press_ok()


func test_initial_state() -> void:
	assert_eq(state.mode, NameInputState.Mode.ENTRY)
	assert_eq(state.row, 0)
	assert_eq(state.col, 0)
	assert_eq(state.name, "")
	assert_true(state.confirm_yes)


func test_type_letters_appends_in_order() -> void:
	_type("ABC")
	assert_eq(state.name, "ABC")


func test_name_capped_at_twelve() -> void:
	_type("ABCDEFGHIJKLM")
	assert_eq(state.name, "ABCDEFGHIJKL")
	assert_eq(state.name.length(), NameInputState.MAX_NAME)


func test_backspace_removes_last_and_empty_is_noop() -> void:
	_type("AB")
	var cell := _find_cell(NameInputState.BACKSPACE)
	state.row = cell[0]
	state.col = cell[1]
	state.press_ok()
	assert_eq(state.name, "A")
	state.press_ok()
	assert_eq(state.name, "")
	state.press_ok()
	assert_eq(state.name, "", "空名退格无动作")


func test_decide_with_empty_name_is_noop() -> void:
	var cell := _find_cell(NameInputState.DECIDE)
	state.row = cell[0]
	state.col = cell[1]
	assert_eq(state.press_ok(), NameInputState.Action.NONE)
	assert_eq(state.mode, NameInputState.Mode.ENTRY, "空名不进确认页")


func test_decide_enters_confirm_with_yes() -> void:
	_type("A")
	var cell := _find_cell(NameInputState.DECIDE)
	state.row = cell[0]
	state.col = cell[1]
	state.press_ok()
	assert_eq(state.mode, NameInputState.Mode.CONFIRM)
	assert_true(state.confirm_yes, "确认页默认是")


func test_confirm_yes_returns_start() -> void:
	_type("A")
	state.mode = NameInputState.Mode.CONFIRM
	state.confirm_yes = true
	assert_eq(state.press_ok(), NameInputState.Action.START)


func test_confirm_no_returns_to_entry_keeps_name() -> void:
	_type("AB")
	state.mode = NameInputState.Mode.CONFIRM
	state.confirm_yes = false
	assert_eq(state.press_ok(), NameInputState.Action.NONE)
	assert_eq(state.mode, NameInputState.Mode.ENTRY)
	assert_eq(state.name, "AB", "否回输入页保留名字")


func test_cancel_backtracks_then_exits() -> void:
	state.mode = NameInputState.Mode.CONFIRM
	assert_eq(state.press_cancel(), NameInputState.Action.NONE)
	assert_eq(state.mode, NameInputState.Mode.ENTRY)
	assert_eq(state.press_cancel(), NameInputState.Action.EXIT)


func test_horizontal_navigation_wraps_in_row() -> void:
	state.move_left()
	assert_eq(state.col, 9, "行首左移到最后")
	state.move_right()
	assert_eq(state.col, 0)


func test_vertical_navigation_clamps_to_row_length() -> void:
	state.col = 9
	state.move_down()
	assert_eq(state.row, 1)
	assert_eq(state.col, 9)
	state.move_down()
	assert_eq(state.row, 2)
	assert_eq(state.col, 7, "第三行只有 8 格，列号钳制")
	state.move_up()
	assert_eq(state.row, 1)
	assert_eq(state.col, 7)
