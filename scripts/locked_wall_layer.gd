extends TileMapLayer

func _ready() -> void:
	print("[LockedWalls] _ready() starting on node: ", name)
	
	var cells = get_used_cells()
	print("[LockedWalls] get_used_cells() returned: ", cells.size())
	
	# Automatically adds tags to every tile on this specific layer
	for pos in cells:
		Grid.add_layer_tag(pos, name, "SOLID")
		Grid.add_layer_tag(pos, name, "LOCKED")
	
	print("[LockedWalls] Finished tagging. Grid.wall_tags count now: ", Grid.wall_tags.size())
