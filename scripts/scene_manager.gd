extends Node

## Handles scene transitions with fade in/out. Extracted from GameState.
## Register as autoload "SceneManager" in project.godot.

var is_transitioning: bool = false

var _transition_layer: CanvasLayer
var _transition_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 128
	add_child(_transition_layer)

	_transition_rect = ColorRect.new()
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color(0, 0, 0, 0)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_transition_rect)


func transition_to_scene(path: String, start_bgm: bool = false, fade_color: Color = Color.BLACK) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	_transition_rect.color = fade_color
	_transition_rect.color.a = 0.0

	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_transition_rect, "color:a", 1.0, 0.8)
	await tw.finished

	GameState.reset_state()
	get_tree().change_scene_to_file(path)
	await get_tree().create_timer(1.0, true).timeout

	if start_bgm:
		AudioManager.start_gameplay_music()

	tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_transition_rect, "color:a", 0.0, 0.8)
	await tw.finished
	is_transitioning = false
