extends Node3D
class_name SoundSource

@export var radius: float = 5.0
@export var duration: float = 4.0
@export var cone_angle: float = 0.0
@export var layer_mask: int = 1
@export var auto_register: bool = true
@export var show_debug_sphere: bool = false

var current_radius: float = 0.0
var _time_alive: float = 0.0
var _is_active: bool = false
var _debug_mesh: MeshInstance3D


func _ready() -> void:
	if auto_register:
		play()
		
	if show_debug_sphere:
		_debug_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.0, 0.2, 0.3)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		sphere.material = mat
		_debug_mesh.mesh = sphere
		add_child(_debug_mesh)


func play() -> void:
	_time_alive = 0.0
	if not _is_active:
		_is_active = true
		SoundManager.register(self)


func stop() -> void:
	if _is_active:
		_is_active = false
		SoundManager.unregister(self)
		current_radius = 0.0
		if _debug_mesh:
			_debug_mesh.visible = false


func _process(delta: float) -> void:
	if not _is_active:
		return
		
	_time_alive += delta
	var progress: float = _time_alive / duration if duration > 0.0 else 0.5
	
	if duration > 0.0 and progress >= 1.0:
		stop()
	else:
		# Realistic sound vibrations: Radius expands linearly over time
		var base_scale := progress # 0.0 to 1.0 linear expansion
		
		# Fade out quickly at the very end
		var fade := 1.0 - smoothstep(0.9, 1.0, progress)
		
		var flicker := 0.0
		if progress > 0.5:
			var t = _time_alive
			flicker = sin(t * 15.0) * 0.02 + sin(t * 7.3) * 0.03
			
		current_radius = radius * base_scale * fade * (1.0 + flicker)

	if _debug_mesh:
		_debug_mesh.visible = true
		var sphere = _debug_mesh.mesh as SphereMesh
		sphere.radius = maxf(0.01, current_radius)
		sphere.height = maxf(0.01, current_radius * 2.0)


func _exit_tree() -> void:
	SoundManager.unregister(self)


func get_forward() -> Vector3:
	return -global_transform.basis.z
