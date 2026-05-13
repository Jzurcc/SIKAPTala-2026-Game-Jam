@tool
extends Node2D
class_name SubtextRegion

const TILE_SIZE = 16

@export var tag_rect: Rect2i = Rect2i(0, 0, 1, 1):
	set(value):
		tag_rect = Rect2i(value.position.x, value.position.y, max(1, value.size.x), max(1, value.size.y))
		queue_redraw()

@export var highlight_rect: Rect2i = Rect2i(0, 0, 1, 1):
	set(value):
		highlight_rect = Rect2i(value.position.x, value.position.y, max(1, value.size.x), max(1, value.size.y))
		queue_redraw()

@export var target_layer_name: String = ""
@export var tags_enum: Array[Grid.TagTypes] = []
@export var id: String = ""
@export var custom_dialogues: Array[String] = []
var tags: Array[String] = []
var _highlight_sprites: Array[Sprite2D] = []
var _sprites_initialized: bool = false

func get_effective_layer_name() -> String:
	if target_layer_name != "":
		return target_layer_name
	var p = get_parent()
	if p is TileMapLayer:
		return p.name
	return "SubtextRegion"

func _ready() -> void:
	var keys = Grid.TagTypes.keys()
	for t in tags_enum:
		if t >= 0 and t < keys.size():
			tags.append(keys[t])

	_snap_to_grid()

	if Engine.is_editor_hint():
		return

	Grid.register_region(self)

	var rect = get_grid_rect()
	var layer_to_inject = get_effective_layer_name()
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var pos = rect.position + Vector2i(x, y)
			for tag in tags:
				Grid.add_layer_tag(pos, layer_to_inject, tag)

func update_tags(new_tags: Array[String]) -> void:
	var rect = get_grid_rect()
	var layer = get_effective_layer_name()
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var pos = rect.position + Vector2i(x, y)
			Grid.clear_layer_tags(pos, layer)

	tags = new_tags

	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var pos = rect.position + Vector2i(x, y)
			for tag in tags:
				Grid.add_layer_tag(pos, layer, tag)

	Grid.refresh_all_tags()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_snap_to_grid()

func _snap_to_grid() -> void:
	var gx = floori(position.x / TILE_SIZE)
	var gy = floori(position.y / TILE_SIZE)
	position = Vector2(gx * TILE_SIZE, gy * TILE_SIZE)
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		var ts = float(TILE_SIZE)
		var t_rect = Rect2(Vector2(tag_rect.position) * ts, Vector2(tag_rect.size) * ts)
		draw_rect(t_rect, Color(1.0, 0.2, 0.2, 0.3), true)
		draw_rect(t_rect, Color(1.0, 0.2, 0.2, 0.8), false, 1.0)

		var h_rect = Rect2(Vector2(highlight_rect.position) * ts, Vector2(highlight_rect.size) * ts)
		draw_rect(h_rect, Color(0.2, 1.0, 0.2, 0.15), true)
		draw_rect(h_rect, Color(0.2, 1.0, 0.2, 0.8), false, 1.0)

func get_center_world_pos() -> Vector2:
	var gx = floori(position.x / TILE_SIZE)
	var gy = floori(position.y / TILE_SIZE)
	var center_grid = Vector2(gx, gy) + Vector2(highlight_rect.position) + Vector2(highlight_rect.size) / 2.0
	return Vector2(center_grid.x * TILE_SIZE, center_grid.y * TILE_SIZE)

func get_grid_rect() -> Rect2i:
	var gx = floori(position.x / TILE_SIZE)
	var gy = floori(position.y / TILE_SIZE)
	return Rect2i(Vector2i(gx, gy) + tag_rect.position, tag_rect.size)

func set_highlighted(active: bool) -> void:
	if active and not _sprites_initialized:
		_setup_highlight_sprites()

	for sprite in _highlight_sprites:
		sprite.visible = active

func _setup_highlight_sprites() -> void:
	if _sprites_initialized: return

	for s in _highlight_sprites:
		if is_instance_valid(s): s.queue_free()
	_highlight_sprites.clear()

	var gx = floori(position.x / TILE_SIZE)
	var gy = floori(position.y / TILE_SIZE)
	var base_grid_pos = Vector2i(gx, gy)

	var target_layer: TileMapLayer = null
	var effective_layer_name = get_effective_layer_name()

	if effective_layer_name != "":
		for layer in GameState.solid_tilemaps:
			if layer.name == effective_layer_name:
				target_layer = layer
				break

	if target_layer == null:
		for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
			var layer = GameState.solid_tilemaps[i]
			var found = false
			for x in range(highlight_rect.size.x):
				for y in range(highlight_rect.size.y):
					var pos = base_grid_pos + highlight_rect.position + Vector2i(x, y)
					if layer.get_cell_source_id(pos) != -1:
						target_layer = layer
						found = true
						break
				if found: break
			if found: break

	if target_layer == null:
		_sprites_initialized = true
		return

	for x in range(highlight_rect.size.x):
		for y in range(highlight_rect.size.y):
			var pos = base_grid_pos + highlight_rect.position + Vector2i(x, y)
			var source_id = target_layer.get_cell_source_id(pos)
			if source_id != -1:
				var atlas_coords = target_layer.get_cell_atlas_coords(pos)
				var source = target_layer.tile_set.get_source(source_id) as TileSetAtlasSource
				if source:
					var sprite = Sprite2D.new()
					sprite.texture = source.texture
					sprite.region_enabled = true
					sprite.region_rect = source.get_tile_texture_region(atlas_coords)
					sprite.centered = true

					var tile_data = source.get_tile_data(atlas_coords, 0)
					var tex_offset = Vector2(tile_data.texture_origin) if tile_data else Vector2.ZERO

					var local_pos_x = (highlight_rect.position.x + x) * TILE_SIZE + TILE_SIZE * 0.5
					var local_pos_y = (highlight_rect.position.y + y) * TILE_SIZE + TILE_SIZE * 0.5
					sprite.position = Vector2(local_pos_x, local_pos_y) - tex_offset

					sprite.z_index = target_layer.z_index + 1

					sprite.modulate = Color(0.5, 0.8, 1.5, 0.6)
					sprite.visible = false
					add_child(sprite)
					_highlight_sprites.append(sprite)

	_sprites_initialized = true

func is_pixel_opaque(world_pos: Vector2) -> bool:
	if not _sprites_initialized:
		_setup_highlight_sprites()

	for sprite in _highlight_sprites:
		var local_pos = sprite.to_local(world_pos)
		var rect = sprite.region_rect
		var half_size = rect.size / 2.0

		if local_pos.x >= -half_size.x and local_pos.x < half_size.x and \
		   local_pos.y >= -half_size.y and local_pos.y < half_size.y:

			var img = Grid.get_texture_image(sprite.texture)
			var pixel_x = int(rect.position.x + local_pos.x + half_size.x)
			var pixel_y = int(rect.position.y + local_pos.y + half_size.y)

			if pixel_x >= 0 and pixel_y >= 0 and pixel_x < img.get_width() and pixel_y < img.get_height():
				if img.get_pixel(pixel_x, pixel_y).a > 0.5:
					return true
	return false

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		if Grid.has_method("unregister_region"):
			Grid.unregister_region(self)
