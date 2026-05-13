extends Node

enum TagTypes {
	IMPASSABLE, LOCKED, PASSABLE, FRAGILE, HEAVY, LIGHT, INTERACTABLE
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

func get_region_at(pos: Vector2i, layer_name: String = "") -> Node2D:
	for i in range(regions.size() - 1, -1, -1):
		var region = regions[i]
		if region.get_grid_rect().has_point(pos):
			if layer_name == "" or region.get_effective_layer_name() == layer_name:
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

var _is_refreshing: bool = false

func add_wall_tag(pos: Vector2i, tag: String) -> void:
	var t: Array = wall_tags.get(pos, [])
	if not tag in t:
		t.append(tag)
	wall_tags[pos] = t


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

	# PASS 1: Gather all tags
	for layer in GameState.solid_tilemaps:
		if is_instance_valid(layer) and layer.get("tags") != null:
			var cells = layer.get_used_cells()
			for pos in cells:
				for tag in layer.tags:
					add_layer_tag(pos, layer.name, tag)

	for region in regions:
		if is_instance_valid(region):
			var rect = region.get_grid_rect()
			var layer = region.get_effective_layer_name()
			for x in range(rect.size.x):
				for y in range(rect.size.y):
					var pos = rect.position + Vector2i(x, y)
					# Clear tags from ALL layers for this cell in OVERRIDE mode
					for l in GameState.solid_tilemaps:
						clear_layer_tags(pos, l.name)
					for tag in region.tags:
						add_wall_tag(pos, tag)

	for obj in GameState.world_objects:
		if is_instance_valid(obj) and obj.get("tags") != null:
			for tag in obj.tags:
				var g_size = obj.get("grid_size")
				if g_size == null: g_size = Vector2i.ONE
				for x in range(g_size.x):
					for y in range(g_size.y):
						add_wall_tag(obj.grid_pos + Vector2i(x, y), tag)
				
	# PASS 2: Handle conversions for any newly detected LIGHT tags
	var targets = wall_tags.keys()
	for pos in targets:
		if "LIGHT" in wall_tags[pos]:
			_try_convert_to_node(pos)

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
				obj.z_index = 100 # Visibility fix

				var sprite = Sprite2D.new()
				sprite.texture = source.texture
				sprite.region_enabled = true
				sprite.region_rect = source.get_tile_texture_region(atlas_coords)
				
				var size_in_atlas = source.get_tile_size_in_atlas(atlas_coords)
				obj.set("grid_size", size_in_atlas)
				
				var tile_data = source.get_tile_data(atlas_coords, 0)
				var tex_offset = Vector2(tile_data.texture_origin) if tile_data else Vector2.ZERO
				sprite.position = -tex_offset
				
				obj.add_child(sprite)

				obj.position = grid_to_world(pos)
				layer.add_sibling(obj)

				if obj.get("tags") != null:
					obj.tags.assign(wall_tags.get(pos, []))

				# Region Capture: If a region was providing the LIGHT tag, move it to the object
				for region in regions:
					if is_instance_valid(region) and region.get_grid_rect().has_point(pos):
						# Copy ID and Dialogues from the region
						if region.id != "": obj.id = region.id
						if region.custom_dialogues.size() > 0:
							obj.custom_dialogues = region.custom_dialogues.duplicate()
						
						if "LIGHT" in region.tags:
							region.reparent(obj)
							region.position = Vector2.ZERO
							break

				layer.set_cell(pos, -1)
				return

func isolate_tile_as_region(pos: Vector2i, layer_name: String) -> SubtextRegion:
	var existing = get_region_at(pos, layer_name)
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
