extends Node

var hover_label: TagLabel
var current_tags: Array = []
var last_highlighted: Node2D = null
var tile_highlight_sprite: Sprite2D
var highlight_container: Node2D
var label_container: CanvasLayer

var is_selected: bool = false

var is_dragging: bool = false
var drag_tag: String = ""
var drag_index: int = -1
var drag_source_node: Node2D = null
var drag_source_pos: Vector2i = Vector2i.ZERO
var drag_visual: RichTextLabel = null
var drag_velocity: Vector2 = Vector2.ZERO
var last_mouse_pos: Vector2 = Vector2.ZERO
var _target_world_pos: Vector2 = Vector2.ZERO
var _last_preview_idx: int = -1
var _last_preview_label: TagLabel = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	highlight_container = Node2D.new()
	add_child(highlight_container)

	label_container = CanvasLayer.new()
	label_container.layer = 101
	label_container.follow_viewport_enabled = true
	add_child(label_container)

	tile_highlight_sprite = Sprite2D.new()
	tile_highlight_sprite.centered = true
	tile_highlight_sprite.region_enabled = true
	tile_highlight_sprite.modulate = Color(0.5, 0.8, 1.5, 0.6)
	tile_highlight_sprite.visible = false
	highlight_container.add_child(tile_highlight_sprite)

	hover_label = TagLabel.new()
	label_container.add_child(hover_label)
	hover_label.modulate.a = 0.0
	hover_label.tag_drag_started.connect(_on_tag_drag_started)

func _input(event: InputEvent) -> void:
	if not GameState.is_substrate: return

	if event.is_action_pressed("ui_cancel"):
		if is_dragging: _cancel_drag()
		_deselect()
		return

	if event is InputEventMouseButton:
		var mouse_pos = get_tree().current_scene.get_global_mouse_position()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_dragging:
					_handle_drop(mouse_pos)
					get_viewport().set_input_as_handled()
					return
			else:
				pass # Released does nothing in sticky mode

func _on_tag_drag_started(tag: String, index: int) -> void:
	if "LOCKED" in current_tags: 
		if hover_label:
			hover_label.shake_tag("LOCKED")
		GameState.play_error_sfx()
		return
	if last_highlighted == null: return

	if last_highlighted is TileMapLayer:
		var m_pos = get_tree().current_scene.get_global_mouse_position()
		var g_pos = Grid.world_to_grid(m_pos)
		last_highlighted = Grid.isolate_tile_as_region(g_pos, last_highlighted.name)

	is_dragging = true
	GameState.play_select_sfx()
	drag_source_pos = Grid.world_to_grid(get_tree().current_scene.get_global_mouse_position())
	drag_tag = tag
	drag_index = index
	drag_source_node = last_highlighted

	drag_visual = RichTextLabel.new()
	drag_visual.bbcode_enabled = true
	drag_visual.fit_content = true
	drag_visual.autowrap_mode = TextServer.AUTOWRAP_OFF
	drag_visual.clip_contents = false
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_visual.z_index = 200

	var font = load("res://assets/sprites/World/Fonts/Kenney Mini.ttf")
	if font: drag_visual.add_theme_font_override("normal_font", font)
	drag_visual.add_theme_font_size_override("normal_font_size", 5)
	drag_visual.add_theme_constant_override("outline_size", 2)
	drag_visual.add_theme_color_override("outline_color", Color.BLACK)

	var color = hover_label.tag_colors.get(tag, "#ffffff")
	drag_visual.text = "[center][color=" + color + "][" + tag + "][/color][/center]"

	label_container.add_child(drag_visual)
	drag_visual.global_position = hover_label.get_tag_global_position(index)
	drag_visual.pivot_offset = drag_visual.size / 2.0
	drag_visual.scale = Vector2(0.5, 0.5)
	
	var pop = create_tween()
	pop.tween_property(drag_visual, "scale", Vector2(1.4, 1.4), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	hover_label.remove_tag_visual(index)
	last_mouse_pos = get_tree().current_scene.get_global_mouse_position()

func _cancel_drag() -> void:
	is_dragging = false
	GameState.play_deselect_sfx()
	if drag_visual:
		drag_visual.queue_free()
	if hover_label:
		hover_label.restore_tag_visual(drag_index)
	
	# Also restore any tag hidden for preview
	if _last_preview_label:
		_last_preview_label.restore_tag_visual(_last_preview_idx)
		_last_preview_label = null
		_last_preview_idx = -1

func _handle_drop(mouse_pos: Vector2) -> void:
	var grid_pos = Grid.world_to_grid(mouse_pos)
	var target_layer = get_hovered_tile_layer(mouse_pos, true)
	if target_layer == null:
		target_layer = get_hovered_tile_layer(mouse_pos, false)
	var target_node: Node2D = null

	# 1. Check if we are clicking directly on a tag label
	if hover_label and hover_label.get_hovered_tag_index(mouse_pos, false) != -1:
		target_node = last_highlighted

	# 2. Fallback to spatial detection if not on a tag
	if not target_node:
		var region = Grid.get_region_at(grid_pos, target_layer.name if target_layer else "")
		if region and region.is_pixel_opaque(mouse_pos):
			target_node = region

	if not target_node:
		var occ = Grid.get_occupant(grid_pos)
		if occ and occ != GameState.player_ref:
			target_node = occ

	if not target_node and target_layer:
		if target_layer.get("tags") != null:
			target_node = target_layer

	if target_node and target_node != drag_source_node:
		var target_idx = hover_label.get_hovered_tag_index(mouse_pos, false)
		if target_idx == -1: target_idx = 0
		_perform_swap(drag_source_node, drag_index, target_node, target_idx)

	_cancel_drag()

func _perform_swap(source: Node2D, s_idx: int, target: Node2D, t_idx: int) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target): return
	
	if source is TileMapLayer:
		source = Grid.isolate_tile_as_region(drag_source_pos, source.name)

	if target is TileMapLayer:
		var m_pos = get_tree().current_scene.get_global_mouse_position()
		var g_pos = Grid.world_to_grid(m_pos)
		target = Grid.isolate_tile_as_region(g_pos, target.name)

	GameState.push_undo_state()

	var s_tags = source.get("tags")
	var t_tags = target.get("tags")

	if s_tags == null or t_tags == null: return
	
	if "LOCKED" in t_tags:
		if hover_label:
			hover_label.shake_tag("LOCKED")
		GameState.play_error_sfx()
		_deselect()
		_clear_highlight()
		return
		
	if t_idx < 0 or t_idx >= t_tags.size(): return

	var tag_to_move = s_tags[s_idx]
	var tag_from_target = t_tags[t_idx]

	s_tags[s_idx] = tag_from_target
	t_tags[t_idx] = tag_to_move

	if source.has_method("update_tags"):
		source.update_tags(s_tags)

	if target.has_method("update_tags"):
		target.update_tags(t_tags)

	Grid.refresh_all_tags()
	_deselect()
	_clear_highlight()
	current_tags = [] 


func _select() -> void:
	is_selected = true
	tile_highlight_sprite.visible = false
	if hover_label.has_method("set_selected"):
		hover_label.set_selected(true)

func _deselect() -> void:
	is_selected = false
	if hover_label.has_method("set_selected"):
		hover_label.set_selected(false)

func _process(delta: float) -> void:
	if not GameState.is_substrate:
		if is_dragging: _cancel_drag()
		_deselect()
		_clear_highlight()
		tile_highlight_sprite.visible = false
		hover_label.modulate.a = 0
		current_tags = []
		return

	if is_dragging:
		_update_dragging_visual(delta)
	
	_update_pulsating_highlight(delta)


	var scene = get_tree().current_scene
	if not scene: return

	var mouse_pos = scene.get_global_mouse_position()
	
	var tags: Array = []
	var has_content: bool = false
	var is_locked: bool = false

	if is_selected:
		if hover_label.is_mouse_over_label_area(mouse_pos):
			is_locked = true

	if is_locked:
		tags = current_tags.duplicate()
		has_content = true
	else:
		var grid_pos = Grid.world_to_grid(mouse_pos)
		var top_layer = get_hovered_tile_layer(mouse_pos, true)
		if top_layer == null:
			top_layer = get_hovered_tile_layer(mouse_pos, false)

		var region = Grid.get_region_at(grid_pos, top_layer.name if top_layer else "")

		if region != null:
			var target = region.get_effective_layer_name()
			if target != "" and top_layer != null and target != top_layer.name:
				region = null
			elif not region.is_pixel_opaque(mouse_pos):
				region = null

		var occupant = Grid.get_occupant(grid_pos)

		if region != null:
			tags = region.tags.duplicate()
			_target_world_pos = region.get_center_world_pos()
			has_content = true
			tile_highlight_sprite.visible = false
			_set_highlight(region)
		else:
			tags = []
			if top_layer != null and Grid.layer_tags.has(grid_pos):
				var lt = Grid.layer_tags[grid_pos]
				if lt.has(top_layer.name):
					tags = lt[top_layer.name].duplicate()

			_target_world_pos = Grid.grid_to_world(grid_pos)

			if occupant and occupant != GameState.player_ref:
				_set_highlight(occupant)
				tile_highlight_sprite.visible = false
				if occupant.get("tags") != null:
					tags = occupant.tags.duplicate()
				has_content = true
			elif top_layer != null and not tags.is_empty():
				if last_highlighted != top_layer:
					_clear_highlight()
					last_highlighted = top_layer
				_highlight_layer_tile(top_layer, grid_pos)
				has_content = true
			else:
				tile_highlight_sprite.visible = false
				_clear_highlight()

	if has_content and not tags.is_empty():
		if not is_selected:
			_select()
		if tags != current_tags:
			current_tags = tags
			hover_label.setup(tags)
		
		hover_label.holding_tag = drag_tag if is_dragging else ""
		if is_dragging and last_highlighted == drag_source_node:
			hover_label.remove_tag_visual(drag_index)

		hover_label.global_position = hover_label.global_position.lerp(_target_world_pos, 0.15)
		hover_label.modulate.a = lerp(hover_label.modulate.a, 1.0, 0.2)
	else:
		if is_selected:
			_deselect()
		hover_label.modulate.a = lerp(hover_label.modulate.a, 0.0, 0.3)
		if hover_label.modulate.a < 0.05:
			current_tags = []

func _update_dragging_visual(delta: float) -> void:
	var mouse_pos = get_tree().current_scene.get_global_mouse_position()
	var velocity = (mouse_pos - last_mouse_pos) / delta
	drag_velocity = drag_velocity.lerp(velocity, 0.1)
	last_mouse_pos = mouse_pos

	var target_pos = mouse_pos
	var is_snapping = false
	
	if is_selected and hover_label:
		var hovered_idx = hover_label.get_hovered_tag_index(mouse_pos, false) 
		
		# Clear old preview if needed
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

	var center_offset = drag_visual.size / 2.0
	drag_visual.pivot_offset = center_offset

	var lerp_speed = 0.6 if is_snapping else 0.3
	drag_visual.global_position = drag_visual.global_position.lerp(target_pos - center_offset, lerp_speed)

	var target_rotation = clamp(drag_velocity.x * 0.001, -0.4, 0.4)
	if is_snapping: target_rotation = 0.0
	drag_visual.rotation = lerp_angle(drag_visual.rotation, target_rotation, 0.2)

	var speed = drag_velocity.length()
	var target_scale = 1.4 + clamp(speed * 0.0001, 0.0, 0.3)
	if is_snapping: target_scale = 1.25
	drag_visual.scale = lerp(drag_visual.scale, Vector2(target_scale, target_scale), 0.1)

func _update_pulsating_highlight(_delta: float) -> void:
	var p = (sin(Time.get_ticks_msec() * 0.012) + 1.0) / 2.0
	var alpha = lerp(0.3, 0.8, p)
	
	if tile_highlight_sprite.visible:
		tile_highlight_sprite.modulate.a = alpha
	
	if is_instance_valid(last_highlighted) and not last_highlighted is TileMapLayer:
		last_highlighted.modulate.a = alpha

func get_hovered_tile_layer(mouse_pos: Vector2, check_tags: bool = false) -> TileMapLayer:
	var grid_pos = Grid.world_to_grid(mouse_pos)
	for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
		var layer = GameState.solid_tilemaps[i]
		
		if check_tags:
			if not Grid.layer_tags.has(grid_pos) or not Grid.layer_tags[grid_pos].has(layer.name):
				if not Grid.get_region_at(grid_pos):
					continue
		
		var source_id = layer.get_cell_source_id(grid_pos)
		if source_id != -1:
			var atlas_coords = layer.get_cell_atlas_coords(grid_pos)
			var source = layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if source:
				var rect = source.get_tile_texture_region(atlas_coords)
				var tile_data = source.get_tile_data(atlas_coords, 0)
				var offset = Vector2(tile_data.texture_origin) if tile_data else Vector2.ZERO
				var cell_center = Grid.grid_to_world(grid_pos)
				var tex_center = cell_center - offset
				var local_pos = mouse_pos - tex_center
				var half_size = rect.size / 2.0

				if local_pos.x >= -half_size.x and local_pos.x < half_size.x and \
				   local_pos.y >= -half_size.y and local_pos.y < half_size.y:

					var pixel_x = int(rect.position.x + local_pos.x + half_size.x)
					var pixel_y = int(rect.position.y + local_pos.y + half_size.y)

					var img = Grid.get_texture_image(source.texture)
					if pixel_x >= 0 and pixel_y >= 0 and pixel_x < img.get_width() and pixel_y < img.get_height():
						if img.get_pixel(pixel_x, pixel_y).a > 0.5:
							return layer
	return null

func _highlight_layer_tile(layer: TileMapLayer, pos: Vector2i) -> void:
	var source_id = layer.get_cell_source_id(pos)
	if source_id != -1:
		var atlas_coords = layer.get_cell_atlas_coords(pos)
		var source: TileSetAtlasSource = layer.tile_set.get_source(source_id)
		if source:
			tile_highlight_sprite.texture = source.texture
			tile_highlight_sprite.region_rect = source.get_tile_texture_region(atlas_coords)
			tile_highlight_sprite.global_position = Grid.grid_to_world(pos)
			tile_highlight_sprite.z_index = layer.z_index + 1
			tile_highlight_sprite.visible = true
			return

	tile_highlight_sprite.visible = false

func _set_highlight(node: Node2D) -> void:
	if last_highlighted == node: return
	_clear_highlight()
	last_highlighted = node
	if node.has_method("set_highlighted"):
		node.set_highlighted(true)
	else:
		node.modulate = Color(1.2, 1.2, 1.5, 1.0)

func _clear_highlight() -> void:
	if is_instance_valid(last_highlighted):
		if last_highlighted.has_method("set_highlighted"):
			last_highlighted.set_highlighted(false)
		last_highlighted.modulate = Color.WHITE
	
	tile_highlight_sprite.modulate.a = 0.6
	last_highlighted = null
