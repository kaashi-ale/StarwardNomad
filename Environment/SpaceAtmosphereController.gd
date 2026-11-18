extends Node
## Continuously blends sky colors, ambient lighting, and star visibility
## as the player travels seamlessly from a planet's surface into deep space.

@export var world_environment_path: NodePath
@export var starfield_path: NodePath

var _world_env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _starfield: Node3D
var _update_accum: float = 0.0

var _space_top := Color(0.01, 0.015, 0.035)
var _space_horizon := Color(0.03, 0.05, 0.11)
var _space_ground := Color(0.01, 0.015, 0.03)


func _ready() -> void:
	_world_env = get_node_or_null(world_environment_path) as WorldEnvironment
	_starfield = get_node_or_null(starfield_path) as Node3D

	if _world_env and _world_env.environment and _world_env.environment.sky:
		_sky_mat = _world_env.environment.sky.sky_material as ProceduralSkyMaterial


func _process(delta: float) -> void:
	_update_accum += delta
	if _update_accum < 0.05:
		return
	_update_accum = 0.0

	if _world_env == null or _world_env.environment == null:
		return

	var focus: Node3D = GameState.ship_node if GameState.current_mode == GameState.ControlMode.IN_SHIP else GameState.player_node
	if not is_instance_valid(focus) or not is_instance_valid(GameState.space_system):
		return

	var nearest_info: Dictionary = GameState.space_system.get_nearest_planet_info(focus.global_position)
	var planet: Node3D = nearest_info.get("planet", null)
	var altitude: float = nearest_info.get("altitude", 9999.0)
	var atmo_height: float = nearest_info.get("atmosphere_height", 300.0)

	# 0.0 = on surface, 1.0 = deep space
	var space_ratio: float = clampf(altitude / maxf(atmo_height, 1.0), 0.0, 1.0)
	var atmo_weight: float = 1.0 - smoothstep(0.0, 1.0, space_ratio)

	var sky_top: Color = _space_top
	var sky_horizon: Color = _space_horizon
	var ground_col: Color = _space_ground

	if is_instance_valid(planet) and planet.has_method("get_sky_colors"):
		var cols: Dictionary = planet.get_sky_colors()
		sky_top = _space_top.lerp(cols["zenith"], atmo_weight)
		sky_horizon = _space_horizon.lerp(cols["horizon"], atmo_weight)
		ground_col = _space_ground.lerp(cols["ground"], atmo_weight)

		var loc_label: String = planet.planet_name
		if space_ratio < 0.22:
			loc_label += " — Superfície"
		elif space_ratio < 0.85:
			loc_label += " — Atmosfera"
		elif space_ratio < 1.0:
			loc_label += " — Órbita Baixa"
		else:
			loc_label = "Espaço Profundo"

		GameState.set_active_planet(planet if space_ratio < 1.0 else null, planet.planet_name)
		GameState.altitude_updated.emit(maxf(0.0, altitude), space_ratio, loc_label)

	if _sky_mat:
		_sky_mat.sky_top_color = sky_top
		_sky_mat.sky_horizon_color = sky_horizon
		_sky_mat.ground_bottom_color = ground_col
		_sky_mat.ground_horizon_color = sky_horizon

	var env := _world_env.environment
	env.ambient_light_color = Color(0.22, 0.26, 0.35).lerp(sky_horizon, atmo_weight * 0.75)
	env.ambient_light_energy = lerpf(0.45, 0.95, atmo_weight)

	if is_instance_valid(_starfield) and _starfield.has_method("set_space_visibility"):
		_starfield.set_space_visibility(space_ratio)
