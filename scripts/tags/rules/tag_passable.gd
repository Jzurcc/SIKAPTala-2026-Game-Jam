class_name TagPassable
extends "res://scripts/core/tag_rule.gd"

## PASSABLE allows any actor to enter the cell or pass through the occupant.

func can_enter(_actor: Node2D, _target_pos: Vector2i, _tags: Array[String]) -> bool:
	return true
