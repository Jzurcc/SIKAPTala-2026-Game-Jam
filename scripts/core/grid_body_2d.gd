class_name GridBody2D
extends Node2D

## Base class for all grid-positioned objects: pushable props, world objects, and AI entities.
## In the Baba Is You inspired architecture, all grid objects are instances of GridBody2D
## whose behavior (pushing, stepping, AI chasing, damage, vulnerability) is 100% governed by TagRule strategies.

@export var id: String = ""
@export var custom_dialogues: Array[String] = []
@export var tags: Array = []

var grid_pos: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var facing_dir: Vector2i = Vector2i.DOWN
var is_moving: bool = false
var is_alive: bool = true

const MOVE_DURATION := 0.18


func _ready() -> void:
	y_sort_enabled = true
	z_index = 1
	grid_pos = Grid.world_to_grid(position)
	position = get_base_world_pos()
	_occupy_cells()
	GameState.register_object(self)
	if has_tag("YOU"):
		TagRegistry.notify_tag_added(self, "YOU")
	_on_ready()


## Subclass hook for visual setup or additional signal connections
func _on_ready() -> void:
	pass


func _occupy_cells() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			Grid.occupy(grid_pos + Vector2i(x, y), self)


func _vacate_cells() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			Grid.vacate(grid_pos + Vector2i(x, y))


func _exit_tree() -> void:
	_vacate_cells()
	if has_tag("YOU"):
		TagRegistry.notify_tag_removed(self, "YOU")
	GameState.unregister_object(self)



## Queries TagRegistry to determine if this body can be pushed
func can_be_pushed(dir: Vector2i) -> bool:
	return TagRegistry.can_push(null, self, dir)


## Executes a push on this body in the given direction
func push(dir: Vector2i) -> bool:
	if is_moving or not is_alive:
		return false

	# Check if any tag intercepts the push (e.g. FRAGILE shatters on push)
	if TagRegistry.on_pushed(null, self, dir):
		return true

	if not can_be_pushed(dir):
		return false

	# Check all cells at the destination for blockers and recursive push chains
	var target: Vector2i = grid_pos + dir
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var check: Vector2i = target + Vector2i(x, y)
			if GameState.is_tile_blocked(check):
				return false
			var occ: Node2D = Grid.get_occupant(check)
			if occ != null and occ != self:
				if TagRegistry.on_pushed(self, occ, dir):
					pass
				elif occ.has_method("push") and occ.push(dir):
					pass
				else:
					return false

	_vacate_cells()
	grid_pos = target
	_occupy_cells()
	Grid.refresh_all_tags()
	_tween_to(get_base_world_pos())
	return true


## Executes a single discrete grid step in the specified direction
func step(dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO or is_moving or not is_alive:
		return false

	facing_dir = dir
	_update_facing(dir)

	var res: Dictionary = Grid.resolve_step(self, dir)
	if not res.get("success", false):
		play_anim("Idle")
		return false

	_vacate_cells()
	grid_pos = res["target_pos"]
	_occupy_cells()
	Grid.refresh_all_tags()

	_tween_to(get_base_world_pos())
	play_anim("Walk")
	return true


## Executes autonomous turn behavior during GameState turn tick
func take_turn() -> void:
	if not is_alive or is_moving:
		return
	TagRegistry.tick_body(self)


func _update_facing(dir: Vector2i) -> void:
	var anim_node: Node = _find_anim_node()
	if anim_node is AnimatedSprite2D:
		if dir.x < 0:
			(anim_node as AnimatedSprite2D).flip_h = true
		elif dir.x > 0:
			(anim_node as AnimatedSprite2D).flip_h = false
	elif anim_node is Sprite2D:
		if dir.x < 0:
			(anim_node as Sprite2D).flip_h = true
		elif dir.x > 0:
			(anim_node as Sprite2D).flip_h = false


func play_anim(anim_name: String) -> void:
	var anim_node: Node = _find_anim_node()
	if anim_node is AnimatedSprite2D:
		var spr: AnimatedSprite2D = anim_node as AnimatedSprite2D
		if spr.sprite_frames and spr.sprite_frames.has_animation(anim_name):
			spr.play(anim_name)


func _find_anim_node() -> Node:
	for child: Node in get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			return child
	return null


func _tween_to(target_world: Vector2) -> void:
	is_moving = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", target_world, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(_on_tween_finished)


func _on_tween_finished() -> void:
	is_moving = false
	play_anim("Idle")


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	_vacate_cells()
	_on_die()
	GameState.mark_dead(self)


func _on_die() -> void:
	pass


func get_tag_names() -> Array[String]:
	var res: Array[String] = []
	for t in tags:
		if t is RefCounted and t.get("name") != null:
			res.append(str(t.name))
		else:
			res.append(str(t))
	return res


func has_tag(tag_name: String) -> bool:
	for t in tags:
		if t is RefCounted and t.get("name") != null:
			if str(t.name) == tag_name:
				return true
		elif str(t) == tag_name:
			return true
	return false


func update_tags(new_tags: Array) -> void:
	var old_tag_names: Array[String] = get_tag_names()
	tags = new_tags.duplicate()
	var new_tag_names: Array[String] = get_tag_names()
	for t: String in old_tag_names:
		if not t in new_tag_names:
			TagRegistry.notify_tag_removed(self, t)
	for t: String in new_tag_names:
		if not t in old_tag_names:
			TagRegistry.notify_tag_added(self, t)
	Grid.refresh_all_tags()


func add_tag(tag: Variant) -> bool:
	var tag_name: String = tag.name if (tag is RefCounted and tag.get("name") != null) else str(tag)
	if has_tag(tag_name):
		return false
	tags.append(tag)
	TagRegistry.notify_tag_added(self, tag_name)
	Grid.refresh_all_tags()
	return true


func remove_tag(tag_name: String) -> bool:
	var found_idx: int = -1
	for i in range(tags.size()):
		var t = tags[i]
		var t_name: String = t.name if (t is RefCounted and t.get("name") != null) else str(t)
		if t_name == tag_name:
			found_idx = i
			break
	if found_idx == -1:
		return false
	tags.remove_at(found_idx)
	TagRegistry.notify_tag_removed(self, tag_name)
	Grid.refresh_all_tags()
	return true


func add_subtext_tag(tag: Variant) -> bool:
	return add_tag(tag)


func remove_subtext_tag(tag: Variant) -> bool:
	var tag_name: String = tag.name if (tag is RefCounted and tag.get("name") != null) else str(tag)
	return remove_tag(tag_name)


func get_bounding_rect() -> Rect2:
	var origin: Vector2 = Vector2(grid_pos * Grid.TILE_SIZE)
	var size: Vector2 = Vector2(grid_size * Grid.TILE_SIZE)
	return Rect2(origin, size)


func get_base_world_pos() -> Vector2:
	var base_cell: Vector2i = Vector2i(grid_pos.x, grid_pos.y + grid_size.y - 1)
	return Grid.grid_to_world(base_cell)


func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			cells.append(grid_pos + Vector2i(x, y))
	return cells


func get_display_top_world_pos() -> Vector2:
	var top_x: float = (float(grid_pos.x) + float(grid_size.x) * 0.5) * float(Grid.TILE_SIZE)
	var top_y: float = float(grid_pos.y) * float(Grid.TILE_SIZE)
	return Vector2(top_x, top_y)
