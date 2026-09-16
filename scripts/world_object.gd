extends GridBody2D

# GridBody2D provides: grid_pos, grid_size, tags, id, custom_dialogues,
# _occupy_cells(), _vacate_cells(), push(), die(), update_tags(), _tween_to()


func _on_ready() -> void:
	GameState.register_object(self)


func _on_die() -> void:
	GameState.unregister_object(self)
	Grid.refresh_all_tags()


func _process(_delta: float) -> void:
	if "HIDDEN" in tags:
		modulate.a = 0.3 if GameState.is_substrate else 0.0
	else:
		modulate.a = 1.0
