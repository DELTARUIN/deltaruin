extends Node

@onready var chapter_menu: Control = $HudLayer/ChapterMenu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	chapter_menu.show()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
