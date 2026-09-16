class_name TagHeavy
extends "res://scripts/core/tag_rule.gd"

## HEAVY prevents a GridBody2D from being pushed.

func can_push(_pusher: Node2D, _target: Node2D, _dir: Vector2i) -> bool:
	return false
