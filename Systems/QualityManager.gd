extends Node
## Hardware profile manager tuned for Motorola Moto G04s (Unisoc T606 / Mali-G57 MP1).

enum Preset {
	LOW = 0,     # Default: 0.68 render scale, no real-time shadows
	MEDIUM = 1,  # 0.88 render scale, directional shadow, medium scatter
	HIGH = 2,    # Full render scale, shadows and dense vegetation
	ECONOMY = 3  # Lower render scale and vegetation density for older hardware
}

signal quality_changed(preset: int)

var current_preset: int = Preset.LOW
var target_fps: int = 30
var touch_sensitivity: float = 1.0
var scatter_density_multiplier: float = 0.50
var detail_distance_multiplier: float = 0.70


const SETTINGS_PATH := "user://settings.cfg"
var volume_percent := 75
var sound_muted := false
var _settings := ConfigFile.new()


func _ready() -> void:
	_settings.load(SETTINGS_PATH)
	volume_percent = clampi(int(_settings.get_value("audio", "volume", 75)), 0, 100)
	sound_muted = bool(_settings.get_value("audio", "muted", false))
	_apply_audio()
	apply_preset(int(_settings.get_value("graphics", "preset", Preset.LOW)))


func set_audio(volume: int, muted: bool) -> void:
	volume_percent = clampi(volume, 0, 100)
	sound_muted = muted
	_apply_audio()
	_settings.set_value("audio", "volume", volume_percent)
	_settings.set_value("audio", "muted", sound_muted)
	_settings.save(SETTINGS_PATH)


func _apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.001, volume_percent / 100.0)))
	AudioServer.set_bus_mute(master, sound_muted or volume_percent == 0)


func apply_preset(preset: int) -> void:
	current_preset = clampi(preset, Preset.LOW, Preset.ECONOMY)
	var vp := get_viewport()

	match current_preset:
		Preset.ECONOMY:
			target_fps = 30
			scatter_density_multiplier = 0.32
			detail_distance_multiplier = 0.54
			if vp:
				vp.scaling_3d_scale = 0.55
		Preset.LOW:
			target_fps = 30
			scatter_density_multiplier = 0.50
			detail_distance_multiplier = 0.70
			if vp:
				vp.scaling_3d_scale = 0.68
		Preset.MEDIUM:
			target_fps = 45
			scatter_density_multiplier = 0.80
			detail_distance_multiplier = 0.90
			if vp:
				vp.scaling_3d_scale = 0.88
		Preset.HIGH:
			target_fps = 60
			scatter_density_multiplier = 1.00
			detail_distance_multiplier = 1.15
			if vp:
				vp.scaling_3d_scale = 1.00

	Engine.max_fps = target_fps
	refresh_scene_settings()
	quality_changed.emit(current_preset)


func select_preset(preset: int) -> void:
	apply_preset(preset)
	_settings.set_value("graphics", "preset", current_preset)
	_settings.save(SETTINGS_PATH)


func set_target_fps(fps: int) -> void:
	target_fps = clampi(fps, 24, 60)
	Engine.max_fps = target_fps


func refresh_scene_settings() -> void:
	if not is_inside_tree():
		return
	var sun := get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = (current_preset == Preset.MEDIUM or current_preset == Preset.HIGH)
