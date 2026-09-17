class_name SpriteHitDetector
extends RefCounted

## Utility service for pixel-perfect sprite hit testing, dynamic bounds calculation,
## and multi-layer candidate resolution across GridBody2D, SubtextRegion, and TileMapLayers.

static var _texture_image_cache: Dictionary = {}


static func get_cached_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var rid: RID = texture.get_rid()
	if not _texture_image_cache.has(rid):
		var img: Image = texture.get_image()
		if img != null:
			_texture_image_cache[rid] = img
	return _texture_image_cache.get(rid, null)


static func clear_cache() -> void:
	_texture_image_cache.clear()


## Tests whether a world-space coordinate lands on an opaque pixel of the given node
static func is_node_pixel_opaque(node: Node2D, world_pos: Vector2) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree():
		return false

	if node is TileMapLayer:
		var g_pos: Vector2i = node.local_to_map(node.to_local(world_pos))
		return is_tile_pixel_opaque(node, g_pos, world_pos)

	if node is SubtextRegion:
		var g_pos: Vector2i = Grid.world_to_grid(world_pos)
		if not node.get_grid_rect().has_point(g_pos):
			return false
		var eff_name: String = node.get_effective_layer_name()
		var target_layer: TileMapLayer = null
		for layer: TileMapLayer in GameState.solid_tilemaps:
			if is_instance_valid(layer) and layer.name == eff_name:
				target_layer = layer
				break
		if target_layer != null:
			return is_tile_pixel_opaque(target_layer, g_pos, world_pos)
		return true

	# Check for Sprite2D children or node itself
	var sprites: Array[Sprite2D] = []
	if node is Sprite2D:
		sprites.append(node)
	for child in node.get_children():
		if child is Sprite2D and child.visible and is_instance_valid(child):
			sprites.append(child)

	for spr in sprites:
		if _check_sprite2d_pixel(spr, world_pos):
			return true

	# Check for AnimatedSprite2D children or node itself
	var anim_sprites: Array[AnimatedSprite2D] = []
	if node is AnimatedSprite2D:
		anim_sprites.append(node)
	for child in node.get_children():
		if child is AnimatedSprite2D and child.visible and is_instance_valid(child):
			anim_sprites.append(child)

	for anim in anim_sprites:
		if _check_animated_sprite_pixel(anim, world_pos):
			return true

	# Fallback if no sprite components are found: use node's bounding rect
	if sprites.is_empty() and anim_sprites.is_empty():
		if node.has_method("get_bounding_rect"):
			var b: Rect2 = node.get_bounding_rect()
			return b.has_point(world_pos)
		var g_pos: Vector2i = Grid.world_to_grid(world_pos)
		var node_g_pos: Vector2i = node.get("grid_pos") if node.get("grid_pos") != null else Grid.world_to_grid(node.global_position)
		return g_pos == node_g_pos

	return false


static func _check_sprite2d_pixel(spr: Sprite2D, world_pos: Vector2) -> bool:
	if not is_instance_valid(spr) or not spr.visible or spr.texture == null:
		return false

	var img: Image = get_cached_image(spr.texture)
	if img == null:
		return false

	var local_pos: Vector2 = spr.to_local(world_pos)

	if spr.region_enabled:
		var reg: Rect2 = spr.region_rect
		var origin: Vector2 = -reg.size * 0.5 if spr.centered else Vector2.ZERO
		var px: float = local_pos.x - (origin.x + spr.offset.x)
		var py: float = local_pos.y - (origin.y + spr.offset.y)

		if spr.flip_h:
			px = reg.size.x - 1.0 - px
		if spr.flip_v:
			py = reg.size.y - 1.0 - py

		if px >= 0 and px < reg.size.x and py >= 0 and py < reg.size.y:
			var atlas_x: int = int(reg.position.x + px)
			var atlas_y: int = int(reg.position.y + py)
			if atlas_x >= 0 and atlas_x < img.get_width() and atlas_y >= 0 and atlas_y < img.get_height():
				return img.get_pixel(atlas_x, atlas_y).a > 0.1
	else:
		var tex_size: Vector2 = spr.texture.get_size()
		var origin: Vector2 = -tex_size * 0.5 if spr.centered else Vector2.ZERO
		var px: float = local_pos.x - (origin.x + spr.offset.x)
		var py: float = local_pos.y - (origin.y + spr.offset.y)

		if spr.flip_h:
			px = tex_size.x - 1.0 - px
		if spr.flip_v:
			py = tex_size.y - 1.0 - py

		if px >= 0 and px < tex_size.x and py >= 0 and py < tex_size.y:
			var ix: int = int(px)
			var iy: int = int(py)
			if ix >= 0 and ix < img.get_width() and iy >= 0 and iy < img.get_height():
				return img.get_pixel(ix, iy).a > 0.1

	return false


static func _check_animated_sprite_pixel(anim: AnimatedSprite2D, world_pos: Vector2) -> bool:
	if not is_instance_valid(anim) or not anim.visible or anim.sprite_frames == null:
		return false

	var anim_name: StringName = anim.animation
	if not anim.sprite_frames.has_animation(anim_name):
		return false

	var frame_idx: int = anim.frame
	var frame_tex: Texture2D = anim.sprite_frames.get_frame_texture(anim_name, frame_idx)
	if frame_tex == null:
		return false

	var local_pos: Vector2 = anim.to_local(world_pos)

	if frame_tex is AtlasTexture:
		var atlas_tex: AtlasTexture = frame_tex as AtlasTexture
		var base_tex: Texture2D = atlas_tex.atlas
		if base_tex == null:
			return false
		var img: Image = get_cached_image(base_tex)
		if img == null:
			return false

		var reg: Rect2 = atlas_tex.region
		var origin: Vector2 = -reg.size * 0.5 if anim.centered else Vector2.ZERO
		var px: float = local_pos.x - (origin.x + anim.offset.x)
		var py: float = local_pos.y - (origin.y + anim.offset.y)

		if anim.flip_h:
			px = reg.size.x - 1.0 - px
		if anim.flip_v:
			py = reg.size.y - 1.0 - py

		if px >= 0 and px < reg.size.x and py >= 0 and py < reg.size.y:
			var atlas_x: int = int(reg.position.x + px)
			var atlas_y: int = int(reg.position.y + py)
			if atlas_x >= 0 and atlas_x < img.get_width() and atlas_y >= 0 and atlas_y < img.get_height():
				return img.get_pixel(atlas_x, atlas_y).a > 0.1
	else:
		var img: Image = get_cached_image(frame_tex)
		if img == null:
			return false
		var tex_size: Vector2 = frame_tex.get_size()
		var origin: Vector2 = -tex_size * 0.5 if anim.centered else Vector2.ZERO
		var px: float = local_pos.x - (origin.x + anim.offset.x)
		var py: float = local_pos.y - (origin.y + anim.offset.y)

		if anim.flip_h:
			px = tex_size.x - 1.0 - px
		if anim.flip_v:
			py = tex_size.y - 1.0 - py

		if px >= 0 and px < tex_size.x and py >= 0 and py < tex_size.y:
			var ix: int = int(px)
			var iy: int = int(py)
			if ix >= 0 and ix < img.get_width() and iy >= 0 and iy < img.get_height():
				return img.get_pixel(ix, iy).a > 0.1

	return false


## Tests whether a TileMapLayer has an opaque pixel at the given grid position and world coordinate
static func is_tile_pixel_opaque(layer: TileMapLayer, grid_pos: Vector2i, world_pos: Vector2) -> bool:
	if not is_instance_valid(layer) or not layer.is_inside_tree() or not layer.is_visible_in_tree():
		return false

	var source_id: int = layer.get_cell_source_id(grid_pos)
	if source_id == -1:
		return false

	var atlas_coords: Vector2i = layer.get_cell_atlas_coords(grid_pos)
	if not layer.tile_set:
		return false

	var source: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if not source or not source.texture:
		return false

	var img: Image = get_cached_image(source.texture)
	if img == null:
		return false

	var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
	var tex_region: Rect2i = source.get_tile_texture_region(atlas_coords)

	var cell_center: Vector2 = layer.to_global(layer.map_to_local(grid_pos))
	var cell_top_left: Vector2 = cell_center - Vector2(float(Grid.TILE_SIZE) * 0.5, float(Grid.TILE_SIZE) * 0.5)
	if tile_data:
		cell_top_left += Vector2(tile_data.texture_origin)

	var px: float = world_pos.x - cell_top_left.x
	var py: float = world_pos.y - cell_top_left.y

	if px >= 0 and px < tex_region.size.x and py >= 0 and py < tex_region.size.y:
		var atlas_x: int = tex_region.position.x + int(px)
		var atlas_y: int = tex_region.position.y + int(py)
		if atlas_x >= 0 and atlas_x < img.get_width() and atlas_y >= 0 and atlas_y < img.get_height():
			return img.get_pixel(atlas_x, atlas_y).a > 0.1

	return false


## Computes the visual bounding rectangle for lock-on and mouse hover detection
static func get_visual_bounding_rect(node: Node2D, target_pos: Vector2i = Vector2i(-1, -1)) -> Rect2:
	if not is_instance_valid(node):
		return Rect2()

	if node is SubtextRegion:
		var r_rect: Rect2i = node.get_grid_rect()
		return Rect2(Vector2(r_rect.position * Grid.TILE_SIZE), Vector2(r_rect.size * Grid.TILE_SIZE))

	if node is TileMapLayer:
		var g_pos: Vector2i = target_pos if target_pos != Vector2i(-1, -1) else Grid.world_to_grid(node.global_position)
		return Rect2(Vector2(g_pos * Grid.TILE_SIZE), Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE))

	if node.has_method("get_bounding_rect"):
		return node.get_bounding_rect()

	for child in node.get_children():
		if child is Sprite2D and child.visible and child.texture:
			var s: Vector2 = child.region_rect.size if child.region_enabled else child.texture.get_size()
			var origin: Vector2 = child.global_position - (s * 0.5 if child.centered else Vector2.ZERO)
			return Rect2(origin, s)
		elif child is AnimatedSprite2D and child.visible and child.sprite_frames:
			var frame_tex: Texture2D = child.sprite_frames.get_frame_texture(child.animation, child.frame)
			if frame_tex is AtlasTexture:
				var s: Vector2 = (frame_tex as AtlasTexture).region.size
				var origin: Vector2 = child.global_position - (s * 0.5 if child.centered else Vector2.ZERO)
				return Rect2(origin, s)

	return Rect2(node.global_position - Vector2(8, 8), Vector2(16, 16))


## Gathers all selectable tagged candidates at a world position in visual depth order
static func get_candidates_at_position(world_pos: Vector2) -> Array[Dictionary]:
	if GameState.solid_tilemaps.is_empty():
		GameState.refresh_tilemaps()

	var grid_pos: Vector2i = Grid.world_to_grid(world_pos)
	var candidates: Array[Dictionary] = []
	var visited_nodes: Dictionary = {}

	# 1. Occupant at this grid cell (e.g., SubtextProp, Entity, Player)
	var occ: Node2D = Grid.get_occupant(grid_pos)
	if is_instance_valid(occ) and not visited_nodes.has(occ):
		var occ_tags: Array = occ.tags.duplicate() if occ.get("tags") != null else []
		if TagRegistry.has_renderable_tags(occ_tags):
			if is_node_pixel_opaque(occ, world_pos):
				visited_nodes[occ] = true
				var target_pos: Vector2 = occ.get_display_top_world_pos() if occ.has_method("get_display_top_world_pos") else occ.global_position
				var name_str: String = occ.id if (occ.get("id") != null and occ.id != "") else occ.name
				candidates.append({
					"node": occ,
					"pos": occ.grid_pos if occ.get("grid_pos") != null else grid_pos,
					"tags": occ_tags,
					"target_world_pos": target_pos,
					"type": "occupant",
					"name": name_str
				})

	var visited_layer_names_at_pos: Dictionary = {}

	# 2. SubtextRegions covering this cell (e.g., Carpet)
	for region in Grid.regions:
		if is_instance_valid(region) and not visited_nodes.has(region):
			if region.get_grid_rect().has_point(grid_pos):
				if TagRegistry.has_renderable_tags(region.tags):
					if is_node_pixel_opaque(region, world_pos):
						visited_nodes[region] = true
						visited_layer_names_at_pos[region.get_effective_layer_name()] = true
						var target_pos: Vector2 = region.get_center_world_pos() if region.has_method("get_center_world_pos") else region.global_position
						var name_str: String = region.id if region.id != "" else region.name
						candidates.append({
							"node": region,
							"pos": grid_pos,
							"tags": region.tags.duplicate(),
							"target_world_pos": target_pos,
							"type": "region",
							"name": name_str
						})

	# 3. TileMapLayers (topmost down to bottommost)
	for i in range(GameState.solid_tilemaps.size() - 1, -1, -1):
		var layer: TileMapLayer = GameState.solid_tilemaps[i]
		if is_instance_valid(layer) and not visited_nodes.has(layer) and not visited_layer_names_at_pos.has(layer.name):
			if layer.get_cell_source_id(grid_pos) != -1:
				if is_tile_pixel_opaque(layer, grid_pos, world_pos):
					var l_tags: Array = Grid.get_cell_tags(grid_pos, layer.name)
					if not l_tags.is_empty() and TagRegistry.has_renderable_tags(l_tags):
						visited_nodes[layer] = true
						var c_pos: Vector2 = Grid.grid_to_world(grid_pos)
						var name_str: String = layer.id if (layer.get("id") != null and layer.id != "") else layer.name
						candidates.append({
							"node": layer,
							"pos": grid_pos,
							"tags": l_tags,
							"target_world_pos": c_pos,
							"type": "tile",
							"name": name_str
						})

	return candidates
