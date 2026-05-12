extends CanvasLayer

var color_rect: ColorRect
var shader_mat: ShaderMaterial
var tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = load("res://assets/shaders/subtext2.gdshader")
	if shader:
		shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader
		shader_mat.set_shader_parameter("radius", 0.0)
		shader_mat.set_shader_parameter("global_alpha", 0.3)
		color_rect.material = shader_mat

	color_rect.modulate.a = 0.75
	add_child(color_rect)

	GameState.substrate_toggled.connect(_on_substrate_toggled)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("substrate_toggle"):
		GameState.toggle_substrate()
		get_viewport().set_input_as_handled()

func _on_substrate_toggled(active: bool) -> void:
	if not shader_mat:
		return

	if tween and tween.is_valid():
		tween.kill()

	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var screen_size = get_viewport().get_visible_rect().size
	var aspect = screen_size.x / max(screen_size.y, 1.0)
	shader_mat.set_shader_parameter("aspect_ratio_expansion", aspect)

	var center_uv = Vector2(0.5, 0.5)
	if GameState.player_ref:
		var screen_pos = GameState.player_ref.get_global_transform_with_canvas().origin
		center_uv = screen_pos / screen_size

	shader_mat.set_shader_parameter("center", center_uv)

	if active:
		tween.tween_property(shader_mat, "shader_parameter/radius", 2.0, 0.4)
	else:
		tween.tween_property(shader_mat, "shader_parameter/radius", 0.0, 0.4)
