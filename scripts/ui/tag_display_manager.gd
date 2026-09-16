extends Node

## Manages hover detection, tag display, and substrate highlight orchestration.
## Enforces clean Top-Layer Precedence: Occupant -> SubtextRegion -> TileMapLayer.

const DragControllerScript = preload("res://scripts/ui/drag_controller.gd")

var hover_label: TagLabel
var current_tags: Array = []
var last_highlighted: Node2D = null
var tile_highlight_sprite: Sprite2D
var highlight_container: Node2D
var label_container: CanvasLayer

var is_selected: bool = false
var _target_world_pos: Vector2 = Vector2.ZERO

var drag: DragController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	drag = DragControllerScript.new()
	add_child(drag)
	drag.swap_completed.connect(_on_swap_completed)

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


func _on_swap_completed() -> void:
	_deselect()
	_clear_highlight()
	current_tags = []


func _input(event: InputEvent) -> void:
	if not GameState.is_substrate:
		return

	if event.is_action_pressed("ui_cancel"):
		if drag.is_dragging:
			drag.cancel(hover_label)
		_deselect()
		return

	if event is InputEventMouseButton:
		var current_sc: Node = get_tree().current_scene
		var mouse_pos: Vector2 = (current_sc as Node2D).get_global_mouse_position() if current_sc is Node2D else Vector2.ZERO

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if drag.is_dragging:
				drag.handle_drop(mouse_pos, hover_label, last_highlighted, self)
				get_viewport().set_input_as_handled()
				return


func _on_tag_drag_started(tag: Variant, index: int) -> void:
	if last_highlighted == null:
		return

	var current_sc: Node = get_tree().current_scene
	var m_pos: Vector2 = (current_sc as Node2D).get_global_mouse_position() if current_sc is Node2D else Vector2.ZERO
	var source_pos: Vector2i = Grid.world_to_grid(m_pos)
	var player_pos: Vector2i = GameState.player_ref.grid_pos if GameState.player_ref else Vector2i.ZERO

	var context: Dictionary = {
		"host": last_highlighted,
		"host_pos": source_pos,
		"player_pos": player_pos
	}

	if not TagRegistry.can_drag_tag(tag, context):
		if hover_label:
			var tag_name: String = tag.name if (tag is RefCounted and tag.get("name") != null) else str(tag)
			hover_label.shake_tag(tag_name)
		GameState.play_error_sfx()
		return

	drag.begin_drag(tag, index, last_highlighted, source_pos, label_container, hover_label)


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
		if drag.is_dragging:
			drag.cancel(hover_label)
		_deselect()
		_clear_highlight()
		tile_highlight_sprite.visible = false
		hover_label.modulate.a = 0.0
		current_tags = []
		return

	if drag.is_dragging:
		drag.update_visual(delta, is_selected, hover_label)

	_update_pulsating_highlight(delta)

	var scene: Node = get_tree().current_scene
	if not scene or not (scene is Node2D):
		return

	var mouse_pos: Vector2 = (scene as Node2D).get_global_mouse_position()

	var tags: Array = []
	var has_content: bool = false
	var is_locked: bool = false

	# Generous lock-on area: keep target active while mouse is over the target, label, or intermediate area
	if is_selected and is_instance_valid(last_highlighted):
		var target_bounds: Rect2
		if last_highlighted.has_method("get_bounding_rect"):
			target_bounds = last_highlighted.get_bounding_rect()
		elif last_highlighted is SubtextRegion:
			var r_rect: Rect2i = last_highlighted.get_grid_rect()
			target_bounds = Rect2(Vector2(r_rect.position * Grid.TILE_SIZE), Vector2(r_rect.size * Grid.TILE_SIZE))
		elif last_highlighted is TileMapLayer:
			var g_pos: Vector2i = Grid.world_to_grid(_target_world_pos)
			target_bounds = Rect2(Vector2(g_pos * Grid.TILE_SIZE), Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE))
		else:
			target_bounds = Rect2(last_highlighted.global_position - Vector2(8, 8), Vector2(16, 16))

		var label_bounds: Rect2 = hover_label.get_total_label_rect()
		var combined_zone: Rect2 = target_bounds.merge(label_bounds).grow(4.0)

		if combined_zone.has_point(mouse_pos):
			is_locked = true

	if is_locked:
		tags = current_tags.duplicate()
		has_content = true
	else:
		var grid_pos: Vector2i = Grid.world_to_grid(mouse_pos)
		var occupant: Node2D = Grid.get_occupant(grid_pos)
		var top_layer: TileMapLayer = get_hovered_tile_layer(mouse_pos, true)
		if top_layer == null:
			top_layer = get_hovered_tile_layer(mouse_pos, false)

		var layer_name: String = str(top_layer.name) if top_layer else ""
		var region: Node2D = Grid.get_region_at(grid_pos, layer_name)
		if region != null and region.has_method("is_pixel_opaque") and not region.is_pixel_opaque(mouse_pos):
			region = null

		# Top-Layer Precedence Hierarchy:
		# 1. Occupant (GridBody2D / Prop / Entity)
		if occupant and occupant != GameState.player_ref:
			_set_highlight(occupant)
			tile_highlight_sprite.visible = false
			if occupant.get("tags") != null:
				tags = occupant.tags.duplicate()
			if occupant.has_method("get_display_top_world_pos"):
				_target_world_pos = occupant.get_display_top_world_pos()
			else:
				_target_world_pos = occupant.global_position
			has_content = true
		# 2. SubtextRegion (Carpet / Furniture / Zone)
		elif region != null:
			tags = region.tags.duplicate()
			_target_world_pos = region.get_center_world_pos() if region.has_method("get_center_world_pos") else region.global_position
			has_content = true
			tile_highlight_sprite.visible = false
			_set_highlight(region)
		# 3. Base TileMapLayer (Floor / Wall)
		elif top_layer != null:
			tags = Grid.get_cell_tags(grid_pos, top_layer.name)
			_target_world_pos = Grid.grid_to_world(grid_pos)
			if not tags.is_empty():
				if last_highlighted != top_layer:
					_clear_highlight()
					last_highlighted = top_layer
				_highlight_layer_tile(top_layer, grid_pos)
				has_content = true
			else:
				tile_highlight_sprite.visible = false
				_clear_highlight()
		else:
			tile_highlight_sprite.visible = false
			_clear_highlight()

	if has_content and not tags.is_empty():
		if not is_selected:
			_select()
		if tags != current_tags:
			current_tags = tags
			hover_label.setup(tags)

		hover_label.holding_tag = drag.drag_tag if drag.is_dragging else ""
		if drag.is_dragging and last_highlighted == drag.drag_source_node:
			hover_label.remove_tag_visual(drag.drag_index)

		hover_label.global_position = hover_label.global_position.lerp(_target_world_pos, 0.15)
		hover_label.modulate.a = lerpf(hover_label.modulate.a, 1.0, 0.2)
	else:
		if is_selected:
			_deselect()
		hover_label.modulate.a = lerpf(hover_label.modulate.a, 0.0, 0.3)
		if hover_label.modulate.a < 0.05:
			current_tags = []


func _update_pulsating_highlight(_delta: float) -> void:
	var p: float = (sin(Time.get_ticks_msec() * 0.012) + 1.0) / 2.0
	var alpha: float = lerpf(0.3, 0.8, p)

	if tile_highlight_sprite.visible:
		tile_highlight_sprite.modulate.a = alpha

	if is_instance_valid(last_highlighted) and not last_highlighted is TileMapLayer:
		last_highlighted.modulate.a = alpha


func get_hovered_tile_layer(mouse_pos: Vector2, check_tags: bool = false) -> TileMapLayer:
	var grid_pos: Vector2i = Grid.world_to_grid(mouse_pos)
	for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
		var layer: TileMapLayer = GameState.solid_tilemaps[i]
		if is_instance_valid(layer) and layer.get_cell_source_id(grid_pos) != -1:
			if check_tags:
				if not Grid.get_cell_tags(grid_pos, layer.name).is_empty() or Grid.get_region_at(grid_pos, layer.name) != null:
					return layer
			else:
				return layer
	return null


func _highlight_layer_tile(layer: TileMapLayer, pos: Vector2i) -> void:
	var source_id: int = layer.get_cell_source_id(pos)
	if source_id != -1:
		var atlas_coords: Vector2i = layer.get_cell_atlas_coords(pos)
		var source: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source:
			tile_highlight_sprite.texture = source.texture
			tile_highlight_sprite.region_rect = source.get_tile_texture_region(atlas_coords)
			tile_highlight_sprite.global_position = Grid.grid_to_world(pos)
			tile_highlight_sprite.z_index = layer.z_index + 1
			tile_highlight_sprite.visible = true
			return

	tile_highlight_sprite.visible = false


func _set_highlight(node: Node2D) -> void:
	if last_highlighted == node:
		return
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
