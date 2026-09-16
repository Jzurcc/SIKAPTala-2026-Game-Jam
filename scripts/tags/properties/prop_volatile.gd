class_name PropVolatile
extends "res://scripts/core/tag_property_rule.gd"

## VOLATILE (Placeholder)
## Snaps the tag back to its origin host/position after a configured number of turns.

@export var turns_remaining: int = 3

func on_turn_tick(_tag: RefCounted, _host_body: Node2D) -> void:
	# Placeholder turn counter logic
	pass
