@tool
extends Node2D
class_name SubtextRegion

@export var tag_rect: Rect2i = Rect2i(0, 0, 1, 1):
	set(value):
		tag_rect = Rect2i(value.position.x, value.position.y, max(1, value.size.x), max(1, value.size.y))
		queue_redraw()

@export var highlight_rect: Rect2i = Rect2i(0, 0, 1, 1):
	set(value):
		highlight_rect = Rect2i(value.position.x, value.position.y, max(1, value.size.x), max(1, value.size.y))
		queue_redraw()

enum TagTypes {
	SOLID, LOCKED, PASSABLE, PUSHABLE, FRAGILE, HEAVY, LIGHT
}

@export var target_layer_name: String = ""
@export var tags_enum: Array[TagTypes] = []
var tags: Array[String] = []
var _highlight_sprites: Array[Sprite2D] = []
var _sprites_initialized: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	# Convert enums to strings for the engine's tag logic
	for t in tags_enum:
		tags.append(TagTypes.keys()[t])
		
	# (Visual highlights are now lazily generated in _setup_highlight_sprites to preserve transparency)
		
	# Snap position to the top-left of the nearest tile
	var base_grid_pos = Grid.world_to_grid(position)
	# Grid.grid_to_world returns the CENTER of the tile.
	# We want the top-left corner for the region's origin.
	position = Vector2(base_grid_pos.x * Grid.TILE_SIZE, base_grid_pos.y * Grid.TILE_SIZE)
	
	Grid.register_region(self)
	
	# Manually inject our tags into the correct layer via the grid
	var rect = get_grid_rect()
	var layer_to_inject = target_layer_name if target_layer_name != "" else "SubtextRegion"
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var p = rect.position + Vector2i(x, y)
			for tag in tags:
				Grid.add_layer_tag(p, layer_to_inject, tag)

func _draw() -> void:
	if Engine.is_editor_hint():
		var t_rect = Rect2(Vector2(tag_rect.position) * 16.0, Vector2(tag_rect.size) * 16.0)
		draw_rect(t_rect, Color(1.0, 0.2, 0.2, 0.4), true) # Red fill for tag logic
		draw_rect(t_rect, Color(1.0, 0.2, 0.2, 1.0), false, 2.0)
		
		var h_rect = Rect2(Vector2(highlight_rect.position) * 16.0, Vector2(highlight_rect.size) * 16.0)
		draw_rect(h_rect, Color(0.2, 1.0, 0.2, 0.2), true) # Green fill for hover visual
		draw_rect(h_rect, Color(0.2, 1.0, 0.2, 1.0), false, 2.0)

func get_center_world_pos() -> Vector2:
	var base_grid_pos = Grid.world_to_grid(position)
	var center_grid = Vector2(base_grid_pos) + Vector2(tag_rect.position) + Vector2(tag_rect.size) / 2.0
	return Vector2(center_grid.x * Grid.TILE_SIZE, center_grid.y * Grid.TILE_SIZE)

func get_grid_rect() -> Rect2i:
	var base_grid_pos = Grid.world_to_grid(position)
	return Rect2i(base_grid_pos + tag_rect.position, tag_rect.size)

func set_highlighted(active: bool) -> void:
	if active and not _sprites_initialized:
		_setup_highlight_sprites()
		
	for sprite in _highlight_sprites:
		sprite.visible = active

func _setup_highlight_sprites() -> void:
	_sprites_initialized = true
	var base_grid_pos = Grid.world_to_grid(position)
	
	# 1. Identify the target layer for this region
	var target_layer: TileMapLayer = null
	
	if target_layer_name != "":
		for layer in GameState.solid_tilemaps:
			if layer.name == target_layer_name:
				target_layer = layer
				break
				
	if target_layer == null:
		# Fallback to the top-most layer that contains ANY tiles for this highlight region
		for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
			var layer = GameState.solid_tilemaps[i]
			var found = false
			for x in range(highlight_rect.size.x):
				for y in range(highlight_rect.size.y):
					var pos = base_grid_pos + highlight_rect.position + Vector2i(x, y)
					if layer.get_cell_source_id(pos) != -1:
						target_layer = layer
						found = true
						break
				if found: break
			if found: break
		
	if target_layer == null:
		return
		
	# 2. Extract sprites ONLY from the target layer so we don't accidentally grab the floor beneath empty gaps
	for x in range(highlight_rect.size.x):
		for y in range(highlight_rect.size.y):
			var pos = base_grid_pos + highlight_rect.position + Vector2i(x, y)
			var source_id = target_layer.get_cell_source_id(pos)
			if source_id != -1:
				var atlas_coords = target_layer.get_cell_atlas_coords(pos)
				var source = target_layer.tile_set.get_source(source_id) as TileSetAtlasSource
				if source:
					var sprite = Sprite2D.new()
					sprite.texture = source.texture
					sprite.region_enabled = true
					sprite.region_rect = source.get_tile_texture_region(atlas_coords)
					sprite.centered = true
					var local_pos_x = (highlight_rect.position.x + x) * Grid.TILE_SIZE + Grid.TILE_SIZE * 0.5
					var local_pos_y = (highlight_rect.position.y + y) * Grid.TILE_SIZE + Grid.TILE_SIZE * 0.5
					sprite.position = Vector2(local_pos_x, local_pos_y)
					sprite.modulate = Color(0.5, 0.8, 1.5, 0.6)
					sprite.visible = false
					add_child(sprite)
					_highlight_sprites.append(sprite)

func is_pixel_opaque(world_pos: Vector2) -> bool:
	if not _sprites_initialized:
		_setup_highlight_sprites()
	
	for sprite in _highlight_sprites:
		var local_pos = sprite.to_local(world_pos)
		var rect = sprite.region_rect
		var half_size = rect.size / 2.0
		
		# Check if local_pos is inside this specific sprite area
		if local_pos.x >= -half_size.x and local_pos.x < half_size.x and \
		   local_pos.y >= -half_size.y and local_pos.y < half_size.y:
			
			var img = Grid.get_texture_image(sprite.texture)
			# Convert from local centered coordinates to atlas pixel coordinates
			var pixel_x = int(rect.position.x + local_pos.x + half_size.x)
			var pixel_y = int(rect.position.y + local_pos.y + half_size.y)
			
			if pixel_x >= 0 and pixel_y >= 0 and pixel_x < img.get_width() and pixel_y < img.get_height():
				if img.get_pixel(pixel_x, pixel_y).a > 0.5:
					return true
	return false

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		if Grid.has_method("unregister_region"):
			Grid.unregister_region(self)
