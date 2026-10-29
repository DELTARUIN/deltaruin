extends DialogicNode_ChoiceButton

@onready var texture_rect: TextureRect = $TextureRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	texture_rect.modulate.a=0
	pass # Replace with function body.

func _on_focus_exited() -> void:
	texture_rect.modulate.a=0
	pass # Replace with function body.


func _on_focus_entered() -> void:
	texture_rect.modulate.a=1
	pass # Replace with function body.
