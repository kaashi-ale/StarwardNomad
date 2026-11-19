extends Node
## Continuously blends sky colors, ambient lighting, and star visibility
## as the player travels seamlessly from a planet's surface into deep space.

@export var world_environment_path: NodePath
@export var starfield_path: NodePath

var _world_env: WorldEnvironment
const PLANET_SKY := preload("res://Environment/PlanetSky.gdshader")
var _sky_mat: ShaderMaterial
var _starfield: Node3D
var _update_accum: float = 0.0
var _last_sky_planet: Node3D
var _last_sky_weight := -1.0
var _last_sky_up := Vector3.ZERO

var _space_horizon := Color(0.03, 0.05, 0.11)


func _ready() -> void:
	_world_env = get_node_or_null(world_environment_path) as WorldEnvironment
	_starfield = get_node_or_null(starfield_path) as Node3D

	if _world_env and _world_env.environment and _world_env.environment.sky:
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = PLANET_SKY
		var noise := FastNoiseLite.new()
		noise.seed = 421
		noise.frequency = 0.014
		noise.fractal_octaves = 4
		var clouds := NoiseTexture2D.new()
		clouds.width = 256
		clouds.height = 256
		clouds.seamless = true
		clouds.noise = noise
		_sky_mat.set_shader_parameter("cloud_noise", clouds)
		var sun := get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D
		if sun:
			_sky_mat.set_shader_parameter("sun_direction", sun.global_basis.z.normalized())
		_world_env.environment.sky.sky_material = _sky_mat


func _process(delta: float) -> void:
	_update_accum += delta
	if _update_accum < 0.10:
		return
	_update_accum = 0.0

	if _world_env == null or _world_env.environment == null:
		return

	var focus: Node3D = GameState.ship_node if GameState.current_mode == GameState.ControlMode.IN_SHIP else GameState.player_node
	if not is_instance_valid(focus) or not is_instance_valid(GameState.space_system):
		return

	var nearest_info: Dictionary = GameState.space_system.get_nearest_planet_info(focus.global_position)
	var planet: PlanetBody = nearest_info.get("planet", null)
	var altitude: float = nearest_info.get("altitude", 9999.0)
	var atmo_height: float = nearest_info.get("atmosphere_height", 300.0)

	# 0.0 = on surface, 1.0 = deep space
	var space_ratio: float = clampf(altitude / maxf(atmo_height, 1.0), 0.0, 1.0)
	var atmo_weight: float = 1.0 - smoothstep(0.0, 1.0, space_ratio)
	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.atmospheric_air = atmo_weight

	var sky_horizon: Color = _space_horizon

	if is_instance_valid(planet) and planet.has_method("get_sky_colors"):
		var cols: Dictionary = planet.get_sky_colors()
		sky_horizon = _space_horizon.lerp(cols["horizon"], atmo_weight)

		var loc_label: String = planet.planet_name
		if space_ratio < 0.22:
			if GameState.current_mode == GameState.ControlMode.ON_FOOT:
				var up := planet.global_position.direction_to(focus.global_position)
				var ground_height := planet.get_surface_radius_at_dir(up) - planet.data.radius
				loc_label += " · " + planet.data.biome_names[planet.get_biome(up, ground_height)]
				altitude -= ground_height
			else:
				loc_label += " — Superfície"
		elif space_ratio < 0.85:
			loc_label += " — Atmosfera"
		elif space_ratio < 1.0:
			loc_label += " — Órbita Baixa"
		else:
			loc_label = "Espaço Profundo"

		GameState.set_active_planet(planet if space_ratio < 1.0 else null, planet.planet_name)
		GameState.altitude_updated.emit(maxf(0.0, altitude), space_ratio, loc_label)

	var env := _world_env.environment
	var sky_planet := planet if atmo_weight > 0.005 else null
	if sky_planet != _last_sky_planet or absf(atmo_weight - _last_sky_weight) > 0.018:
		if _sky_mat:
			if is_instance_valid(planet):
				var colors := planet.get_sky_colors()
				_sky_mat.set_shader_parameter("zenith", colors["zenith"])
				_sky_mat.set_shader_parameter("horizon", colors["horizon"])
				_sky_mat.set_shader_parameter("below_horizon", colors["horizon"].darkened(0.22))
				_sky_mat.set_shader_parameter("cloud_cover", 0.49 if planet.is_aurelia() else 0.55)
			_sky_mat.set_shader_parameter("air", atmo_weight)
		env.ambient_light_color = Color(0.22, 0.26, 0.35).lerp(sky_horizon, atmo_weight * 0.75)
		env.ambient_light_energy = lerpf(0.42, 0.68, atmo_weight)
		env.fog_enabled = atmo_weight > 0.005
		env.fog_light_color = sky_horizon
		env.fog_density = 0.00235 * atmo_weight
		env.fog_sky_affect = 0.0
		_last_sky_planet = sky_planet
		_last_sky_weight = atmo_weight
	for world: PlanetBody in GameState.space_system.planets:
		world.set_sky_obscuration(atmo_weight if world != sky_planet else 0.0)
	if atmo_weight > 0.005 and is_instance_valid(planet):
		var radial_up := planet.global_position.direction_to(focus.global_position)
		if radial_up.distance_squared_to(_last_sky_up) > 0.00006:
			if _sky_mat:
				_sky_mat.set_shader_parameter("local_up", radial_up)
			_last_sky_up = radial_up
	var belt := GameState.space_system.get_node_or_null("AsteroidBelt") as MultiMeshInstance3D
	if is_instance_valid(belt):
		belt.visible = space_ratio > 0.63
	if is_instance_valid(_starfield) and _starfield.has_method("set_space_visibility"):
		_starfield.set_space_visibility(space_ratio)
