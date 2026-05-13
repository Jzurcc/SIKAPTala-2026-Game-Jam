extends Node2D

@onready var anim_player: AnimatedSprite2D = $PlayerSprite
@onready var anim_hair: AnimatedSprite2D = $HairSprite
@onready var anim_tool: AnimatedSprite2D = $ToolSprite

const MOVE_DURATION := 0.18

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array[String] = []
var is_dead: bool = false
var is_moving: bool = false
var facing_dir: Vector2i = Vector2i(0, 1)
var _move_tween: Tween = null

var _held_dirs: Array[Vector2i] = []
var _dialogue_label: Label = null
var _dialogue_tween: Tween = null
var _last_dialogue_indices: Dictionary = {} # instance_id -> int
var selector: Sprite2D
var selector_tween: Tween


func _ready() -> void:
	_setup_dialogue_ui()
	GameState.register_player(self)
	
	# Create a nice interaction selector
	selector = Sprite2D.new()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	# Draw a THICKER, SMALLER outline box (2px thick, 12x12 size)
	for i in range(2, 14):
		for t in range(2): # 2px thickness
			img.set_pixel(i, 2 + t, Color.WHITE) # Top
			img.set_pixel(i, 13 - t, Color.WHITE) # Bottom
			img.set_pixel(2 + t, i, Color.WHITE) # Left
			img.set_pixel(13 - t, i, Color.WHITE) # Right
	selector.texture = ImageTexture.create_from_image(img)
	selector.modulate = Color(1, 1, 1, 0.0) # Start hidden
	selector.top_level = true
	selector.z_index = 5 # Below player, above floor
	add_child(selector)
	
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	_play_anim("Idle")
	GameState.call_deferred("refresh_tilemaps")
	Grid.call_deferred("refresh_all_tags")


func _setup_dialogue_ui() -> void:
	_dialogue_label = Label.new()
	var font = load("res://assets/sprites/World/Fonts/Kenney Mini.ttf")
	if font:
		_dialogue_label.add_theme_font_override("font", font)
	_dialogue_label.add_theme_font_size_override("font_size", 6)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.position = Vector2(-50, 14) # Below character
	_dialogue_label.size = Vector2(100, 48) # Slightly taller for multiline
	_dialogue_label.visible_ratio = 0.0
	add_child(_dialogue_label)
	_dialogue_label.modulate.a = 0.0


func _process(_delta: float) -> void:
	if selector:
		selector.global_position = Grid.grid_to_world(grid_pos + facing_dir)
	
	if _dialogue_label and _dialogue_label.modulate.a > 0.0:
		var sway = sin(Time.get_ticks_msec() * 0.004) * 1.5
		_dialogue_label.position.y = 14 + sway


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

	if event.is_action_pressed("interact"):
		_interact()
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


func _interact() -> void:
	# Pulse the selector
	if selector:
		if selector_tween: selector_tween.kill()
		selector_tween = create_tween()
		selector.scale = Vector2(1.2, 1.2)
		selector.modulate.a = 0.8
		selector_tween.parallel().tween_property(selector, "scale", Vector2.ONE, 0.2)
		selector_tween.parallel().tween_property(selector, "modulate:a", 0.0, 0.2)

	var target := grid_pos + facing_dir
	
	# 1. Check for Occupant (Beads, WorldObjects)
	var occupant = Grid.get_occupant(target)
	if occupant != null:
		if occupant.get("tags") != null and "FRAGILE" in occupant.tags:
			if occupant.has_method("_die"):
				occupant._die()
			return
		if "INTERACTABLE" in occupant.tags:
			_display_dialogue_for(occupant)
			return
		
	# 2. Check for SubtextRegions (Any layer)
	var region = Grid.get_region_at(target)
	if region != null and "INTERACTABLE" in region.tags:
		_display_dialogue_for(region)
		return
		
	# 3. Check for TileMap Layers (Fallback for static walls/floors)
	for layer in GameState.solid_tilemaps:
		if layer.get_used_cells().has(target):
			if "tags" in layer and "INTERACTABLE" in layer.tags:
				_display_dialogue_for(layer)
				return


func _display_dialogue_for(object: Object) -> void:
	var text = _get_dialogue_text(object)
	
	if _dialogue_tween: _dialogue_tween.kill()
	_dialogue_label.text = text
	_dialogue_label.visible_ratio = 0.0
	_dialogue_label.modulate.a = 1.0
	
	_dialogue_tween = create_tween()
	# Fast typewriter effect (approx 0.02s per character)
	_dialogue_tween.tween_property(_dialogue_label, "visible_ratio", 1.0, text.length() * 0.02)
	_dialogue_tween.tween_interval(1.5)
	_dialogue_tween.tween_property(_dialogue_label, "modulate:a", 0.0, 0.5)


func _get_dialogue_text(object: Object) -> String:
	var raw_text = ""
	
	# 1. Check for custom dialogues set in the inspector (Randomized, no repeats)
	if "custom_dialogues" in object and not object.custom_dialogues.is_empty():
		raw_text = _pick_random_dialogue(object)
	# 2. Inherit from base layer if it's a SubtextRegion
	elif object is SubtextRegion:
		var layer_name = object.get_effective_layer_name()
		var layer = null
		for l in GameState.solid_tilemaps:
			if l.name == layer_name:
				layer = l
				break
		if layer and "custom_dialogues" in layer and not layer.custom_dialogues.is_empty():
			raw_text = _pick_random_dialogue(layer)
			
	if raw_text == "":
		# 3. Check for predefined ID-based dialogue
		var id = object.id if "id" in object else ""
		if id != "":
			match id.to_upper():
				"BED": raw_text = "It looks comfortable, but I have work to do."
				"SHELF": raw_text = "Just some old books about perception."
				"BEAD": raw_text = "A strange, glowing bead. It feels heavy with meaning."
				"LOCKED_DOOR": raw_text = "It's locked. I need to change its properties."
				"WALL": raw_text = "It's a wall..."
				"FLOOR": raw_text = "It's a floor..."
		
		# Fallback for objects with tags
		if raw_text == "" and object.get("tags") != null and object.tags.size() > 0:
			var tag_str = ", ".join(object.tags)
			raw_text = "It's " + tag_str + "."

		# Fallback for SubtextRegions
		if raw_text == "" and object is SubtextRegion:
			var layer = object.get_effective_layer_name()
			if "Wall" in layer: raw_text = "It's a wall..."
			elif "Floor" in layer: raw_text = "It's a floor..."
	
	if raw_text == "": raw_text = "I don't see anything special about this."

	# Pre-wrap the text manually to avoid "jumping" layout during typewriter effect
	var font = _dialogue_label.get_theme_font("font")
	var font_size = _dialogue_label.get_theme_font_size("font_size")
	if font:
		return _wrap_text(raw_text, font, font_size, 100)
	
	return raw_text


func _pick_random_dialogue(object: Object) -> String:
	var dialogues = object.custom_dialogues
	if dialogues.size() == 1:
		return dialogues[0]
	
	var obj_id = object.get_instance_id()
	var last_idx = _last_dialogue_indices.get(obj_id, -1)
	var new_idx = randi() % dialogues.size()
	while new_idx == last_idx:
		new_idx = randi() % dialogues.size()
	
	_last_dialogue_indices[obj_id] = new_idx
	return dialogues[new_idx]


func _wrap_text(text: String, font: Font, font_size: int, width: float) -> String:
	var wrapped := ""
	var lines := []
	var words := text.split(" ")
	var current_line := ""
	
	for word in words:
		var test_line = current_line + (" " if current_line != "" else "") + word
		var size = font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		
		if size.x > width and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line
			
	if current_line != "":
		lines.append(current_line)
		
	return "\n".join(lines)


func _attempt_move(dir: Vector2i) -> void:
	facing_dir = dir
	
	# Capture state BEFORE any movement or pushes happen
	GameState.push_undo_state()
	
	if dir.x < 0:
		_set_flip(true)
	elif dir.x > 0:
		_set_flip(false)
		
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		GameState.undo_stack.pop_back() # Move failed, forget the state
		_play_anim("Idle")
		return

	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		if occupant.get("tags") != null and "FRAGILE" in occupant.tags:
			if occupant.has_method("_die"):
				occupant._die()
		elif occupant.has_method("push"):
			if occupant.push(dir):
				# Success!
				pass
			else:
				GameState.undo_stack.pop_back() # Push failed
				_play_anim("Idle")
				return
		else:
			GameState.undo_stack.pop_back() # Not pushable
			_play_anim("Idle")
			return

	_step_to(target, dir)

	if GameState.has_harmful_at(grid_pos):
		_die()
		return

	GameState.process_turn()


func _step_to(new_pos: Vector2i, _dir: Vector2i) -> void:
	Grid.vacate(grid_pos)
	grid_pos = new_pos
	Grid.occupy(grid_pos, self)
	GameState.player_moved.emit(position)

	_play_anim("Walk")

	if _move_tween:
		_move_tween.kill()

	is_moving = true
	_move_tween = create_tween()
	
	var target_pos = Grid.grid_to_world(grid_pos)
	_move_tween.tween_property(self, "position", target_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
