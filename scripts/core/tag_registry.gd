extends Node

## Central registry and dispatch matrix for all TagRule behaviors.
## Decouples movement physics, collision, turn ticks, and object state from hardcoded logic.

const TagRule = preload("res://scripts/core/tag_rule.gd")
const TagPassable = preload("res://scripts/tags/rules/tag_passable.gd")
const TagImpassable = preload("res://scripts/tags/rules/tag_impassable.gd")
const TagLight = preload("res://scripts/tags/rules/tag_light.gd")
const TagHeavy = preload("res://scripts/tags/rules/tag_heavy.gd")
const TagHarmful = preload("res://scripts/tags/rules/tag_harmful.gd")
const TagFragile = preload("res://scripts/tags/rules/tag_fragile.gd")
const TagPushing = preload("res://scripts/tags/rules/tag_pushing.gd")
const TagChasing = preload("res://scripts/tags/rules/tag_chasing.gd")
const TagPatrolling = preload("res://scripts/tags/rules/tag_patrolling.gd")
const TagFleeing = preload("res://scripts/tags/rules/tag_fleeing.gd")
const TagSleeping = preload("res://scripts/tags/rules/tag_sleeping.gd")
const TagHidden = preload("res://scripts/tags/rules/tag_hidden.gd")

# Property Rules
const PropLocked = preload("res://scripts/tags/properties/prop_locked.gd")
const PropHidden = preload("res://scripts/tags/properties/prop_hidden.gd")
const PropAnchored = preload("res://scripts/tags/properties/prop_anchored.gd")
const PropDormant = preload("res://scripts/tags/properties/prop_dormant.gd")
const PropSpreading = preload("res://scripts/tags/properties/prop_spreading.gd")
const PropBrittle = preload("res://scripts/tags/properties/prop_brittle.gd")
const PropVolatile = preload("res://scripts/tags/properties/prop_volatile.gd")
const PropExpiring = preload("res://scripts/tags/properties/prop_expiring.gd")

static var _rules: Dictionary = {}
static var _property_rules: Dictionary = {}
static var _initialized: bool = false


func _ready() -> void:
	_ensure_initialized()


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_default_rules()
	_register_default_property_rules()


static func _register_default_rules() -> void:
	register_rule("PASSABLE", TagPassable.new())
	register_rule("IMPASSABLE", TagImpassable.new())
	register_rule("LIGHT", TagLight.new())
	register_rule("HEAVY", TagHeavy.new())
	register_rule("HARMFUL", TagHarmful.new())
	register_rule("FRAGILE", TagFragile.new())
	register_rule("PUSHING", TagPushing.new())
	register_rule("CHASING", TagChasing.new())
	register_rule("PATROLLING", TagPatrolling.new())
	register_rule("FLEEING", TagFleeing.new())
	register_rule("SLEEPING", TagSleeping.new())
	register_rule("HIDDEN", TagHidden.new())


static func _register_default_property_rules() -> void:
	register_property_rule("LOCKED", PropLocked.new())
	register_property_rule("HIDDEN", PropHidden.new())
	register_property_rule("ANCHORED", PropAnchored.new())
	register_property_rule("DORMANT", PropDormant.new())
	register_property_rule("SPREADING", PropSpreading.new())
	register_property_rule("BRITTLE", PropBrittle.new())
	register_property_rule("VOLATILE", PropVolatile.new())
	register_property_rule("EXPIRING", PropExpiring.new())


static func register_rule(tag_name: String, rule: RefCounted) -> void:
	_rules[tag_name] = rule


static func get_rule(tag_name: String) -> RefCounted:
	_ensure_initialized()
	return _rules.get(tag_name, null)


static func register_property_rule(prop_name: String, rule: RefCounted) -> void:
	_property_rules[prop_name] = rule


static func get_property_rule(prop_name: String) -> RefCounted:
	_ensure_initialized()
	return _property_rules.get(prop_name, null)


## --- Rule Dispatch Methods ---

## Evaluates whether an actor can step into a cell/occupant with the given tags.
static func can_enter(actor: Node2D, target_pos: Vector2i, tags: Array[String]) -> bool:
	_ensure_initialized()
	if "IMPASSABLE" in tags or "SOLID" in tags:
		return false
	if "PASSABLE" in tags:
		return true
	for tag: String in tags:
		var rule: TagRule = _rules.get(tag, null)
		if rule != null and not rule.can_enter(actor, target_pos, tags):
			return false
	return true


## Triggers enter effects (e.g. HARMFUL damage/death, SINKING, SLIPPERY)
static func on_enter(actor: Node2D, target_pos: Vector2i, occupant: Node2D, tags: Array[String]) -> void:
	_ensure_initialized()
	for tag: String in tags:
		var rule: TagRule = _rules.get(tag, null)
		if rule != null:
			rule.on_enter(actor, target_pos, occupant)


static func extract_tag_names(tags_variant: Variant) -> Array[String]:
	var res: Array[String] = []
	if tags_variant == null:
		return res
	var tags: Array = tags_variant as Array
	for t in tags:
		if t is RefCounted and t.get("name") != null:
			res.append(str(t.name))
		else:
			res.append(str(t))
	return res


## Checks whether an object can be pushed
static func can_push(pusher: Node2D, target: Node2D, dir: Vector2i) -> bool:
	_ensure_initialized()
	var tags_variant = target.get("tags")
	if tags_variant == null:
		return false
	var tags: Array[String] = extract_tag_names(tags_variant)
	if "HEAVY" in tags:
		return false
	if "LIGHT" in tags:
		return true
	for tag: String in tags:
		var rule: TagRule = _rules.get(tag, null)
		if rule != null and rule.can_push(pusher, target, dir):
			return true
	return false


## Triggers on_pushed reaction (e.g. FRAGILE destruction, SWAPPING)
## Returns true if the push was intercepted/handled by a rule (e.g., shattered).
static func on_pushed(pusher: Node2D, target: Node2D, dir: Vector2i) -> bool:
	_ensure_initialized()
	var tags_variant = target.get("tags")
	if tags_variant == null:
		return false
	var tags: Array[String] = extract_tag_names(tags_variant)
	for tag: String in tags:
		var rule: TagRule = _rules.get(tag, null)
		if rule != null and rule.on_pushed(pusher, target, dir):
			return true
	return false


## Ticks autonomous behavior for a GridBody2D during turn execution
static func tick_body(body: Node2D) -> void:
	_ensure_initialized()
	if body == null or not is_instance_valid(body):
		return
	var tags_variant = body.get("tags")
	if tags_variant == null:
		return
	var tags: Array[String] = extract_tag_names(tags_variant)
	# SLEEPING suppresses all movement tags
	if "SLEEPING" in tags:
		var sleeping_rule: TagRule = _rules.get("SLEEPING", null)
		if sleeping_rule != null:
			sleeping_rule.on_turn_tick(body)
		return

	# Prioritize behavioral movement tags in deterministic order: CHASING -> PATROLLING -> FLEEING
	if "CHASING" in tags:
		var rule: TagRule = _rules.get("CHASING", null)
		if rule != null:
			rule.on_turn_tick(body)
	elif "PATROLLING" in tags:
		var rule: TagRule = _rules.get("PATROLLING", null)
		if rule != null:
			rule.on_turn_tick(body)
	elif "FLEEING" in tags:
		var rule: TagRule = _rules.get("FLEEING", null)
		if rule != null:
			rule.on_turn_tick(body)
	else:
		# Tick any other custom tags
		for tag: String in tags:
			if not tag in ["CHASING", "PATROLLING", "FLEEING"]:
				var rule: TagRule = _rules.get(tag, null)
				if rule != null:
					rule.on_turn_tick(body)


## Tag lifecycle notifications
static func notify_tag_added(target: Object, tag: String) -> void:
	_ensure_initialized()
	var rule: TagRule = _rules.get(tag, null)
	if rule != null:
		rule.on_tag_added(target)


static func notify_tag_removed(target: Object, tag: String) -> void:
	_ensure_initialized()
	var rule: TagRule = _rules.get(tag, null)
	if rule != null:
		rule.on_tag_removed(target)


## --- Tag Property Interceptor Methods ---

## Checks whether a tag can be dragged by evaluating its attached properties.
static func can_drag_tag(tag: Variant, context: Dictionary = {}) -> bool:
	_ensure_initialized()
	if tag == null:
		return false
	var props: Array = []
	if tag is RefCounted and tag.get("properties") != null:
		props = tag.get("properties") as Array
	for p_item in props:
		var p: String = str(p_item)
		var rule: RefCounted = _property_rules.get(p, null)
		if rule != null and not rule.can_drag(tag, context):
			return false
	return true


## Checks whether a tag can be rendered in Subtext view by evaluating its attached properties.
static func can_render_tag(tag: Variant, context: Dictionary = {}) -> bool:
	_ensure_initialized()
	if tag == null:
		return false
	var props: Array = []
	if tag is RefCounted and tag.get("properties") != null:
		props = tag.get("properties") as Array
	for p_item in props:
		var p: String = str(p_item)
		var rule: RefCounted = _property_rules.get(p, null)
		if rule != null and not rule.can_render(tag, context):
			return false
	return true


## Dispatches host physical contact to the property rules of all attached tags
static func on_host_contact(host: Node2D, other: Node2D) -> void:
	_ensure_initialized()
	if host == null:
		return
	var tags_variant = host.get("tags")
	if tags_variant == null:
		return
	var tags: Array = tags_variant as Array
	for tag in tags:
		if tag is RefCounted and tag.get("properties") != null:
			var props: Array = tag.get("properties") as Array
			for p_item in props:
				var p: String = str(p_item)
				var rule: RefCounted = _property_rules.get(p, null)
				if rule != null:
					rule.on_host_contact(tag, host, other)

