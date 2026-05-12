extends Node2D

@onready var anim_player: AnimatedSprite2D = $PlayerSprite
@onready var anim_hair: AnimatedSprite2D = $HairSprite
@onready var anim_tool: AnimatedSprite2D = $ToolSprite

const MOVE_DURATION := 0.18

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array[String] = []
var is_dead: bool = false
var is_moving: bool = false
var _move_tween: Tween = null

var _held_dirs: Array[Vector2i] = []


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.register_player(self)
	_play_anim("Idle")
	GameState.call_deferred("refresh_tilemaps")


func _unhandled_input(event: InputEvent) -> void:
	_handle_dir_stack(event, "move_left", Vector2i(-1, 0))
	_handle_dir_stack(event, "move_right", Vector2i(1, 0))
	_handle_dir_stack(event, "move_forward", Vector2i(0, -1))
	_handle_dir_stack(event, "move_back", Vector2i(0, 1))

	if is_dead:
		return

	if event.is_action_pressed("undo"):
		_cancel_move()
		GameState.pop_undo_state()
		_play_anim("Idle")
		get_viewport().set_input_as_handled()
		return

	if is_moving:
		return

	if is_dead:
		return

	if GameState.is_substrate:
		return

	var is_move_event = event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_forward") or event.is_action("move_back")
	if not is_move_event:
		return

	if event.is_echo():
		return

	var dir := _get_held_dir()
	if dir == Vector2i.ZERO:
		return

	get_viewport().set_input_as_handled()
	_attempt_move(dir)

func _handle_dir_stack(event: InputEvent, action: String, dir: Vector2i) -> void:
	if event.is_action_pressed(action):
		if not _held_dirs.has(dir):
			_held_dirs.append(dir)
	elif event.is_action_released(action):
		_held_dirs.erase(dir)


func _attempt_move(dir: Vector2i) -> void:
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		_play_anim("Idle")
		return

	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		if not _try_push(occupant, dir):
			return

	GameState.push_undo_state()
	_step_to(target, dir)

	if GameState.has_harmful_at(grid_pos):
		_die()
		return

	GameState.process_turn()


func _step_to(new_pos: Vector2i, dir: Vector2i) -> void:
	Grid.vacate(grid_pos)
	grid_pos = new_pos
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.player_moved.emit(position)

	if dir.x < 0:
		_set_flip(true)
	elif dir.x > 0:
		_set_flip(false)

	var offset := Vector2(-dir.x, -dir.y) * Grid.TILE_SIZE
	anim_player.position = offset
	anim_hair.position = offset
	anim_tool.position = offset

	_play_anim("Walk")

	if _move_tween:
		_move_tween.kill()

	is_moving = true
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_EXPO)
	_move_tween.set_ease(Tween.EASE_OUT)
		
	_move_tween.tween_property(anim_player, "position", Vector2.ZERO, MOVE_DURATION)
	_move_tween.parallel().tween_property(anim_hair, "position", Vector2.ZERO, MOVE_DURATION)
	_move_tween.parallel().tween_property(anim_tool, "position", Vector2.ZERO, MOVE_DURATION)
	_move_tween.finished.connect(_on_move_finished, CONNECT_ONE_SHOT)


func _on_move_finished() -> void:
	is_moving = false
	var held := _get_held_dir()
	if held != Vector2i.ZERO and not is_dead and not GameState.is_substrate:
		_attempt_move(held)
	else:
		_play_anim("Idle")


func _get_held_dir() -> Vector2i:
	for i in range(_held_dirs.size() - 1, -1, -1):
		var dir = _held_dirs[i]
		var action = ""
		if dir == Vector2i(-1, 0): action = "move_left"
		elif dir == Vector2i(1, 0): action = "move_right"
		elif dir == Vector2i(0, -1): action = "move_forward"
		elif dir == Vector2i(0, 1): action = "move_back"
		
		# Fallback check against global input state in case we missed a release event
		if Input.is_action_pressed(action):
			return dir
		else:
			_held_dirs.remove_at(i)
	return Vector2i.ZERO


func _cancel_move() -> void:
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	is_moving = false
	anim_player.position = Vector2.ZERO
	anim_hair.position = Vector2.ZERO
	anim_tool.position = Vector2.ZERO


func _try_push(obj: Node2D, dir: Vector2i) -> bool:
	if obj.get("tags") == null:
		return false
	if not "LIGHT" in obj.tags:
		return false
	if not obj.has_method("push"):
		return false
	return obj.push(dir)


func _play_anim(anim_name: String) -> void:
	if anim_player.sprite_frames != null and anim_player.sprite_frames.has_animation(anim_name):
		anim_player.play(anim_name)
	if anim_hair.sprite_frames != null and anim_hair.sprite_frames.has_animation(anim_name):
		anim_hair.play(anim_name)
	if anim_tool.sprite_frames != null and anim_tool.sprite_frames.has_animation(anim_name):
		anim_tool.play(anim_name)


func _set_flip(flipped: bool) -> void:
	anim_player.flip_h = flipped
	anim_hair.flip_h = flipped
	anim_tool.flip_h = flipped


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	GameState.player_died.emit()
	await get_tree().create_timer(0.4).timeout
	get_tree().reload_current_scene()
