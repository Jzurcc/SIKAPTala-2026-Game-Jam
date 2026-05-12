extends TileMapLayer

enum TagTypes {
	SOLID, LOCKED, PASSABLE, PUSHABLE, FRAGILE, HEAVY, LIGHT
}

@export var initial_tags: Array[TagTypes] = [TagTypes.PASSABLE]

## Script for floor layers that registers all tiles with dynamic tags.
func _ready() -> void:
	var string_tags = []
	for t in initial_tags:
		string_tags.append(TagTypes.keys()[t])
		
	var cells = get_used_cells()
	for pos in cells:
		for tag in string_tags:
			Grid.add_layer_tag(pos, name, tag)
