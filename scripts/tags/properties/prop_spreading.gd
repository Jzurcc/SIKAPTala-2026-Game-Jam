class_name PropSpreading
extends "res://scripts/core/tag_property_rule.gd"

## SPREADING replicates the parent tag onto any object the host makes contact with.

func on_host_contact(tag: RefCounted, host: Node2D, other: Node2D) -> void:
	if other != null and other.has_method("add_subtext_tag"):
		var tag_name: String = tag.get("name") if tag.get("name") != null else ""
		if not tag_name.is_empty():
			other.add_subtext_tag(tag.duplicate())
