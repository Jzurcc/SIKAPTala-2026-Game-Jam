extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array[String] = []
var patrol_path: Array[Vector2i] = []
var patrol_index: int = 0
var queued_turns: int = 0
var is_alive: bool = true


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.register_entity(self)
	GameState.substrate_toggled.connect(_on_substrate_toggled)


func take_turn() -> void:
	if not is_alive:
		return
	if "SLEEPING" in tags:
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


func _do_chase() -> void:
	if GameState.player_ref == null:
		return
	var target_pos := GameState.player_ref.grid_pos
	var dir := _dir_toward(target_pos)
	if dir == Vector2i.ZERO:
		return
	_try_move(dir)


func _do_patrol() -> void:
	if patrol_path.is_empty():
		return
	var next := patrol_path[patrol_index]
	var dir := _dir_toward(next)
	if _try_move(dir):
		if grid_pos == next:
			patrol_index = (patrol_index + 1) % patrol_path.size()


func _do_flee() -> void:
	if GameState.player_ref == null:
		return
	var player_pos := GameState.player_ref.grid_pos
	var dir := _dir_toward(player_pos)
	var flee_dir := Vector2i(-dir.x, -dir.y)
	if not _try_move(flee_dir):
		var perp_a := Vector2i(-flee_dir.y, flee_dir.x)
		var perp_b := Vector2i(flee_dir.y, -flee_dir.x)
		if not _try_move(perp_a):
			_try_move(perp_b)


func _try_move(dir: Vector2i) -> bool:
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		return false

	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		if occupant == GameState.player_ref:
			if "HARMFUL" in tags:
				GameState.player_ref._die()
			return false
		if "PUSHING" in tags and occupant.has_method("push"):
			occupant.push(dir)
		else:
			return false

	if "FRAGILE" in tags:
		_die()
		return false

	Grid.vacate(grid_pos)
	grid_pos = target
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)

	if GameState.is_tile_blocked(grid_pos):
		if "FRAGILE" in tags:
			_die()

	_check_harmful_tile()
	return true


func _check_harmful_tile() -> void:
	var wt := Grid.get_wall_tags(grid_pos)
	if "HARMFUL" in wt:
		_die()


func _dir_toward(target: Vector2i) -> Vector2i:
	var diff := target - grid_pos
	if abs(diff.x) >= abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	return Vector2i(0, sign(diff.y))


func _die() -> void:
	if not is_alive:
		return
	is_alive = false
	_scatter_tags()
	GameState.unregister_entity(self)
	Grid.vacate(grid_pos)
	queue_free()


func _scatter_tags() -> void:
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var tag_queue := tags.duplicate()
	for tag in tag_queue:
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


func add_tag(tag: String) -> bool:
	if tags.size() >= 2:
		return false
	if tag in tags:
		return false
	tags.append(tag)
	return true


func remove_tag(tag: String) -> bool:
	if not tag in tags:
		return false
	tags.erase(tag)
	return true


func _on_substrate_toggled(active: bool) -> void:
	if not active and queued_turns > 0:
		var turns := queued_turns
		queued_turns = 0
		for i in turns:
			take_turn()


func _exit_tree() -> void:
	Grid.vacate(grid_pos)
