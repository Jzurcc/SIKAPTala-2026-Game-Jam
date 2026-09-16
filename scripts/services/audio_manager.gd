extends Node

## Manages all audio: BGM playlist, SFX players, and the substrate LPF filter effect.
## Extracted from GameState. Register as autoload "AudioManager" in project.godot.

var bgm_player: AudioStreamPlayer
var sfx_select: AudioStreamPlayer
var sfx_deselect: AudioStreamPlayer
var sfx_error: AudioStreamPlayer

var bgm_playlist: Array[String] = [
	"res://assets/music/bgm/punky-troll-oxcc-5-u.wav",
	"res://assets/music/bgm/ooh-a-fly-wait-it-isn-t-tloagd.wav",
	"res://assets/music/bgm/welcome-space-traveler-4-wct-1-b.wav"
]
var bgm_index: int = 0
var lpf_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)

	sfx_select = AudioStreamPlayer.new()
	sfx_select.stream = load("res://assets/music/sfx/select.wav")
	add_child(sfx_select)

	sfx_deselect = AudioStreamPlayer.new()
	sfx_deselect.stream = load("res://assets/music/sfx/deselect.wav")
	add_child(sfx_deselect)

	sfx_error = AudioStreamPlayer.new()
	sfx_error.stream = load("res://assets/music/sfx/error.wav")
	add_child(sfx_error)

	# Connect to substrate toggle for LPF effect
	GameState.substrate_toggled.connect(_on_substrate_toggled)


func start_gameplay_music() -> void:
	if bgm_player.playing:
		return
	bgm_index = 0
	_play_current_bgm()


func play_select_sfx() -> void:
	sfx_select.play()


func play_deselect_sfx() -> void:
	sfx_deselect.play()


func play_error_sfx() -> void:
	sfx_error.play()


func _play_current_bgm() -> void:
	var stream = load(bgm_playlist[bgm_index])
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	bgm_player.stream = stream
	bgm_player.play()


func _on_bgm_finished() -> void:
	bgm_index = (bgm_index + 1) % bgm_playlist.size()
	await get_tree().create_timer(randf_range(2.0, 3.0)).timeout
	_play_current_bgm()


func _on_substrate_toggled(active: bool) -> void:
	if lpf_tween:
		lpf_tween.kill()

	var bus_idx := AudioServer.get_bus_index("BGM")
	if bus_idx != -1 and AudioServer.get_bus_effect_count(bus_idx) > 0:
		var effect := AudioServer.get_bus_effect(bus_idx, 0)
		if effect is AudioEffectLowPassFilter:
			lpf_tween = create_tween()
			lpf_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			var target_hz := 600.0 if active else 20000.0
			var target_pitch := 0.8 if active else 1.0
			lpf_tween.tween_property(effect, "cutoff_hz", target_hz, 0.25).set_trans(Tween.TRANS_SINE)
			lpf_tween.parallel().tween_property(bgm_player, "pitch_scale", target_pitch, 0.25).set_trans(Tween.TRANS_SINE)
