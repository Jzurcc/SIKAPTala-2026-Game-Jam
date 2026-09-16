class_name GridBody2D
extends Node2D

## Base class for all grid-positioned objects: pushable props, world objects, and AI entities.
## Handles: grid snapping, multi-cell occupancy, push logic, tween movement, and death.
## Subclasses implement _on_ready(), _on_die(), and can_be_pushed() hooks.

@export var id: String = ""
@export var custom_dialogues: Array[String] = []
@export var tags: Array[String] = []

var grid_pos: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var is_moving: bool = false

const MOVE_DURATION := 0.18


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	_occupy_cells()
	_on_ready()


## Override in subclasses to register with GameState etc.
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


## Override to change when this body may be pushed.
## Default: only LIGHT-tagged bodies can be pushed.
func can_be_pushed(_dir: Vector2i) -> bool:
	return "LIGHT" in tags


func push(dir: Vector2i) -> bool:
	if is_moving:
		return false
	if not can_be_pushed(dir):
		return false

	# FRAGILE objects die instead of moving
	if "FRAGILE" in tags:
		die()
		return true

	# Check all cells at the destination for blockers
	var target := grid_pos + dir
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var check := target + Vector2i(x, y)
			if GameState.is_tile_blocked(check):
				return false
			var occ: Node2D = Grid.get_occupant(check)
			if occ != null and occ != self:
				var occ_tags = occ.get("tags")
				if occ_tags != null and "FRAGILE" in occ_tags:
					if occ.has_method("die"):
						occ.die()
					elif occ.has_method("_die"):
						occ._die()
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


func _tween_to(target_world: Vector2) -> void:
	is_moving = true
	var tw := create_tween()
	tw.tween_property(self, "position", target_world, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func(): is_moving = false)


func die() -> void:
	_vacate_cells()
	_on_die()
	queue_free()


## Override to handle cleanup before queue_free (e.g., unregister from GameState).
func _on_die() -> void:
	pass


func update_tags(new_tags: Array[String]) -> void:
	tags.assign(new_tags)


func add_tag(tag: String) -> bool:
	if tag in tags:
		return false
	tags.append(tag)
	return true


func remove_tag(tag: String) -> bool:
	if not tag in tags:
		return false
	tags.erase(tag)
	return true
