extends GridBody2D

# GridBody2D provides: grid_pos, grid_size, tags, id, custom_dialogues,
# push(), die(), update_tags(), add_tag(), remove_tag(), _tween_to()

@export var patrol_path: Array[Vector2i] = []

var patrol_index: int = 0
var queued_turns: int = 0
var is_alive: bool = true
var anim: AnimatedSprite2D


func _on_ready() -> void:
	z_index = 100
	for child in get_children():
		if child is AnimatedSprite2D:
			anim = child
			break

	GameState.register_entity(self)
	GameState.substrate_toggled.connect(_on_substrate_toggled)
	_play_anim("Idle")


## Entities are not pushable by default (override can_be_pushed if needed).
func can_be_pushed(_dir: Vector2i) -> bool:
	return false


func take_turn() -> void:
	if not is_alive:
		return
	if "SLEEPING" in tags:
		_play_anim("Idle")
		return
	if queued_turns > 0:
		queued_turns -= 1
		return

	if "CHASING" in tags:
		_do_chase()
	elif "PATROLLING" in tags:
		_do_patrol()
	elif "FLEEING" in tags:
		_do_flee()
	else:
		_play_anim("Idle")


func _do_chase() -> void:
	if GameState.player_ref == null:
		return
	if randf() > 0.5:
		_play_anim("Idle")
		return
	var target_pos: Vector2i = GameState.player_ref.get("grid_pos")
	if target_pos:
		_move_entity(_dir_toward(target_pos))


func _do_patrol() -> void:
	if patrol_path.is_empty():
		return
	var next := patrol_path[patrol_index]
	var dir := _dir_toward(next)
	if _move_entity(dir):
		if grid_pos == next:
			patrol_index = (patrol_index + 1) % patrol_path.size()


func _do_flee() -> void:
	if GameState.player_ref == null:
		return
	var player_pos: Vector2i = GameState.player_ref.get("grid_pos")
	if not player_pos:
		return
	var dir := _dir_toward(player_pos)
	var flee_dir := Vector2i(-dir.x, -dir.y)
	if not _move_entity(flee_dir):
		var perp_a := Vector2i(-flee_dir.y, flee_dir.x)
		var perp_b := Vector2i(flee_dir.y, -flee_dir.x)
		if not _move_entity(perp_a):
			_move_entity(perp_b)


func _move_entity(dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO:
		return false

	if dir.x < 0 and anim: anim.flip_h = true
	elif dir.x > 0 and anim: anim.flip_h = false

	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		_play_anim("Idle")
		return false

	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		if occupant == GameState.player_ref:
			if "HARMFUL" in tags:
				attack_player()
			else:
				_play_anim("Idle")
			return false

		if occupant.get("tags") != null and "FRAGILE" in occupant.tags:
			if occupant.has_method("die"):
				occupant.die()
			elif occupant.has_method("_die"):
				occupant._die()
		elif "PUSHING" in tags and occupant.has_method("push"):
			if not occupant.push(dir):
				_play_anim("Idle")
				return false
		else:
			_play_anim("Idle")
			return false

	if "FRAGILE" in tags:
		_on_die_as_entity()
		return false

	Grid.vacate(grid_pos)
	grid_pos = target
	Grid.occupy(grid_pos, self)

	_play_anim("Walk")
	var tw := create_tween()
	tw.tween_property(self, "position", Grid.grid_to_world(grid_pos), MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func(): _play_anim("Idle"))

	if GameState.is_tile_blocked(grid_pos) and "FRAGILE" in tags:
		_on_die_as_entity()

	_check_harmful_tile()
	return true


func _check_harmful_tile() -> void:
	if "HARMFUL" in Grid.get_wall_tags(grid_pos):
		_on_die_as_entity()


func attack_player() -> void:
	var attack_duration := 0.8
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("Attack"):
		var fps := anim.sprite_frames.get_animation_speed("Attack")
		var frames := anim.sprite_frames.get_frame_count("Attack")
		if fps > 0:
			attack_duration = frames / float(fps)

	if GameState.player_ref:
		var diff: Vector2i = GameState.player_ref.get("grid_pos") - grid_pos
		if diff.x < 0 and anim: anim.flip_h = true
		elif diff.x > 0 and anim: anim.flip_h = false

	_play_anim("Attack")
	if GameState.player_ref and GameState.player_ref.has_method("_die"):
		GameState.player_ref._die(attack_duration)


func _dir_toward(target: Vector2i) -> Vector2i:
	var diff := target - grid_pos
	if abs(diff.x) >= abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	return Vector2i(0, sign(diff.y))


func _on_die() -> void:
	_on_die_as_entity()


func _on_die_as_entity() -> void:
	if not is_alive:
		return
	is_alive = false
	_scatter_tags()
	GameState.unregister_entity(self)
	Grid.vacate(grid_pos)
	queue_free()


func _scatter_tags() -> void:
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for tag in tags.duplicate():
		for dir in dirs:
			var neighbor := grid_pos + dir
			var occ: Node2D = Grid.get_occupant(neighbor)
			if occ != null and occ.get("tags") != null:
				if occ.tags.size() < 2 and not tag in occ.tags:
					occ.tags.append(tag)
					break
			var wt := Grid.get_wall_tags(neighbor)
			if wt.size() < 2 and not tag in wt:
				Grid.add_wall_tag(neighbor, tag)
				break


func _play_anim(anim_name: String) -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func _on_substrate_toggled(active: bool) -> void:
	if not active and queued_turns > 0:
		var turns := queued_turns
		queued_turns = 0
		for i in turns:
			take_turn()


func _exit_tree() -> void:
	Grid.vacate(grid_pos)
