extends Node2D

signal tag_drag_started(tag: String, index: int)

var container: HBoxContainer
var font_path = "res://assets/sprites/World/Fonts/Kenney Mini.ttf"

var tag_colors = {
	"SOLID": "#888888",
	"LOCKED": "#ff4444",
	"PASSABLE": "#aaddaa",
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
	var dur = 0.8
	var amt = 2.5
	var base_y = container.position.y

	container.position.y = base_y - amt

	tween.tween_property(container, "position:y", base_y + amt, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(container, "position:y", base_y - amt, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

var current_tags: Array = []
var is_shaking: bool = false

func setup(tags: Array) -> void:
	if not container: await ready
	current_tags = tags

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
		label.set_meta("tag", tag)

		await get_tree().process_frame
		if is_instance_valid(label):
			label.pivot_offset = label.size / 2.0
			label.mouse_entered.connect(_on_tag_hover.bind(true, label))
			label.mouse_exited.connect(_on_tag_hover.bind(false, label))
			label.gui_input.connect(_on_tag_gui_input.bind(label))

func _process(_delta: float) -> void:
	_just_selected = false

var _shake_tweens: Dictionary = {}

func _on_tag_gui_input(event: InputEvent, node: Control) -> void:
	if not is_selected or _just_selected: return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if "LOCKED" in current_tags:
			for child in container.get_children():
				if child.get_meta("tag", "") == "LOCKED":
					_shake_node(child)
					break

		var index = node.get_index()
		var tag = node.get_meta("tag", "")
		tag_drag_started.emit(tag, index)

func _shake_node(node: Control) -> void:
	if _shake_tweens.has(node):
		_shake_tweens[node].kill()

	var tween = create_tween()
	_shake_tweens[node] = tween

	var amt = 4.0
	var dur = 0.03
	var base_x = node.position.x

	for i in 4:
		tween.tween_property(node, "position:x", base_x + amt, dur)
		tween.tween_property(node, "position:x", base_x - amt, dur)
		amt *= 0.7

	tween.tween_property(node, "position:x", base_x, dur)
	tween.finished.connect(func(): _shake_tweens.erase(node))

var is_selected: bool = false
var _just_selected: bool = false

func set_selected(selected: bool) -> void:
	if selected and not is_selected:
		_just_selected = true
	is_selected = selected

	var tween = create_tween().set_parallel(true)
	if selected:
		tween.tween_property(container, "scale", Vector2(1.4, 1.4), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.2)

func _on_tag_hover(is_hover: bool, node: Control) -> void:
	if not is_selected: return

	var tween = node.create_tween().set_parallel(true)
	if is_hover:
		tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.15)

func get_tag_global_position(index: int) -> Vector2:
	if index < 0 or index >= container.get_child_count(): return global_position
	return container.get_child(index).global_position

func get_hovered_tag_index(mouse_pos: Vector2) -> int:
	for i in range(container.get_child_count()):
		var child = container.get_child(i)
		if child is Control and child.get_global_rect().has_point(mouse_pos):
			return i
	return -1

func remove_tag_visual(index: int) -> void:
	if index < 0 or index >= container.get_child_count(): return
	container.get_child(index).modulate.a = 0.0


func appear(delay: float) -> void:
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)

func disappear() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func(): queue_free())
