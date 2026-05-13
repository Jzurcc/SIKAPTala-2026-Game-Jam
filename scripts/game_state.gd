extends Node

signal turn_processed
signal substrate_toggled(active: bool)
signal player_died
signal player_moved(world_pos: Vector2)
signal level_won

var is_substrate: bool = false
var undo_stack: Array[Dictionary] = []

var bgm_player: AudioStreamPlayer
var bgm_playlist: Array[String] = [
	"res://assets/music/bgm/punky-troll-oxcc-5-u.wav",
	"res://assets/music/bgm/ooh-a-fly-wait-it-isn-t-tloagd.wav",
	"res://assets/music/bgm/welcome-space-traveler-4-wct-1-b.wav"
]
var bgm_index: int = 0
var lpf_tween: Tween

var transition_layer: CanvasLayer
var transition_rect: ColorRect

var player_ref: Node2D = null
var entities: Array[Node2D] = []
var world_objects: Array[Node2D] = []
var solid_tilemaps: Array[TileMapLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 128
	add_child(transition_layer)
	
	transition_rect = ColorRect.new()
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)


func start_gameplay_music() -> void:
	if bgm_player.playing:
		return
	bgm_index = 0
	_play_current_bgm()


func transition_to_scene(path: String, start_bgm: bool = false) -> void:
	var tw = create_tween()
	tw.tween_property(transition_rect, "color:a", 1.0, 0.8)
	await tw.finished
	
	get_tree().change_scene_to_file(path)
	await get_tree().create_timer(2.0).timeout 
	
	if start_bgm:
		start_gameplay_music()
		
	tw = create_tween()
	tw.tween_property(transition_rect, "color:a", 0.0, 0.8)


func _play_current_bgm() -> void:
	var stream = load(bgm_playlist[bgm_index])
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	bgm_player.stream = stream
	bgm_player.play()


func _on_bgm_finished() -> void:
	bgm_index = (bgm_index + 1) % bgm_playlist.size()
	await get_tree().create_timer(randf_range(2.0, 3.0)).timeout
	_play_current_bgm()


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


func refresh_tilemaps() -> void:
	solid_tilemaps.clear()
	var root = get_tree().current_scene
	if root:
		_find_tilemaps_recursive(root)

func _find_tilemaps_recursive(node: Node) -> void:
	if node is TileMapLayer:
		if not node in solid_tilemaps:
			# Auto-attach script if missing
			if node.get_script() == null:
				if "Floor" in node.name:
					node.set_script(load("res://scripts/floor_layer.gd"))
				else:
					node.set_script(load("res://scripts/wall_layer.gd"))
			
			# Use Z-index 1 for sorting layers, 0 for floors
			if "Floor" in node.name:
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
	get_tree().paused = is_substrate
	substrate_toggled.emit(is_substrate)
	
	if lpf_tween:
		lpf_tween.kill()
		
	var bus_idx = AudioServer.get_bus_index("BGM")
	if bus_idx != -1 and AudioServer.get_bus_effect_count(bus_idx) > 0:
		var effect = AudioServer.get_bus_effect(bus_idx, 0)
		if effect is AudioEffectLowPassFilter:
			lpf_tween = create_tween()
			lpf_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			var target_hz = 600.0 if is_substrate else 20000.0
			var target_pitch = 0.8 if is_substrate else 1.0
			lpf_tween.tween_property(effect, "cutoff_hz", target_hz, 0.25).set_trans(Tween.TRANS_SINE)
			lpf_tween.parallel().tween_property(bgm_player, "pitch_scale", target_pitch, 0.25).set_trans(Tween.TRANS_SINE)


func is_wall_at(pos: Vector2i) -> bool:
	for t in solid_tilemaps:
		if t.get_cell_source_id(pos) != -1:
			return true
	return false


func is_tile_blocked(pos: Vector2i) -> bool:
	for i in range(solid_tilemaps.size() - 1, -1, -1):
		var layer = solid_tilemaps[i]
		if layer.get_cell_source_id(pos) != -1:
			var is_passable = false
			if Grid.layer_tags.has(pos) and Grid.layer_tags[pos].has(layer.name):
				var tags = Grid.layer_tags[pos][layer.name]
				if "PASSABLE" in tags: is_passable = true
				elif "IMPASSABLE" in tags: return true
			
			if not is_passable and layer.name.to_lower().contains("wall"):
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
		player_moved.emit(player_ref.position)

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

	for o_data in snap["o"]:
		var obj: Node2D = o_data["r"]
		if is_instance_valid(obj):
			# Reset movement state so they don't slide back after undo
			if "is_moving" in obj:
				obj.is_moving = false
			
			# Kill any active tweens on the object to snap it back
			var tweens = get_tree().get_processed_tweens()
			for t in tweens:
				if t.is_valid() and t.get_meta("target_node", null) == obj:
					t.kill()

			obj.grid_pos = o_data["pos"]
			obj.position = Grid.grid_to_world(obj.grid_pos)
			if obj.get("tags") != null:
				obj.tags.assign(o_data["t"])
			Grid.occupy(obj.grid_pos, obj)


func process_turn() -> void:
	for e in entities:
		if is_instance_valid(e) and e.has_method("take_turn"):
			e.take_turn()
	turn_processed.emit()
