extends Area2D
class_name CameraZone

## If Vector2.ZERO, it will use the global_position of this CameraZone node.
@export var camera_pos: Vector2 = Vector2.ZERO
@export var camera_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	if camera_pos == Vector2.ZERO:
		camera_pos = global_position
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body == GameState.player_ref:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("enter_zone"):
			cam.enter_zone(self)


func _on_body_exited(body: Node2D) -> void:
	if body == GameState.player_ref:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("exit_zone"):
			cam.exit_zone(self)
