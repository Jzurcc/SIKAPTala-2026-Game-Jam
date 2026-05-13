@tool
extends Sprite2D

@export var id: String = ""
@export var custom_dialogues: Array[String] = []
@export var tags: Array[String] = []
var grid_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false

@export_group("Tileset Visuals")
@export var source_tileset: TileSet:
	set(val):
		source_tileset = val
		_update_visuals()
@export var atlas_coords: Vector2i = Vector2i.ZERO:
	set(val):
		atlas_coords = val
		_update_visuals()
@export var atlas_size: Vector2i = Vector2i(1, 1):
	set(val):
		atlas_size = val
		_update_visuals()

func _ready() -> void:
	_update_visuals()
	
	if Engine.is_editor_hint(): 
		return
	
	# Ensure it stays above the TileMap layers (which are 10, 20, 30...)
	z_index = 100
	
	# Snap to grid for interaction/logic purposes
	grid_pos = Grid.world_to_grid(global_position)
	global_position = Grid.grid_to_world(grid_pos)
	
	# If larger than 1x1, offset visuals to stay centered on the top-left cell's grid position
	# This ensures the sprite's "region" aligns perfectly with the cells we occupy
	centered = false 
	
	# Occupy all cells covered by this object's dimensions
	for x in range(atlas_size.x):
		for y in range(atlas_size.y):
			Grid.occupy(grid_pos + Vector2i(x, y), self)
			
	GameState.register_object(self)


func push(dir: Vector2i) -> bool:
	if is_moving: return false
	if not "LIGHT" in tags: return false
	
	var target := grid_pos + dir
	if GameState.is_tile_blocked(target): return false
	var occupant = Grid.get_occupant(target)
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


func _update_visuals():
	if not is_inside_tree(): return
	
	if source_tileset:
		var source = source_tileset.get_source(0) as TileSetAtlasSource
		if source:
			region_enabled = true
			texture = source.texture
			var rect = source.get_tile_texture_region(atlas_coords)
			# Expand the region to cover the atlas_size
			rect.size.x *= atlas_size.x
			rect.size.y *= atlas_size.y
			region_rect = rect
			
			# When not centered, (0,0) is the top-left of the first tile
			# This matches how we occupy cells starting from grid_pos
			if not Engine.is_editor_hint():
				centered = false
				offset = Vector2(-Grid.TILE_SIZE/2, -Grid.TILE_SIZE/2)
	else:
		region_enabled = false
