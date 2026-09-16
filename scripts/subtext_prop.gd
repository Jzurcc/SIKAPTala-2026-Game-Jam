@tool
class_name SubtextProp
extends GridBody2D

# GridBody2D provides: grid_pos, grid_size, tags, push(), die(), _tween_to(), etc.
# This subclass adds: tileset visual configuration via an internal Sprite2D child.

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
		grid_size = val  # Keep grid_size in sync with visual footprint
		_update_visuals()

var _sprite: Sprite2D


func _get_or_create_sprite() -> Sprite2D:
	if _sprite != null and is_instance_valid(_sprite):
		return _sprite
	# Try to find an existing Sprite2D child (e.g., from a saved scene)
	for child in get_children():
		if child is Sprite2D:
			_sprite = child
			return _sprite
	# Create a fresh one
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	return _sprite


func _on_ready() -> void:
	_get_or_create_sprite()
	_update_visuals()

	if Engine.is_editor_hint():
		return

	z_index = 100
	grid_size = atlas_size  # Ensure multi-tile occupancy matches visual size

	# Snap to grid — GridBody2D._ready() already did this but grid_size was ONE.
	# Vacate the single-cell occupation and re-occupy with correct atlas_size.
	_vacate_cells()
	_occupy_cells()

	GameState.register_object(self)


func _on_die() -> void:
	GameState.unregister_object(self)
	Grid.refresh_all_tags()


func _update_visuals() -> void:
	var sprite := _get_or_create_sprite()

	if source_tileset:
		var source := source_tileset.get_source(0) as TileSetAtlasSource
		if source:
			sprite.texture = source.texture
			sprite.region_enabled = true
			var rect := source.get_tile_texture_region(atlas_coords)
			rect.size.x *= atlas_size.x
			rect.size.y *= atlas_size.y
			sprite.region_rect = rect
			sprite.centered = false
			if not Engine.is_editor_hint():
				sprite.position = Vector2(-Grid.TILE_SIZE / 2.0, -Grid.TILE_SIZE / 2.0)
	else:
		sprite.region_enabled = false
