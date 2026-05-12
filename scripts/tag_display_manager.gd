extends Node

var tag_label_script = preload("res://scripts/tag_label.gd")
var hover_label: Node2D
var current_tags: Array = []
var last_highlighted: Node2D = null
var tile_highlight_sprite: Sprite2D
var highlight_container: CanvasLayer
var label_container: CanvasLayer

var is_selected: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	highlight_container = CanvasLayer.new()
	highlight_container.layer = 99
	highlight_container.follow_viewport_enabled = true
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

func _input(event: InputEvent) -> void:
	if not GameState.is_substrate: return
	
	if event.is_action_pressed("ui_cancel"):
		_deselect()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_tree().current_scene.get_global_mouse_position()
		
		if is_selected:
			var dist = mouse_pos.distance_to(hover_label.global_position)
			if dist > 30.0:
				_deselect()
		else:
			var grid_pos = Grid.world_to_grid(mouse_pos)
			var tags = Grid.get_wall_tags(grid_pos)
			var occupant = Grid.get_occupant(grid_pos)
			if not tags.is_empty() or (occupant and occupant != GameState.player_ref):
				_select()

func _select() -> void:
	is_selected = true
	tile_highlight_sprite.visible = false
	_clear_highlight()
	if hover_label.has_method("set_selected"):
		hover_label.set_selected(true)

func _deselect() -> void:
	is_selected = false
	if hover_label.has_method("set_selected"):
		hover_label.set_selected(false)

func _process(_delta: float) -> void:
	if not GameState.is_substrate:
		_deselect()
		_clear_highlight()
		tile_highlight_sprite.visible = false
		hover_label.modulate.a = 0
		return
	
	if is_selected:
		return
		
	var scene = get_tree().current_scene
	if not scene: return
	
	var mouse_pos = scene.get_global_mouse_position()
	var grid_pos = Grid.world_to_grid(mouse_pos)
	
	var tags = Grid.get_wall_tags(grid_pos)
	var occupant = Grid.get_occupant(grid_pos)
	
	var has_content = not tags.is_empty() or (occupant and occupant != GameState.player_ref)
	
	if has_content:
		if occupant and occupant != GameState.player_ref:
			_set_highlight(occupant)
			tile_highlight_sprite.visible = false
			if occupant.get("tags") != null:
				for t in occupant.tags:
					if not t in tags: tags.append(t)
		else:
			_clear_highlight()
			_highlight_tile(grid_pos)
	else:
		tile_highlight_sprite.visible = false
		_clear_highlight()

	if not tags.is_empty():
		if tags != current_tags:
			current_tags = tags
			hover_label.setup(tags)
		
		hover_label.global_position = Grid.grid_to_world(grid_pos)
		hover_label.modulate.a = lerp(hover_label.modulate.a, 1.0, 0.2)
	else:
		hover_label.modulate.a = lerp(hover_label.modulate.a, 0.0, 0.3)
		if hover_label.modulate.a < 0.05:
			current_tags = []

func _highlight_tile(pos: Vector2i) -> void:
	for layer in GameState.solid_tilemaps:
		var source_id = layer.get_cell_source_id(pos)
		if source_id != -1:
			var atlas_coords = layer.get_cell_atlas_coords(pos)
			var alternative_tile = layer.get_cell_alternative_tile(pos)
			var source: TileSetAtlasSource = layer.tile_set.get_source(source_id)
			
			if source:
				tile_highlight_sprite.texture = source.texture
				tile_highlight_sprite.region_rect = source.get_tile_texture_region(atlas_coords)
				tile_highlight_sprite.global_position = Grid.grid_to_world(pos)
				tile_highlight_sprite.visible = true
				return
	
	tile_highlight_sprite.visible = false

func _set_highlight(node: Node2D) -> void:
	if last_highlighted == node: return
	_clear_highlight()
	last_highlighted = node
	node.modulate = Color(0.7, 0.8, 1.2, 1.0) 

func _clear_highlight() -> void:
	if is_instance_valid(last_highlighted):
		last_highlighted.modulate = Color.WHITE
	last_highlighted = null
