extends TileMapLayer
class_name TaggedTileLayer

## Single unified TileMapLayer script replacing wall_layer.gd, floor_layer.gd,
## and locked_wall_layer.gd. Set initial_tags in the inspector to configure behavior.

@export var initial_tags: Array[TagDef.Tag] = [TagDef.Tag.IMPASSABLE]
@export var initial_subtext_tags: Array[SubtextTag] = []
@export var id: String = ""
@export var custom_dialogues: Array[String] = []

## Runtime tags (Strings or SubtextTag resources)
var tags: Array = []


func _ready() -> void:
	if not initial_subtext_tags.is_empty():
		tags = initial_subtext_tags.duplicate()
	else:
		tags = TagDef.to_string_array(initial_tags)
	var cells = get_used_cells()
	for pos in cells:
		for tag in tags:
			Grid.add_layer_tag(pos, name, tag)
	add_to_group("tagged_tile_layer")


func update_tags(new_tags: Array) -> void:
	var cells = get_used_cells()
	for pos in cells:
		Grid.clear_layer_tags(pos, name)
	tags = new_tags.duplicate()
	for pos in cells:
		for tag in tags:
			Grid.add_layer_tag(pos, name, tag)
	Grid.refresh_all_tags()
