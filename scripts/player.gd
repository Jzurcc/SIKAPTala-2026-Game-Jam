extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.002
const LOOK_CLAMP := PI / 2.0 - 0.01

const HUM_COOLDOWN := 0.0
const SHOUT_COOLDOWN := 0.0

@onready var _camera: Camera3D = $Camera3D
@onready var _hum_source: SoundSource = $HumSource
@onready var _shout_source: SoundSource = $ShoutSource

var _pitch := 0.0
var _hum_cooldown := 0.0
var _shout_cooldown := 0.0
var _debug_timer := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(
			_pitch - event.relative.y * MOUSE_SENSITIVITY,
			-LOOK_CLAMP,
			LOOK_CLAMP
		)
		_camera.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("voice_hum"):
		if _hum_cooldown <= 0.0:
			_hum_cooldown = HUM_COOLDOWN
			_hum_source.play()
			print("[Player] Hum activated | cooldown: ", HUM_COOLDOWN, "s")
		else:
			print("[Player] Hum on cooldown: ", snapped(_hum_cooldown, 0.1), "s remaining")

	if event.is_action_pressed("voice_shout"):
		if _shout_cooldown <= 0.0:
			_shout_cooldown = SHOUT_COOLDOWN
			_shout_source.play()
			print("[Player] Shout activated | cooldown: ", SHOUT_COOLDOWN, "s")
		else:
			print("[Player] Shout on cooldown: ", snapped(_shout_cooldown, 0.1), "s remaining")


func _process(delta: float) -> void:
	_hum_cooldown = maxf(_hum_cooldown - delta, 0.0)
	_shout_cooldown = maxf(_shout_cooldown - delta, 0.0)

	_debug_timer -= delta
	if _debug_timer <= 0.0:
		_debug_timer = 0.5
		var pos := global_position
		print("[Player] pos=(%.2f, %.2f, %.2f) | sources=%d | hum_cd=%.1f | shout_cd=%.1f" % [
			pos.x, pos.y, pos.z,
			SoundManager.get_sources().size(),
			_hum_cooldown,
			_shout_cooldown
		])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	move_and_slide()
