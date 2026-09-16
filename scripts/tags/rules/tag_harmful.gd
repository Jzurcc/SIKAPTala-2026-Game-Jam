class_name TagHarmful
extends "res://scripts/core/tag_rule.gd"

## HARMFUL destroys or damages any actor that steps onto the cell or collides with the occupant.

func on_enter(actor: Node2D, _target_pos: Vector2i, _occupant: Node2D) -> void:
	if actor != null and actor.has_method("die"):
		actor.die()
