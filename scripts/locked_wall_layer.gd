extends TileMapLayer

var tags: Array[String] = ["IMPASSABLE", "LOCKED"]

func _ready() -> void:
	print("[LockedWalls] _ready() starting on node: ", name)
	var cells = get_used_cells()
	for pos in cells:
		for tag in tags:
			Grid.add_layer_tag(pos, name, tag)

func update_tags(new_tags: Array[String]) -> void:
	var cells = get_used_cells()
	for pos in cells:
		Grid.clear_layer_tags(pos, name)
	tags = new_tags
	for pos in cells:
		for tag in tags:
			Grid.add_layer_tag(pos, name, tag)
	Grid.refresh_all_tags()
