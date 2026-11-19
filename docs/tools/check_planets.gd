extends SceneTree

var failures := 0
var state: Node
var ship: CharacterBody3D
var explorer: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _ticks(110)
	Engine.max_fps = 0
	state = root.get_node("GameState")
	ship = state.ship_node
	explorer = state.player_node
	var planets: Array = state.space_system.planets
	_check(planets.size() == 5, "cinco planetas")
	explorer.try_board_ship()
	await _ticks(5)
	_check(state.current_mode == 1, "embarque")
	Input.action_press("jump")
	await _ticks(75)
	Input.action_release("jump")
	_check(not ship.is_landed and ship.surface_altitude > 11.0, "decolagem")
	ship.navigation_target = planets[1]
	ship.toggle_navigation_assist()
	var low := false
	var orbit := false
	var fast := false
	var reached := false
	Input.action_press("move_forward")
	for step in range(330):
		await _ticks(15)
		var info: Dictionary = state.space_system.get_nearest_planet_info(ship.global_position)
		var planet: Node3D = info["planet"]
		var altitude: float = info["altitude"]
		low = low or (planet == planets[0] and ship.surface_altitude < 50.0 and ship.velocity.length() > 12.0)
		orbit = orbit or altitude > float(info["atmosphere_height"])
		fast = fast or ship.velocity.length() > 500.0
		if planet == planets[1] and altitude < 116.0:
			reached = true
			break
	Input.action_release("move_forward")
	_check(low and orbit and fast, "voo baixo, saída atmosférica e cruzeiro rápido")
	_check(reached, "viagem contínua de Aurelia a Pyros com curso assistido")
	ship.navigation_assist = false
	for planet: Node3D in planets:
		await _probe(planet)
	quit(1 if failures > 0 else 0)


func _probe(planet: Node3D) -> void:
	var up: Vector3 = planet._landmark.direction
	var label: String = planet.planet_name
	_check(up != Vector3.ZERO, label + " tem destino determinístico")
	if up == Vector3.ZERO:
		return
	# Reposition only the harness. Landing and walking use normal game logic.
	var forward := Vector3.FORWARD.slide(up).normalized()
	var target: Vector3 = (up * planet.data.radius + forward * 12.0).normalized()
	ship.global_basis = Basis.looking_at(forward.slide(target), target)
	ship.global_position = planet.global_position + target * (planet.get_surface_radius_at_dir(target) + 21.0)
	ship.velocity = Vector3.ZERO
	ship._current_speed = 0.0
	ship._climb_speed = 0.0
	ship.is_landed = false
	var quality := root.get_node("QualityManager")
	for mode: int in [3, 0, 1, 2, 3]:
		quality.apply_preset(mode)
		Engine.max_fps = 0
		await _ticks(25)
	_check(planet._landmark.get_child_count() >= 3, label + " gera marco visitável")
	var world := planet.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var hits := 0
	var above := 0
	var below := 0
	var terrain_center: Vector3 = planet.global_position
	for i in range(96):
		var angle := TAU * i / 96.0
		var axis := Vector3(1.0, sin(angle), cos(angle)).normalized()
		var sample_radius: float = planet.get_surface_radius_at_dir(axis)
		var ray := PhysicsRayQueryParameters3D.create(terrain_center + axis * (sample_radius + 120), terrain_center + axis * (sample_radius - 120), 1)
		var hit := world.intersect_ray(ray)
		if hit.get("collider") == planet and axis.dot(hit["normal"]) > 0.01:
			hits += 1
			if planet.data.has_ocean:
				if terrain_center.distance_to(hit["position"]) < planet.data.radius + planet.data.ocean_level_offset:
					below += 1
				else:
					above += 1
	_check(hits == 96, label + " superfície fechada em 96 raios incluindo bordas")
	if planet.data.has_ocean:
		_check(planet._water_chunks.any(func(patch: MeshInstance3D) -> bool: return patch != null) and above > 0 and below > 0, label + " possui terra e regiões oceânicas")
	var landmark: Vector3 = planet._landmark.global_position
	var shape := world.intersect_ray(PhysicsRayQueryParameters3D.create(landmark + up * 19.0, landmark - up, 32))
	_check(not shape.is_empty(), label + " colisão no marco")
	var landed: bool = ship.try_land_ship()
	_check(landed, label + " pouso manual")
	if landed:
		ship.exit_ship()
		await _ticks(40)
		_check(state.current_mode == 0 and explorer.is_on_floor(), label + " desembarque com chão sólido")
		var start := explorer.global_position - planet.global_position
		Input.action_press("move_forward")
		await _ticks(25)
		Input.action_release("move_forward")
		_check(start.distance_to(explorer.global_position - planet.global_position) > 0.6, label + " movimentação na superfície")
		ship.board_ship(explorer)
	else:
		print("Pouso indisponível: ", ship.landing_status)


func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func _ticks(count: int) -> void:
	for step in range(count):
		await physics_frame
