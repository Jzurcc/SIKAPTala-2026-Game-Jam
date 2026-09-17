class_name TagYou
extends "res://scripts/core/tag_rule.gd"

## YOU designates the target body as a controllable player entity.
## In Baba Is You inspired mechanics, any body possessing the YOU tag
## is linked to player input and control orchestration.

func on_tag_added(target: Object) -> void:
	if target is Node2D:
		GameState.register_you_body(target as Node2D)


func on_tag_removed(target: Object) -> void:
	if target is Node2D:
		GameState.unregister_you_body(target as Node2D)
