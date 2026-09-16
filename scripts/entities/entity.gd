class_name Entity
extends GridBody2D

## Animated NPC / enemy entity.
## Inherits from GridBody2D. Movement, collision, pushing, and AI turn behaviors
## are delegated to TagRule strategies via TagRegistry.

@export var patrol_path: Array[Vector2i] = []
var patrol_index: int = 0
var queued_turns: int = 0
var anim: AnimatedSprite2D


func _on_ready() -> void:
	z_index = 100
	for child: Node in get_children():
		if child is AnimatedSprite2D:
			anim = child
			break

	GameState.register_entity(self)
	GameState.substrate_toggled.connect(_on_substrate_toggled)
	play_anim("Idle")


func attack_player() -> void:
	var attack_duration: float = 0.8
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("Attack"):
		var fps: float = anim.sprite_frames.get_animation_speed("Attack")
		var frames: int = anim.sprite_frames.get_frame_count("Attack")
		if fps > 0:
			attack_duration = float(frames) / fps

	if GameState.player_ref:
		var target_pos: Vector2i = GameState.player_ref.get("grid_pos")
		var diff: Vector2i = target_pos - grid_pos
		if diff.x < 0 and anim:
			anim.flip_h = true
		elif diff.x > 0 and anim:
			anim.flip_h = false

	play_anim("Attack")
	if GameState.player_ref and GameState.player_ref.has_method("_die"):
		GameState.player_ref._die(attack_duration)


func _on_die() -> void:
	_scatter_tags()
	GameState.unregister_entity(self)


func _scatter_tags() -> void:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for tag: String in tags.duplicate():
		for dir: Vector2i in dirs:
			var neighbor: Vector2i = grid_pos + dir
			var occ: Node2D = Grid.get_occupant(neighbor)
			if occ != null and occ.get("tags") != null:
				if occ.tags.size() < 2 and not tag in occ.tags:
					occ.tags.append(tag)
					break
			var wt: Array = Grid.get_wall_tags(neighbor)
			if wt.size() < 2 and not tag in wt:
				Grid.add_wall_tag(neighbor, tag)
				break


func _on_substrate_toggled(active: bool) -> void:
	if not active and queued_turns > 0:
		var turns: int = queued_turns
		queued_turns = 0
		for i in range(turns):
			take_turn()
