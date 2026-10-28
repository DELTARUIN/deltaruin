extends GutTest
## ChapterSelectState 状态机测试：锁定行跳过 / 子菜单切换 / 取消与渐隐路径

var state: ChapterSelectState


func before_each() -> void:
	state = ChapterSelectState.new([false, false, false, false, false, true, true])


func test_initial_state() -> void:
	assert_eq(state.state, ChapterSelectState.State.ROW_SELECTED)
	assert_eq(state.cursor, 0)


func test_move_down_skips_locked_rows() -> void:
	state.move_down()
	state.move_down()
	state.move_down()
	state.move_down()
	assert_eq(state.cursor, 4, "1->2->3->4，不经过锁定行")


func test_move_down_from_last_unlocked_goes_to_footer() -> void:
	state.cursor = 4
	state.move_down()
	assert_eq(state.cursor, ChapterSelectState.FOOTER_EXIT, "第5章向下跳过锁定行进页脚")


func test_move_down_from_footer_wraps_to_first_row() -> void:
	state.cursor = 4
	state.move_down()
	assert_eq(state.cursor, ChapterSelectState.FOOTER_EXIT, "第5章向下跳过锁定行进页脚")
	state.move_down()
	assert_eq(state.cursor, 0, "页脚之后循环回第1章")


func test_move_up_from_first_wraps_to_footer() -> void:
	state.move_up()
	assert_eq(state.cursor, ChapterSelectState.FOOTER_EXIT)


func test_ok_on_row_opens_submenu_at_play() -> void:
	state.press_ok()
	assert_eq(state.state, ChapterSelectState.State.SUBMENU_OPEN)
	assert_eq(state.sub_item, ChapterSelectState.SubItem.PLAY)
	assert_eq(state.cursor, 0, "焦点不变")


func test_left_right_toggles_sub_item() -> void:
	state.press_ok()
	state.move_left()
	assert_eq(state.sub_item, ChapterSelectState.SubItem.BACK)
	state.move_right()
	assert_eq(state.sub_item, ChapterSelectState.SubItem.PLAY)


func test_vertical_in_submenu_toggles_sub_item_not_chapter() -> void:
	state.press_ok()
	state.move_down()
	assert_eq(state.state, ChapterSelectState.State.SUBMENU_OPEN)
	assert_eq(state.cursor, 0, "焦点不切换章节")
	assert_eq(state.sub_item, ChapterSelectState.SubItem.BACK, "上下键切换游玩/返回")
	state.move_up()
	assert_eq(state.sub_item, ChapterSelectState.SubItem.PLAY)


func test_vertical_in_submenu_keeps_cursor_on_locked_neighbor() -> void:
	state.cursor = 4
	state.press_ok()
	state.move_down()
	assert_eq(state.cursor, 4, "相邻锁定行不可达，焦点原地不动")
	assert_eq(state.state, ChapterSelectState.State.SUBMENU_OPEN)


func test_cancel_closes_submenu_keeps_focus() -> void:
	state.cursor = 3
	state.press_ok()
	state.move_left()
	state.press_cancel()
	assert_eq(state.state, ChapterSelectState.State.ROW_SELECTED)
	assert_eq(state.cursor, 3, "焦点不变")


func test_ok_on_play_fades_out() -> void:
	state.press_ok()
	state.press_ok()
	assert_eq(state.state, ChapterSelectState.State.FADE_OUT)
	assert_eq(state.pending, ChapterSelectState.Pending.PLAY)
	assert_eq(state.loading_row, 0)


func test_play_path_returns_to_menu() -> void:
	state.cursor = 2
	state.press_ok()
	state.press_ok()
	state.finish_fade()
	assert_eq(state.state, ChapterSelectState.State.ROW_SELECTED)
	assert_eq(state.pending, ChapterSelectState.Pending.NONE)


func test_ok_on_back_equals_cancel() -> void:
	state.press_ok()
	state.move_left()
	state.press_ok()
	assert_eq(state.state, ChapterSelectState.State.ROW_SELECTED)


func test_ok_on_exit_fades_out_with_exit_pending() -> void:
	state.cursor = ChapterSelectState.FOOTER_EXIT
	state.press_ok()
	assert_eq(state.state, ChapterSelectState.State.FADE_OUT)
	assert_eq(state.pending, ChapterSelectState.Pending.EXIT)


func test_fade_out_ignores_all_input() -> void:
	state.press_ok()
	state.press_ok()
	state.move_down()
	state.move_left()
	state.press_cancel()
	assert_eq(state.state, ChapterSelectState.State.FADE_OUT)
	assert_eq(state.sub_item, ChapterSelectState.SubItem.PLAY)


func test_all_rows_locked_cursor_goes_to_footer() -> void:
	var all_locked := ChapterSelectState.new([true, true, true, true, true, true, true])
	all_locked.move_down()
	assert_eq(all_locked.cursor, ChapterSelectState.FOOTER_EXIT, "行全锁定时跳到页脚（页脚永远可选）")
