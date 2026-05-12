extends Node

const TILE_SIZE := 16

var occupied: Dictionary = {}
var wall_tags: Dictionary = {}
var layer_tags: Dictionary = {}
var regions: Array = [] # Array[SubtextRegion]

func register_region(region: Node2D) -> void:
	if not region in regions:
		regions.append(region)
		# Automatically add its tags to the grid for puzzle logic
		var rect = region.get_grid_rect()
		for x in range(rect.size.x):
			for y in range(rect.size.y):
				var pos = rect.position + Vector2i(x, y)
				for tag in region.tags:
					add_wall_tag(pos, tag)

func unregister_region(region: Node2D) -> void:
	regions.erase(region)
	# We don't remove the wall tags here because other things might share them,
	# but for a dynamic system, we'd need a more robust tag ref-counting.

func get_region_at(pos: Vector2i) -> Node2D:
	for region in regions:
		if region.get_grid_rect().has_point(pos):
			return region
	return null

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / TILE_SIZE),
		floori(world_pos.y / TILE_SIZE)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * TILE_SIZE + TILE_SIZE * 0.5,
		grid_pos.y * TILE_SIZE + TILE_SIZE * 0.5
	)

func occupy(pos: Vector2i, node: Node2D) -> void:
	occupied[pos] = node

func vacate(pos: Vector2i) -> void:
	occupied.erase(pos)

func is_occupied(pos: Vector2i) -> bool:
	return occupied.has(pos)

func get_occupant(pos: Vector2i) -> Node2D:
	return occupied.get(pos, null)

func get_wall_tags(pos: Vector2i) -> Array:
	return wall_tags.get(pos, [])

func set_wall_tags(pos: Vector2i, tags: Array) -> void:
	if tags.is_empty():
		wall_tags.erase(pos)
	else:
		wall_tags[pos] = tags

var world_object_script = preload("res://scripts/world_object.gd")

func add_wall_tag(pos: Vector2i, tag: String) -> void:
	var t: Array = wall_tags.get(pos, [])
	if not tag in t:
		t.append(tag)
	wall_tags[pos] = t
	
	if tag == "PUSHABLE":
		_try_convert_to_node(pos)

func add_layer_tag(pos: Vector2i, layer_name: String, tag: String) -> void:
	if not layer_tags.has(pos):
		layer_tags[pos] = {}
	if not layer_tags[pos].has(layer_name):
		layer_tags[pos][layer_name] = []
	
	var tags: Array = layer_tags[pos][layer_name]
	if not tag in tags:
		tags.append(tag)
	
	add_wall_tag(pos, tag)

func _try_convert_to_node(pos: Vector2i) -> void:
	if is_occupied(pos): return
	
	# Iterate backwards to ensure "Top-Most Wins" (Z-Index order)
	for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
		var layer = GameState.solid_tilemaps[i]
		var source_id = layer.get_cell_source_id(pos)
		if source_id != -1:
			var atlas_coords = layer.get_cell_atlas_coords(pos)
			var source = layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if source:
				var obj = Node2D.new()
				obj.set_script(world_object_script)
				
				var sprite = Sprite2D.new()
				sprite.texture = source.texture
				sprite.region_enabled = true
				sprite.region_rect = source.get_tile_texture_region(atlas_coords)
				obj.add_child(sprite)
				
				obj.position = grid_to_world(pos)
				layer.add_sibling(obj)
				
				if obj.get("tags") != null:
					obj.tags = wall_tags.get(pos, []).duplicate()
				
				layer.set_cell(pos, -1)
				wall_tags.erase(pos)
				return

func remove_wall_tag(pos: Vector2i, tag: String) -> void:
	var t: Array = wall_tags.get(pos, [])
	t.erase(tag)
	if t.is_empty():
		wall_tags.erase(pos)
	else:
		wall_tags[pos] = t

func clear() -> void:
	occupied.clear()
	wall_tags.clear()
	layer_tags.clear()
	regions.clear()
	_image_cache.clear()

var _image_cache: Dictionary = {}

func get_texture_image(texture: Texture2D) -> Image:
	if not _image_cache.has(texture):
		_image_cache[texture] = texture.get_image()
	return _image_cache[texture]
