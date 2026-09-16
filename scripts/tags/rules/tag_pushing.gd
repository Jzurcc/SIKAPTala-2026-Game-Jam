class_name TagPushing
extends "res://scripts/core/tag_rule.gd"

## PUSHING pushes adjacent occupants or blocks actors that cannot be pushed.

func on_enter(_actor: Node2D, _target_pos: Vector2i, occupant: Node2D) -> void:
	if occupant != null and occupant.has_method("push"):
		var dir: Vector2i = Vector2i.ZERO
		if _actor != null:
			var f_dir = _actor.get("facing_dir")
			if f_dir is Vector2i:
				dir = f_dir
		if dir != Vector2i.ZERO:
			occupant.push(dir)
