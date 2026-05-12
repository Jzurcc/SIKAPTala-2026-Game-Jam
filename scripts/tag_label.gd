extends Node2D

signal tag_drag_started(tag: String, index: int)

var container: Control
var font_path = "res://assets/sprites/World/Fonts/Kenney Mini.ttf"

var tag_colors = {
	"IMPASSABLE": "#888888",
	"LOCKED": "#ff4444",
	"PASSABLE": "#aaddaa",
	"FRAGILE": "#ffff44",
	"COLD": "#44ccff",
	"LIGHT": "#ffffff",
	"HEAVY": "#aa88ff"
}

var _labels: Array[Control] = []
var _hover_scales: Array[float] = []
var _target_positions: Array[float] = []
var _base_widths: Array[float] = []
var holding_tag: String = ""

func _ready() -> void:
	z_index = 110
	container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	modulate.a = 0.0
	_add_float_animation()

func _add_float_animation() -> void:
	var tween = container.create_tween().set_loops()
	var dur = 0.8
	var amt = 1.0
	var base_y = container.position.y

	tween.tween_property(container, "position:y", base_y + amt, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(container, "position:y", base_y - amt, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

var current_tags: Array = []

func setup(tags: Array) -> void:
	if not container: await ready
	current_tags = tags
	
	for child in container.get_children():
		child.queue_free()
	
	_labels.clear()
	_hover_scales.clear()
	_target_positions.clear()
	_base_widths.clear()

	for tag in tags:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_contents = false
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var font = load(font_path)
		if font: label.add_theme_font_override("normal_font", font)
		label.add_theme_font_size_override("normal_font_size", 5)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("outline_color", Color.BLACK)

		var color = tag_colors.get(tag, "#ffffff")
		label.text = "[color=" + color + "][" + tag + "][/color]"

		container.add_child(label)
		label.set_meta("tag", tag)
		
		_labels.append(label)
		_hover_scales.append(1.0)
		_target_positions.append(0.0)
		_base_widths.append(0.0)

	await get_tree().process_frame
	
	for i in range(_labels.size()):
		var label = _labels[i]
		if is_instance_valid(label):
			_base_widths[i] = label.size.x
			label.pivot_offset = label.size / 2.0
			label.gui_input.connect(_on_tag_gui_input.bind(label))

func _process(delta: float) -> void:
	if _labels.is_empty(): return
	
	var mouse_pos = get_global_mouse_position()
	var hovered_idx = get_hovered_tag_index(mouse_pos, false)
	
	for i in range(_labels.size()):
		var is_hovered = (i == hovered_idx)
		var target_scale = 1.0
		var target_mod = Color.WHITE
		
		if is_hovered:
			if holding_tag != "" and holding_tag != _labels[i].get_meta("tag", ""):
				target_scale = 1.4
				var c = Color(tag_colors.get(holding_tag, "#ffffff"))
				target_mod = c.lerp(Color.WHITE, 0.3)
				target_mod.a = 1.0 + (sin(Time.get_ticks_msec() * 0.01) * 0.2) # Subtle pulse
			else:
				target_scale = 1.25
		
		_hover_scales[i] = lerp(_hover_scales[i], target_scale, 0.2)
		_labels[i].modulate = _labels[i].modulate.lerp(target_mod, 0.2)

	# Calculate layout
	var total_width = 0.0
	var spacing = 4.0
	var widths = []
	
	for i in range(_labels.size()):
		var scale_factor = _hover_scales[i]
		# Use a slightly larger width for layout when scaled
		var w = _base_widths[i] * (1.0 + (scale_factor - 1.0) * 1.5)
		widths.append(w)
		total_width += w
	
	total_width += spacing * (_labels.size() - 1)
	
	var current_x = -total_width / 2.0
	for i in range(_labels.size()):
		var label = _labels[i]
		var w = widths[i]
		
		# Center of the slot
		var target_x = current_x + w / 2.0
		label.position.x = lerp(label.position.x, target_x - _base_widths[i]/2.0, 0.2)
		label.position.y = -8
		
		# Update visual scale
		label.scale = lerp(label.scale, Vector2.ONE * _hover_scales[i], 0.2)
		
		current_x += w + spacing


func _on_tag_gui_input(event: InputEvent, node: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if "LOCKED" in current_tags:
			for label in _labels:
				if label.get_meta("tag", "") == "LOCKED":
					_shake_node(label)
					break
		
		var index = node.get_index()
		var tag = node.get_meta("tag", "")
		tag_drag_started.emit(tag, index)

func _shake_node(node: Control) -> void:
	var tween = create_tween()
	var amt = 4.0
	var dur = 0.03
	var base_x = node.position.x

	for i in 4:
		tween.tween_property(node, "position:x", base_x + amt, dur)
		tween.tween_property(node, "position:x", base_x - amt, dur)
		amt *= 0.7

	tween.tween_property(node, "position:x", base_x, dur)

func shake_tag(tag_name: String) -> void:
	for label in _labels:
		if label.get_meta("tag", "") == tag_name:
			label.modulate.a = 1.0 # Ensure visible for shake
			_shake_node(label)
			return

var is_selected: bool = false

func set_selected(selected: bool) -> void:
	is_selected = selected
	var tween = create_tween()
	if selected:
		tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.2)

func get_tag_global_position(index: int) -> Vector2:
	if index < 0 or index >= _labels.size(): return global_position
	return _labels[index].global_position

func get_hovered_tag_index(mouse_pos: Vector2, use_shrink: bool = false) -> int:
	for i in range(_labels.size()):
		var rect = _labels[i].get_global_rect()
		if use_shrink:
			var shrink = rect.size.x * 0.25 # 25% each side = 50% center
			rect.position.x += shrink
			rect.size.x -= shrink * 2
		if rect.has_point(mouse_pos):
			return i
	return -1

func is_mouse_over_label_area(mouse_pos: Vector2) -> bool:
	if _labels.is_empty(): return false
	var rects: Array[Rect2] = []
	for label in _labels:
		var r = label.get_global_rect()
		# Use 50% center for sticky lock-on area
		var shrink = r.size.x * 0.25
		r.position.x += shrink
		r.size.x -= shrink * 2
		rects.append(r)
	
	var total_rect = rects[0]
	for i in range(1, rects.size()):
		total_rect = total_rect.merge(rects[i])
		
	return total_rect.grow(2.0).has_point(mouse_pos)

func remove_tag_visual(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	_labels[index].modulate.a = 0.0

func restore_tag_visual(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	_labels[index].modulate.a = 1.0

func appear(delay: float) -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)

func disappear() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func(): queue_free())
