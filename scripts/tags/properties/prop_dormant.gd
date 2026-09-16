class_name PropDormant
extends "res://scripts/core/tag_property_rule.gd"

## DORMANT marks a tag as inactive until an in-world condition wakes it up.

func on_turn_tick(_tag: RefCounted, host_body: Node2D) -> void:
	# Awakening condition hook (e.g. proximity or switch)
	pass
