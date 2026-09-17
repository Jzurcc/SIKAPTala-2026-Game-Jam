extends Node

## Manages pixel-perfect hover detection, tag display, and substrate highlight orchestration.
## Dynamically evaluates sprite image sizes, alpha transparency, and allows cycling through
## overlapping layers/objects (e.g. selecting a floor tile underneath a carpet).

const DragControllerScript = preload("res://scripts/ui/drag_controller.gd")

var hover_label: TagLabel
var current_tags: Array = []
var last_highlighted: Node2D = null
var last_highlighted_pos: Vector2i = Vector2i.ZERO
var tile_highlight_sprite: Sprite2D
var highlight_container: Node2D
var label_container: Node2D

var is_selected: bool = false
var _target_world_pos: Vector2 = Vector2.ZERO

var _candidates: Array[Dictionary] = []
var _selected_candidate_idx: int = 0
var _last_grid_pos: Vector2i = Vector2i(-9999, -9999)

var drag: DragController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	drag = DragControllerScript.new()
	add_child(drag)
	drag.swap_completed.connect(_on_swap_completed)

	highlight_container = Node2D.new()
	highlight_container.z_index = 105
	add_child(highlight_container)

	label_container = Node2D.new()
	label_container.z_index = 110
	add_child(label_container)

	tile_highlight_sprite = Sprite2D.new()
	tile_highlight_sprite.centered = true
	tile_highlight_sprite.region_enabled = true
	tile_highlight_sprite.modulate = Color(0.5, 0.8, 1.5, 0.6)
	tile_highlight_sprite.visible = false
	highlight_container.add_child(tile_highlight_sprite)

	hover_label = TagLabel.new()
	label_container.add_child(hover_label)
	hover_label.modulate.a = 0.0
	hover_label.tag_drag_started.connect(_on_tag_drag_started)


func _on_swap_completed() -> void:
	_deselect()
	_clear_highlight()
	current_tags = []
	_candidates.clear()
	_selected_candidate_idx = 0


func _input(event: InputEvent) -> void:
	if not GameState.is_substrate:
		return

	if event.is_action_pressed("ui_cancel"):
		if drag.is_dragging:
			drag.cancel(hover_label)
		_deselect()
		return

	# Candidate layer cycling via mouse wheel, right click, or Tab
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _cycle_candidate(-1):
				get_viewport().set_input_as_handled()
				return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _cycle_candidate(1):
				get_viewport().set_input_as_handled()
				return
		elif event.button_index == MOUSE_BUTTON_RIGHT and not drag.is_dragging:
			if _cycle_candidate(1):
				get_viewport().set_input_as_handled()
				return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if drag.is_dragging:
				var current_sc: Node = get_tree().current_scene
				var mouse_pos: Vector2 = (current_sc as Node2D).get_global_mouse_position() if current_sc is Node2D else Vector2.ZERO
				drag.handle_drop(mouse_pos, hover_label, last_highlighted, self)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if _cycle_candidate(1):
				get_viewport().set_input_as_handled()
				return


func _cycle_candidate(step: int) -> bool:
	if _candidates.size() <= 1:
		return false

	_selected_candidate_idx = (_selected_candidate_idx + step) % _candidates.size()
	if _selected_candidate_idx < 0:
		_selected_candidate_idx += _candidates.size()

	GameState.play_select_sfx()
	_apply_current_candidate()
	return true


func _apply_current_candidate() -> void:
	if _candidates.is_empty():
		return

	var idx: int = _selected_candidate_idx % _candidates.size()
	var cand: Dictionary = _candidates[idx]

	var cand_node: Node2D = cand["node"]
	var cand_pos: Vector2i = cand["pos"]
	var cand_tags: Array = cand["tags"]
	var cand_target_world_pos: Vector2 = cand["target_world_pos"]
	var cand_type: String = cand["type"]

	last_highlighted_pos = cand_pos

	if cand_type == "tile":
		_highlight_layer_tile(cand_node as TileMapLayer, cand_pos)
		last_highlighted = cand_node
	else:
		tile_highlight_sprite.visible = false
		_set_highlight(cand_node)

	_target_world_pos = cand_target_world_pos

	var info_str: String = ""
	if _candidates.size() > 1:
		var name_label: String = str(cand.get("name", ""))
		info_str = "%s [%d/%d] ↕" % [name_label.capitalize(), idx + 1, _candidates.size()]

	current_tags = cand_tags
	hover_label.setup(cand_tags, info_str)
	_select()


func _on_tag_drag_started(tag: Variant, index: int) -> void:
	if last_highlighted == null:
		return

	var current_sc: Node = get_tree().current_scene
	var m_pos: Vector2 = (current_sc as Node2D).get_global_mouse_position() if current_sc is Node2D else Vector2.ZERO
	var source_pos: Vector2i = last_highlighted_pos
	var player_pos: Vector2i = GameState.player_ref.grid_pos if GameState.player_ref else Vector2i.ZERO

	var context: Dictionary = {
		"host": last_highlighted,
		"host_pos": source_pos,
		"player_pos": player_pos
	}

	if not TagRegistry.can_drag_tag(tag, context):
		if hover_label:
			var tag_name: String = tag.name if (tag is RefCounted and tag.get("name") != null) else str(tag)
			hover_label.shake_tag(tag_name)
		GameState.play_error_sfx()
		return

	drag.begin_drag(tag, index, last_highlighted, source_pos, label_container, hover_label)


func _select() -> void:
	is_selected = true
	if hover_label.has_method("set_selected"):
		hover_label.set_selected(true)


func _deselect() -> void:
	is_selected = false
	if hover_label.has_method("set_selected"):
		hover_label.set_selected(false)


func _process(delta: float) -> void:
	if not GameState.is_substrate:
		if drag.is_dragging:
			drag.cancel(hover_label)
		_deselect()
		_clear_highlight()
		tile_highlight_sprite.visible = false
		hover_label.modulate.a = 0.0
		current_tags = []
		_candidates.clear()
		_selected_candidate_idx = 0
		return

	if drag.is_dragging:
		drag.update_visual(delta, is_selected, hover_label)

	_update_pulsating_highlight(delta)

	var scene: Node = get_tree().current_scene
	if not scene or not (scene is Node2D):
		return

	var mouse_pos: Vector2 = (scene as Node2D).get_global_mouse_position()

	# If currently dragging, keep the active target locked
	var over_label: bool = is_selected and not current_tags.is_empty() and hover_label.is_mouse_over_label_area(mouse_pos)

	if not drag.is_dragging and not over_label:
		var new_candidates: Array[Dictionary] = SpriteHitDetector.get_candidates_at_position(mouse_pos)

		if new_candidates.is_empty():
			if is_selected:
				_deselect()
			_clear_highlight()
			tile_highlight_sprite.visible = false
			_candidates.clear()
			_selected_candidate_idx = 0
			current_tags = []
		else:
			var changed: bool = false
			if new_candidates.size() != _candidates.size():
				changed = true
			else:
				for i in range(new_candidates.size()):
					if new_candidates[i]["node"] != _candidates[i]["node"] or new_candidates[i]["pos"] != _candidates[i]["pos"]:
						changed = true
						break

			_candidates = new_candidates

			if changed or not is_selected:
				_selected_candidate_idx = 0
				_apply_current_candidate()

	# Update visual position and opacity of hover label
	if is_selected and not current_tags.is_empty():
		hover_label.holding_tag = drag.drag_tag if drag.is_dragging else ""
		if drag.is_dragging and last_highlighted == drag.drag_source_node and last_highlighted_pos == drag.drag_source_pos:
			hover_label.remove_tag_visual(drag.drag_index)

		hover_label.global_position = hover_label.global_position.lerp(_target_world_pos, 0.25)
		hover_label.modulate.a = lerpf(hover_label.modulate.a, 1.0, 0.25)
	else:
		hover_label.modulate.a = lerpf(hover_label.modulate.a, 0.0, 0.35)
		if hover_label.modulate.a < 0.05:
			current_tags = []


func _update_pulsating_highlight(_delta: float) -> void:
	var p: float = (sin(Time.get_ticks_msec() * 0.012) + 1.0) / 2.0
	var alpha: float = lerpf(0.3, 0.8, p)

	if tile_highlight_sprite.visible:
		tile_highlight_sprite.modulate.a = alpha

	if is_instance_valid(last_highlighted) and not last_highlighted is TileMapLayer:
		last_highlighted.modulate.a = alpha


func _highlight_layer_tile(layer: TileMapLayer, pos: Vector2i) -> void:
	if not is_instance_valid(layer) or not layer.tile_set:
		tile_highlight_sprite.visible = false
		return

	var source_id: int = layer.get_cell_source_id(pos)
	if source_id != -1:
		var atlas_coords: Vector2i = layer.get_cell_atlas_coords(pos)
		var source: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source and source.texture:
			tile_highlight_sprite.texture = source.texture
			tile_highlight_sprite.region_rect = source.get_tile_texture_region(atlas_coords)
			tile_highlight_sprite.global_position = Grid.grid_to_world(pos)
			tile_highlight_sprite.z_index = layer.z_index + 1
			tile_highlight_sprite.visible = true
			return

	tile_highlight_sprite.visible = false


func _set_highlight(node: Node2D) -> void:
	if last_highlighted == node:
		return
	_clear_highlight()
	last_highlighted = node
	if node.has_method("set_highlighted"):
		node.set_highlighted(true)
	else:
		node.modulate = Color(1.2, 1.2, 1.5, 1.0)


func _clear_highlight() -> void:
	if is_instance_valid(last_highlighted):
		if last_highlighted.has_method("set_highlighted"):
			last_highlighted.set_highlighted(false)
		last_highlighted.modulate = Color.WHITE

	tile_highlight_sprite.visible = false
	tile_highlight_sprite.modulate.a = 0.6
	last_highlighted = null


func get_selected_target_data() -> Dictionary:
	if _candidates.is_empty():
		return {
			"node": last_highlighted,
			"pos": last_highlighted_pos
		}
	var idx: int = _selected_candidate_idx % _candidates.size()
	return _candidates[idx]
