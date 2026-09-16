extends Area2D

@export_file("*.tscn") var next_scene: String
@export var fade_color: Color = Color.WHITE

func _ready() -> void:
	body_exited.connect(_on_body_exited)
	area_exited.connect(_on_area_exited)


func _on_body_exited(body: Node) -> void:
	_trigger_exit(body)


func _on_area_exited(area: Area2D) -> void:
	_trigger_exit(area.get_parent() if area else null)


func _trigger_exit(node: Node) -> void:
	if GameState.is_transitioning:
		return
	if node == null:
		return

	if node.name == "Player" or node.is_in_group("player"):
		if node.get("is_dead") == true:
			return

		if next_scene != "":
			var target_path: String = next_scene
			if target_path.begins_with("uid://"):
				var resolved: String = ResourceUID.get_id_path(ResourceUID.text_to_id(target_path))
				if resolved != "":
					target_path = resolved
			GameState.transition_to_scene(target_path, true, fade_color)
		else:
			print("[LevelExit] WARNING: next_scene is empty!")
