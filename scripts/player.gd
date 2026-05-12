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


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.register_player(self)
	_play_anim("Idle")


func _unhandled_input(event: InputEvent) -> void:
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

	if dir == Vector2i.ZERO:
		return

	get_viewport().set_input_as_handled()
	_attempt_move(dir)


func _attempt_move(dir: Vector2i) -> void:
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
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
	if Input.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	if Input.is_action_pressed("move_forward"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_back"):
		return Vector2i(0, 1)
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
