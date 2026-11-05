extends Panel
class_name PotraitPanel

@export var hide_when_empty := true

@onready var dialogic_node_portrait_container: DialogicNode_PortraitContainer = $PortraitBackgroundColor/DialogicNode_PortraitContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if hide_when_empty:
		visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if hide_when_empty:
		visible = dialogic_node_portrait_container.get_child_count() > 0
	pass
