extends GutTest
## 章节菜单视图同步冒烟：状态机状态 → 行配色/显隐/红心（守护节点路径与映射）

const MENU_SCENE := "res://scenes/ui/chapter_menu.tscn"

var menu: CanvasLayer
var select: Node ## chapter_select.gd（无 class_name，用无类型变量以便调用内部方法）
var state: ChapterSelectState


func before_each() -> void:
	menu = load(MENU_SCENE).instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	select = menu.get_node("ChapterSelect")
	state = select.state


func _label(row: int, path: String) -> Label:
	return select.get_node("Rows/Row%d/%s" % [row + 1, path])


func test_initial_focus_skips_locked_rows() -> void:
	assert_eq(state.cursor, 4, "前 4 行锁定，初始焦点在第 5 行（第?章）")
	assert_eq(_label(4, "NameLabel").get_theme_color("font_color"), Color("ffff00"), "选中行黄")
	assert_eq(_label(0, "NameLabel").get_theme_color("font_color"), Color("7F7F7F"), "锁定行灰")
	assert_eq(_label(4, "Margin/Line/Stars").modulate, Color("ffff00"), "选中行星星黄")
	assert_eq(_label(0, "Margin/Line/Stars").modulate, Color("7F7F7F"), "锁定行星星灰")


func test_ok_opens_submenu_with_play_selected() -> void:
	state.press_ok()
	select._apply_focus()
	assert_eq(state.state, ChapterSelectState.State.SUBMENU_OPEN)
	assert_false(_label(4, "NameLabel").visible)
	assert_true(_label(4, "RowPlay").visible)
	assert_true(_label(4, "RowBack").visible)
	assert_eq(_label(4, "RowPlay").get_theme_color("font_color"), Color("ffff00"), "默认选中游玩")
	assert_eq(_label(4, "RowBack").get_theme_color("font_color"), Color.WHITE)


func test_footer_exit_focus() -> void:
	state.cursor = ChapterSelectState.FOOTER_EXIT
	select._apply_focus()
	var exit_label: Label = select.get_node("ExitLabel")
	assert_eq(exit_label.get_theme_color("font_color"), Color("ffff00"))
	assert_eq(select.get_node("Heart").position.x, exit_label.position.x - 26.0)


func test_row_centers_match_scene_layout() -> void:
	var centers: Array = select._row_centers
	for i: int in centers.size():
		var row: Control = select.get_node("Rows").get_child(i)
		assert_almost_eq(centers[i], row.position.y + row.size.y / 2.0, 0.5, "行中心与场景一致")


func test_rows_filled_from_chapters_data() -> void:
	assert_eq(_label(0, "Margin/Line/ChapterLabel").text, "第1章")
	assert_eq(_label(0, "NameLabel").text, "开端")
	assert_eq(_label(4, "Margin/Line/ChapterLabel").text, "第?章")
	assert_eq(_label(4, "NameLabel").text, "???")
	assert_eq(_label(6, "NameLabel").text, "--")
	assert_true(state.locked[0], "第1章锁定")
	assert_false(state.locked[4], "第?章可选")


func test_icons_assigned_from_chapter_sheet() -> void:
	for i: int in 7:
		var icon: TextureRect = select.get_node("Rows/Row%d/Margin/Line/Icon" % (i + 1))
		assert_not_null(icon.texture, "第 %d 行图标" % (i + 1))
		assert_eq((icon.texture as AtlasTexture).region, select.CHAPTERS[i]["icon"])


func test_submenu_offsets_centered_with_row5_exception() -> void:
	var play5: Label = select.get_node("Rows/Row5/RowPlay")
	assert_almost_eq(play5.offset_top, 9.0, 0.01, "Row5 子菜单 42 高居中")
	assert_eq(play5.offset_left, 244.0)
	var play2: Label = select.get_node("Rows/Row2/RowPlay")
	assert_almost_eq(play2.offset_top, 14.0, 0.01)
