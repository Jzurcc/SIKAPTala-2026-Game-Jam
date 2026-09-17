class_name TagFleeing
extends "res://scripts/core/tag_rule.gd"

## FLEEING causes any GridBody2D to step away from the player.

func on_turn_tick(body: Node2D) -> void:
	if not (body is GridBody2D):
		return
	var grid_body: GridBody2D = body as GridBody2D
	if not grid_body.is_alive:
		return
	if "SLEEPING" in grid_body.tags:
		return

	var you_bodies: Array[Node2D] = GameState.get_you_bodies()
	if you_bodies.is_empty():
		return

	var closest: Node2D = you_bodies[0]
	var min_dist: float = (Vector2(closest.grid_pos) - Vector2(grid_body.grid_pos)).length_squared()
	for i in range(1, you_bodies.size()):
		var b: Node2D = you_bodies[i]
		if is_instance_valid(b) and "grid_pos" in b:
			var d: float = (Vector2(b.grid_pos) - Vector2(grid_body.grid_pos)).length_squared()
			if d < min_dist:
				min_dist = d
				closest = b

	var player_pos: Vector2i = closest.grid_pos

	var diff: Vector2i = player_pos - grid_body.grid_pos
	var dir: Vector2i = Vector2i.ZERO

	if absi(diff.x) >= absi(diff.y):
		dir = Vector2i(-signi(diff.x), 0)
	else:
		dir = Vector2i(0, -signi(diff.y))

	if dir != Vector2i.ZERO and not grid_body.step(dir):
		var perp_a: Vector2i = Vector2i(-dir.y, dir.x)
		var perp_b: Vector2i = Vector2i(dir.y, -dir.x)
		if not grid_body.step(perp_a):
			grid_body.step(perp_b)
