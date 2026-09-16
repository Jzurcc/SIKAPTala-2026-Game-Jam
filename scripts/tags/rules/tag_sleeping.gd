class_name TagSleeping
extends "res://scripts/core/tag_rule.gd"

## SLEEPING suppresses autonomous movement on turn tick.

func on_turn_tick(body: Node2D) -> void:
	if body.has_method("play_anim"):
		body.play_anim("Idle")
