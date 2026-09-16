class_name TagRule
extends RefCounted

## Base class for all tag behavior rules in the SUBTEXT engine.
## Subclasses implement specific hooks to define how a tag affects movement,
## collision, turn ticks, pushing, and visual state.

## Hook 1: Can an actor step into this cell or occupant?
## Return false to veto movement.
func can_enter(_actor: Node2D, _target_pos: Vector2i, _tags: Array[String]) -> bool:
	return true


## Hook 2: Triggered when an actor successfully enters a cell or collides with an occupant.
func on_enter(_actor: Node2D, _target_pos: Vector2i, _occupant: Node2D) -> void:
	pass


## Hook 3: Can this target body be pushed in the given direction?
## Return true if pushing is allowed by this tag.
func can_push(_pusher: Node2D, _target: Node2D, _dir: Vector2i) -> bool:
	return false


## Hook 4: Triggered when this target body is pushed.
## Return true to indicate the push action was handled/consumed (e.g., shattered if fragile).
func on_pushed(_pusher: Node2D, _target: Node2D, _dir: Vector2i) -> bool:
	return false


## Hook 5: Processed during GameState turn ticks for autonomous entities / active props.
func on_turn_tick(_body: Node2D) -> void:
	pass


## Hook 6: Triggered when this tag is added to an object or tile.
func on_tag_added(_target: Object) -> void:
	pass


## Hook 7: Triggered when this tag is removed from an object or tile.
func on_tag_removed(_target: Object) -> void:
	pass
