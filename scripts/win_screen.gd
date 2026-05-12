extends Control

@onready var yes_label: Label = $OptionsRow/YesLabel
@onready var no_label: Label = $OptionsRow/NoLabel

var selected: int = 0
var options: Array = []


func _ready() -> void:
	options = [yes_label, no_label]
	_update_sel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		selected = wrapi(selected - 1, 0, options.size())
		_update_sel()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		selected = wrapi(selected + 1, 0, options.size())
		_update_sel()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_confirm()


func _update_sel() -> void:
	for i in range(options.size()):
		options[i].modulate.a = 1.0 if i == selected else 0.5


func _confirm() -> void:
	match selected:
		0:
			get_tree().change_scene_to_file("res://scenes/node_2d.tscn")
		1:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
