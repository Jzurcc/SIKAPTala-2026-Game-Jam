extends TileMapLayer

func _ready() -> void:
	print("[LockedWalls] _ready() starting on node: ", name)
	# Registers this layer as solid collision walls
	GameState.register_tilemap(self)
	
	var cells = get_used_cells()
	print("[LockedWalls] get_used_cells() returned: ", cells.size())
	
	# Automatically adds tags to every tile on this specific layer
	for pos in cells:
		Grid.add_wall_tag(pos, "SOLID")
		Grid.add_wall_tag(pos, "LOCKED")
	
	print("[LockedWalls] Finished tagging. Grid.wall_tags count now: ", Grid.wall_tags.size())
