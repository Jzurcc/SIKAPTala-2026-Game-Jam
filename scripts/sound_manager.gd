extends Node

const MAX_SOURCES := 16

var _sources: Array[Node] = []


func register(source: Node) -> void:
	if _sources.has(source):
		return
		
	if _sources.size() >= MAX_SOURCES:
		# FIFO replacement: oldest sound dies early to make room
		var oldest = _sources.pop_front()
		if oldest and oldest.has_method("stop"):
			oldest.stop()
		print("[SoundManager] MAX reached. Kicked oldest: ", oldest.name)
		
	_sources.append(source)
	print("[SoundManager] Registered: ", source.name, " | Total: ", _sources.size())


func unregister(source: Node) -> void:
	if _sources.has(source):
		_sources.erase(source)
		print("[SoundManager] Unregistered: ", source.name, " | Total: ", _sources.size())


func get_sources() -> Array[Node]:
	return _sources
