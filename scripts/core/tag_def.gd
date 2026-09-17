extends RefCounted
class_name TagDef

## Single canonical definition of all game tags.
## Every script that needs a tag name should reference TagDef.Tag enum values
## and convert to/from strings via the helpers below.

enum Tag {
	IMPASSABLE,
	LOCKED,
	PASSABLE,
	FRAGILE,
	HEAVY,
	LIGHT,
	INTERACTABLE,
	COLD,
	SLEEPING,
	CHASING,
	PATROLLING,
	FLEEING,
	PUSHING,
	HARMFUL,
	HIDDEN,
	YOU,
}

## Returns the string name of a Tag enum value (e.g. Tag.LIGHT -> "LIGHT").
static func tag_to_string(t: Tag) -> String:
	return Tag.keys()[t]

## Parses a string into a Tag enum value. Asserts on unknown tag names.
static func tag_from_string(s: String) -> Tag:
	var idx: int = Tag.keys().find(s)
	assert(idx != -1, "TagDef.tag_from_string: unknown tag '" + s + "'")
	return idx as Tag

## Converts an Array[Tag] into an Array[String].
static func to_string_array(tags: Array) -> Array[String]:
	var result: Array[String] = []
	for t in tags:
		result.append(tag_to_string(t))
	return result

## Returns true if the string is a registered tag name.
static func is_valid(s: String) -> bool:
	return Tag.keys().has(s)
