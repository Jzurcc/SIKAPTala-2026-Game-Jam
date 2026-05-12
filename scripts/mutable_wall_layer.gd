extends TileMapLayer

func _ready() -> void:
	# Registers this layer as solid collision walls
	GameState.register_tilemap(self)
