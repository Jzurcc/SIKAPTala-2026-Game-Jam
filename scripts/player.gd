extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array[String] = []
var is_dead: bool = false


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.register_player(self)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event.is_action_pressed("undo"):
		GameState.pop_undo_state()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("substrate_toggle"):
		GameState.toggle_substrate()
		get_viewport().set_input_as_handled()
		return

	if GameState.is_substrate:
		return

	var dir := Vector2i.ZERO
	if event.is_action_pressed("move_left"):
		dir = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		dir = Vector2i(1, 0)
	elif event.is_action_pressed("move_forward"):
		dir = Vector2i(0, -1)
	elif event.is_action_pressed("move_back"):
		dir = Vector2i(0, 1)

	if dir != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_attempt_move(dir)


func _attempt_move(dir: Vector2i) -> void:
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		return

	var occupant := Grid.get_occupant(target)
	if occupant != null:
		if not _try_push(occupant, dir):
			return

	GameState.push_undo_state()
	_step_to(target)

	if GameState.has_harmful_at(grid_pos):
		_die()
		return

	GameState.process_turn()


func _step_to(new_pos: Vector2i) -> void:
	Grid.vacate(grid_pos)
	grid_pos = new_pos
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)


func _try_push(obj: Node2D, dir: Vector2i) -> bool:
	if obj.get("tags") == null:
		return false
	if not "LIGHT" in obj.tags:
		return false
	if not obj.has_method("push"):
		return false
	return obj.push(dir)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	GameState.player_died.emit()
	await get_tree().create_timer(0.4).timeout
	get_tree().reload_current_scene()
