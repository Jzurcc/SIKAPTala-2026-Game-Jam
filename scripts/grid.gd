extends Node

enum TagTypes {
	IMPASSABLE, LOCKED, PASSABLE, PUSHABLE, FRAGILE, HEAVY, LIGHT
}

const TILE_SIZE := 16

var occupied: Dictionary = {}
var wall_tags: Dictionary = {}
var layer_tags: Dictionary = {}
var regions: Array = []

func register_region(region: Node2D) -> void:
	if not region in regions:
		regions.append(region)
		var rect = region.get_grid_rect()
		var layer = region.get_effective_layer_name()
		for x in range(rect.size.x):
			for y in range(rect.size.y):
				var pos = rect.position + Vector2i(x, y)
				for tag in region.tags:
					add_layer_tag(pos, layer, tag)

func unregister_region(region: Node2D) -> void:
	regions.erase(region)

func get_region_at(pos: Vector2i, _check_tags: bool = false) -> Node2D:
	for i in range(regions.size() - 1, -1, -1):
		var region = regions[i]
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

	var tags_list: Array = layer_tags[pos][layer_name]
	if not tag in tags_list:
		tags_list.append(tag)

	add_wall_tag(pos, tag)

func clear_layer_tags(pos: Vector2i, layer_name: String) -> void:
	if layer_tags.has(pos) and layer_tags[pos].has(layer_name):
		for tag in layer_tags[pos][layer_name]:
			remove_wall_tag(pos, tag)
		layer_tags[pos].erase(layer_name)

func refresh_all_tags() -> void:
	wall_tags.clear()
	layer_tags.clear()

	# 1. Base Layer Tags
	for layer in GameState.solid_tilemaps:
		if is_instance_valid(layer) and layer.get("tags") != null:
			var cells = layer.get_used_cells()
			for pos in cells:
				for tag in layer.tags:
					add_layer_tag(pos, layer.name, tag)

	# 2. Region Overrides (Isolation)
	for region in regions:
		if is_instance_valid(region):
			var rect = region.get_grid_rect()
			var layer = region.get_effective_layer_name()
			for x in range(rect.size.x):
				for y in range(rect.size.y):
					var pos = rect.position + Vector2i(x, y)
					# Clear global layer tags for this cell so Region tags completely override them
					clear_layer_tags(pos, layer)
					for tag in region.tags:
						add_layer_tag(pos, layer, tag)

	for obj in GameState.world_objects:
		if is_instance_valid(obj) and obj.get("tags") != null:
			for tag in obj.tags:
				add_wall_tag(obj.grid_pos, tag)

func _try_convert_to_node(pos: Vector2i) -> void:
	if is_occupied(pos): return

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

func isolate_tile_as_region(pos: Vector2i, layer_name: String) -> SubtextRegion:
	var existing = get_region_at(pos)
	if existing: return existing
	
	var region = SubtextRegion.new()
	region.target_layer_name = layer_name
	region.tag_rect = Rect2i(0, 0, 1, 1)
	region.highlight_rect = Rect2i(0, 0, 1, 1)
	region.position = grid_to_world(pos)
	
	if layer_tags.has(pos) and layer_tags[pos].has(layer_name):
		var t_list = layer_tags[pos][layer_name]
		for t in t_list:
			region.tags.append(t)
	
	get_tree().current_scene.add_child(region)
	return region

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
