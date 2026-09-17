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

	var is_player_node: bool = false
	if node == GameState.player_ref or node.is_in_group("player") or node.name == "Player":
		is_player_node = true
	elif node in GameState.get_you_bodies():
		is_player_node = true
	elif node.has_method("has_tag") and node.has_tag("YOU"):
		is_player_node = true

	if is_player_node:
		if node.get("is_dead") == true or node.get("is_alive") == false:
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
