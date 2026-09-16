extends Node

## Converts a tilemap cell into a runtime GridBody2D (WorldObject) node.
## Extracted from Grid._legacy_try_convert_to_node(). This is the single
## canonical place for tile-atlas-to-sprite conversion logic.
##
## Registered as autoload "TileConverter" in project.godot.
## Phase 7: Also tracks dirty cells for undo restoration.

var _world_object_script = preload("res://scripts/objects/world_object.gd")

## Dirty cell tracker for undo support (Phase 7).
## Maps Vector2i -> {layer_name: String, source_id: int, atlas_coords: Vector2i}
var _dirty_cells: Dictionary = {}


## Checks if the tile at pos has LIGHT tag and hasn't been converted yet.
## If so, converts it to a WorldObject node in the scene. Called from Grid.refresh_all_tags().
func convert_to_prop_if_unoccupied(pos: Vector2i, scene_root: Node) -> void:
	if scene_root == null:
		return
	if Grid.is_occupied(pos):
		return

	for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
		var layer: TileMapLayer = GameState.solid_tilemaps[i]
		var source_id := layer.get_cell_source_id(pos)
		if source_id == -1:
			continue

		var atlas_coords := layer.get_cell_atlas_coords(pos)
		var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if not source:
			continue

		# Record for undo (Phase 7)
		_dirty_cells[pos] = {
			"layer_name": layer.name,
			"source_id": source_id,
			"atlas_coords": atlas_coords
		}

		var obj := Node2D.new()
		obj.set_script(_world_object_script)
		obj.z_index = 100
		obj.set_meta("converted_from_tile", {
			"layer_name": layer.name,
			"pos": pos,
			"source_id": source_id,
			"atlas_coords": atlas_coords
		})

		var sprite := Sprite2D.new()
		sprite.texture = source.texture
		sprite.region_enabled = true
		sprite.region_rect = source.get_tile_texture_region(atlas_coords)

		var size_in_atlas := source.get_tile_size_in_atlas(atlas_coords)
		obj.set("grid_size", size_in_atlas)

		var tile_data := source.get_tile_data(atlas_coords, 0)
		var tex_offset := Vector2(tile_data.texture_origin) if tile_data else Vector2.ZERO
		sprite.position = -tex_offset
		obj.add_child(sprite)

		obj.position = Grid.grid_to_world(pos)
		layer.add_sibling(obj)

		if obj.get("tags") != null:
			obj.tags.assign(Grid.wall_tags.get(pos, []))

		# Region capture: if a region was providing the LIGHT tag, reparent it
		for region in Grid.regions:
			if is_instance_valid(region) and region.get_grid_rect().has_point(pos):
				if region.id != "":
					obj.id = region.id
				if region.custom_dialogues.size() > 0:
					obj.custom_dialogues = region.custom_dialogues.duplicate()
				if "LIGHT" in region.tags:
					region.reparent(obj)
					region.position = Vector2.ZERO
					break

		layer.set_cell(pos, -1)
		return


## Builds a Sprite2D from a tilemap cell. Used by SubtextRegion and TagDisplayManager
## for highlight sprites — single canonical implementation of atlas-rect extraction.
static func build_sprite_from_tile(layer: TileMapLayer, pos: Vector2i, _image_cache: Dictionary = {}) -> Sprite2D:
	var source_id := layer.get_cell_source_id(pos)
	if source_id == -1:
		return null
	var atlas_coords := layer.get_cell_atlas_coords(pos)
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if not source:
		return null

	var sprite := Sprite2D.new()
	sprite.texture = source.texture
	sprite.region_enabled = true
	sprite.region_rect = source.get_tile_texture_region(atlas_coords)
	sprite.centered = true

	var tile_data := source.get_tile_data(atlas_coords, 0)
	sprite.position = Vector2(tile_data.texture_origin) if tile_data else Vector2.ZERO

	return sprite


## Clears dirty cell records. Called at the start of each new undo snapshot (Phase 7).
func flush_dirty_cells() -> Dictionary:
	var snapshot := _dirty_cells.duplicate()
	_dirty_cells.clear()
	return snapshot


## Restores a set of dirty cells back to their tilemap (used by undo in Phase 7).
func restore_dirty_cells(snapshot: Dictionary) -> void:
	for pos in snapshot:
		var data: Dictionary = snapshot[pos]
		for layer in GameState.solid_tilemaps:
			if layer.name == data["layer_name"]:
				layer.set_cell(pos, data["source_id"], data["atlas_coords"])
				break
