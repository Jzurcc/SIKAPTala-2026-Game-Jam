extends Node

const TILE_SIZE := 16

var occupied: Dictionary = {}
var wall_tags: Dictionary = {}


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


func occupy(pos: Vector2i, node: Node2D) -> void:
	occupied[pos] = node


func vacate(pos: Vector2i) -> void:
	occupied.erase(pos)


func is_occupied(pos: Vector2i) -> bool:
	return occupied.has(pos)


func get_occupant(pos: Vector2i) -> Node2D:
	return occupied.get(pos, null)


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


func clear() -> void:
	occupied.clear()
	wall_tags.clear()
