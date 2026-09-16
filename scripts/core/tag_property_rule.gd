class_name TagPropertyRule
extends RefCounted

## Base strategy class for all Tag Property modifiers in the SUBTEXT engine.
## Modifiers alter how individual tags behave during dragging, rendering, turn ticks, and collisions.

## Hook 1: Can the player start dragging this tag? (e.g. LOCKED, ANCHORED)
func can_drag(_tag: RefCounted, _context: Dictionary) -> bool:
	return true


## Hook 2: Can this tag be rendered on the Subtext overlay? (e.g. HIDDEN)
func can_render(_tag: RefCounted, _context: Dictionary) -> bool:
	return true


## Hook 3: Processed during turn execution for active tags
func on_turn_tick(_tag: RefCounted, _host_body: Node2D) -> void:
	pass


## Hook 4: Triggered on physical collision / push with another body (e.g. SPREADING, BRITTLE)
func on_host_contact(_tag: RefCounted, _host: Node2D, _other: Node2D) -> void:
	pass


## Hook 5: Triggered when this tag is removed or destroyed
func on_tag_removed(_tag: RefCounted, _host: Node2D) -> void:
	pass
