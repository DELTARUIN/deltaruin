extends GutTest
## ArchiveSelectState 状态机测试：三槽循环 / 二次确认展开 / 取消与确认动作路径

var state: ArchiveSelectState


func before_each() -> void:
	state = ArchiveSelectState.new()


func test_initial_state() -> void:
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED)
	assert_eq(state.cursor, 0)


func test_move_down_cycles_slots_then_enters_bar() -> void:
	state.move_down()
	assert_eq(state.cursor, 1)
	state.move_down()
	assert_eq(state.cursor, 2)
	state.move_down()
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED, "槽3之后进入操作栏")
	assert_eq(state.bar_index, ArchiveSelectState.BAR_COPY)


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


#region 操作栏与复制/消除/退出

func test_bar_navigation() -> void:
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_COPY
	state.move_right()
	assert_eq(state.bar_index, ArchiveSelectState.BAR_CLEAR, "左右键在行内换列")
	state.move_left()
	assert_eq(state.bar_index, ArchiveSelectState.BAR_COPY)
	state.move_down()
	assert_eq(state.bar_index, ArchiveSelectState.BAR_CH4, "下键换到第二行同列")
	state.move_up()
	assert_eq(state.bar_index, ArchiveSelectState.BAR_COPY)
	state.move_up()
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED, "第一行上键回槽区")
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_CH4
	state.move_down()
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED, "第二行下键回槽区")


func test_bar_ok_copy_enters_source_select() -> void:
	state.occupied = [true, false, false]
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_COPY
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_SOURCE)


func test_copy_flow_to_empty_target() -> void:
	state.occupied = [true, false, false]
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_COPY
	state.press_ok()
	state.cursor = 0
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_TARGET)
	assert_eq(state.copy_source, 0)
	state.cursor = 1
	assert_eq(state.press_ok(), ArchiveSelectState.Action.COPY, "空目标直接复制")
	assert_eq(state.copy_target, 1)
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED)
	assert_eq(state.bar_index, ArchiveSelectState.BAR_COPY, "完成后焦点回复制")


func test_copy_to_occupied_target_asks_confirm() -> void:
	state.occupied = [true, true, false]
	state.state = ArchiveSelectState.State.COPY_SELECT_SOURCE
	state.cursor = 0
	state.press_ok()
	state.cursor = 1
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.COPY_CONFIRM)
	assert_false(state.confirm_yes, "默认光标在否")
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE, "直接确认（否）不复制")
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_TARGET)
	state.press_ok()
	state.move_left()
	assert_true(state.confirm_yes)
	assert_eq(state.press_ok(), ArchiveSelectState.Action.COPY, "切到是后确认复制")


func test_copy_source_must_be_occupied() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.COPY_SELECT_SOURCE
	state.cursor = 1
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_SOURCE, "空槽不可作为复制源")


func test_copy_same_slot_noop() -> void:
	state.occupied = [true, false, false]
	state.state = ArchiveSelectState.State.COPY_SELECT_TARGET
	state.copy_source = 0
	state.cursor = 0
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_TARGET, "目标不能是源槽自身")


func test_clear_flow() -> void:
	state.occupied = [false, true, false]
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_CLEAR
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_SELECT)
	state.cursor = 1
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_CONFIRM)
	assert_false(state.confirm_yes, "默认光标在否")
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_SELECT, "否返回选槽")
	state.press_ok()
	state.move_right()
	assert_true(state.confirm_yes)
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE, "第一问选是进入二次确认")
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN)
	assert_false(state.confirm_yes, "二次确认默认光标在否")
	state.move_right()
	assert_eq(state.press_ok(), ArchiveSelectState.Action.CLEAR, "二次确认选是才消除")
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED)
	assert_eq(state.bar_index, ArchiveSelectState.BAR_CLEAR, "完成后焦点回消除")
	assert_eq(state.cursor, 1, "cursor 仍指向被消除的槽（_do_clear 依赖）")


func test_clear_second_confirm_no_returns_to_first() -> void:
	state.occupied = [true, false, false]
	state.state = ArchiveSelectState.State.CLEAR_CONFIRM
	state.confirm_yes = true
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN)
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE, "第二问否不消除")
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_CONFIRM, "退回第一问")
	assert_false(state.confirm_yes, "光标重置到否")


func test_cancel_second_confirm_returns_to_first() -> void:
	state.state = ArchiveSelectState.State.CLEAR_CONFIRM_AGAIN
	state.press_cancel()
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_CONFIRM)
	assert_false(state.confirm_yes)


func test_clear_with_no_saves_returns_no_target() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_CLEAR
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NO_TARGET)
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED, "全空不进选槽")


func test_copy_with_no_saves_returns_no_target() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_COPY
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NO_TARGET)
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED, "全空不进选源")


func test_clear_empty_slot_noop() -> void:
	state.occupied = [false, false, false]
	state.state = ArchiveSelectState.State.CLEAR_SELECT
	state.cursor = 2
	assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.CLEAR_SELECT, "空槽不可消除")


func test_quit_action() -> void:
	state.state = ArchiveSelectState.State.BAR_SELECTED
	state.bar_index = ArchiveSelectState.BAR_QUIT
	assert_eq(state.press_ok(), ArchiveSelectState.Action.QUIT)


func test_placeholder_bar_items_noop() -> void:
	state.state = ArchiveSelectState.State.BAR_SELECTED
	for index: int in [ArchiveSelectState.BAR_CHAPTER, ArchiveSelectState.BAR_CH4, ArchiveSelectState.BAR_NAMES]:
		state.bar_index = index
		assert_eq(state.press_ok(), ArchiveSelectState.Action.NONE, "占位项无动作")
		assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED)


func test_cancel_backtracks() -> void:
	state.state = ArchiveSelectState.State.BAR_SELECTED
	assert_eq(state.press_cancel(), ArchiveSelectState.Action.NONE)
	assert_eq(state.state, ArchiveSelectState.State.SLOT_SELECTED, "栏取消回槽区")
	state.state = ArchiveSelectState.State.CLEAR_SELECT
	state.press_cancel()
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED)
	assert_eq(state.bar_index, ArchiveSelectState.BAR_CLEAR, "消除取消回栏焦点在消除")
	state.state = ArchiveSelectState.State.COPY_SELECT_TARGET
	state.press_cancel()
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_SOURCE, "复制目标取消回选源")
	state.state = ArchiveSelectState.State.COPY_SELECT_SOURCE
	state.press_cancel()
	assert_eq(state.state, ArchiveSelectState.State.BAR_SELECTED, "复制选源取消回栏")
	assert_eq(state.bar_index, ArchiveSelectState.BAR_COPY, "复制取消回栏焦点在复制")
	state.state = ArchiveSelectState.State.COPY_CONFIRM
	state.press_cancel()
	assert_eq(state.state, ArchiveSelectState.State.COPY_SELECT_TARGET, "覆盖确认取消只退一级回选目标")

#endregion
