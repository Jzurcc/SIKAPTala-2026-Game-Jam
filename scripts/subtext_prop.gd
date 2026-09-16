@tool
extends GridBody2D

# GridBody2D provides: grid_pos, grid_size, tags, push(), die(), _tween_to(), etc.
# This subclass adds: tileset visual configuration and GameState registration.

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
		grid_size = val  # Keep grid_size in sync with visual size
		_update_visuals()


func _on_ready() -> void:
	_update_visuals()

	if Engine.is_editor_hint():
		return

	z_index = 100
	grid_size = atlas_size  # Ensure multi-tile occupancy matches visual

	# Snap to grid
	grid_pos = Grid.world_to_grid(global_position)
	global_position = Grid.grid_to_world(grid_pos)
	centered = false

	# _occupy_cells() is called by GridBody2D._ready() before _on_ready(),
	# but grid_size was ONE at that point. Re-occupy with the correct size now.
	_vacate_cells()  # Remove the single-cell occupation
	_occupy_cells()  # Re-occupy all cells with correct atlas_size

	GameState.register_object(self)


func _on_die() -> void:
	GameState.unregister_object(self)
	Grid.refresh_all_tags()


func _update_visuals() -> void:
	if not is_inside_tree():
		return

	if source_tileset:
		var source := source_tileset.get_source(0) as TileSetAtlasSource
		if source:
			region_enabled = true
			texture = source.texture
			var rect := source.get_tile_texture_region(atlas_coords)
			rect.size.x *= atlas_size.x
			rect.size.y *= atlas_size.y
			region_rect = rect

			if not Engine.is_editor_hint():
				centered = false
				offset = Vector2(-Grid.TILE_SIZE / 2, -Grid.TILE_SIZE / 2)
	else:
		region_enabled = false
