extends TileMapLayer

## Basic wall layer script that registers collision and adds the [SOLID] tag to all tiles.
func _ready() -> void:
	GameState.register_tilemap(self)
	
	var cells = get_used_cells()
	for pos in cells:
		Grid.add_wall_tag(pos, "SOLID")
