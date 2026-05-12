extends Control

@onready var title: Label = $ShakeContainer/Title
@onready var title_red: Label = $ShakeContainer/TitleRed
@onready var title_blue: Label = $ShakeContainer/TitleBlue
@onready var shake_container: Control = $ShakeContainer
@onready var start_label: Label = $StartLabel
@onready var exit_label: Label = $ExitLabel

enum Phase { STATIC, CORRECTION, REVEAL, SETTLE }
var phase: Phase = Phase.STATIC
var timer: float = 0.0

const WORD := "SUBTEXT"
const GLYPHS := "0101010101<>|_/\\" 


var display_chars: Array[String] = ["", "", "", "", "", "", ""]
var char_cycle_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var char_intervals: Array[float] = [0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06]


var locked := [false, false, false, false, false, false, false]
var lock_order := [5, 2, 0, 3, 4, 1, 6]
var lock_idx: int = 0
var next_lock_time: float = 0.0


var selected: int = 0
var options: Array = []
var can_input: bool = false


func _ready() -> void:
	options = [start_label, exit_label]
	start_label.modulate.a = 0.0
	exit_label.modulate.a = 0.0
	title_red.modulate = Color(1.0, 0.4, 0.4, 0.0)
	title_blue.modulate = Color(0.4, 0.4, 1.0, 0.0)
	
	for i in range(7):
		display_chars[i] = _rand_char()
		char_cycle_timers[i] = randf_range(0, 0.08)
	
	_update_title_text()


func _process(delta: float) -> void:
	timer += delta

	match phase:
		Phase.STATIC:
			_process_char_cycles(delta)
			if timer >= 0.5:
				phase = Phase.CORRECTION
				timer = 0.0
				next_lock_time = 0.12
		
		Phase.CORRECTION:
			_process_char_cycles(delta)
			if lock_idx < lock_order.size() and timer >= next_lock_time:
				_lock_next_character()
				next_lock_time = timer + 0.12
			
			if lock_idx >= lock_order.size() and timer >= next_lock_time:
				phase = Phase.REVEAL
				timer = 0.0
		
		Phase.REVEAL:
			_do_reveal()
		
		Phase.SETTLE:
			_do_settle()


func _rand_char() -> String:
	return GLYPHS[randi() % GLYPHS.length()]


func _process_char_cycles(delta: float) -> void:
	for i in range(7):
		if locked[i]: 
			display_chars[i] = WORD[i]
			continue
			
		char_cycle_timers[i] += delta
		if char_cycle_timers[i] >= char_intervals[i]:
			char_cycle_timers[i] = 0.0
			display_chars[i] = _rand_char()
	
	_update_title_text()


func _lock_next_character() -> void:
	var idx_to_lock = lock_order[lock_idx]
	locked[idx_to_lock] = true
	display_chars[idx_to_lock] = WORD[idx_to_lock]
	lock_idx += 1
	
	_ghost_flash()
	_update_title_text()


func _update_title_text() -> void:
	title.text = "".join(display_chars)


func _do_reveal() -> void:
	var p: float = sin(timer * PI / 0.8)
	var pulse: float = 1.0 + 0.4 * p
	title.modulate = Color(pulse, pulse, pulse, 1.0)
	
	title_red.modulate.a = 0.15 * p
	title_blue.modulate.a = 0.15 * p

	if timer >= 0.8:
		title.modulate = Color(1, 1, 1, 1)
		title_red.modulate.a = 0.0
		title_blue.modulate.a = 0.0
		phase = Phase.SETTLE
		timer = 0.0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(start_label, "modulate:a", 1.0, 0.7) 
		tw.parallel().tween_property(exit_label, "modulate:a", 0.5, 0.7)
		tw.tween_callback(func(): can_input = true)


func _do_settle() -> void:
	title.modulate.a = 0.85 + 0.15 * sin(timer * 0.5)


func _ghost_flash() -> void:
	title_red.text = title.text
	title_blue.text = title.text
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_red, "modulate:a", 0.3, 0.1)
	tw.parallel().tween_property(title_blue, "modulate:a", 0.3, 0.1)
	tw.tween_property(title_red, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(title_blue, "modulate:a", 0.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if not can_input:
		return
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		selected = wrapi(selected - 1, 0, options.size())
		_update_sel()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
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
			get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
		1:
			get_tree().quit()
