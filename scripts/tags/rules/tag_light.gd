class_name TagLight
extends "res://scripts/core/tag_rule.gd"

## LIGHT allows a GridBody2D to be pushed by other actors.

func can_push(_pusher: Node2D, _target: Node2D, _dir: Vector2i) -> bool:
	return true
