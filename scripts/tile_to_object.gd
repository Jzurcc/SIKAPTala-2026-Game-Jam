extends Node2D

## The size of the tile block to capture from the TileMap (in tiles).
@export var size: Vector2i = Vector2i(1, 1)
@export var id: String = ""
@export var custom_dialogues: Array[String] = []
@export var tags: Array[String] = []

var grid_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	grid_pos = Grid.world_to_grid(global_position)
	# Snap to exact grid center
	global_position = Grid.grid_to_world(grid_pos)
	
	_capture_tiles_from_map()
	
	# Register for interaction
	z_index = 100
	for x in range(size.x):
		for y in range(size.y):
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


func _capture_tiles_from_map() -> void:
	# Look for the tiles directly under us in the solid tilemaps
	# We take the data from the first layer that has a tile here
	var source_layer: TileMapLayer = null
	var atlas_coords: Vector2i
	
	for layer in GameState.solid_tilemaps:
		if layer.get_cell_source_id(grid_pos) != -1:
			source_layer = layer
			atlas_coords = layer.get_cell_atlas_coords(grid_pos)
			break
	
	if not source_layer:
		push_warning("[TileToObject] No tiles found at %s to capture!" % grid_pos)
		return

	var source = source_layer.tile_set.get_source(0) as TileSetAtlasSource
	if not source: return
	
	# Create the visual sprite from the captured atlas area
	var sprite = Sprite2D.new()
	sprite.texture = source.texture
	sprite.region_enabled = true
	
	var rect = source.get_tile_texture_region(atlas_coords)
	rect.size.x *= size.x
	rect.size.y *= size.y
	sprite.region_rect = rect
	
	# Align sprite top-left with the object's top-left tile
	sprite.centered = false
	sprite.offset = Vector2(-Grid.TILE_SIZE/2, -Grid.TILE_SIZE/2)
	add_child(sprite)
	
	# Remove the tiles from the original TileMap so they are "moved" into this object
	for x in range(size.x):
		for y in range(size.y):
			source_layer.set_cell(grid_pos + Vector2i(x, y), -1)
