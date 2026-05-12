extends Node

var tag_label_script = preload("res://scripts/tag_label.gd")
var hover_label: Node2D
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
var drag_visual: RichTextLabel = null
var drag_velocity: Vector2 = Vector2.ZERO
var last_mouse_pos: Vector2 = Vector2.ZERO

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

	hover_label = Node2D.new()
	hover_label.set_script(tag_label_script)
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
				if is_selected:
					if not is_dragging:
						var dist = mouse_pos.distance_to(hover_label.global_position)
						if dist > 60.0:
							_deselect()
				else:
					var grid_pos = Grid.world_to_grid(mouse_pos)
					var top_layer = get_hovered_tile_layer(mouse_pos)
					var region = Grid.get_region_at(grid_pos)
					if region and not region.is_pixel_opaque(mouse_pos): region = null
					var has_tile_tags = top_layer != null and Grid.layer_tags.has(grid_pos) and Grid.layer_tags[grid_pos].has(top_layer.name)

					if region != null or Grid.get_occupant(grid_pos) != null or has_tile_tags:
						_select()
			else:
				if is_dragging:
					_handle_drop(mouse_pos)

func _on_tag_drag_started(tag: String, index: int) -> void:
	if "LOCKED" in current_tags: return
	if last_highlighted == null: return

	is_dragging = true
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
	drag_visual.add_theme_font_size_override("normal_font_size", 6)
	drag_visual.add_theme_constant_override("outline_size", 3)
	drag_visual.add_theme_color_override("outline_color", Color.BLACK)

	var color = hover_label.tag_colors.get(tag, "#ffffff")
	drag_visual.text = "[center][color=" + color + "][" + tag + "][/color][/center]"

	label_container.add_child(drag_visual)
	drag_visual.global_position = hover_label.get_tag_global_position(index)

	hover_label.remove_tag_visual(index)
	last_mouse_pos = get_tree().current_scene.get_global_mouse_position()

func _cancel_drag() -> void:
	is_dragging = false
	if drag_visual:
		drag_visual.queue_free()
	hover_label.setup(current_tags)

func _handle_drop(mouse_pos: Vector2) -> void:
	var grid_pos = Grid.world_to_grid(mouse_pos)
	var target_layer = get_hovered_tile_layer(mouse_pos)
	var target_node: Node2D = null

	var region = Grid.get_region_at(grid_pos)
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
		var target_idx = hover_label.get_hovered_tag_index(mouse_pos)
		if target_idx == -1: target_idx = 0
		_perform_swap(drag_source_node, drag_index, target_node, target_idx)

	_cancel_drag()

func _perform_swap(source: Node2D, s_idx: int, target: Node2D, t_idx: int) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target): return

	GameState.push_undo_state()

	var s_tags = source.get("tags")
	var t_tags = target.get("tags")

	if s_tags == null or t_tags == null: return
	if t_idx < 0 or t_idx >= t_tags.size(): return

	var tag_to_move = s_tags[s_idx]
	var tag_from_target = t_tags[t_idx]

	s_tags[s_idx] = tag_from_target
	t_tags[t_idx] = tag_to_move

	if source.has_method("update_tags"):
		source.update_tags(s_tags)

	if target.has_method("update_tags"):
		target.update_tags(t_tags)

	_deselect()
	_select()

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

	if is_selected and not is_dragging:
		return

	var scene = get_tree().current_scene
	if not scene: return

	var mouse_pos = scene.get_global_mouse_position()
	var grid_pos = Grid.world_to_grid(mouse_pos)

	var tags: Array = []
	var target_world_pos: Vector2
	var has_content: bool = false

	var top_layer = get_hovered_tile_layer(mouse_pos)
	var region = Grid.get_region_at(grid_pos)

	if region != null:
		var target = region.get_effective_layer_name()
		if target != "" and top_layer != null and target != top_layer.name:
			region = null
		elif not region.is_pixel_opaque(mouse_pos):
			region = null

	var occupant = Grid.get_occupant(grid_pos)

	if region != null:
		tags = region.tags.duplicate()
		target_world_pos = mouse_pos if is_dragging else region.get_center_world_pos()
		has_content = true
		tile_highlight_sprite.visible = false
		_set_highlight(region)
	else:
		tags = []
		if top_layer != null and Grid.layer_tags.has(grid_pos):
			var lt = Grid.layer_tags[grid_pos]
			if lt.has(top_layer.name):
				tags = lt[top_layer.name].duplicate()

		target_world_pos = mouse_pos if is_dragging else Grid.grid_to_world(grid_pos)

		if occupant and occupant != GameState.player_ref:
			_set_highlight(occupant)
			tile_highlight_sprite.visible = false
			if occupant.get("tags") != null:
				for t in occupant.tags:
					if not t in tags: tags.append(t)
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
		if tags != current_tags:
			current_tags = tags
			hover_label.setup(tags)
			if is_dragging and last_highlighted == drag_source_node:
				hover_label.remove_tag_visual(drag_index)

		hover_label.global_position = hover_label.global_position.lerp(target_world_pos, 0.15)
		hover_label.modulate.a = lerp(hover_label.modulate.a, 1.0, 0.2)
	else:
		hover_label.modulate.a = lerp(hover_label.modulate.a, 0.0, 0.3)
		if hover_label.modulate.a < 0.05:
			current_tags = []

func _update_dragging_visual(delta: float) -> void:
	var mouse_pos = get_tree().current_scene.get_global_mouse_position()

	var velocity = (mouse_pos - last_mouse_pos) / delta
	drag_velocity = drag_velocity.lerp(velocity, 0.1)
	last_mouse_pos = mouse_pos

	var center_offset = drag_visual.size / 2.0
	drag_visual.pivot_offset = center_offset

	drag_visual.global_position = drag_visual.global_position.lerp(mouse_pos - center_offset, 0.3)

	var target_rotation = clamp(drag_velocity.x * 0.001, -0.4, 0.4)
	drag_visual.rotation = lerp(drag_visual.rotation, target_rotation, 0.1)

	var speed = drag_velocity.length()
	var target_scale = 1.0 + clamp(speed * 0.0001, 0.0, 0.3)
	drag_visual.scale = lerp(drag_visual.scale, Vector2(target_scale, target_scale), 0.1)

func get_hovered_tile_layer(mouse_pos: Vector2) -> TileMapLayer:
	var grid_pos = Grid.world_to_grid(mouse_pos)
	for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
		var layer = GameState.solid_tilemaps[i]
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
		node.modulate = Color(0.7, 0.8, 1.2, 1.0)

func _clear_highlight() -> void:
	if is_instance_valid(last_highlighted):
		if last_highlighted.has_method("set_highlighted"):
			last_highlighted.set_highlighted(false)
		else:
			last_highlighted.modulate = Color.WHITE
	last_highlighted = null
