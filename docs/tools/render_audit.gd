extends SceneTree

var _stage := OS.get_environment("NOMAD_STAGE")
var _path := OS.get_environment("NOMAD_AUDIT_DIR")
var _state: Node
var _camera: Camera3D
var _specs: Array = []
var _results: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if _path.is_empty():
		_path = "/tmp/nomad-global-captures/"
	_path = _path.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_path + _stage)
	change_scene_to_file("res://Main.tscn")
	await _frames(45)
	_state = root.get_node("GameState")
	_camera = Camera3D.new()
	_camera.far = 24000
	_camera.near = 0.25
	_camera.fov = 66
	root.add_child(_camera)
	current_scene.get_node("TouchHUD").hide()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1120, 630)
	root.get_node("QualityManager").apply_preset(3)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if OS.get_environment("NOMAD_AUDIT_MODE") == "motion":
		_specs = JSON.parse_string(FileAccess.get_file_as_string(_path + "locais.json"))
		await _motion()
	else:
		if OS.get_environment("NOMAD_AUDIT_MODE") == "recapture":
			_specs = JSON.parse_string(FileAccess.get_file_as_string(_path + "locais.json"))
			await _capture(_specs[7])
			quit()
			return
		if _stage == "antes":
			_make_specs()
			_write_json(_path + "locais.json", _specs)
		else:
			_specs = JSON.parse_string(FileAccess.get_file_as_string(_path + "locais.json"))
			_add_reconstruction_views()
			_write_json(_path + "locais-depois.json", _specs)
		var extras := OS.get_environment("NOMAD_AUDIT_MODE") == "extras"
		var selected: Array = _specs.slice(16) if extras else _specs.slice(0, 16)
		for spec: Dictionary in selected:
			await _capture(spec)
		_write_json(_path + _stage + ("-extras" if extras else "-metrics") + ".json", _results)
	quit()

func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))

func _make_specs() -> void:
	var planet: Node3D = _state.space_system.planets[0]
	var site: Node3D = planet.get_node("AureliaLanding")
	_add(0, "01-vila-e-bosque", site.surface_at_offset(Vector2(24, 84)).normalized(), 5.0, 0.55, -0.08)
	_add(0, "02-floresta-distante", _pick(planet, "forest"), 2.9, 1.05, -0.12)
	_add(0, "03-campo-distante", _pick(planet, "open"), 2.4, 2.8, -0.10)
	_add(0, "04-montanhas", _pick(planet, "high"), 13.0, 0.4, -0.10)
	_add(0, "05-costa", _pick(planet, "coast"), 3.8, 0.9, -0.10)
	_add(0, "06-regiao-rochosa", _pick(planet, "rock"), 7.0, 2.1, -0.17)
	_add(0, "07-panorama", site.surface_at_offset(Vector2(52, 47)).normalized(), 92, 2.7, -0.51)
	_add(0, "08-orbita", Vector3(0.37, 0.71, 0.61).normalized(), 4450.0, 0.0, -1.56)
	for index in range(1, 5):
		planet = _state.space_system.planets[index]
		var slug: String = ["pyros", "glacius", "veridian", "dusthaven"][index - 1]
		var direction := _pick(planet, "forest" if index == 3 else "high")
		_add(index, "%02d-%s-superficie" % [7 + index * 2, slug], direction, 2.7, 0.75, -0.09)
		_add(index, "%02d-%s-panorama" % [8 + index * 2, slug], direction, 105, 2.6, -0.36)

func _add_reconstruction_views() -> void:
	var aurelia: Node3D = _state.space_system.planets[0]
	var canopy := _pick(aurelia, "forest")
	var coast := _pick(aurelia, "coast")
	var valley := _pick(aurelia, "open")
	var grove: Node3D = aurelia.get_node("AureliaLanding")
	_add(0, "17-copas-e-sub-bosque", canopy, 3.6, 0.1, 0.08)
	_add(0, "18-litoral-em-voo-baixo", coast, 26.0, 0.84, -0.34)
	_add(0, "19-voo-alto-transicao-de-biomas", valley, 184.0, 2.5, -0.49)
	for index in range(5):
		var planet: Node3D = _state.space_system.planets[index]
		var target: Vector3 = planet._landmark.direction
		if target == Vector3.ZERO:
			continue
		var offset := Vector3.UP.cross(target).normalized()
		var direction: Vector3 = (target * planet.data.radius + offset * 20.0).normalized()
		var aim := target.slide(direction).normalized()
		var yaw := Vector3.FORWARD.slide(direction).normalized().signed_angle_to(aim, direction)
		var slug: String = ["lapa-dos-ventos", "dentes-de-basalto", "agulhas-de-geada", "raizes-da-varzea", "janela-das-mesetas"][index]
		_add(index, "%02d-%s" % [20 + index, slug], direction, 4.5, yaw, -0.14)
	var village: Vector3 = grove.surface_at_offset(Vector2(35.0, 91.0)).normalized()
	var toward: Vector3 = grove.surface_at_offset(Vector2(29.0, 109.0)).normalized().slide(village).normalized()
	var yaw := Vector3.FORWARD.slide(village).normalized().signed_angle_to(toward, village)
	_add(0, "25-vale-do-trevo", village, 10.0, yaw, -0.36)
	var mire: Node3D = _state.space_system.planets[3]
	_add(3, "26-mata-umida", _pick(mire, "forest"), 5.0, 0.25, -0.12)


func _pick(planet: Node3D, mode: String) -> Vector3:
	var random := RandomNumberGenerator.new()
	random.seed = planet.data.seed_value + hash(mode)
	var choice := Vector3.UP
	var best := -INF
	for attempt in range(1300):
		var dir := Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1)).normalized()
		if dir.dot(Vector3(0.35, 0.70, 0.61)) < 0.15 or (planet.is_aurelia() and dir.angle_to(Vector3(0.18, 0.96, 0.21)) < 0.35):
			continue
		var height: float = planet.get_surface_radius_at_dir(dir) - planet.data.radius
		var biome: int = planet.get_biome(dir, height)
		var score := height if mode == "high" else -absf(height - 8.0) + (17.0 if biome == (1 if mode == "forest" else 0) else 0.0)
		if mode == "coast":
			score = -absf(height - planet.data.ocean_level_offset - 1.9)
		elif mode == "rock":
			score = -absf(height - planet.data.terrain_amplitude * 0.34)
		if score > best:
			best = score
			choice = dir
	return choice

func _add(index: int, label: String, direction: Vector3, altitude: float, yaw: float, pitch: float) -> void:
	var planet: Node3D = _state.space_system.planets[index]
	_specs.append({"index": index, "planet": planet.planet_name, "seed": planet.data.seed_value,
		"label": label, "direction": [direction.x, direction.y, direction.z], "altitude": altitude,
		"yaw": yaw, "pitch": pitch, "profile": "Econômico"})

func _capture(spec: Dictionary) -> void:
	var planet: Node3D = _state.space_system.planets[int(spec.index)]
	var vector: Array = spec.direction
	var up := Vector3(vector[0], vector[1], vector[2]).normalized()
	var player: CharacterBody3D = _state.player_node
	var heading := Vector3.FORWARD.slide(up).normalized().rotated(up, float(spec.yaw))
	var pitch: float = spec.pitch
	var look := heading * cos(pitch) + up * sin(pitch)
	player.global_position = planet.global_position + up * (planet.get_surface_radius_at_dir(up) + float(spec.altitude))
	player.global_basis = Basis.looking_at(heading, up)
	player.velocity = Vector3.ZERO
	await _frames(72)
	paused = true
	player.hide()
	var position: Vector3 = planet.global_position + up * (planet.get_surface_radius_at_dir(up) + float(spec.altitude))
	var state := planet.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	if spec.altitude < 210:
		var ground := state.intersect_ray(PhysicsRayQueryParameters3D.create(position + up * 180, position - up * 250, 1))
		if ground.get("collider") == planet:
			position = ground["position"] + up * float(spec.altitude)
	_camera.global_position = position
	_camera.look_at(position + look, up)
	_camera.make_current()
	await _frames(6)
	var elapsed := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	for i in range(24):
		await process_frame
		var tick := Time.get_ticks_usec()
		elapsed.append((tick - previous) / 1000.0)
		previous = tick
	elapsed.sort()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, roundi(960.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_LANCZOS)
	var result := image.save_webp(_path + _stage + "/" + spec.label + ".webp", true, 0.80)
	var life := planet.get_node("SurfaceLife")
	var instances := 0
	for node in life.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh:
			instances += maxi(0, node.multimesh.visible_instance_count)
	var row := {"label": spec.label, "p50_ms": elapsed[12], "p95_ms": elapsed[22], "tiles": life.get_child_count(), "instances": instances,
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "width": root.size.x, "height": root.size.y, "save": result}
	_results.append(row)
	print(row)
	player.show()
	paused = false

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _motion() -> void:
	var results: Array = []
	var player: CharacterBody3D = _state.player_node
	var ship: CharacterBody3D = _state.ship_node
	var quality: Node = root.get_node("QualityManager")
	for scenario: Array in [
		["vila-parado", 0, 2.0, "still"],
		["caminhada-floresta", 1, 1.8, "walk"],
		["caminhada-campo", 2, 1.8, "walk"],
		["caminhada-serra", 3, 1.8, "walk"],
		["voo-baixo", 1, 18.0, "low"],
		["voo-rapido", 1, 195.0, "fast"],
		["aproximacao", 0, 1280.0, "approach"],
		["desembarque", 0, 13.0, "landing"],
		["perfis-graficos", 0, 1.8, "quality"],
		["pyros", 8, 1.8, "walk"],
		["glacius", 10, 1.8, "walk"],
		["veridian", 12, 1.8, "walk"],
		["dusthaven", 14, 1.8, "walk"],
	]:
		var spec: Dictionary = _specs[scenario[1]]
		var planet: Node3D = _state.space_system.planets[int(spec.index)]
		var vector: Array = spec.direction
		var up := Vector3(vector[0], vector[1], vector[2]).normalized()
		if scenario[3] == "landing":
			up = Vector3(0.180171244, 0.960913302, 0.210199785)
		var forward := Vector3.FORWARD.slide(up).normalized().rotated(up, float(spec.yaw))
		var in_ship: bool = scenario[3] in ["low", "fast", "approach", "landing"]
		var p: Vector3 = planet.global_position + up * (planet.get_surface_radius_at_dir(up) + float(scenario[2]))
		var focus := ship if in_ship else player
		player.visible = not in_ship
		_state.set_control_mode(1 if in_ship else 0)
		focus.global_position = p
		focus.global_basis = Basis.looking_at(forward if scenario[3] != "approach" else -up, up if scenario[3] != "approach" else forward)
		focus.velocity = Vector3.ZERO
		if in_ship:
			ship.is_landed = false
			ship._current_speed = 0.0
			ship._climb_speed = 0.0
			ship.navigation_assist = false
		await _frames(50)
		var start := focus.global_position - planet.global_position
		if scenario[3] in ["low", "fast", "approach", "walk"]:
			Input.action_press("move_forward")
		var elapsed := PackedFloat64Array()
		var previous := Time.get_ticks_usec()
		var landed := false
		for frame in range(144):
			if scenario[3] == "quality" and frame % 36 == 0:
				quality.apply_preset([3, 0, 1, 2][frame / 36])
				Engine.max_fps = 0
			if scenario[3] == "landing" and frame == 18:
				ship.exit_ship()
				landed = ship.is_landed and _state.current_mode == 0
			await process_frame
			var tick := Time.get_ticks_usec()
			elapsed.append(float(tick - previous) / 1000.0)
			previous = tick
		Input.action_release("move_forward")
		if scenario[3] == "quality":
			quality.apply_preset(3)
			Engine.max_fps = 0
		elapsed.sort()
		var sum := 0.0
		for sample in elapsed:
			sum += sample
		var life := planet.get_node("SurfaceLife")
		var instances := 0
		for node in life.find_children("*", "MultiMeshInstance3D", true, false):
			if node.multimesh:
				instances += maxi(0, node.multimesh.visible_instance_count)
		var row := {"scenario": scenario[0], "frames": elapsed.size(), "mean_ms": sum / elapsed.size(),
			"p95_ms": elapsed[136], "max_ms": elapsed[-1], "fps": elapsed.size() * 1000.0 / sum,
			"distance": start.distance_to(focus.global_position - planet.global_position), "landed": landed,
			"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"triangles": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"tiles": life.get_child_count(), "instances": instances,
			"memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0}
		results.append(row)
		print(row)
		_write_json(_path + _stage + "-motion.json", results)
