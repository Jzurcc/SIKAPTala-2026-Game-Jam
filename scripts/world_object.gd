extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array[String] = []


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.register_object(self)


func push(dir: Vector2i) -> bool:
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		return false

	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		return false

	Grid.vacate(grid_pos)
	grid_pos = target
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	return true


func add_tag(tag: String) -> bool:
	if tags.size() >= 2:
		return false
	if tag in tags:
		return false
	tags.append(tag)
	return true


func remove_tag(tag: String) -> bool:
	if not tag in tags:
		return false
	tags.erase(tag)
	return true


func _exit_tree() -> void:
	Grid.vacate(grid_pos)
