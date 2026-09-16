class_name TagHidden
extends "res://scripts/core/tag_rule.gd"

## HIDDEN modulates the visual alpha/visibility of the target when not in substrate view.

func on_tag_added(target: Object) -> void:
	if target is CanvasItem:
		(target as CanvasItem).visible = GameState.is_substrate_active() if GameState.has_method("is_substrate_active") else true

func on_tag_removed(target: Object) -> void:
	if target is CanvasItem:
		(target as CanvasItem).visible = true
