class_name PropLocked
extends "res://scripts/core/tag_property_rule.gd"

## LOCKED prevents the tag from being dragged or detached from its host.

func can_drag(_tag: RefCounted, _context: Dictionary) -> bool:
	return false
