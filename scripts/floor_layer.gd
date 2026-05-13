extends TileMapLayer

@export var initial_tags: Array[Grid.TagTypes] = [Grid.TagTypes.PASSABLE]
@export var id: String = ""
@export var custom_dialogues: Array[String] = []
var tags: Array[String] = []

func _ready() -> void:
	var keys = Grid.TagTypes.keys()
	for t in initial_tags:
		if t >= 0 and t < keys.size():
			tags.append(keys[t])

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
