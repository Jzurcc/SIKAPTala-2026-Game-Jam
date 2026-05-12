extends Node

signal turn_processed
signal substrate_toggled(active: bool)
signal player_died
signal level_won

var is_substrate: bool = false
var undo_stack: Array[Dictionary] = []

var player_ref: Node2D = null
var entities: Array[Node2D] = []
var world_objects: Array[Node2D] = []
var wall_tilemap: TileMapLayer = null


func register_player(p: Node2D) -> void:
	player_ref = p


func register_entity(e: Node2D) -> void:
	if not entities.has(e):
		entities.append(e)


func unregister_entity(e: Node2D) -> void:
	entities.erase(e)


func register_object(o: Node2D) -> void:
	if not world_objects.has(o):
		world_objects.append(o)


func register_tilemap(t: TileMapLayer) -> void:
	wall_tilemap = t


func reset() -> void:
	entities.clear()
	world_objects.clear()
	undo_stack.clear()
	player_ref = null
	wall_tilemap = null
	is_substrate = false
	Grid.clear()


func toggle_substrate() -> void:
	is_substrate = !is_substrate
	substrate_toggled.emit(is_substrate)


func is_wall_at(pos: Vector2i) -> bool:
	if wall_tilemap == null:
		return false
	return wall_tilemap.get_cell_source_id(pos) != -1


func is_tile_blocked(pos: Vector2i) -> bool:
	var wt := Grid.get_wall_tags(pos)
	if is_wall_at(pos) and not "PASSABLE" in wt:
		return true
	return false


func has_harmful_at(pos: Vector2i) -> bool:
	var wt := Grid.get_wall_tags(pos)
	if "HARMFUL" in wt:
		return true
	var occ := Grid.get_occupant(pos)
	if occ != null and occ != player_ref:
		if occ.get("tags") != null and "HARMFUL" in occ.tags:
			return true
	return false


func push_undo_state() -> void:
	var snap: Dictionary = {}

	if player_ref:
		snap["p"] = player_ref.grid_pos

	snap["wt"] = {}
	for k in Grid.wall_tags:
		snap["wt"][k] = Grid.wall_tags[k].duplicate()

	var entity_snaps: Array = []
	for e in entities:
		if is_instance_valid(e):
			entity_snaps.append({
				"r": e,
				"pos": e.grid_pos,
				"t": e.get("tags").duplicate() if e.get("tags") != null else []
			})
	snap["e"] = entity_snaps

	var obj_snaps: Array = []
	for o in world_objects:
		if is_instance_valid(o):
			obj_snaps.append({
				"r": o,
				"pos": o.grid_pos,
				"t": o.get("tags").duplicate() if o.get("tags") != null else []
			})
	snap["o"] = obj_snaps

	undo_stack.append(snap)


func pop_undo_state() -> void:
	if undo_stack.is_empty():
		return

	var snap: Dictionary = undo_stack.pop_back()

	Grid.occupied.clear()

	if player_ref and snap.has("p"):
		player_ref.grid_pos = snap["p"]
		player_ref.position = Grid.grid_to_world(player_ref.grid_pos)
		Grid.occupy(player_ref.grid_pos, player_ref)

	Grid.wall_tags.clear()
	for k in snap["wt"]:
		Grid.wall_tags[k] = snap["wt"][k].duplicate()

	for edata in snap["e"]:
		var e: Node2D = edata["r"]
		if is_instance_valid(e):
			e.grid_pos = edata["pos"]
			e.position = Grid.grid_to_world(e.grid_pos)
			if e.get("tags") != null:
				e.tags = edata["t"].duplicate()
			Grid.occupy(e.grid_pos, e)

	for odata in snap["o"]:
		var o: Node2D = odata["r"]
		if is_instance_valid(o):
			o.grid_pos = odata["pos"]
			o.position = Grid.grid_to_world(o.grid_pos)
			if o.get("tags") != null:
				o.tags = odata["t"].duplicate()
			Grid.occupy(o.grid_pos, o)


func process_turn() -> void:
	for e in entities:
		if is_instance_valid(e) and e.has_method("take_turn"):
			e.take_turn()
	turn_processed.emit()
