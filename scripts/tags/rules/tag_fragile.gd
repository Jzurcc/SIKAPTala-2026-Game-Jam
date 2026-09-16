class_name TagFragile
extends "res://scripts/core/tag_rule.gd"

## FRAGILE causes the target object to break/die when pushed or collided with.

func on_pushed(_pusher: Node2D, target: Node2D, _dir: Vector2i) -> bool:
	if target != null and target.has_method("die"):
		target.die()
		return true
	return false
