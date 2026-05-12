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
	
	# Container for highlights (Under shader)
	highlight_container = CanvasLayer.new()
	highlight_container.layer = 99
	highlight_container.follow_viewport_enabled = true
	add_child(highlight_container)
	
	# Container for labels (Above shader)
	label_container = CanvasLayer.new()
	label_container.layer = 101
	label_container.follow_viewport_enabled = true
	add_child(label_container)
	
	# Create a sprite to "clone" the hovered tile for pixel-perfect modulation
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
	
	if event.is_action_pressed("ui_cancel"): # ESC
		_deselect()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_tree().current_scene.get_global_mouse_position()
		
		if is_selected:
			# Check if clicking outside labels
			var dist = mouse_pos.distance_to(hover_label.global_position)
			if dist > 30.0: # Distance threshold for "outside"
				_deselect()
		else:
			# Check if clicking on content to select
			var grid_pos = Grid.world_to_grid(mouse_pos)
			var top_layer = get_hovered_tile_layer(mouse_pos)
			
			var region = Grid.get_region_at(grid_pos)
			if region != null:
				var target = region.get("target_layer_name")
				if target != null and target != "" and top_layer != null and target != top_layer.name:
					region = null # Region doesn't belong to the topmost hovered layer
				elif not region.is_pixel_opaque(mouse_pos):
					region = null # Region is transparent here, fall through
			
			if region != null:
				_select()
			else:
				var tags = []
				if top_layer != null and Grid.layer_tags.has(grid_pos):
					var lt = Grid.layer_tags[grid_pos]
					if lt.has(top_layer.name):
						tags = lt[top_layer.name].duplicate()
				
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
		current_tags = [] # Reset tags so reopen triggers setup()
		return
	
	if is_selected:
		return # Don't update hover while selected
		
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
		var target = region.get("target_layer_name")
		if target != null and target != "" and top_layer != null and target != top_layer.name:
			region = null # Region is obscured by a higher layer
		elif not region.is_pixel_opaque(mouse_pos):
			region = null # Region is transparent here, fall through
			
	var occupant = Grid.get_occupant(grid_pos)
	
	if region != null:
		# Gather all tags from the entire area the region covers, BUT only for its target layer
		tags = []
		var rect = region.get_grid_rect()
		var target_name = region.get("target_layer_name")
		if target_name == null or target_name == "": target_name = "SubtextRegion"
		
		for x in range(rect.size.x):
			for y in range(rect.size.y):
				var p = rect.position + Vector2i(x, y)
				if Grid.layer_tags.has(p) and Grid.layer_tags[p].has(target_name):
					for t in Grid.layer_tags[p][target_name]:
						if not t in tags: tags.append(t)
					
		target_world_pos = region.get_center_world_pos()
		has_content = true
		tile_highlight_sprite.visible = false
		_set_highlight(region)
	else:
		tags = []
		if top_layer != null and Grid.layer_tags.has(grid_pos):
			var lt = Grid.layer_tags[grid_pos]
			if lt.has(top_layer.name):
				tags = lt[top_layer.name].duplicate()
				
		target_world_pos = Grid.grid_to_world(grid_pos)
		
		if occupant and occupant != GameState.player_ref:
			_set_highlight(occupant)
			tile_highlight_sprite.visible = false
			if occupant.get("tags") != null:
				for t in occupant.tags:
					if not t in tags: tags.append(t)
			has_content = true
		elif top_layer != null and not tags.is_empty():
			_clear_highlight()
			_highlight_layer_tile(top_layer, grid_pos)
			has_content = true
		else:
			tile_highlight_sprite.visible = false
			_clear_highlight()

	# 3. Tag Logic
	if has_content and not tags.is_empty():
		if tags != current_tags:
			current_tags = tags
			hover_label.setup(tags)
		
		# Smoothly glide the label to the target position instead of snapping
		hover_label.global_position = hover_label.global_position.lerp(target_world_pos, 0.15)
		hover_label.modulate.a = lerp(hover_label.modulate.a, 1.0, 0.2)
	else:
		hover_label.modulate.a = lerp(hover_label.modulate.a, 0.0, 0.3)
		if hover_label.modulate.a < 0.05:
			current_tags = []

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
