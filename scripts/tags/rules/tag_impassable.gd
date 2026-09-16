class_name TagImpassable
extends "res://scripts/core/tag_rule.gd"

## IMPASSABLE blocks movement into the cell or occupant.

func can_enter(_actor: Node2D, _target_pos: Vector2i, _tags: Array[String]) -> bool:
	return false
