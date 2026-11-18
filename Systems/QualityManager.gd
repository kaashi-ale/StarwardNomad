extends Node
## Hardware profile manager tuned for Motorola Moto G04s (Unisoc T606 / Mali-G57 MP1).

enum Preset {
	LOW = 0,     # Default Moto G04s target: 0.75 render scale, no real-time shadows, compact scatter
	MEDIUM = 1,  # Balanced mobile: 0.88 render scale, directional shadow, medium scatter
	HIGH = 2     # High-end / Desktop: 1.00 render scale, crisp shadows, full scatter
}

signal quality_changed(preset: int)

var current_preset: int = Preset.LOW
var target_fps: int = 30
var touch_sensitivity: float = 1.0
var scatter_density_multiplier: float = 0.50
var detail_distance_multiplier: float = 0.70


func _ready() -> void:
	if OS.has_feature("android") or OS.has_feature("mobile"):
		apply_preset(Preset.LOW)
	else:
		apply_preset(Preset.MEDIUM)


func apply_preset(preset: int) -> void:
	current_preset = clampi(preset, Preset.LOW, Preset.HIGH)
	var vp := get_viewport()

	match current_preset:
		Preset.LOW:
			target_fps = 30
			scatter_density_multiplier = 0.50
			detail_distance_multiplier = 0.70
			if vp:
				vp.scaling_3d_scale = 0.75
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


func set_target_fps(fps: int) -> void:
	target_fps = clampi(fps, 24, 60)
	Engine.max_fps = target_fps


func refresh_scene_settings() -> void:
	if not is_inside_tree():
		return
	var sun := get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = (current_preset >= Preset.MEDIUM)
