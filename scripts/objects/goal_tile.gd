extends Node2D

enum WinType { EXIT, DELIVER, SLEEP, DEFEAT, PROTECT, SHATTER }

@export var win_type: WinType = WinType.EXIT
@export var target_entity_name: String = ""
@export var target_object_name: String = ""

var goal_grid_pos: Vector2i = Vector2i.ZERO
var is_won: bool = false


func _ready() -> void:
	goal_grid_pos = Grid.world_to_grid(position)
	position = Grid.grid_to_world(goal_grid_pos)
	GameState.turn_processed.connect(_check_win)


func _check_win() -> void:
	if is_won:
		return

	match win_type:
		WinType.EXIT:
			_check_exit()
		WinType.DELIVER:
			_check_deliver()
		WinType.SLEEP:
			_check_sleep()
		WinType.DEFEAT:
			_check_defeat()
		WinType.PROTECT:
			_check_protect()
		WinType.SHATTER:
			_check_shatter()


func _check_exit() -> void:
	if GameState.player_ref == null:
		return
	if GameState.player_ref.grid_pos == goal_grid_pos:
		_win()


func _check_deliver() -> void:
	var occ: Node2D = Grid.get_occupant(goal_grid_pos)
	if occ != null and occ.name == target_object_name:
		_win()


func _check_sleep() -> void:
	var occ: Node2D = Grid.get_occupant(goal_grid_pos)
	if occ != null and occ.name == target_entity_name:
		if occ.get("tags") != null and "SLEEPING" in occ.tags:
			_win()


func _check_defeat() -> void:
	for e in GameState.entities:
		if is_instance_valid(e) and e.name == target_entity_name:
			return
	_win()


func _check_protect() -> void:
	if GameState.player_ref == null:
		return
	if GameState.player_ref.grid_pos != goal_grid_pos:
		return
	for e in GameState.entities:
		if is_instance_valid(e) and e.name == target_entity_name:
			_win()
			return


func _check_shatter() -> void:
	pass


func notify_shatter_target_destroyed() -> void:
	_win()


func _win() -> void:
	is_won = true
	GameState.level_won.emit()
