extends Node
## Zero-asset procedural audio feedback using Godot's AudioStreamGenerator.
## Produces lightweight sci-fi laser pulses, thruster rumble, discovery chimes, and footsteps.

var _sfx_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 22050.0

var _tone_freq: float = 0.0
var _tone_end_freq: float = 0.0
var _tone_time: float = 0.0
var _tone_duration: float = 0.0
var _tone_volume: float = 0.0
var _noise_mix: float = 0.0
var _phase: float = 0.0
var jetpack_active := false
var _jet_level := 0.0
var _jet_phase := 0.0


func _ready() -> void:
	GameState.audio_system = self
	_sfx_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = 0.08
	_sfx_player.stream = gen
	_sfx_player.volume_db = -8.0
	add_child(_sfx_player)
	_sfx_player.play()
	_playback = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _exit_tree() -> void:
	_playback = null
	_sfx_player.stop()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	for i in range(frames_available):
		var sample: float = 0.0
		if _tone_time < _tone_duration and _tone_duration > 0.0:
			var t: float = _tone_time / _tone_duration
			var freq: float = lerpf(_tone_freq, _tone_end_freq, t)
			var env: float = (1.0 - t) * _tone_volume
			_phase = fmod(_phase + freq / _sample_rate, 1.0)
			var wave: float = sin(_phase * TAU)
			if _noise_mix > 0.0:
				var n: float = randf_range(-1.0, 1.0)
				wave = lerpf(wave, n, _noise_mix)
			sample = wave * env
			_tone_time += 1.0 / _sample_rate
		_jet_level = move_toward(_jet_level, 1.0 if jetpack_active else 0.0, 0.0018)
		if _jet_level > 0.001:
			_jet_phase = fmod(_jet_phase + 92.0 / _sample_rate, 1.0)
			sample += (sin(_jet_phase * TAU) * 0.08 + randf_range(-0.16, 0.16)) * _jet_level
		_playback.push_frame(Vector2(sample, sample))


func play_laser() -> void:
	_trigger_tone(920.0, 210.0, 0.14, 0.45, 0.15)


func play_jump() -> void:
	_trigger_tone(180.0, 420.0, 0.18, 0.30, 0.55)


func play_step() -> void:
	_trigger_tone(120.0, 65.0, 0.06, 0.16, 0.70)


func play_landing() -> void:
	_trigger_tone(95.0, 38.0, 0.14, 0.30, 0.66)


func play_board_ship() -> void:
	_trigger_tone(240.0, 560.0, 0.28, 0.38, 0.10)


func play_discovery() -> void:
	_trigger_tone(523.25, 783.99, 0.42, 0.42, 0.0)


func play_hit() -> void:
	_trigger_tone(150.0, 48.0, 0.16, 0.45, 0.65)


func _trigger_tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> void:
	_tone_freq = f0
	_tone_end_freq = f1
	_tone_duration = dur
	_tone_time = 0.0
	_tone_volume = vol
	_noise_mix = noise
