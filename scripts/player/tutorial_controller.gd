class_name TutorialController
extends Node

## Handles the intro tutorial sequence (CanvasLayer, typewriter animation, input).
## Extracted from player.gd in Phase 5.

var is_active: bool = false
var _tutorial_layer: CanvasLayer
var _tutorial_label: Label
var _tutorial_prompt: Label
var _tutorial_is_typing: bool = false
var _tutorial_texts: Array[String] = [
	"Most people walk through the world without reading it.",
	"You have always read everything.",
	"Press TAB to perceive the Subtext.",
	"Hover over any object to view its tags.",
	"You can rearrange the words of this world.",
	"Click a tag to hold it, and drop it onto another object's tag.",
	"Press E to interact with your surroundings.",
	"Swap the word, shape the world.",
	"Change your view and escape this reality."
]
var _tutorial_index: int = 0
var _tutorial_tween: Tween
var _prompt_tween: Tween


func start() -> void:
	# Disabled for debugging
	return
	# if GameState.tutorial_completed:
	# 	return

	await get_tree().create_timer(4.0).timeout

	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 110

	_tutorial_label = Label.new()
	_tutorial_label.name = "TutLabel"
	_tutorial_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tutorial_label.offset_top = -50
	_tutorial_label.offset_bottom = -25
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/sprites/World/Fonts/Kenney Mini.ttf")
	if font:
		_tutorial_label.add_theme_font_override("font", font)
	_tutorial_label.add_theme_font_size_override("font_size", 8)
	_tutorial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_label.add_theme_constant_override("outline_size", 4)
	_tutorial_label.visible_ratio = 0.0
	_tutorial_layer.add_child(_tutorial_label)

	_tutorial_prompt = Label.new()
	_tutorial_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tutorial_prompt.offset_top = -32
	_tutorial_prompt.offset_bottom = -20
	_tutorial_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_tutorial_prompt.add_theme_font_override("font", font)
	_tutorial_prompt.add_theme_font_size_override("font_size", 6)
	_tutorial_prompt.text = "Press SPACE to continue"
	_tutorial_prompt.modulate.a = 0.0
	_tutorial_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_prompt.add_theme_constant_override("outline_size", 4)
	_tutorial_layer.add_child(_tutorial_prompt)

	add_child(_tutorial_layer)

	is_active = true
	GameState.is_tutorial_active = true
	get_tree().paused = true
	_show_tutorial_text()


func handle_input(event: InputEvent) -> bool:
	if not is_active:
		return false

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		var is_tab_line: bool = (_tutorial_index == 2)
		var key: Key = key_event.keycode

		if _tutorial_is_typing:
			if key == KEY_SPACE or (is_tab_line and key == KEY_TAB):
				if _tutorial_tween:
					_tutorial_tween.kill()
				_on_tutorial_text_finished()
				get_viewport().set_input_as_handled()
				return true
		else:
			if is_tab_line:
				if key == KEY_TAB:
					_tutorial_index += 1
					_show_tutorial_text()
					# Don't mark handled so it actually toggles substrate
					return true
			elif key == KEY_SPACE:
				_tutorial_index += 1
				_show_tutorial_text()
				get_viewport().set_input_as_handled()
				return true
	return true


func _show_tutorial_text() -> void:
	if _tutorial_index >= _tutorial_texts.size():
		is_active = false
		GameState.is_tutorial_active = false
		GameState.tutorial_completed = true
		if _prompt_tween:
			_prompt_tween.kill()
		if _tutorial_layer:
			_tutorial_layer.queue_free()
			_tutorial_layer = null
		get_tree().paused = GameState.is_substrate
		return

	if _prompt_tween:
		_prompt_tween.kill()
	_tutorial_label.text = _tutorial_texts[_tutorial_index]
	_tutorial_label.visible_ratio = 0.0
	_tutorial_prompt.modulate.a = 0.0
	_tutorial_is_typing = true

	if _tutorial_index == 2:
		_tutorial_prompt.text = "Press TAB to continue"
	else:
		_tutorial_prompt.text = "Press SPACE to continue"

	if _tutorial_tween:
		_tutorial_tween.kill()
	_tutorial_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tutorial_tween.tween_property(_tutorial_label, "visible_ratio", 1.0, _tutorial_label.text.length() * 0.015)
	_tutorial_tween.finished.connect(_on_tutorial_text_finished)


func _on_tutorial_text_finished() -> void:
	_tutorial_is_typing = false
	_tutorial_label.visible_ratio = 1.0
	if _tutorial_prompt:
		_tutorial_prompt.visible = true
		_tutorial_prompt.modulate.a = 1.0
		if _prompt_tween:
			_prompt_tween.kill()
		_prompt_tween = create_tween().set_loops()
		_prompt_tween.tween_property(_tutorial_prompt, "modulate:a", 0.3, 0.6)
		_prompt_tween.tween_property(_tutorial_prompt, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
