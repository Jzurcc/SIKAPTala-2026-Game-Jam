class_name TagChasing
extends "res://scripts/core/tag_rule.gd"

## CHASING causes any GridBody2D to pursue the player on turn ticks.

func on_turn_tick(body: Node2D) -> void:
	if not (body is GridBody2D):
		return
	var grid_body: GridBody2D = body as GridBody2D
	if not grid_body.is_alive:
		return
	if "SLEEPING" in grid_body.tags:
		return

	if GameState.player_ref == null:
		return

	# 50% chance to pause/idle per turn (matches legacy behavior)
	if randf() > 0.5:
		if grid_body.has_method("play_anim"):
			grid_body.play_anim("Idle")
		return

	var player_pos: Vector2i = GameState.player_ref.grid_pos
	var diff: Vector2i = player_pos - grid_body.grid_pos
	var dir: Vector2i = Vector2i.ZERO

	if absi(diff.x) >= absi(diff.y):
		dir = Vector2i(signi(diff.x), 0)
	else:
		dir = Vector2i(0, signi(diff.y))

	if dir != Vector2i.ZERO:
		grid_body.step(dir)
