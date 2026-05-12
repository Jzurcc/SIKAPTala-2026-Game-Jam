extends TileMapLayer

func _ready() -> void:
	GameState.register_tilemap(self)
