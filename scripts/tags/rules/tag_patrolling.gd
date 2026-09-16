class_name TagPatrolling
extends "res://scripts/core/tag_rule.gd"

## PATROLLING causes any GridBody2D to follow its patrol_path waypoints.

func on_turn_tick(body: Node2D) -> void:
	if not (body is GridBody2D):
		return
	var grid_body: GridBody2D = body as GridBody2D
	if not grid_body.is_alive:
		return
	if "SLEEPING" in grid_body.tags:
		return

	var path: Array = grid_body.get("patrol_path")
	if path == null or path.is_empty():
		return

	var idx: int = grid_body.get("patrol_index") if grid_body.get("patrol_index") != null else 0
	var next: Vector2i = path[idx]
	var diff: Vector2i = next - grid_body.grid_pos
	var dir: Vector2i = Vector2i.ZERO

	if diff.x != 0:
		dir = Vector2i(signi(diff.x), 0)
	elif diff.y != 0:
		dir = Vector2i(0, signi(diff.y))

	if dir != Vector2i.ZERO and grid_body.step(dir):
		if grid_body.grid_pos == next:
			grid_body.set("patrol_index", (idx + 1) % path.size())
