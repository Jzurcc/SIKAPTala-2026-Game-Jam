extends Camera2D

const MOVE_DURATION := 0.18

var _tween: Tween = null
var _current_zone: CameraZone = null
var _default_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_default_zoom = zoom
	if GameState.player_ref != null:
		global_position = GameState.player_ref.position
	GameState.player_moved.connect(_on_player_moved)
	GameState.player_died.connect(_on_player_died)


func enter_zone(zone: CameraZone) -> void:
	_current_zone = zone
	_transition_to(zone.camera_pos, zone.camera_zoom)


func exit_zone(zone: CameraZone) -> void:
	if _current_zone == zone:
		_current_zone = null
		if GameState.player_ref:
			_transition_to(GameState.player_ref.position, _default_zoom)


func _on_player_moved(world_pos: Vector2) -> void:
	if _current_zone != null:
		return # Stay in fixed zone position
		
	_transition_to(world_pos, _default_zoom)


func _transition_to(target_pos: Vector2, target_zoom: Vector2) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_pos, MOVE_DURATION)
	_tween.parallel().tween_property(self, "zoom", target_zoom, MOVE_DURATION)


func _on_player_died() -> void:
	if _tween:
		_tween.kill()
