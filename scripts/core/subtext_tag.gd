class_name SubtextTag
extends Resource

## Represents an active tag and its attached property modifiers in the SUBTEXT engine.

@export var name: String = ""
@export var properties: Array[String] = []


static func create(tag_name: String, props: Array[String] = []) -> Resource:
	var t: Resource = load("res://scripts/core/subtext_tag.gd").new()
	t.set("name", tag_name)
	t.set("properties", props)
	return t


func has_property(prop_name: String) -> bool:
	return prop_name in properties


func add_property(prop_name: String) -> void:
	if not prop_name in properties:
		properties.append(prop_name)


func remove_property(prop_name: String) -> void:
	properties.erase(prop_name)
