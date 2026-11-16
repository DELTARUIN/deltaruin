class_name ArchiveSlot
extends Control
## 单个存档槽视图组件：内容文本 + 焦点灰框 + 槽内确认与问句覆盖。
## 红心光标为场景级唯一节点（archive_menu.tscn 的 HeartCursor），
## 本组件经 heart_anchor() 提供其在槽内的锚点坐标。
## 节点结构在 archive_slot.tscn（由 archive_menu.tscn 实例化 ×3）。

#region 常量

const COLOR_DANGER := Color(1, 0, 0) ## 二次确认红色（边框/问句）
const HEART_SIZE := 18.0 ## 红心光标边长
const HEART_GAP := 4.0   ## 红心与文本左缘的间距

#endregion

#region 节点引用

@onready var _box: TextureRect = $Box
@onready var _dodulate: Panel = $DisableDodulate
@onready var _source_highlight: Panel = $SourceHighlight
@onready var _name_row: Control = $MarginContainer/VBoxContainer/Control
@onready var _name_label: Label = $MarginContainer/VBoxContainer/Control/NameLabel
@onready var _time_label: Label = $MarginContainer/VBoxContainer/Control/TimeLabel
@onready var _position_label: Label = $MarginContainer/VBoxContainer/PositionLabel
@onready var _confirm_box: Control = $MarginContainer/VBoxContainer/Confirm
@onready var _confirm_start: Label = $MarginContainer/VBoxContainer/Confirm/ConfirmStart
@onready var _confirm_back: Label = $MarginContainer/VBoxContainer/Confirm/ConfirmBack

#endregion

var _position_home := true ## 位置标签的场景默认显隐（覆盖后还原）
var _position_text := ""   ## 常态位置文本（确认态临时替换）


func _ready() -> void:
	_position_home = _position_label.visible


#region 视图 API

## 常态内容三行文本
func set_content(player_name: String, time_text: String, position_text: String) -> void:
	_name_label.text = player_name
	_time_label.text = time_text
	_position_text = position_text
	_position_label.text = position_text


## 焦点灰框（红心光标独立在场景级，由 archive_select 驱动）
func set_frame(focused: bool) -> void:
	_dodulate.visible = not focused


func set_source_highlight(on: bool) -> void:
	_source_highlight.visible = on


## 还原常态：位置文本/显隐/颜色、姓名行、确认区、红框全部复位
func clear_overlay() -> void:
	_position_label.text = _position_text
	_position_label.visible = _position_home
	_position_label.remove_theme_color_override("font_color")
	_box.modulate = Color.WHITE
	_name_row.visible = true
	_confirm_box.visible = false


## 槽内确认区：两个选项；question 非空时替换位置行、隐藏姓名行腾出两行，
## danger 时边框与问句染红；无问句（开始/返回）则保留姓名行、隐藏位置行
func show_confirm(first_text: String, second_text: String,
		question := "", danger := false) -> void:
	_confirm_box.visible = true
	_confirm_start.text = first_text
	_confirm_back.text = second_text
	_name_row.visible = question == ""
	if question == "":
		_position_label.visible = false
		return
	_position_label.text = question
	_position_label.visible = true
	if danger:
		_position_label.add_theme_color_override("font_color", COLOR_DANGER)
		_box.modulate = COLOR_DANGER


## 红心光标在本槽的锚点（全局坐标，18×18 左上角）。
## 确认区展开时锚在所选项文本左侧，否则锚在槽左缘竖直居中。
func heart_anchor(first_selected: bool) -> Vector2:
	if _confirm_box.visible:
		var label: Label = _confirm_start if first_selected else _confirm_back
		var rect := label.get_global_rect()
		var x: float = rect.position.x - HEART_SIZE - HEART_GAP
		return Vector2(x, rect.position.y + rect.size.y * 0.5 - HEART_SIZE * 0.5)
	return get_global_rect().position + Vector2(20.0, size.y * 0.5 - HEART_SIZE * 0.5)

#endregion
