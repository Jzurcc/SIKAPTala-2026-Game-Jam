extends Node3D
class_name SchrodingerObject

@export var layer_mask: int = 1
@export var collision_shape_path: NodePath
@export var mesh_instance_path: NodePath

var _collision_shape: CollisionShape3D
var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _was_revealed := false
var _initialized := false

var _positions := PackedVector3Array()
var _radii := PackedFloat32Array()


func _ready() -> void:
	_positions.resize(8)
	_radii.resize(8)
	
	if not collision_shape_path.is_empty():
		_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	if not mesh_instance_path.is_empty():
		_mesh_instance = get_node_or_null(mesh_instance_path) as MeshInstance3D


func _physics_process(_delta: float) -> void:
	if not _initialized:
		_initialized = true
		if _mesh_instance:
			_material = _mesh_instance.get_surface_override_material(0) as ShaderMaterial
			if not _material:
				_material = ShaderMaterial.new()
				_material.shader = load("res://shaders/schrodinger_reveal.gdshader")
				_mesh_instance.set_surface_override_material(0, _material)
				print("[SchrodingerObject] ", get_parent().name, " | material was null — created new one")
			else:
				print("[SchrodingerObject] ", get_parent().name, " | material OK: ", _material)
		else:
			print("[SchrodingerObject] ", get_parent().name, " | _mesh_instance is NULL (check NodePath)")

	var count := _fill_source_arrays()
	
	# Determine if the object should be physically active based on proximity to any sound source
	var is_physically_active := false
	if count > 0:
		for source: Node in SoundManager.get_sources():
			var src := source as SoundSource
			if src == null or src.layer_mask & layer_mask == 0:
				continue
			
			# Check if source radius reaches the object center
			# We use a small buffer or could use AABB for better large-object support
			var dist = global_position.distance_to(src.global_position)
			if dist <= src.current_radius + 2.0: # 2m buffer to be safe with collision
				is_physically_active = true
				break
	
	var revealed := count > 0 # Still keep it 'revealed' for shader processing if any source exists

	if revealed != _was_revealed:
		_was_revealed = revealed
		print("[SchrodingerObject] ", get_parent().name, " -> ", "REVEALED" if revealed else "HIDDEN", " | active sources: ", count)

	if _collision_shape:
		_collision_shape.disabled = not is_physically_active
	if _mesh_instance:
		_mesh_instance.visible = revealed
	if _material:
		_material.set_shader_parameter("source_positions", _positions)
		_material.set_shader_parameter("source_radii", _radii)
		_material.set_shader_parameter("source_count", count)


func _fill_source_arrays() -> int:
	for i in 8:
		_positions[i] = Vector3.ZERO
		_radii[i] = 0.0

	var count := 0
	for source: Node in SoundManager.get_sources():
		var src := source as SoundSource
		if src == null or src.layer_mask & layer_mask == 0:
			continue
		_positions[count] = src.global_position
		_radii[count] = src.current_radius
		count += 1
		if count >= 8:
			break
	return count
