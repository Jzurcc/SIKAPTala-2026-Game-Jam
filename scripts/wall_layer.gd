extends TileMapLayer

@export var initial_tags: Array[Grid.TagTypes] = [Grid.TagTypes.IMPASSABLE]
var tags: Array[String] = []

func _ready() -> void:
	for t in initial_tags:
		tags.append(Grid.TagTypes.keys()[t])

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
