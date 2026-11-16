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


func test_set_frame_controls_border() -> void:
	slot.set_frame(true)
	assert_false(slot.get_node("DisableDodulate").visible, "聚焦槽无灰框")
	slot.set_frame(false)
	assert_true(slot.get_node("DisableDodulate").visible)


func test_heart_anchor_follows_confirm_selection() -> void:
	var rect := slot.get_global_rect()
	assert_eq(slot.heart_anchor(false),
		rect.position + Vector2(20.0, rect.size.y * 0.5 - ArchiveSlot.HEART_SIZE * 0.5),
		"常态锚在槽左缘竖直居中")
	slot.show_confirm("开始", "返回")
	var start: Label = slot.get_node("MarginContainer/VBoxContainer/Confirm/ConfirmStart")
	var anchor := slot.heart_anchor(true)
	assert_eq(anchor.x, start.get_global_rect().position.x
		- ArchiveSlot.HEART_SIZE - ArchiveSlot.HEART_GAP, "红心在所选项文本左侧")
	assert_eq(anchor.y, start.get_global_rect().position.y
		+ start.get_global_rect().size.y * 0.5 - ArchiveSlot.HEART_SIZE * 0.5, "红心竖直居中")


func test_show_confirm_question_and_danger() -> void:
	var vbox := "MarginContainer/VBoxContainer"
	slot.set_content("KRIS", "1:02:03", "城堡")
	slot.show_confirm("消除！", "不要！", "真的要消除吗？", true)
	assert_true(slot.get_node(vbox + "/Confirm").visible)
	assert_eq(slot.get_node(vbox + "/Confirm/ConfirmStart").text, "消除！")
	assert_eq(slot.get_node(vbox + "/Confirm/ConfirmBack").text, "不要！")
	assert_eq(slot.get_node(vbox + "/PositionLabel").text, "真的要消除吗？")
	assert_eq(slot.get_node(vbox + "/PositionLabel").get_theme_color("font_color"), Color(1, 0, 0))
	assert_eq(slot.get_node("Box").modulate, Color(1, 0, 0), "边框染红")
	assert_false(slot.get_node(vbox + "/Control").visible, "隐藏姓名/时间行")


func test_show_confirm_without_question_keeps_name_row() -> void:
	var vbox := "MarginContainer/VBoxContainer"
	slot.show_confirm("开始", "返回")
	assert_true(slot.get_node(vbox + "/Confirm").visible)
	assert_eq(slot.get_node(vbox + "/Confirm/ConfirmStart").text, "开始")
	assert_true(slot.get_node(vbox + "/Control").visible, "开始/返回保留姓名行")
	assert_false(slot.get_node(vbox + "/PositionLabel").visible, "位置行隐藏")
	assert_eq(slot.get_node("Box").modulate, Color.WHITE, "无问句不染红")


func test_clear_overlay_restores_defaults() -> void:
	var vbox := "MarginContainer/VBoxContainer"
	var position_label: Label = slot.get_node(vbox + "/PositionLabel")
	slot.set_content("KRIS", "1:02:03", "城堡")
	slot.show_confirm("是", "否", "消除这份存档吗？", true)
	slot.clear_overlay()
	assert_false(slot.get_node(vbox + "/Confirm").visible)
	assert_true(slot.get_node(vbox + "/Control").visible)
	assert_eq(position_label.text, "城堡", "位置文本还原")
	assert_false(position_label.has_theme_color_override("font_color"), "红色覆盖移除")
	assert_eq(slot.get_node("Box").modulate, Color.WHITE)
