class_name DragController
extends Node

## Handles dragging and dropping of tags in Subtext mode.
## Operates directly with Grid's spatial tag registry without transient node spawning.

signal drag_started(tag: String, index: int)
signal drag_cancelled
signal swap_completed

var is_dragging: bool = false
var drag_tag: String = ""
var drag_index: int = -1
var drag_source_node: Node2D = null
var drag_source_pos: Vector2i = Vector2i.ZERO
var drag_visual: RichTextLabel = null
var drag_velocity: Vector2 = Vector2.ZERO
var last_mouse_pos: Vector2 = Vector2.ZERO

var _last_preview_idx: int = -1
var _last_preview_label: TagLabel = null


func begin_drag(tag: String, index: int, source_node: Node2D, source_pos: Vector2i, container: CanvasLayer, hover_label: TagLabel) -> void:
	is_dragging = true
	GameState.play_select_sfx()
	drag_source_pos = source_pos
	drag_tag = tag
	drag_index = index
	drag_source_node = source_node

	drag_visual = RichTextLabel.new()
	drag_visual.bbcode_enabled = true
	drag_visual.fit_content = true
	drag_visual.autowrap_mode = TextServer.AUTOWRAP_OFF
	drag_visual.clip_contents = false
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_visual.z_index = 200

	var font: Font = load("res://assets/sprites/World/Fonts/Kenney Mini.ttf")
	if font:
		drag_visual.add_theme_font_override("normal_font", font)
	drag_visual.add_theme_font_size_override("normal_font_size", 5)
	drag_visual.add_theme_constant_override("outline_size", 2)
	drag_visual.add_theme_color_override("outline_color", Color.BLACK)

	var color: String = hover_label.tag_colors.get(tag, "#ffffff") if hover_label else "#ffffff"
	drag_visual.text = "[center][color=" + color + "][" + tag + "][/color][/center]"

	container.add_child(drag_visual)
	if hover_label:
		drag_visual.global_position = hover_label.get_tag_global_position(index)
	drag_visual.pivot_offset = drag_visual.size / 2.0
	drag_visual.scale = Vector2(0.5, 0.5)

	var pop: Tween = create_tween()
	pop.tween_property(drag_visual, "scale", Vector2(1.4, 1.4), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if hover_label:
		hover_label.remove_tag_visual(index)

	var current_sc: Node = get_tree().current_scene
	if current_sc is Node2D:
		last_mouse_pos = (current_sc as Node2D).get_global_mouse_position()
	else:
		last_mouse_pos = Vector2.ZERO

	drag_started.emit(tag, index)


func cancel(hover_label: TagLabel = null) -> void:
	if not is_dragging:
		return
	is_dragging = false
	GameState.play_deselect_sfx()
	if drag_visual:
		drag_visual.queue_free()
		drag_visual = null
	if hover_label:
		hover_label.restore_tag_visual(drag_index)

	if _last_preview_label:
		_last_preview_label.restore_tag_visual(_last_preview_idx)
		_last_preview_label = null
		_last_preview_idx = -1

	drag_cancelled.emit()


func update_visual(delta: float, is_selected: bool, hover_label: TagLabel) -> void:
	if not is_dragging or not drag_visual:
		return

	var current_sc: Node = get_tree().current_scene
	var mouse_pos: Vector2 = (current_sc as Node2D).get_global_mouse_position() if current_sc is Node2D else Vector2.ZERO
	var velocity: Vector2 = (mouse_pos - last_mouse_pos) / maxf(delta, 0.0001)
	drag_velocity = drag_velocity.lerp(velocity, 0.1)
	last_mouse_pos = mouse_pos

	var target_pos: Vector2 = mouse_pos
	var is_snapping: bool = false

	if is_selected and hover_label:
		var hovered_idx: int = hover_label.get_hovered_tag_index(mouse_pos, false)

		if _last_preview_label != hover_label or _last_preview_idx != hovered_idx:
			if is_instance_valid(_last_preview_label):
				_last_preview_label.restore_tag_visual(_last_preview_idx)
			_last_preview_idx = -1
			_last_preview_label = null

		if hovered_idx != -1:
			target_pos = hover_label.get_tag_global_position(hovered_idx)
			hover_label.set_replacement_pulse(hovered_idx)
			_last_preview_idx = hovered_idx
			_last_preview_label = hover_label
			is_snapping = true

	var center_offset: Vector2 = drag_visual.size / 2.0
	drag_visual.pivot_offset = center_offset

	var lerp_speed: float = 0.6 if is_snapping else 0.3
	drag_visual.global_position = drag_visual.global_position.lerp(target_pos - center_offset, lerp_speed)

	var target_rotation: float = clampf(drag_velocity.x * 0.001, -0.4, 0.4)
	if is_snapping:
		target_rotation = 0.0
	drag_visual.rotation = lerp_angle(drag_visual.rotation, target_rotation, 0.2)

	var speed: float = drag_velocity.length()
	var target_scale: float = 1.4 + clampf(speed * 0.0001, 0.0, 0.3)
	if is_snapping:
		target_scale = 1.25
	drag_visual.scale = lerp(drag_visual.scale, Vector2(target_scale, target_scale), 0.1)


func handle_drop(mouse_pos: Vector2, hover_label: TagLabel, last_highlighted: Node2D, display_manager: Node) -> void:
	if not is_dragging:
		return

	var grid_pos: Vector2i = Grid.world_to_grid(mouse_pos)
	var target_layer: TileMapLayer = null
	if display_manager and display_manager.has_method("get_hovered_tile_layer"):
		target_layer = display_manager.get_hovered_tile_layer(mouse_pos, true)
		if target_layer == null:
			target_layer = display_manager.get_hovered_tile_layer(mouse_pos, false)

	var target_node: Node2D = null

	# 1. Check if clicking directly on a tag label
	if hover_label and hover_label.get_hovered_tag_index(mouse_pos, false) != -1:
		target_node = last_highlighted

	# 2. Fallback to spatial detection if not on a tag
	if not target_node:
		var layer_name: String = str(target_layer.name) if target_layer else ""
		var region: Node2D = Grid.get_region_at(grid_pos, layer_name)
		if region and region.has_method("is_pixel_opaque") and region.is_pixel_opaque(mouse_pos):
			target_node = region

	if not target_node:
		var occ: Node2D = Grid.get_occupant(grid_pos)
		if occ and occ != GameState.player_ref:
			target_node = occ

	if not target_node and target_layer:
		if target_layer.get("tags") != null or not Grid.get_cell_tags(grid_pos, target_layer.name).is_empty():
			target_node = target_layer

	if target_node and (target_node != drag_source_node or grid_pos != drag_source_pos):
		var target_idx: int = hover_label.get_hovered_tag_index(mouse_pos, false) if hover_label else -1
		if target_idx == -1:
			target_idx = 0
		perform_swap(drag_source_node, drag_source_pos, drag_index, target_node, grid_pos, target_idx, hover_label)

	cancel(hover_label)


func perform_swap(source_node: Node2D, source_pos: Vector2i, s_idx: int, target_node: Node2D, target_pos: Vector2i, t_idx: int, hover_label: TagLabel) -> void:
	if not is_instance_valid(source_node) or not is_instance_valid(target_node):
		return

	var s_tags: Array[String] = _get_node_tags(source_node, source_pos)
	var t_tags: Array[String] = _get_node_tags(target_node, target_pos)

	if s_tags.is_empty() or t_tags.is_empty():
		return

	if "LOCKED" in t_tags:
		if hover_label:
			hover_label.shake_tag("LOCKED")
		GameState.play_error_sfx()
		swap_completed.emit()
		return

	if s_idx < 0 or s_idx >= s_tags.size() or t_idx < 0 or t_idx >= t_tags.size():
		return

	GameState.push_undo_state()

	var tag_to_move: String = s_tags[s_idx]
	var tag_from_target: String = t_tags[t_idx]

	s_tags[s_idx] = tag_from_target
	t_tags[t_idx] = tag_to_move

	_set_node_tags(source_node, source_pos, s_tags)
	_set_node_tags(target_node, target_pos, t_tags)

	Grid.refresh_all_tags()
	swap_completed.emit()


func _get_node_tags(node: Node2D, pos: Vector2i) -> Array[String]:
	if not is_instance_valid(node):
		return []
	if node is TileMapLayer:
		return Grid.get_cell_tags(pos, node.name)
	if node.get("tags") != null:
		var res: Array[String] = []
		res.assign(node.tags)
		return res
	return []


func _set_node_tags(node: Node2D, pos: Vector2i, new_tags: Array[String]) -> void:
	if not is_instance_valid(node):
		return
	if node is TileMapLayer:
		Grid.set_cell_tag_override(pos, node.name, new_tags)
	elif node.has_method("update_tags"):
		node.update_tags(new_tags)
	elif node.get("tags") != null:
		node.tags.assign(new_tags)
