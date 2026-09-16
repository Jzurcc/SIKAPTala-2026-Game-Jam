class_name PropExpiring
extends "res://scripts/core/tag_property_rule.gd"

## EXPIRING (Placeholder)
## Decrements a turn counter each step, dissolving the tag when depleted.

@export var turns_remaining: int = 3

func on_turn_tick(_tag: RefCounted, _host_body: Node2D) -> void:
	# Placeholder turn decay logic
	pass
