extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var tags: Array[String] = []
var id: String = ""
var custom_dialogues: Array[String] = []
var is_moving: bool = false


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	Grid.occupy(grid_pos, self)
	GameState.register_object(self)


func push(dir: Vector2i) -> bool:
	if is_moving: return false
	
	var target := grid_pos + dir

	if GameState.is_tile_blocked(target):
		return false

	var occupant: Node2D = Grid.get_occupant(target)
	if occupant != null:
		if occupant.has_method("push") and occupant.push(dir):
			pass
		else:
			return false

	Grid.vacate(grid_pos)
	grid_pos = target
	Grid.occupy(grid_pos, self)
	Grid.refresh_all_tags()
	
	var tw = create_tween()
	is_moving = true
	tw.tween_property(self, "position", Grid.grid_to_world(grid_pos), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func(): is_moving = false)
	
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
