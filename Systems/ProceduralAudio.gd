extends Node
## Small synthesized clips cached at startup. Runtime mixing stays in the audio engine.

const SAMPLE_RATE := 22050
var jetpack_active := false
var ship_thrust_level := 0.0
var atmospheric_air := 0.0
var _wind_player: AudioStreamPlayer
var _wind_volume := 0.0
var _sfx_player: AudioStreamPlayer
var _jet_player: AudioStreamPlayer
var _jet_volume := 0.0
var _laser: AudioStreamWAV
var _jump: AudioStreamWAV
var _step: AudioStreamWAV
var _landing: AudioStreamWAV
var _board: AudioStreamWAV
var _discovery: AudioStreamWAV
var _hit: AudioStreamWAV


func _ready() -> void:
	GameState.audio_system = self
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -8.0
	add_child(_sfx_player)
	_jet_player = AudioStreamPlayer.new()
	_jet_player.stream = _make_jet_loop()
	_jet_player.volume_db = -60.0
	add_child(_jet_player)
	_wind_player = AudioStreamPlayer.new()
	_wind_player.stream = _make_wind_loop()
	_wind_player.volume_db = -60.0
	add_child(_wind_player)
	_laser = _tone(920.0, 210.0, 0.14, 0.45, 0.15)
	_jump = _tone(180.0, 420.0, 0.18, 0.30, 0.55)
	_step = _tone(120.0, 65.0, 0.06, 0.16, 0.70)
	_landing = _tone(95.0, 38.0, 0.14, 0.30, 0.66)
	_board = _tone(240.0, 560.0, 0.28, 0.38, 0.10)
	_discovery = _tone(523.25, 783.99, 0.42, 0.42, 0.0)
	_hit = _tone(150.0, 48.0, 0.16, 0.45, 0.65)


func _exit_tree() -> void:
	_sfx_player.stop()
	_jet_player.stop()
	_wind_player.stop()


func _process(delta: float) -> void:
	_update_wind(delta)
	var target := 1.0 if jetpack_active else ship_thrust_level
	if is_equal_approx(_jet_volume, target):
		return
	_jet_volume = move_toward(_jet_volume, target, delta * 8.0)
	if _jet_volume <= 0.0:
		_jet_player.stop()
		return
	if not _jet_player.playing:
		_jet_player.play()
	_jet_player.volume_db = linear_to_db(_jet_volume) - 7.0


func play_laser() -> void:
	_play(_laser)


func play_jump() -> void:
	_play(_jump)


func play_step() -> void:
	_play(_step)


func play_landing() -> void:
	_play(_landing)


func play_board_ship() -> void:
	_play(_board)


func play_discovery() -> void:
	_play(_discovery)


func play_hit() -> void:
	_play(_hit)


func _play(clip: AudioStreamWAV) -> void:
	_sfx_player.stream = clip
	_sfx_player.play()


func _audio(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream


func _tone(start_frequency: float, end_frequency: float, duration: float, amplitude: float, noise: float) -> AudioStreamWAV:
	var frames := roundi(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = frames
	for frame in range(frames):
		var progress := float(frame) / frames
		phase += lerpf(start_frequency, end_frequency, progress) * TAU / SAMPLE_RATE
		var wave := lerpf(sin(phase), rng.randf_range(-1.0, 1.0), noise)
		var envelope := minf(frame / 36.0, 1.0) * (1.0 - progress) * amplitude
		data.encode_s16(frame * 2, roundi(wave * envelope * 32767.0))
	return _audio(data)


func _make_jet_loop() -> AudioStreamWAV:
	var frames := SAMPLE_RATE >> 2
	var data := PackedByteArray()
	data.resize(frames * 2)
	for frame in range(frames):
		var phase := float(frame) * TAU / frames
		var rumble := sin(phase * 23.0) * 0.065 + sin(phase * 47.0) * 0.045 + sin(phase * 83.0) * 0.032
		var flutter := 0.78 + sin(phase * 3.0) * 0.22
		data.encode_s16(frame * 2, roundi(rumble * flutter * 32767.0))
	var stream := _audio(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream


func _update_wind(delta: float) -> void:
	_wind_volume = move_toward(_wind_volume, atmospheric_air, delta * 0.65)
	if _wind_volume < 0.015:
		if _wind_player.playing:
			_wind_player.stop()
		return
	var enclosed := GameState.current_mode == GameState.ControlMode.IN_SHIP
	_wind_player.volume_db = linear_to_db(_wind_volume) - (18.0 if enclosed else 9.0)
	if not _wind_player.playing:
		_wind_player.play()


func _make_wind_loop() -> AudioStreamWAV:
	var frames := SAMPLE_RATE * 3
	var data := PackedByteArray()
	data.resize(frames * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1432
	var breeze := 0.0
	var gust := 0.0
	for frame in range(frames):
		breeze = lerpf(breeze, random.randf_range(-1.0, 1.0), 0.032)
		gust = lerpf(gust, breeze, 0.075)
		var phase := float(frame) / frames
		var edge := minf(minf(phase, 1.0 - phase) * 16.0, 1.0)
		var swell := 0.57 + 0.32 * sin(phase * TAU)
		data.encode_s16(frame * 2, roundi((breeze * 0.28 + gust * 0.52) * edge * swell * 32767.0))
	var stream := _audio(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream
