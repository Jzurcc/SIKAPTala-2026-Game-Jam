class_name PropBrittle
extends "res://scripts/core/tag_property_rule.gd"

## BRITTLE causes the tag itself to shatter and be removed if the host is pushed or damaged.

func on_host_contact(tag: RefCounted, host: Node2D, _other: Node2D) -> void:
	if host != null and host.has_method("remove_subtext_tag"):
		host.remove_subtext_tag(tag)
