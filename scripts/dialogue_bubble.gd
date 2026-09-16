class_name DialogueBubble
extends Node2D

## Handles over-head / under-character dialogue bubbles and typewritten text.
## Extracted from player.gd in Phase 5.

var _dialogue_label: Label = null
var _dialogue_tween: Tween = null
var _last_dialogue_indices: Dictionary = {}  # instance_id -> int


func _ready() -> void:
	_setup_dialogue_ui()


func _setup_dialogue_ui() -> void:
	_dialogue_label = Label.new()
	var font = load("res://assets/sprites/World/Fonts/Kenney Mini.ttf")
	if font:
		_dialogue_label.add_theme_font_override("font", font)
	_dialogue_label.add_theme_font_size_override("font_size", 6)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.position = Vector2(-50, 14)  # Below character
	_dialogue_label.size = Vector2(100, 48)
	_dialogue_label.visible_ratio = 0.0
	_dialogue_label.modulate.a = 0.0
	add_child(_dialogue_label)


func _process(_delta: float) -> void:
	if _dialogue_label and _dialogue_label.modulate.a > 0.0:
		var sway = sin(Time.get_ticks_msec() * 0.004) * 1.5
		_dialogue_label.position.y = 14 + sway


func show_for(object: Object) -> void:
	var text := _get_dialogue_text(object)

	if _dialogue_tween:
		_dialogue_tween.kill()
	_dialogue_label.text = text
	_dialogue_label.visible_ratio = 0.0
	_dialogue_label.modulate.a = 1.0

	_dialogue_tween = create_tween()
	# Fast typewriter effect (approx 0.02s per character)
	_dialogue_tween.tween_property(_dialogue_label, "visible_ratio", 1.0, text.length() * 0.02)
	_dialogue_tween.tween_interval(1.5)
	_dialogue_tween.tween_property(_dialogue_label, "modulate:a", 0.0, 0.5)


func _get_dialogue_text(object: Object) -> String:
	var raw_text := ""

	# 1. Check for custom dialogues set in the inspector (Randomized, no repeats)
	if "custom_dialogues" in object and not object.custom_dialogues.is_empty():
		raw_text = _pick_random_dialogue(object)
	# 2. Inherit from base layer if it's a SubtextRegion
	elif object is SubtextRegion:
		var layer_name: String = object.get_effective_layer_name()
		var layer: TileMapLayer = null
		for l in GameState.solid_tilemaps:
			if l.name == layer_name:
				layer = l
				break
		if layer and "custom_dialogues" in layer and not layer.custom_dialogues.is_empty():
			raw_text = _pick_random_dialogue(layer)

	if raw_text == "":
		# 3. Check for predefined ID-based dialogue
		var id: String = object.id if "id" in object else ""
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
			var tag_str := ", ".join(object.tags)
			raw_text = "It's " + tag_str + "."

		# Fallback for SubtextRegions
		if raw_text == "" and object is SubtextRegion:
			var layer := object.get_effective_layer_name()
			if "Wall" in layer:
				raw_text = "It's a wall..."
			elif "Floor" in layer:
				raw_text = "It's a floor..."

	if raw_text == "":
		raw_text = "I don't see anything special about this."

	# Pre-wrap the text manually to avoid "jumping" layout during typewriter effect
	var font = _dialogue_label.get_theme_font("font")
	var font_size = _dialogue_label.get_theme_font_size("font_size")
	if font:
		return _wrap_text(raw_text, font, font_size, 100.0)

	return raw_text


func _pick_random_dialogue(object: Object) -> String:
	var dialogues: Array = object.custom_dialogues
	if dialogues.size() == 1:
		return dialogues[0]

	var obj_id := object.get_instance_id()
	var last_idx: int = _last_dialogue_indices.get(obj_id, -1)
	var new_idx := randi() % dialogues.size()
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
		var test_line := current_line + (" " if current_line != "" else "") + word
		var size := font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

		if size.x > width and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line

	if current_line != "":
		lines.append(current_line)

	return "\n".join(lines)
