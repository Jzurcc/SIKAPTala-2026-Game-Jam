extends Node

signal turn_processed
signal substrate_toggled(active: bool)
@warning_ignore("unused_signal")
signal player_died
signal player_moved(world_pos: Vector2)
@warning_ignore("unused_signal")
signal level_won

class UndoSnapshot:
	var player_pos: Vector2i = Vector2i.ZERO
	var has_player: bool = false
	var player_tags: Array = []
	var you_bodies: Array[Node2D] = []
	var wall_tags: Dictionary = {}
	var layer_tags: Dictionary = {}
	var cell_tag_overrides: Dictionary = {}
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
var _you_bodies: Array[Node2D] = []
var entities: Array[Node2D] = []
var world_objects: Array[Node2D] = []
var solid_tilemaps: Array[TileMapLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## --- Audio & Transition forwarding stubs ---

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

## --- Registration & YOU Identity ---

func register_player(p: Node2D) -> void:
	player_ref = p
	if player_ref:
		player_ref.z_index = 1
		player_ref.y_sort_enabled = true
		register_you_body(player_ref)


func register_you_body(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not _you_bodies.has(body):
		_you_bodies.append(body)
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = body


func unregister_you_body(body: Node2D) -> void:
	_you_bodies.erase(body)
	if player_ref == body:
		player_ref = _you_bodies[0] if not _you_bodies.is_empty() else null


func get_you_bodies() -> Array[Node2D]:
	var active: Array[Node2D] = []
	for b in _you_bodies:
		if is_instance_valid(b) and (b.get("is_alive") == null or b.get("is_alive") == true) and (b.get("is_dead") == null or b.get("is_dead") == false):
			active.append(b)
	if player_ref and is_instance_valid(player_ref) and not active.has(player_ref):
		if player_ref.has_method("has_tag") and player_ref.has_tag("YOU"):
			active.append(player_ref)
		elif player_ref.get("tags") != null and "YOU" in TagRegistry.extract_tag_names(player_ref.tags):
			active.append(player_ref)
	for obj in world_objects:
		if is_instance_valid(obj) and not active.has(obj):
			if obj.has_method("has_tag") and obj.has_tag("YOU"):
				active.append(obj)
			elif obj.get("tags") != null and "YOU" in TagRegistry.extract_tag_names(obj.tags):
				active.append(obj)
	for ent in entities:
		if is_instance_valid(ent) and not active.has(ent):
			if ent.has_method("has_tag") and ent.has_tag("YOU"):
				active.append(ent)
			elif ent.get("tags") != null and "YOU" in TagRegistry.extract_tag_names(ent.tags):
				active.append(ent)
	if active.is_empty() and player_ref != null and is_instance_valid(player_ref):
		active.append(player_ref)
	return active


func get_primary_player() -> Node2D:
	var bodies: Array[Node2D] = get_you_bodies()
	if not bodies.is_empty():
		return bodies[0]
	return player_ref



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
	var root: Node = get_tree().current_scene
	if root:
		if root is Node2D:
			(root as Node2D).y_sort_enabled = true
		_find_tilemaps_recursive(root)


func _find_tilemaps_recursive(node: Node) -> void:
	if node is TileMapLayer:
		if not node in solid_tilemaps:
			node.z_index = 0
			node.y_sort_enabled = false
			solid_tilemaps.append(node)
	for child: Node in node.get_children():
		_find_tilemaps_recursive(child)


func reset() -> void:
	entities.clear()
	world_objects.clear()
	_you_bodies.clear()
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


func is_substrate_active() -> bool:
	return is_substrate


func is_wall_at(pos: Vector2i) -> bool:
	var wt: Array = Grid.get_wall_tags(pos)
	return "IMPASSABLE" in TagRegistry.extract_tag_names(wt)


func is_tile_blocked(pos: Vector2i) -> bool:
	# 1. Check tilemap layers — if ANY present layer is impassable, tile is blocked
	for i in range(solid_tilemaps.size() - 1, -1, -1):
		var layer: TileMapLayer = solid_tilemaps[i]
		if is_instance_valid(layer) and layer.get_cell_source_id(pos) != -1:
			var l_tags: Array[String] = []
			if Grid.cell_tag_overrides.has(pos) and Grid.cell_tag_overrides[pos].has(layer.name):
				l_tags = TagRegistry.extract_tag_names(Grid.cell_tag_overrides[pos][layer.name])
			elif Grid.layer_tags.has(pos) and Grid.layer_tags[pos].has(layer.name):
				l_tags = TagRegistry.extract_tag_names(Grid.layer_tags[pos][layer.name])
			elif layer.get("tags") != null:
				l_tags = TagRegistry.extract_tag_names(layer.tags)

			if not l_tags.is_empty() and not TagRegistry.can_enter(player_ref, pos, l_tags):
				return true

	# 2. Check region overrides
	for region: Node2D in Grid.regions:
		if is_instance_valid(region) and region.get_grid_rect().has_point(pos):
			var r_tags: Array[String] = TagRegistry.extract_tag_names(region.get("tags"))
			if not r_tags.is_empty() and not TagRegistry.can_enter(player_ref, pos, r_tags):
				return true

	return false


func has_harmful_at(pos: Vector2i) -> bool:
	var wt: Array = Grid.get_wall_tags(pos)
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
	for node: Node2D in _pending_death:
		if is_instance_valid(node):
			node.queue_free()
	_pending_death.clear()


## --- Transactional Turn Pipeline ---

func step_turn(actor: Node2D, dir: Vector2i) -> bool:
	if is_substrate or is_transitioning:
		return false

	push_undo_state()

	var res: Dictionary = Grid.resolve_step(actor, dir)

	if not res.get("success", false):
		if not res.get("harmful", false) and not res.get("attacked_player", false):
			undo_stack.pop_back()
		if not res.get("blocked", false):
			process_turn()
		return false

	Grid.vacate(actor.grid_pos)
	actor.grid_pos = res["target_pos"]
	Grid.occupy(actor.grid_pos, actor)
	player_moved.emit(actor.position)

	# Multi-avatar step: If there are other YOU bodies, step them in parallel
	var you_bodies: Array[Node2D] = get_you_bodies()
	for other in you_bodies:
		if is_instance_valid(other) and other != actor:
			if other.has_method("step"):
				other.step(dir)

	process_turn()
	return true



func process_turn() -> void:
	# Tick all registered entities and active props with autonomous tags
	var bodies: Array[Node2D] = []
	for e: Node2D in entities:
		if is_instance_valid(e) and not bodies.has(e):
			bodies.append(e)
	for o: Node2D in world_objects:
		if is_instance_valid(o) and not bodies.has(o) and o != player_ref:
			bodies.append(o)

	for b: Node2D in bodies:
		if is_instance_valid(b) and b.has_method("take_turn"):
			b.take_turn()

	turn_processed.emit()


## --- Undo / Redo Transactions ---

func push_undo_state() -> void:
	var snap := UndoSnapshot.new()

	if player_ref:
		snap.has_player = true
		snap.player_pos = player_ref.grid_pos
		if player_ref.get("tags") != null:
			snap.player_tags = (player_ref.tags as Array).duplicate()
	snap.you_bodies = _you_bodies.duplicate()


	for k: Vector2i in Grid.wall_tags:
		snap.wall_tags[k] = Grid.wall_tags[k].duplicate()

	for pos: Vector2i in Grid.layer_tags:
		snap.layer_tags[pos] = {}
		for layer_name: String in Grid.layer_tags[pos]:
			snap.layer_tags[pos][layer_name] = Grid.layer_tags[pos][layer_name].duplicate()

	for pos: Vector2i in Grid.cell_tag_overrides:
		snap.cell_tag_overrides[pos] = {}
		for layer_name: String in Grid.cell_tag_overrides[pos]:
			snap.cell_tag_overrides[pos][layer_name] = Grid.cell_tag_overrides[pos][layer_name].duplicate()

	for r: Node2D in Grid.regions:
		if is_instance_valid(r):
			snap.region_states.append({
				"r": r,
				"pos": r.position,
				"tags": r.tags.duplicate()
			})

	for e: Node2D in entities:
		if is_instance_valid(e):
			snap.entity_states.append({
				"r": e,
				"pos": e.grid_pos,
				"t": e.get("tags").duplicate() if e.get("tags") != null else [],
				"is_alive": e.get("is_alive") if "is_alive" in e else true
			})

	for o: Node2D in world_objects:
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
	for o_data: Dictionary in snap.object_states:
		snap_obj_refs.append(o_data["r"])
	for i in range(world_objects.size() - 1, -1, -1):
		var obj: Node2D = world_objects[i]
		if is_instance_valid(obj) and not obj in snap_obj_refs:
			if obj.has_meta("converted_from_tile"):
				var tdata: Dictionary = obj.get_meta("converted_from_tile")
				for layer: TileMapLayer in solid_tilemaps:
					if is_instance_valid(layer) and layer.name == tdata["layer_name"]:
						layer.set_cell(tdata["pos"], tdata["source_id"], tdata["atlas_coords"])
						break
			world_objects.erase(obj)
			Grid.vacate(obj.grid_pos)
			obj.queue_free()

	Grid.occupied.clear()

	# 3. Restore player position & tags
	if player_ref and snap.has_player:
		player_ref.grid_pos = snap.player_pos
		player_ref.position = Grid.grid_to_world(player_ref.grid_pos)
		if not snap.player_tags.is_empty() and player_ref.get("tags") != null:
			player_ref.tags = snap.player_tags.duplicate()
		Grid.occupy(player_ref.grid_pos, player_ref)
		player_moved.emit(player_ref.position)
	_you_bodies = snap.you_bodies.duplicate()


	# 4. Restore spatial cell tag overrides
	Grid.cell_tag_overrides.clear()
	for pos: Vector2i in snap.cell_tag_overrides:
		Grid.cell_tag_overrides[pos] = {}
		for layer_name: String in snap.cell_tag_overrides[pos]:
			Grid.cell_tag_overrides[pos][layer_name] = snap.cell_tag_overrides[pos][layer_name].duplicate()

	# 5. Restore regions
	for rdata: Dictionary in snap.region_states:
		var region: Node2D = rdata["r"]
		if is_instance_valid(region):
			region.position = rdata["pos"]
			if "tags" in region:
				region.tags = rdata["tags"].duplicate()
			if not Grid.regions.has(region):
				Grid.regions.append(region)

	# 6. Restore entities
	for edata: Dictionary in snap.entity_states:
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

	# 7. Restore world objects
	for o_data: Dictionary in snap.object_states:
		var obj: Node2D = o_data["r"]
		if is_instance_valid(obj):
			if "is_moving" in obj:
				obj.is_moving = false

			var tweens: Array[Tween] = get_tree().get_processed_tweens()
			for t: Tween in tweens:
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

	# 8. Refresh spatial tags
	Grid.refresh_all_tags()


func reset_state() -> void:
	_flush_pending_death()
	entities.clear()
	world_objects.clear()
	_you_bodies.clear()
	undo_stack.clear()
	Grid.clear()
	player_ref = null
	is_transitioning = false

