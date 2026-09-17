extends CharacterBody2D

@onready var anim_player: AnimatedSprite2D = $PlayerSprite
@onready var anim_hair: AnimatedSprite2D = $HairSprite
@onready var anim_tool: AnimatedSprite2D = $ToolSprite

const MOVE_DURATION := 0.18

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array = []
var is_dead: bool = false
var is_moving: bool = false
var facing_dir: Vector2i = Vector2i(0, 1)
var _move_tween: Tween = null
var _held_dirs: Array[Vector2i] = []

var selector: Sprite2D
var selector_tween: Tween

var tutorial: TutorialController
var dialogue: DialogueBubble


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")

	anim_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	anim_hair.process_mode = Node.PROCESS_MODE_PAUSABLE
	anim_tool.process_mode = Node.PROCESS_MODE_PAUSABLE

	dialogue = DialogueBubble.new()
	add_child(dialogue)

	# tutorial = TutorialController.new()
	# add_child(tutorial)
	# tutorial.start()

	if tags.is_empty():
		var hidden_props: Array[String] = ["HIDDEN"]
		tags = [SubtextTag.create("YOU", hidden_props)]
	else:
		if has_tag("YOU"):
			TagRegistry.notify_tag_added(self, "YOU")

	GameState.register_player(self)
	_setup_selector()


	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	_play_anim("Idle")
	GameState.call_deferred("refresh_tilemaps")
	Grid.call_deferred("refresh_all_tags")


func _setup_selector() -> void:
	selector = Sprite2D.new()
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for i in range(2, 14):
		for t in range(2):
			img.set_pixel(i, 2 + t, Color.WHITE)
			img.set_pixel(i, 13 - t, Color.WHITE)
			img.set_pixel(2 + t, i, Color.WHITE)
			img.set_pixel(13 - t, i, Color.WHITE)
	selector.texture = ImageTexture.create_from_image(img)
	selector.modulate = Color(1, 1, 1, 0.0)
	selector.top_level = true
	selector.z_as_relative = false
	selector.z_index = 4096
	add_child(selector)


func _process(_delta: float) -> void:
	if selector:
		selector.global_position = Grid.grid_to_world(grid_pos + facing_dir)


func _unhandled_input(event: InputEvent) -> void:
	if tutorial and tutorial.handle_input(event):
		return

	if get_tree().paused:
		return

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

	if event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()
		return

	if is_moving or is_dead or GameState.is_substrate:
		return

	var is_move_event: bool = event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_forward") or event.is_action("move_back")
	if not is_move_event or event.is_echo():
		return

	var dir: Vector2i = _get_held_dir()
	if dir == Vector2i.ZERO:
		return

	get_viewport().set_input_as_handled()

	var you_bodies: Array[Node2D] = GameState.get_you_bodies()
	if you_bodies.is_empty():
		return

	if you_bodies.has(self):
		_attempt_move(dir)
	else:
		var primary: Node2D = you_bodies[0]
		if primary != null and is_instance_valid(primary):
			GameState.step_turn(primary, dir)



func _handle_dir_stack(event: InputEvent, action: String, dir: Vector2i) -> void:
	if event.is_action_pressed(action):
		if not _held_dirs.has(dir):
			_held_dirs.append(dir)
	elif event.is_action_released(action):
		_held_dirs.erase(dir)


func _interact() -> void:
	if selector:
		if selector_tween:
			selector_tween.kill()
		selector_tween = create_tween()
		selector.scale = Vector2(1.2, 1.2)
		selector.modulate.a = 0.8
		selector_tween.parallel().tween_property(selector, "scale", Vector2.ONE, 0.2)
		selector_tween.parallel().tween_property(selector, "modulate:a", 0.0, 0.2)

	var target: Vector2i = grid_pos + facing_dir

	# 1. Check for Occupant (Beads, WorldObjects)
	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		if occupant.get("tags") != null and "FRAGILE" in occupant.tags:
			if occupant.has_method("die"):
				occupant.die()
			elif occupant.has_method("_die"):
				occupant._die()
			return
		if occupant.get("tags") != null and "INTERACTABLE" in occupant.tags:
			dialogue.show_for(occupant)
			return

	# 2. Check for SubtextRegions (Any layer)
	var region: Node2D = Grid.get_region_at(target)
	if region != null and "INTERACTABLE" in region.tags:
		dialogue.show_for(region)
		return

	# 3. Check for TileMap Layers
	for layer: TileMapLayer in GameState.solid_tilemaps:
		if layer.get_used_cells().has(target):
			if "tags" in layer and "INTERACTABLE" in layer.tags:
				dialogue.show_for(layer)
				return


func _attempt_move(dir: Vector2i) -> void:
	facing_dir = dir

	if dir.x < 0:
		_set_flip(true)
	elif dir.x > 0:
		_set_flip(false)

	var success: bool = GameState.step_turn(self, dir)
	if success:
		_play_anim("Walk")
		if _move_tween:
			_move_tween.kill()

		is_moving = true
		_move_tween = create_tween()
		var target_pos: Vector2 = Grid.grid_to_world(grid_pos)
		_move_tween.tween_property(self, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_move_tween.finished.connect(_on_move_finished, CONNECT_ONE_SHOT)
	else:
		_play_anim("Idle")


func _on_move_finished() -> void:
	is_moving = false
	var held: Vector2i = _get_held_dir()
	if held != Vector2i.ZERO and not is_dead and not GameState.is_substrate:
		_attempt_move(held)
	else:
		_play_anim("Idle")


func _get_held_dir() -> Vector2i:
	for i in range(_held_dirs.size() - 1, -1, -1):
		var dir: Vector2i = _held_dirs[i]
		var action: String = ""
		if dir == Vector2i(-1, 0): action = "move_left"
		elif dir == Vector2i(1, 0): action = "move_right"
		elif dir == Vector2i(0, -1): action = "move_forward"
		elif dir == Vector2i(0, 1): action = "move_back"

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


func _die(death_delay: float = 0.8) -> void:
	if is_dead:
		return
	is_dead = true
	_cancel_move()
	GameState.player_died.emit()

	var fade_layer: CanvasLayer = CanvasLayer.new()
	fade_layer.layer = 120
	var color_rect: ColorRect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(color_rect)
	get_tree().current_scene.add_child(fade_layer)

	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(death_delay)
	tw.tween_property(color_rect, "color:a", 1.0, 0.5)
	await tw.finished
	GameState.reset_state()
	get_tree().reload_current_scene()


func get_tag_names() -> Array[String]:
	var res: Array[String] = []
	for t in tags:
		if t is RefCounted and t.get("name") != null:
			res.append(str(t.name))
		else:
			res.append(str(t))
	return res


func has_tag(tag_name: String) -> bool:
	for t in tags:
		if t is RefCounted and t.get("name") != null:
			if str(t.name) == tag_name:
				return true
		elif str(t) == tag_name:
			return true
	return false


func update_tags(new_tags: Array) -> void:
	var old_tag_names: Array[String] = get_tag_names()
	tags = new_tags.duplicate()
	var new_tag_names: Array[String] = get_tag_names()
	for t: String in old_tag_names:
		if not t in new_tag_names:
			TagRegistry.notify_tag_removed(self, t)
	for t: String in new_tag_names:
		if not t in old_tag_names:
			TagRegistry.notify_tag_added(self, t)
	Grid.refresh_all_tags()


func add_tag(tag: Variant) -> bool:
	var tag_name: String = tag.name if (tag is RefCounted and tag.get("name") != null) else str(tag)
	if has_tag(tag_name):
		return false
	tags.append(tag)
	TagRegistry.notify_tag_added(self, tag_name)
	Grid.refresh_all_tags()
	return true


func remove_tag(tag_name: String) -> bool:
	var found_idx: int = -1
	for i in range(tags.size()):
		var t = tags[i]
		var t_name: String = t.name if (t is RefCounted and t.get("name") != null) else str(t)
		if t_name == tag_name:
			found_idx = i
			break
	if found_idx == -1:
		return false
	tags.remove_at(found_idx)
	TagRegistry.notify_tag_removed(self, tag_name)
	Grid.refresh_all_tags()
	return true


func get_bounding_rect() -> Rect2:
	return Rect2(global_position - Vector2(8, 8), Vector2(16, 16))


func get_display_top_world_pos() -> Vector2:
	return global_position + Vector2(0, -12)

