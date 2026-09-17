extends Node2D
class_name TagLabel

signal tag_drag_started(tag: Variant, index: int)

var container: Control
var font_path = "res://assets/sprites/World/Fonts/Kenney Mini.ttf"
var badge_texture_path = "res://assets/sprites/tag_property_badge.svg"

var tag_colors = {
	"IMPASSABLE": "#888888",
	"LOCKED": "#ff4444",
	"PASSABLE": "#aaddaa",
	"FRAGILE": "#ffff44",
	"COLD": "#44ccff",
	"LIGHT": "#ffffff",
	"HEAVY": "#aa88ff",
	"SLEEPING": "#6666ff",
	"CHASING": "#ff2222",
	"PATROLLING": "#ddaa22",
	"FLEEING": "#22ffaa",
	"PUSHING": "#ff8800",
	"HARMFUL": "#ff0000",
	"HIDDEN": "#333333",
	"INTERACTABLE": "#44ffdd",
	"YOU": "#ff66cc",
}

var _labels: Array[Control] = []
var _hover_scales: Array[float] = []
var _target_positions: Array[float] = []
var _base_widths: Array[float] = []
var holding_tag: String = ""
var _pulsating_idx: int = -1

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

static var _cached_badge_tex: Texture2D = null

static func get_badge_texture() -> Texture2D:
	if _cached_badge_tex == null:
		if ResourceLoader.exists("res://icon.svg"):
			_cached_badge_tex = load("res://icon.svg")
		else:
			var img: Image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
			img.fill(Color(1.0, 0.84, 0.0, 1.0))
			_cached_badge_tex = ImageTexture.create_from_image(img)
	return _cached_badge_tex

var current_tags: Array = []
var layer_indicator: RichTextLabel = null

func setup(tags: Array, layer_info: String = "") -> void:
	if not container: await ready
	current_tags = tags
	
	for child in container.get_children():
		child.queue_free()
	
	_labels.clear()
	_hover_scales.clear()
	_target_positions.clear()
	_base_widths.clear()

	if layer_info != "":
		layer_indicator = RichTextLabel.new()
		layer_indicator.bbcode_enabled = true
		layer_indicator.fit_content = true
		layer_indicator.autowrap_mode = TextServer.AUTOWRAP_OFF
		layer_indicator.clip_contents = false
		layer_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font: Font = load(font_path)
		if font: layer_indicator.add_theme_font_override("normal_font", font)
		layer_indicator.add_theme_font_size_override("normal_font_size", 4)
		layer_indicator.add_theme_constant_override("outline_size", 2)
		layer_indicator.add_theme_color_override("outline_color", Color.BLACK)
		layer_indicator.text = "[center][color=#cccccc]" + layer_info + "[/color][/center]"
		layer_indicator.position = Vector2(-30, -9)
		layer_indicator.size = Vector2(60, 8)
		container.add_child(layer_indicator)

	var badge_tex: Texture2D = get_badge_texture()

	for tag in tags:
		# Check visibility in Subtext view via TagRegistry
		if not TagRegistry.can_render_tag(tag):
			continue

		var tag_name: String = tag.name if (tag is RefCounted and tag.get("name") != null) else str(tag)
		var properties: Array = tag.properties if (tag is RefCounted and tag.get("properties") != null) else []

		var tag_box := HBoxContainer.new()
		tag_box.mouse_filter = Control.MOUSE_FILTER_STOP
		tag_box.add_theme_constant_override("separation", 2)

		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_contents = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var font: Font = load(font_path)
		if font: label.add_theme_font_override("normal_font", font)
		label.add_theme_font_size_override("normal_font_size", 5)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("outline_color", Color.BLACK)

		var color: String = tag_colors.get(tag_name, "#ffffff")
		label.text = "[color=" + color + "][" + tag_name + "][/color]"
		tag_box.add_child(label)

		# Add square property badge icons to the right of the tag text
		for prop in properties:
			var badge := TextureRect.new()
			badge.texture = badge_tex
			badge.custom_minimum_size = Vector2(6, 6)
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.set_meta("property", str(prop))
			tag_box.add_child(badge)

		container.add_child(tag_box)
		tag_box.set_meta("tag", tag_name)
		tag_box.set_meta("tag_data", tag)
		
		_labels.append(tag_box)
		_hover_scales.append(1.0)
		_target_positions.append(0.0)
		_base_widths.append(0.0)

	await get_tree().process_frame
	
	for i in range(_labels.size()):
		var tag_box = _labels[i]
		if is_instance_valid(tag_box):
			_base_widths[i] = tag_box.size.x
			tag_box.pivot_offset = tag_box.size / 2.0
			tag_box.gui_input.connect(_on_tag_gui_input.bind(tag_box))

func _process(_delta: float) -> void:
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
			else:
				target_scale = 1.25
		
		if i == _pulsating_idx:
			var p = (sin(Time.get_ticks_msec() * 0.015) + 1.0) / 2.0
			target_mod.a = lerp(0.2, 0.7, p)
		
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
		var index: int = node.get_index()
		var tag_data = node.get_meta("tag_data", node.get_meta("tag", ""))
		tag_drag_started.emit(tag_data, index)

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
	if index < 0 or index >= _labels.size():
		return global_position
	var label: Control = _labels[index]
	var w: float = _base_widths[index] if index < _base_widths.size() and _base_widths[index] > 0.0 else label.size.x
	var h: float = label.size.y if label.size.y > 0.0 else 10.0
	return global_position + label.position + Vector2(w * 0.5, h * 0.5)

func get_hovered_tag_index(mouse_pos: Vector2, use_shrink: bool = false) -> int:
	var local_m: Vector2 = mouse_pos - global_position
	for i in range(_labels.size()):
		var label: Control = _labels[i]
		var w: float = _base_widths[i] if i < _base_widths.size() and _base_widths[i] > 0.0 else label.size.x
		var h: float = label.size.y if label.size.y > 0.0 else 12.0
		var rect := Rect2(label.position, Vector2(w, h))
		if use_shrink:
			var shrink: float = rect.size.x * 0.25
			rect.position.x += shrink
			rect.size.x -= shrink * 2.0
		if rect.has_point(local_m):
			return i
	return -1

func get_total_label_rect() -> Rect2:
	if _labels.is_empty():
		return Rect2(global_position - Vector2(16, 12), Vector2(32, 16))
	var min_x: float = 999999.0
	var max_x: float = -999999.0
	for i in range(_labels.size()):
		var label: Control = _labels[i]
		var w: float = _base_widths[i] if i < _base_widths.size() and _base_widths[i] > 0.0 else label.size.x
		min_x = minf(min_x, label.position.x)
		max_x = maxf(max_x, label.position.x + w)
	if is_instance_valid(layer_indicator) and layer_indicator.visible:
		min_x = minf(min_x, layer_indicator.position.x)
		max_x = maxf(max_x, layer_indicator.position.x + layer_indicator.size.x)
	var r_pos: Vector2 = global_position + Vector2(min_x, -14.0)
	var r_size: Vector2 = Vector2(max_x - min_x, 20.0)
	return Rect2(r_pos, r_size).grow(2.0)


func is_mouse_over_label_area(mouse_pos: Vector2) -> bool:
	if modulate.a < 0.2 or _labels.is_empty():
		return false
	return get_total_label_rect().has_point(mouse_pos)

func set_replacement_pulse(index: int) -> void:
	_pulsating_idx = index

func remove_tag_visual(index: int) -> void:
	if index < 0 or index >= _labels.size(): return
	_labels[index].modulate.a = 0.0

func restore_tag_visual(index: int) -> void:
	if index == _pulsating_idx:
		_pulsating_idx = -1
	if index < 0 or index >= _labels.size(): return
	_labels[index].modulate.a = 1.0

func appear(delay: float) -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)

func disappear() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func(): queue_free())
