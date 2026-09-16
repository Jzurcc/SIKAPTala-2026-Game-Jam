@tool
class_name SubtextProp
extends GridBody2D

## Prop and furniture entity inheriting from GridBody2D.
## Displays a sliced texture region from the tileset atlas and manages multi-cell occupancy.

@export_group("Tileset Visuals")
@export var source_tileset: TileSet = preload("res://tileset.tres"):
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
		grid_size = val
		_update_visuals()

@export var is_overhead: bool = false

var _sprite: Sprite2D


func _get_or_create_sprite() -> Sprite2D:
	if _sprite != null and is_instance_valid(_sprite):
		return _sprite
	for child: Node in get_children():
		if child is Sprite2D:
			_sprite = child
			return _sprite
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.centered = false
	add_child(_sprite)
	return _sprite


func _ready() -> void:
	grid_size = atlas_size
	super._ready()


func _on_ready() -> void:
	_get_or_create_sprite()
	_update_visuals()

	if Engine.is_editor_hint():
		return

	if is_overhead:
		z_index = 50
	else:
		z_index = 1


func _on_die() -> void:
	GameState.unregister_object(self)
	Grid.refresh_all_tags()


func _update_visuals() -> void:
	var sprite: Sprite2D = _get_or_create_sprite()

	if source_tileset:
		var source: TileSetAtlasSource = source_tileset.get_source(0) as TileSetAtlasSource
		if source:
			sprite.texture = source.texture
			sprite.region_enabled = true
			var rect := Rect2(
				float(atlas_coords.x * Grid.TILE_SIZE),
				float(atlas_coords.y * Grid.TILE_SIZE),
				float(atlas_size.x * Grid.TILE_SIZE),
				float(atlas_size.y * Grid.TILE_SIZE)
			)
			sprite.region_rect = rect
			sprite.centered = false
			var y_offset: float = float(atlas_size.y - 1) * float(Grid.TILE_SIZE)
			sprite.position = Vector2(-float(Grid.TILE_SIZE) / 2.0, -float(Grid.TILE_SIZE) / 2.0 - y_offset)
	else:
		sprite.region_enabled = false

