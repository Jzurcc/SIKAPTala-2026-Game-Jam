class_name PropHidden
extends "res://scripts/core/tag_property_rule.gd"

## HIDDEN prevents the tag from rendering on the Subtext overlay unless revealed.

func can_render(_tag: RefCounted, context: Dictionary = {}) -> bool:
	return context.get("is_revealed", false)


func can_drag(_tag: RefCounted, context: Dictionary = {}) -> bool:
	return context.get("is_revealed", false)

