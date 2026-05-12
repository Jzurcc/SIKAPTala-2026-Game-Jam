extends Node2D

var container: HBoxContainer
var font_path = "res://assets/sprites/World/Fonts/Kenney Mini.ttf"

var tag_colors = {
	"SOLID": "#888888",
	"LOCKED": "#ff4444",
	"FRAGILE": "#ffff44",
	"COLD": "#44ccff",
	"LIGHT": "#ffffff",
	"HEAVY": "#aa88ff"
}

func _ready() -> void:
	z_index = 110
	container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	container.custom_minimum_size = Vector2(200, 16) 
	container.position = -Vector2(100, 8) 
	container.pivot_offset = Vector2(100, 8)
	
	container.add_theme_constant_override("separation", 2)
	add_child(container)
	modulate.a = 0.0
	_add_float_animation()

func _add_float_animation() -> void:
	var tween = container.create_tween().set_loops()
	var dur = 1.2
	var amt = 2.0
	var base_y = container.position.y
	tween.tween_property(container, "position:y", base_y - amt, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(container, "position:y", base_y, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func setup(tags: Array) -> void:
	if not container: await ready
	
	for child in container.get_children():
		child.queue_free()
	
	for tag in tags:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_contents = false
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var font = load(font_path)
		if font: label.add_theme_font_override("normal_font", font)
		label.add_theme_font_size_override("normal_font_size", 5)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("outline_color", Color.BLACK)
		
		var color = tag_colors.get(tag, "#ffffff")
		label.text = "[color=" + color + "][" + tag + "][/color]"
		
		container.add_child(label)
		
		await get_tree().process_frame
		if is_instance_valid(label):
			label.pivot_offset = label.size / 2.0
			label.mouse_entered.connect(_on_tag_hover.bind(true, label))
			label.mouse_exited.connect(_on_tag_hover.bind(false, label))

func set_selected(selected: bool) -> void:
	var tween = create_tween().set_parallel(true)
	if selected:
		tween.tween_property(container, "scale", Vector2(1.4, 1.4), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.1)


func _on_tag_hover(is_hover: bool, node: Control) -> void:
	var tween = node.create_tween()
	if is_hover:
		tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.1)
	else:
		tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)

func appear(delay: float) -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)

func disappear() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func(): queue_free())
