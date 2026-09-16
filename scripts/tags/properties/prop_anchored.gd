class_name PropAnchored
extends "res://scripts/core/tag_property_rule.gd"

## ANCHORED requires the player to be physically adjacent to the host object to drag this tag.

func can_drag(_tag: RefCounted, context: Dictionary) -> bool:
	var host_pos: Vector2i = context.get("host_pos", Vector2i.ZERO)
	var player_pos: Vector2i = context.get("player_pos", Vector2i.ZERO)
	var diff: Vector2i = (host_pos - player_pos).abs()
	return (diff.x + diff.y) <= 1
