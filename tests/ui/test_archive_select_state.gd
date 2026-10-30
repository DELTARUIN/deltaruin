extends GutTest
## ArchiveSelectState 状态机测试：三槽循环 / 二次确认展开 / 取消与确认动作路径

var state: ArchiveSelectState


func before_each() -> void:
	state = ArchiveSelectState.new()


func test_initial_state() -> void:
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED)
	assert_eq(state.cursor, 0)


func test_move_down_wraps_between_three_slots() -> void:
	state.move_down()
	assert_eq(state.cursor, 1)
	state.move_down()
	assert_eq(state.cursor, 2)
	state.move_down()
	assert_eq(state.cursor, 0, "槽3之后循环回槽1")


func test_move_up_from_first_wraps_to_last() -> void:
	state.move_up()
	assert_eq(state.cursor, 2)


func test_ok_on_slot_opens_confirm_at_start() -> void:
	state.press_ok()
	assert_eq(state.state, ArchiveSelectState.State.CONFIRM_OPEN)
	assert_eq(state.confirm_item, ArchiveSelectState.ConfirmItem.START)
	assert_eq(state.cursor, 0, "焦点不变")


func test_left_right_toggles_confirm_item() -> void:
	state.press_ok()
	state.move_left()
	assert_eq(state.confirm_item, ArchiveSelectState.ConfirmItem.BACK)
	state.move_right()
	assert_eq(state.confirm_item, ArchiveSelectState.ConfirmItem.START)


func test_left_right_in_slot_state_is_noop() -> void:
	state.move_left()
	state.move_right()
	assert_eq(state.cursor, 0, "选槽态左右键无效果")


func test_vertical_in_confirm_toggles_item_not_slot() -> void:
	state.cursor = 2
	state.press_ok()
	state.move_down()
	assert_eq(state.state, ArchiveSelectState.State.CONFIRM_OPEN)
	assert_eq(state.cursor, 2, "焦点不切换槽")
	assert_eq(state.confirm_item, ArchiveSelectState.ConfirmItem.BACK, "上下键切换开始/返回")
	state.move_up()
	assert_eq(state.confirm_item, ArchiveSelectState.ConfirmItem.START)


func test_cancel_closes_confirm_keeps_focus() -> void:
	state.cursor = 1
	state.press_ok()
	state.move_left()
	assert_eq(state.press_cancel(), ArchiveSelectState.Action.NONE, "收起确认不产生动作")
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED)
	assert_eq(state.cursor, 1, "焦点不变")


func test_cancel_in_slot_state_returns_exit() -> void:
	assert_eq(state.press_cancel(), ArchiveSelectState.Action.EXIT)


func test_ok_on_start_returns_select_with_slot() -> void:
	state.press_ok()
	assert_eq(state.press_ok(), ArchiveSelectState.Action.SELECT)
	assert_eq(state.selected_slot, 0)


func test_ok_on_start_slot_two_reports_slot_two() -> void:
	state.cursor = 2
	state.press_ok()
	assert_eq(state.press_ok(), ArchiveSelectState.Action.SELECT)
	assert_eq(state.selected_slot, 2)


func test_ok_on_back_equals_cancel() -> void:
	state.press_ok()
	state.move_left()
	state.press_ok()
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED)
	assert_eq(state.selected_slot, -1, "未产生选择")
