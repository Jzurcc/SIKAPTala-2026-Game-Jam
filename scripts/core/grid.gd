extends Node

## Grid spatial index, collision resolution engine, and tag registry.
## Handles world/grid coordinate conversions, cell occupancy, step resolution,
## and pure spatial tag overrides without runtime node instantiation.

const TagTypes = TagDef.Tag
const TILE_SIZE := 16

var occupied: Dictionary = {}
var wall_tags: Dictionary = {}
var layer_tags: Dictionary = {}
var cell_tag_overrides: Dictionary = {}
var regions: Array[Node2D] = []


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


## --- Occupancy ---

func occupy(pos: Vector2i, node: Node2D) -> void:
	occupied[pos] = node


func vacate(pos: Vector2i) -> void:
	occupied.erase(pos)


func is_occupied(pos: Vector2i) -> bool:
	return occupied.has(pos)


func get_occupant(pos: Vector2i) -> Node2D:
	return occupied.get(pos, null)


## --- Regions ---

func register_region(region: Node2D) -> void:
	if not region in regions:
		regions.append(region)
		var rect: Rect2i = region.get_grid_rect()
		var layer: String = region.get_effective_layer_name()
		for x in range(rect.size.x):
			for y in range(rect.size.y):
				var pos: Vector2i = rect.position + Vector2i(x, y)
				for tag: String in region.tags:
					add_layer_tag(pos, layer, tag)


func unregister_region(region: Node2D) -> void:
	regions.erase(region)


func get_region_at(pos: Vector2i, layer_name: String = "") -> Node2D:
	for i in range(regions.size() - 1, -1, -1):
		var region: Node2D = regions[i]
		if is_instance_valid(region) and region.get_grid_rect().has_point(pos):
			if layer_name == "" or region.get_effective_layer_name() == layer_name:
				return region
	return null


## --- Tag Registry & Overrides ---

func get_wall_tags(pos: Vector2i) -> Array:
	return wall_tags.get(pos, [])


func set_wall_tags(pos: Vector2i, tags: Array) -> void:
	if tags.is_empty():
		wall_tags.erase(pos)
	else:
		wall_tags[pos] = tags


func add_wall_tag(pos: Vector2i, tag: String) -> void:
	var t: Array = wall_tags.get(pos, [])
	if not tag in t:
		t.append(tag)
	wall_tags[pos] = t


func remove_wall_tag(pos: Vector2i, tag: String) -> void:
	var t: Array = wall_tags.get(pos, [])
	t.erase(tag)
	if t.is_empty():
		wall_tags.erase(pos)
	else:
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
		for tag: String in layer_tags[pos][layer_name]:
			remove_wall_tag(pos, tag)
		layer_tags[pos].erase(layer_name)


func get_cell_tags(pos: Vector2i, layer_name: String) -> Array[String]:
	if cell_tag_overrides.has(pos) and cell_tag_overrides[pos].has(layer_name):
		var res: Array[String] = []
		res.assign(cell_tag_overrides[pos][layer_name])
		return res
	if layer_tags.has(pos) and layer_tags[pos].has(layer_name):
		var res: Array[String] = []
		res.assign(layer_tags[pos][layer_name])
		return res
	return []


func set_cell_tag_override(pos: Vector2i, layer_name: String, tags_list: Array) -> void:
	if not cell_tag_overrides.has(pos):
		cell_tag_overrides[pos] = {}
	cell_tag_overrides[pos][layer_name] = tags_list.duplicate()
	refresh_all_tags()


func refresh_all_tags() -> void:
	wall_tags.clear()
	layer_tags.clear()

	# PASS 1: Base layer tags from TileMap layers
	for layer: TileMapLayer in GameState.solid_tilemaps:
		if is_instance_valid(layer) and layer.get("tags") != null:
			var cells: Array[Vector2i] = layer.get_used_cells()
			for pos: Vector2i in cells:
				for tag: String in layer.tags:
					add_layer_tag(pos, layer.name, tag)

	# PASS 2: Pre-placed level regions
	for region: Node2D in regions:
		if is_instance_valid(region):
			var rect: Rect2i = region.get_grid_rect()
			for x in range(rect.size.x):
				for y in range(rect.size.y):
					var pos: Vector2i = rect.position + Vector2i(x, y)
					for l: TileMapLayer in GameState.solid_tilemaps:
						clear_layer_tags(pos, l.name)
					for tag: String in region.tags:
						add_wall_tag(pos, tag)

	# PASS 3: Cell tag overrides (pure spatial overrides from tag swaps)
	for pos: Vector2i in cell_tag_overrides:
		for layer_name: String in cell_tag_overrides[pos]:
			clear_layer_tags(pos, layer_name)
			var o_tags: Array = cell_tag_overrides[pos][layer_name]
			for tag: String in o_tags:
				add_layer_tag(pos, layer_name, tag)

	# PASS 4: World object tags
	for obj: Node2D in GameState.world_objects:
		if is_instance_valid(obj) and obj.get("tags") != null:
			var obj_tag_names: Array[String] = TagRegistry.extract_tag_names(obj.tags)
			for tag: String in obj_tag_names:
				var g_size: Vector2i = obj.get("grid_size") if obj.get("grid_size") != null else Vector2i.ONE
				for x in range(g_size.x):
					for y in range(g_size.y):
						add_wall_tag(obj.grid_pos + Vector2i(x, y), tag)

	# PASS 5: Light conversions via TileConverter
	var targets: Array = wall_tags.keys()
	for pos: Vector2i in targets:
		if "LIGHT" in wall_tags[pos]:
			if is_instance_valid(TileConverter):
				TileConverter.convert_to_prop_if_unoccupied(pos, get_tree().current_scene if get_tree() else null)


## --- Movement & Step Resolution Engine ---

func resolve_step(actor: Node2D, dir: Vector2i) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"blocked": false,
		"target_pos": Vector2i.ZERO,
		"pushed_nodes": [] as Array[Node2D],
		"killed_nodes": [] as Array[Node2D],
		"harmful": false,
		"attacked_player": false,
	}
	if dir == Vector2i.ZERO:
		return result

	var current_pos: Vector2i = actor.grid_pos if "grid_pos" in actor else world_to_grid(actor.position)
	var target_pos: Vector2i = current_pos + dir
	result["target_pos"] = target_pos

	var actor_tags: Array = actor.get("tags") if actor.get("tags") != null else []
	var is_player: bool = (actor == GameState.player_ref)

	# 1. Check static tile blockage
	if GameState.is_tile_blocked(target_pos):
		result["blocked"] = true
		return result

	# 2. Check occupant at destination
	var occupant: Node2D = get_occupant(target_pos)
	if occupant != null and occupant != actor:
		var occ_tags_var = occupant.get("tags")
		var occ_tags: Array[String] = []
		if occ_tags_var != null:
			for t in (occ_tags_var as Array):
				occ_tags.append(str(t))

		# Enemy / Harmful body attacking player
		if occupant == GameState.player_ref:
			if "HARMFUL" in actor_tags:
				result["attacked_player"] = true
				if actor.has_method("attack_player"):
					actor.attack_player()
				elif GameState.player_ref.has_method("_die"):
					GameState.player_ref._die()
			result["blocked"] = true
			return result

		# Check if occupant is passable via TagRegistry
		if TagRegistry.can_enter(actor, target_pos, occ_tags):
			pass
		elif TagRegistry.on_pushed(actor, occupant, dir):
			result["killed_nodes"].append(occupant)
		elif "HARMFUL" in occ_tags and is_player:
			result["harmful"] = true
			if occupant.has_method("attack_player"):
				occupant.attack_player()
			elif actor.has_method("_die"):
				actor._die()
			return result
		elif occupant.has_method("push") and occupant.push(dir):
			result["pushed_nodes"].append(occupant)
		else:
			result["blocked"] = true
			return result

	# 3. Check actor fragility
	if "FRAGILE" in actor_tags:
		result["killed_nodes"].append(actor)
		if actor.has_method("die"):
			actor.die()
		elif actor.has_method("_die"):
			actor._die()
		return result

	# 4. Trigger on_enter effects for floor/occupant tags
	var target_wall_tags: Array[String] = []
	for t in get_wall_tags(target_pos):
		target_wall_tags.append(str(t))
	TagRegistry.on_enter(actor, target_pos, occupant, target_wall_tags)

	result["success"] = true
	return result


func clear() -> void:
	occupied.clear()
	wall_tags.clear()
	layer_tags.clear()
	cell_tag_overrides.clear()
	regions.clear()
