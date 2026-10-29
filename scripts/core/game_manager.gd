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
	# 展示第一个场景：简单的纯淡入效果，1 秒延迟
	var fade_in_options = SceneManager.create_options(1, "fade")
	var general_options = SceneManager.create_general_options(Color(0, 0, 0), 1, false)
	SceneManager.show_first_scene(fade_in_options, general_options)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_chapter_menu_exit_requested() -> void:
	SceneManager.change_scene("exit", fade_in_options, fade_in_options, general_options)
	pass # Replace with function body.


func _on_chapter_menu_play_requested(row: int) -> void:
	SceneManager.change_scene("archive_menu", fade_in_options, fade_in_options, general_options)
	pass # Replace with function body.
