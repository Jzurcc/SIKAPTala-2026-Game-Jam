extends Area2D

@export_file("*.tscn") var next_scene: String
@export var fade_color: Color = Color.WHITE

func _ready() -> void:
	body_exited.connect(_on_body_exited)

func _on_body_exited(body: Node) -> void:
	if GameState.is_transitioning: return
	
	print("[LevelExit] Body exited: ", body.name)
	# Check if the body is the player
	if body.name == "Player" or body.is_in_group("player"):
		if body.get("is_dead") == true:
			print("[LevelExit] Player is dead, ignoring exit.")
			return
			
		print("[LevelExit] Player detected! Transitioning to: ", next_scene)
		if next_scene != "":
			GameState.transition_to_scene(next_scene, true, fade_color)
		else:
			print("[LevelExit] WARNING: next_scene is empty!")
