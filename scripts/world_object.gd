extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var tags: Array[String] = []
var id: String = ""
var custom_dialogues: Array[String] = []
var is_moving: bool = false


func _occupy_cells() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			Grid.occupy(grid_pos + Vector2i(x, y), self)


func _vacate_cells() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			Grid.vacate(grid_pos + Vector2i(x, y))


func _ready() -> void:
	grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(grid_pos)
	_occupy_cells()
	GameState.register_object(self)


func push(dir: Vector2i) -> bool:
	if is_moving: return false
	
	if "FRAGILE" in tags:
		_die()
		return true
	
	var target := grid_pos + dir

	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var check_pos = target + Vector2i(x, y)
			
			if GameState.is_tile_blocked(check_pos):
				return false

			var occupant: Node2D = Grid.get_occupant(check_pos)
			if occupant != null and occupant != self:
				if occupant.get("tags") != null and "FRAGILE" in occupant.tags:
					if occupant.has_method("_die"):
						occupant._die()
				elif occupant.has_method("push") and occupant.push(dir):
					pass
				else:
					return false

	_vacate_cells()
	grid_pos = target
	_occupy_cells()
	Grid.refresh_all_tags()
	
	var tw = create_tween()
	is_moving = true
	tw.tween_property(self, "position", Grid.grid_to_world(grid_pos), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func(): is_moving = false)
	return true


func remove_tag(tag: String) -> bool:
	if not tag in tags:
		return false
	tags.erase(tag)
	return true


func _exit_tree() -> void:
	_vacate_cells()


func _process(_delta: float) -> void:
	if "HIDDEN" in tags:
		modulate.a = 0.3 if GameState.is_substrate else 0.0
	else:
		modulate.a = 1.0


func _die() -> void:
	GameState.unregister_object(self)
	_vacate_cells()
	Grid.refresh_all_tags()
	queue_free()
