extends Node

@export var logger_level := GameLogger.Level.DEBUG

@export var fade_out_speed: float = 1.0
@export var fade_in_speed: float = 1.0
@export var fade_out_pattern: String = "fade"
@export var fade_in_pattern: String = "fade"
@export var fade_out_smoothness = 0.1 # (float, 0, 1)
@export var fade_in_smoothness = 0.1 # (float, 0, 1)
@export var fade_out_inverted: bool = false
@export var fade_in_inverted: bool = false
@export var color: Color = Color(0, 0, 0)
@export var timeout: float = 0.0
@export var clickable: bool = false
@export var add_to_back: bool = true

@onready var fade_out_options = SceneManager.create_options(fade_out_speed, fade_out_pattern, fade_out_smoothness, fade_out_inverted)
@onready var fade_in_options = SceneManager.create_options(fade_in_speed, fade_in_pattern, fade_in_smoothness, fade_in_inverted)
@onready var general_options = SceneManager.create_general_options(color, timeout, clickable, add_to_back)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameLogger.set_levels(logger_level, logger_level)
	pass # Replace with function body.

func exit_game() -> void:
	SceneManager.change_scene("exit", fade_in_options, fade_in_options, general_options)
	pass # Replace with function body.


func show_chapter() -> void:
	SceneManager.change_scene("chapter_menu", fade_in_options, fade_in_options, general_options)
	pass # Replace with function body.

## 游玩：章节菜单已在自身完成淡出，跳过 SceneManager 的二次淡出，直接切场景并淡入
func play_chapter(row: int) -> void:
	var no_fade_out = SceneManager.create_options(0.0, fade_out_pattern, fade_out_smoothness, fade_out_inverted)
	SceneManager.change_scene("archive_menu", no_fade_out, fade_in_options, general_options)


#region 存档 API（具体逻辑见 SaveSystem，这里只做入口转发）

var _save_system := SaveSystem.new()

## 保存数据到指定槽
func save_game(slot: int, data: SaveData) -> bool:
	return _save_system.save_game(slot, data)


## 新建存档：确认页「是」的唯一入口（具体逻辑在 SaveSystem）
func init_save(slot: int, player_name: String) -> bool:
	return _save_system.create_save(slot, player_name)


## 读取指定槽；空/坏档返回 null
func load_game(slot: int) -> SaveData:
	return _save_system.load_game(slot)


## 复制源槽到目标槽（整体覆盖目标）
func copy_slot(from_slot: int, to_slot: int) -> bool:
	return _save_system.copy_slot(from_slot, to_slot)


## 清除指定槽
func clear_slot(slot: int) -> bool:
	return _save_system.clear_slot(slot)


## 全部槽位快照（空槽为 null），供存档 UI 刷新显示
func get_all_slots() -> Array:
	return _save_system.get_all_slots()

#endregion


func _unhandled_input(event: InputEvent) -> void:
	# 切换窗口全屏/窗口化（按键在项目设置 → 输入映射的 toggle_fullscreen 中定义）
	if event.is_action_pressed("toggle_fullscreen"):
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
