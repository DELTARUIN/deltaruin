extends GutTest
## 存档槽组件冒烟：内容 / 焦点灰框 / 槽内确认与问句 / 还原

const SLOT_SCENE := "res://scenes/ui/archive_slot.tscn"

var slot: ArchiveSlot


func before_each() -> void:
	slot = load(SLOT_SCENE).instantiate()
	add_child_autofree(slot)
	await wait_frames(2)


func test_set_content_writes_labels() -> void:
	slot.set_content("KRIS", "1:02:03", "城堡")
	assert_eq(slot.get_node("MarginContainer/VBoxContainer/Control/NameLabel").text, "KRIS")
	assert_eq(slot.get_node("MarginContainer/VBoxContainer/Control/TimeLabel").text, "1:02:03")
	assert_eq(slot.get_node("MarginContainer/VBoxContainer/PositionLabel").text, "城堡")


func test_set_frame_controls_border_and_heart() -> void:
	slot.set_frame(true, true)
	assert_false(slot.get_node("DisableDodulate").visible, "聚焦槽无灰框")
	assert_true(slot.get_node("SelectCursor").visible)
	slot.set_frame(false, false)
	assert_true(slot.get_node("DisableDodulate").visible)
	assert_false(slot.get_node("SelectCursor").visible)


func test_show_confirm_question_and_danger() -> void:
	var vbox := "MarginContainer/VBoxContainer"
	slot.set_content("KRIS", "1:02:03", "城堡")
	slot.show_confirm("消除！", "不要！", true, "真的要消除吗？", true)
	assert_true(slot.get_node(vbox + "/Confirm").visible)
	assert_eq(slot.get_node(vbox + "/Confirm/ConfirmStart").text, "消除！")
	assert_eq(slot.get_node(vbox + "/Confirm/ConfirmBack").text, "不要！")
	assert_eq(slot.get_node(vbox + "/Confirm/SelectStart").z_index, 0, "所选项红心在上")
	assert_eq(slot.get_node(vbox + "/Confirm/SelectBack").z_index, -1)
	assert_eq(slot.get_node(vbox + "/PositionLabel").text, "真的要消除吗？")
	assert_eq(slot.get_node(vbox + "/PositionLabel").get_theme_color("font_color"), Color(1, 0, 0))
	assert_eq(slot.get_node("Box").modulate, Color(1, 0, 0), "边框染红")
	assert_false(slot.get_node(vbox + "/Control").visible, "隐藏姓名/时间行")


func test_show_confirm_without_question_keeps_name_row() -> void:
	var vbox := "MarginContainer/VBoxContainer"
	slot.show_confirm("开始", "返回", true)
	assert_true(slot.get_node(vbox + "/Confirm").visible)
	assert_eq(slot.get_node(vbox + "/Confirm/ConfirmStart").text, "开始")
	assert_true(slot.get_node(vbox + "/Control").visible, "开始/返回保留姓名行")
	assert_false(slot.get_node(vbox + "/PositionLabel").visible, "位置行隐藏")
	assert_eq(slot.get_node("Box").modulate, Color.WHITE, "无问句不染红")


func test_clear_overlay_restores_defaults() -> void:
	var vbox := "MarginContainer/VBoxContainer"
	var position_label: Label = slot.get_node(vbox + "/PositionLabel")
	slot.set_content("KRIS", "1:02:03", "城堡")
	slot.show_confirm("是", "否", true, "消除这份存档吗？", true)
	slot.clear_overlay()
	assert_false(slot.get_node(vbox + "/Confirm").visible)
	assert_true(slot.get_node(vbox + "/Control").visible)
	assert_eq(position_label.text, "城堡", "位置文本还原")
	assert_false(position_label.has_theme_color_override("font_color"), "红色覆盖移除")
	assert_eq(slot.get_node("Box").modulate, Color.WHITE)
