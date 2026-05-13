extends Control

@onready var yes_label: Label = $OptionsRow/YesLabel
@onready var no_label: Label = $OptionsRow/NoLabel
@onready var you_win_label: Label = $YouWinLabel

var selected: int = 0
var options: Array = []
var base_y: float = 0.0
var timer: float = 0.0


func _ready() -> void:
	options = [yes_label, no_label]
	base_y = you_win_label.position.y
	_update_sel()


func _process(delta: float) -> void:
	timer += delta
	you_win_label.position.y = base_y - 1.5 + pingpong(timer * 4.0, 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		selected = wrapi(selected - 1, 0, options.size())
		GameState.play_deselect_sfx()
		_update_sel()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		selected = wrapi(selected + 1, 0, options.size())
		GameState.play_deselect_sfx()
		_update_sel()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		GameState.play_select_sfx()
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
