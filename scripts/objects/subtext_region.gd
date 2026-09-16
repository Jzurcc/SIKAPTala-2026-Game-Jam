@tool
class_name SubtextRegion
extends Node2D

## Defines an authored spatial region that attaches tags to a tilemap layer or area.

const TILE_SIZE: int = 16

@export var tag_rect: Rect2i = Rect2i(0, 0, 1, 1):
	set(value):
		tag_rect = Rect2i(value.position.x, value.position.y, max(1, value.size.x), max(1, value.size.y))
		queue_redraw()

@export var highlight_rect: Rect2i = Rect2i(0, 0, 1, 1):
	set(value):
		highlight_rect = Rect2i(value.position.x, value.position.y, max(1, value.size.x), max(1, value.size.y))
		queue_redraw()

@export var target_layer_name: String = ""
@export var tags_enum: Array[TagDef.Tag] = []
@export var initial_subtext_tags: Array[SubtextTag] = []
@export var id: String = ""
@export var custom_dialogues: Array[String] = []
var tags: Array = []
var _highlight_sprites: Array[Sprite2D] = []
var _sprites_initialized: bool = false


func get_effective_layer_name() -> String:
	if target_layer_name != "":
		return target_layer_name
	var p: Node = get_parent()
	if p is TileMapLayer:
		return p.name
	return "SubtextRegion"


func _ready() -> void:
	if not initial_subtext_tags.is_empty():
		tags = initial_subtext_tags.duplicate()
	elif not tags_enum.is_empty():
		var keys: Array = TagDef.Tag.keys()
		for t in tags_enum:
			var t_idx: int = int(t)
			if t_idx >= 0 and t_idx < keys.size():
				tags.append(keys[t_idx])

	_snap_to_grid()

	if Engine.is_editor_hint():
		return

	Grid.register_region(self)

	var rect: Rect2i = get_grid_rect()
	var layer_to_inject: String = get_effective_layer_name()
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var pos: Vector2i = rect.position + Vector2i(x, y)
			for tag in tags:
				Grid.add_layer_tag(pos, layer_to_inject, tag)


func update_tags(new_tags: Array) -> void:
	var rect: Rect2i = get_grid_rect()
	var layer: String = get_effective_layer_name()
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var pos: Vector2i = rect.position + Vector2i(x, y)
			Grid.clear_layer_tags(pos, layer)

	tags = new_tags.duplicate()

	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var pos: Vector2i = rect.position + Vector2i(x, y)
			for tag in tags:
				Grid.add_layer_tag(pos, layer, tag)

	Grid.refresh_all_tags()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_snap_to_grid()


func _snap_to_grid() -> void:
	var gx: int = floori(position.x / TILE_SIZE)
	var gy: int = floori(position.y / TILE_SIZE)
	position = Vector2(gx * TILE_SIZE, gy * TILE_SIZE)
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		var ts: float = float(TILE_SIZE)
		var t_rect := Rect2(Vector2(tag_rect.position) * ts, Vector2(tag_rect.size) * ts)
		draw_rect(t_rect, Color(1.0, 0.2, 0.2, 0.3), true)
		draw_rect(t_rect, Color(1.0, 0.2, 0.2, 0.8), false, 1.0)

		var h_rect := Rect2(Vector2(highlight_rect.position) * ts, Vector2(highlight_rect.size) * ts)
		draw_rect(h_rect, Color(0.2, 1.0, 0.2, 0.15), true)
		draw_rect(h_rect, Color(0.2, 1.0, 0.2, 0.8), false, 1.0)


func get_center_world_pos() -> Vector2:
	var gx: int = floori(global_position.x / TILE_SIZE)
	var gy: int = floori(global_position.y / TILE_SIZE)
	var center_grid: Vector2 = Vector2(gx, gy) + Vector2(highlight_rect.position) + Vector2(highlight_rect.size) / 2.0
	return Vector2(center_grid.x * TILE_SIZE, center_grid.y * TILE_SIZE)


func get_grid_rect() -> Rect2i:
	var gx: int = floori(global_position.x / TILE_SIZE)
	var gy: int = floori(global_position.y / TILE_SIZE)
	return Rect2i(Vector2i(gx, gy) + tag_rect.position, tag_rect.size)


func set_highlighted(active: bool) -> void:
	if active and not _sprites_initialized:
		_setup_highlight_sprites()

	for sprite: Sprite2D in _highlight_sprites:
		if is_instance_valid(sprite):
			sprite.visible = active


func _setup_highlight_sprites() -> void:
	if _sprites_initialized:
		return

	for s: Sprite2D in _highlight_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_highlight_sprites.clear()

	var gx: int = floori(global_position.x / TILE_SIZE)
	var gy: int = floori(global_position.y / TILE_SIZE)
	var base_grid_pos := Vector2i(gx, gy)

	var target_layer: TileMapLayer = null
	var effective_layer_name: String = get_effective_layer_name()

	if effective_layer_name != "":
		for layer: TileMapLayer in GameState.solid_tilemaps:
			if layer.name == effective_layer_name:
				target_layer = layer
				break

	if target_layer == null:
		for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
			var layer: TileMapLayer = GameState.solid_tilemaps[i]
			var found: bool = false
			for x in range(highlight_rect.size.x):
				for y in range(highlight_rect.size.y):
					var pos: Vector2i = base_grid_pos + highlight_rect.position + Vector2i(x, y)
					if layer.get_cell_source_id(pos) != -1:
						target_layer = layer
						found = true
						break
				if found:
					break
			if found:
				break

	if target_layer == null:
		_sprites_initialized = true
		return

	for x in range(highlight_rect.size.x):
		for y in range(highlight_rect.size.y):
			var pos: Vector2i = base_grid_pos + highlight_rect.position + Vector2i(x, y)
			var source_id: int = target_layer.get_cell_source_id(pos)
			if source_id != -1:
				var atlas_coords: Vector2i = target_layer.get_cell_atlas_coords(pos)
				var source: TileSetAtlasSource = target_layer.tile_set.get_source(source_id) as TileSetAtlasSource
				if source:
					var sprite := Sprite2D.new()
					sprite.texture = source.texture
					sprite.region_enabled = true
					sprite.region_rect = source.get_tile_texture_region(atlas_coords)
					sprite.centered = true

					var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
					var tex_offset: Vector2 = Vector2(tile_data.texture_origin) if tile_data else Vector2.ZERO

					var local_pos_x: float = float((highlight_rect.position.x + x) * TILE_SIZE) + float(TILE_SIZE) * 0.5
					var local_pos_y: float = float((highlight_rect.position.y + y) * TILE_SIZE) + float(TILE_SIZE) * 0.5
					sprite.position = Vector2(local_pos_x, local_pos_y) - tex_offset

					sprite.z_index = target_layer.z_index + 1
					sprite.modulate = Color(0.5, 0.8, 1.5, 0.6)
					sprite.visible = false
					add_child(sprite)
					_highlight_sprites.append(sprite)

	_sprites_initialized = true


func is_pixel_opaque(world_pos: Vector2) -> bool:
	var g_pos: Vector2i = Grid.world_to_grid(world_pos)
	return get_grid_rect().has_point(g_pos)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		if Grid.has_method("unregister_region"):
			Grid.unregister_region(self)
