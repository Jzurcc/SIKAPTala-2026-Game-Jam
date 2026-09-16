class_name GridBody2D
extends Node2D

## Base class for all grid-positioned objects: pushable props, world objects, and AI entities.
## In the Baba Is You inspired architecture, all grid objects are instances of GridBody2D
## whose behavior (pushing, stepping, AI chasing, damage, vulnerability) is 100% governed by TagRule strategies.

@export var id: String = ""
@export var custom_dialogues: Array[String] = []
@export var tags: Array[String] = []

var grid_pos: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var facing_dir: Vector2i = Vector2i.DOWN
var is_moving: bool = false
var is_alive: bool = true

const MOVE_DURATION := 0.18


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	_occupy_cells()
	GameState.register_object(self)
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
	_tween_to(Grid.grid_to_world(grid_pos))
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

	var target_world: Vector2 = Grid.grid_to_world(grid_pos)
	_tween_to(target_world)
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


func update_tags(new_tags: Array[String]) -> void:
	var old_tags: Array[String] = tags.duplicate()
	tags.assign(new_tags)
	for t: String in old_tags:
		if not t in tags:
			TagRegistry.notify_tag_removed(self, t)
	for t: String in tags:
		if not t in old_tags:
			TagRegistry.notify_tag_added(self, t)
	Grid.refresh_all_tags()


func add_tag(tag: String) -> bool:
	if tag in tags:
		return false
	tags.append(tag)
	TagRegistry.notify_tag_added(self, tag)
	Grid.refresh_all_tags()
	return true


func remove_tag(tag: String) -> bool:
	if not tag in tags:
		return false
	tags.erase(tag)
	TagRegistry.notify_tag_removed(self, tag)
	Grid.refresh_all_tags()
	return true
