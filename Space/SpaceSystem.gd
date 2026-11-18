extends Node3D
## Manages the star system: central star, 5 procedural planets, asteroid belt,
## orbital space station, and unified gravitational / nearest-planet queries.

const STATION_SCENE := preload("res://Space/SpaceStation.tscn")

var planets: Array[PlanetBody] = []
var space_landmarks: Array[Dictionary] = []


func _ready() -> void:
	GameState.space_system = self
	_build_star()
	_build_planets_staggered()
	_build_orbital_station()
	_build_asteroid_belt()


func get_nearest_planet_info(world_pos: Vector3) -> Dictionary:
	var best_planet: PlanetBody = null
	var best_altitude: float = INF
	var atmo_h: float = 300.0

	for p in planets:
		if not is_instance_valid(p) or p.data == null:
			continue
		var dist: float = world_pos.distance_to(p.global_position)
		var alt: float = dist - p.data.radius
		if alt < best_altitude:
			best_altitude = alt
			best_planet = p
			atmo_h = p.data.atmosphere_height

	return {
		"planet": best_planet,
		"altitude": best_altitude,
		"atmosphere_height": atmo_h
	}


func get_total_gravity_at(world_pos: Vector3) -> Vector3:
	var total_g := Vector3.ZERO
	for p in planets:
		if is_instance_valid(p) and p.data != null:
			total_g += p.get_gravity_vector_at(world_pos)
	return total_g


func get_navigation_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for p in planets:
		if is_instance_valid(p) and p.data != null:
			targets.append({
				"name": p.planet_name,
				"position": p.global_position,
				"color": p.data.atmosphere_rim,
				"radius": p.data.radius
			})
	for lm in space_landmarks:
		var node: Node3D = lm.get("node", null)
		if is_instance_valid(node):
			targets.append({
				"name": lm["name"],
				"position": node.global_position,
				"color": Color(1.0, 0.85, 0.35),
				"radius": 60.0
			})
	return targets


func _build_star() -> void:
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 420.0
	sun_mesh.height = 840.0
	sun_mesh.radial_segments = 24
	sun_mesh.rings = 14

	var sun_mat := StandardMaterial3D.new()
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.albedo_color = Color(1.0, 0.92, 0.68)
	sun_mesh.material = sun_mat

	var sun_inst := MeshInstance3D.new()
	sun_inst.name = "CentralStar"
	sun_inst.mesh = sun_mesh
	sun_inst.position = Vector3(-9500.0, 4200.0, -12000.0)
	sun_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sun_inst)


func _build_planets_staggered() -> void:
	var presets: Array[PlanetData] = PlanetData.create_presets()
	var placements: Array[Vector3] = [
		Vector3(0.0, -480.0, 0.0),          # Aurelia Prime (starting planet directly beneath spawn)
		Vector3(3400.0, 620.0, -2900.0),    # Pyros V
		Vector3(-3900.0, 1100.0, -4400.0),  # Glacius IX
		Vector3(1600.0, -1400.0, -6800.0),  # Veridian Mire
		Vector3(-2600.0, -550.0, 3800.0)    # Dusthaven
	]

	if presets.is_empty():
		return

	# Build starting world immediately so first frame renders with ground ready
	_spawn_single_planet(presets[0], placements[0])

	# Build remaining worlds 1 per frame to avoid Android startup freeze / ANR
	if presets.size() > 1:
		call_deferred("_spawn_remaining_planets", presets, placements)


func _spawn_remaining_planets(presets: Array[PlanetData], placements: Array[Vector3]) -> void:
	for i in range(1, presets.size()):
		if not is_inside_tree():
			return
		await get_tree().process_frame
		_spawn_single_planet(presets[i], placements[i])


func _spawn_single_planet(preset: PlanetData, local_pos: Vector3) -> void:
	var planet := PlanetBody.new()
	planet.collision_layer = 1
	planet.collision_mask = 0
	add_child(planet)
	planet.position = local_pos
	planet.initialize(preset)
	planets.append(planet)


func _build_orbital_station() -> void:
	var station := STATION_SCENE.instantiate()
	add_child(station)
	station.position = Vector3(1650.0, 520.0, -1450.0)
	space_landmarks.append({
		"name": "Estação Helios-7",
		"node": station
	})


func _build_asteroid_belt() -> void:
	var count: int = 240
	var rock := SphereMesh.new()
	rock.radius = 12.0
	rock.height = 18.0
	rock.radial_segments = 6
	rock.rings = 4

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	rock.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = rock
	mm.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = 8812

	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(2100.0, 5600.0)
		var pos := Vector3(
			cos(angle) * dist,
			rng.randf_range(-450.0, 950.0),
			sin(angle) * dist - 2200.0
		)
		var b := Basis().rotated(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(0.0, TAU))
		b = b.scaled(Vector3(rng.randf_range(0.5, 2.4), rng.randf_range(0.4, 1.8), rng.randf_range(0.5, 2.4)))
		mm.set_instance_transform(i, Transform3D(b, pos))
		var shade: float = rng.randf_range(0.32, 0.58)
		mm.set_instance_color(i, Color(shade * 1.1, shade, shade * 0.95))

	var mm_inst := MultiMeshInstance3D.new()
	mm_inst.name = "AsteroidBelt"
	mm_inst.multimesh = mm
	mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_inst)
