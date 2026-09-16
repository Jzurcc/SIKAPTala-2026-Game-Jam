extends Node

signal turn_processed
signal substrate_toggled(active: bool)
signal player_died
signal player_moved(world_pos: Vector2)
signal level_won

class UndoSnapshot:
	var player_pos: Vector2i = Vector2i.ZERO
	var has_player: bool = false
	var wall_tags: Dictionary = {}
	var layer_tags: Dictionary = {}
	var region_states: Array[Dictionary] = []
	var entity_states: Array[Dictionary] = []
	var object_states: Array[Dictionary] = []
	var dirty_cells: Dictionary = {}

var is_substrate: bool = false
var is_tutorial_active: bool = false
var tutorial_completed: bool = false
var undo_stack: Array[UndoSnapshot] = []
var _pending_death: Array[Node2D] = []

var player_ref: Node2D = null
var entities: Array[Node2D] = []
var world_objects: Array[Node2D] = []
var solid_tilemaps: Array[TileMapLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## --- Audio & Transition forwarding stubs (delegate to AudioManager / SceneManager) ---
## These exist so existing callers don't need updating immediately.
## TODO: Update all callers to use AudioManager / SceneManager directly, then delete these.

func start_gameplay_music() -> void:
	AudioManager.start_gameplay_music()

func play_select_sfx() -> void:
	AudioManager.play_select_sfx()

func play_deselect_sfx() -> void:
	AudioManager.play_deselect_sfx()

func play_error_sfx() -> void:
	AudioManager.play_error_sfx()

func transition_to_scene(path: String, start_bgm: bool = false, fade_color: Color = Color.BLACK) -> void:
	SceneManager.transition_to_scene(path, start_bgm, fade_color)

var is_transitioning: bool:
	get: return SceneManager.is_transitioning

## --- END forwarding stubs ---


func register_player(p: Node2D) -> void:
	player_ref = p
	if player_ref:
		player_ref.z_index = 100


func register_entity(e: Node2D) -> void:
	if not entities.has(e):
		entities.append(e)


func unregister_entity(e: Node2D) -> void:
	entities.erase(e)


func register_object(o: Node2D) -> void:
	if not world_objects.has(o):
		world_objects.append(o)


func unregister_object(o: Node2D) -> void:
	world_objects.erase(o)


func refresh_tilemaps() -> void:
	solid_tilemaps.clear()
	var root = get_tree().current_scene
	if root:
		_find_tilemaps_recursive(root)

func _find_tilemaps_recursive(node: Node) -> void:
	if node is TileMapLayer:
		if not node in solid_tilemaps:
			# Set z-index by name convention (kept for visual layering, not collision logic)
			if "Floor" in node.name or "Ground" in node.name:
				node.z_index = 0
			else:
				node.z_index = 1
			solid_tilemaps.append(node)
	for child in node.get_children():
		_find_tilemaps_recursive(child)

func reset() -> void:
	entities.clear()
	world_objects.clear()
	undo_stack.clear()
	player_ref = null
	solid_tilemaps.clear()
	is_substrate = false
	Grid.clear()


func toggle_substrate() -> void:
	is_substrate = !is_substrate
	if not is_tutorial_active:
		get_tree().paused = is_substrate
	substrate_toggled.emit(is_substrate)

	if is_substrate:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# AudioManager handles LPF via substrate_toggled signal connection


func is_wall_at(pos: Vector2i) -> bool:
	for t in solid_tilemaps:
		if t.get_cell_source_id(pos) != -1:
			return true
	return false


func is_tile_blocked(pos: Vector2i) -> bool:
	var global_tags = Grid.get_wall_tags(pos)
	if "PASSABLE" in global_tags:
		return false
	if "IMPASSABLE" in global_tags:
		return true

	# Check tilemap layers — tag-based only, no name heuristics
	for i in range(solid_tilemaps.size() - 1, -1, -1):
		var layer = solid_tilemaps[i]
		if layer.get_cell_source_id(pos) != -1:
			if Grid.layer_tags.has(pos) and Grid.layer_tags[pos].has(layer.name):
				var tags = Grid.layer_tags[pos][layer.name]
				if "PASSABLE" in tags: continue
				if "IMPASSABLE" in tags: return true
			# Tile exists with no registered tags — treat as blocking
			# (TaggedTileLayer always registers tags, so this catches untagged legacy tiles)
			return true

	# Check occupants for inherent blocking (if not already covered by PASSABLE tag)
	var occupant = Grid.get_occupant(pos)
	if occupant != null and occupant != player_ref:
		if occupant.get("tags") != null:
			if "PASSABLE" in occupant.tags: return false
			if "IMPASSABLE" in occupant.tags: return true
		
		# If it can't be pushed or broken, it blocks by default
		var has_fragile = occupant.get("tags") != null and "FRAGILE" in occupant.tags
		if not occupant.has_method("push") and not has_fragile:
			return true
			
	return false


func has_harmful_at(pos: Vector2i) -> bool:
	var wt := Grid.get_wall_tags(pos)
	if "HARMFUL" in wt:
		return true
	var occ: Node2D = Grid.get_occupant(pos)
	if occ != null and occ != player_ref:
		if occ.get("tags") != null and "HARMFUL" in occ.tags:
			return true
	return false


func mark_dead(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	node.hide()
	if not _pending_death.has(node):
		_pending_death.append(node)


func _flush_pending_death() -> void:
	for node in _pending_death:
		if is_instance_valid(node):
			node.queue_free()
	_pending_death.clear()


func push_undo_state() -> void:
	var snap := UndoSnapshot.new()

	if player_ref:
		snap.has_player = true
		snap.player_pos = player_ref.grid_pos

	for k in Grid.wall_tags:
		snap.wall_tags[k] = Grid.wall_tags[k].duplicate()

	for pos in Grid.layer_tags:
		snap.layer_tags[pos] = {}
		for layer_name in Grid.layer_tags[pos]:
			snap.layer_tags[pos][layer_name] = Grid.layer_tags[pos][layer_name].duplicate()

	for r in Grid.regions:
		if is_instance_valid(r):
			snap.region_states.append({
				"r": r,
				"pos": r.position,
				"tags": r.tags.duplicate()
			})

	for e in entities:
		if is_instance_valid(e):
			snap.entity_states.append({
				"r": e,
				"pos": e.grid_pos,
				"t": e.get("tags").duplicate() if e.get("tags") != null else [],
				"is_alive": e.get("is_alive") if "is_alive" in e else true
			})

	for o in world_objects:
		if is_instance_valid(o):
			snap.object_states.append({
				"r": o,
				"pos": o.grid_pos,
				"t": o.get("tags").duplicate() if o.get("tags") != null else []
			})

	if is_instance_valid(TileConverter):
		snap.dirty_cells = TileConverter.flush_dirty_cells()

	undo_stack.append(snap)


func pop_undo_state() -> void:
	if undo_stack.is_empty():
		return

	var snap: UndoSnapshot = undo_stack.pop_back()

	# 1. Restore dirty tilemap cells from TileConverter
	if is_instance_valid(TileConverter) and not snap.dirty_cells.is_empty():
		TileConverter.restore_dirty_cells(snap.dirty_cells)

	# 2. Revert any dynamically converted tile-to-world_object nodes spawned since snapshot
	var snap_obj_refs: Array = []
	for o_data in snap.object_states:
		snap_obj_refs.append(o_data["r"])
	for i in range(world_objects.size() - 1, -1, -1):
		var obj = world_objects[i]
		if is_instance_valid(obj) and not obj in snap_obj_refs:
			if obj.has_meta("converted_from_tile"):
				var tdata: Dictionary = obj.get_meta("converted_from_tile")
				for layer in solid_tilemaps:
					if is_instance_valid(layer) and layer.name == tdata["layer_name"]:
						layer.set_cell(tdata["pos"], tdata["source_id"], tdata["atlas_coords"])
						break
			world_objects.erase(obj)
			Grid.vacate(obj.grid_pos)
			obj.queue_free()

	# 3. Revert any dynamically created SubtextRegions spawned since snapshot
	var snap_region_refs: Array = []
	for rdata in snap.region_states:
		snap_region_refs.append(rdata["r"])
	for i in range(Grid.regions.size() - 1, -1, -1):
		var reg = Grid.regions[i]
		if is_instance_valid(reg) and not reg in snap_region_refs:
			Grid.regions.erase(reg)
			reg.queue_free()

	Grid.occupied.clear()

	# 4. Restore player position
	if player_ref and snap.has_player:
		player_ref.grid_pos = snap.player_pos
		player_ref.position = Grid.grid_to_world(player_ref.grid_pos)
		Grid.occupy(player_ref.grid_pos, player_ref)
		player_moved.emit(player_ref.position)

	# 5. Restore wall and layer tags
	Grid.wall_tags.clear()
	for k in snap.wall_tags:
		Grid.wall_tags[k] = snap.wall_tags[k].duplicate()

	Grid.layer_tags.clear()
	for pos in snap.layer_tags:
		Grid.layer_tags[pos] = {}
		for layer_name in snap.layer_tags[pos]:
			Grid.layer_tags[pos][layer_name] = snap.layer_tags[pos][layer_name].duplicate()

	# 6. Restore regions
	for rdata in snap.region_states:
		var region = rdata["r"]
		if is_instance_valid(region):
			region.position = rdata["pos"]
			if "tags" in region:
				region.tags = rdata["tags"].duplicate()
			if not Grid.regions.has(region):
				Grid.regions.append(region)

	# 7. Restore entities
	for edata in snap.entity_states:
		var e: Node2D = edata["r"]
		if is_instance_valid(e):
			e.grid_pos = edata["pos"]
			e.position = Grid.grid_to_world(e.grid_pos)
			if e.get("tags") != null:
				e.tags = edata["t"].duplicate()
			var was_alive: bool = edata.get("is_alive", true)
			if "is_alive" in e:
				e.is_alive = was_alive
			if was_alive:
				e.show()
				_pending_death.erase(e)
				if not entities.has(e):
					entities.append(e)
				Grid.occupy(e.grid_pos, e)
			else:
				e.hide()
				if not _pending_death.has(e):
					_pending_death.append(e)
				entities.erase(e)

	# 8. Restore world objects
	for o_data in snap.object_states:
		var obj: Node2D = o_data["r"]
		if is_instance_valid(obj):
			if "is_moving" in obj:
				obj.is_moving = false

			var tweens = get_tree().get_processed_tweens()
			for t in tweens:
				if t.is_valid() and t.get_meta("target_node", null) == obj:
					t.kill()

			obj.grid_pos = o_data["pos"]
			obj.position = Grid.grid_to_world(obj.grid_pos)
			if obj.get("tags") != null:
				obj.tags.assign(o_data["t"])
			obj.show()
			_pending_death.erase(obj)
			if not world_objects.has(obj):
				world_objects.append(obj)
			Grid.occupy(obj.grid_pos, obj)

	# 9. Refresh visual highlights and spatial tags
	Grid.refresh_all_tags()


func reset_state() -> void:
	_flush_pending_death()
	entities.clear()
	world_objects.clear()
	undo_stack.clear()
	Grid.occupied.clear()
	Grid.wall_tags.clear()
	Grid.layer_tags.clear()
	Grid.regions.clear()
	player_ref = null
	is_transitioning = false


func process_turn() -> void:
	for e in entities:
		if is_instance_valid(e) and e.has_method("take_turn"):
			e.take_turn()
	turn_processed.emit()
