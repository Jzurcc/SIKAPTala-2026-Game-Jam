extends Camera2D

const MOVE_DURATION := 0.18

var _tween: Tween = null


func _ready() -> void:
	if GameState.player_ref != null:
		global_position = GameState.player_ref.position
	GameState.player_moved.connect(_on_player_moved)
	GameState.player_died.connect(_on_player_died)


func _on_player_moved(world_pos: Vector2) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", world_pos, MOVE_DURATION)


func _on_player_died() -> void:
	if _tween:
		_tween.kill()
