extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, description: String) -> void:
	print("PASS " if condition else "FAIL ", description)
	if not condition:
		failed += 1

func tap(hud: CanvasLayer, index: int, point: Vector2, active: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = active
	hud._input(event)

func control_point(control: Control, offset := Vector2.ZERO) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5 + offset)

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	change_scene_to_file("res://Main.tscn")
	await ticks(125)
	Engine.max_fps = 0
	var state := root.get_node("GameState")
	var planet: Node3D = state.space_system.planets[0]
	var player: CharacterBody3D = state.player_node
	var ship: CharacterBody3D = state.ship_node
	var entry: Node3D = planet.get_node("AureliaLanding")
	var forest := entry.get_node("BosqueDoArco") as StaticBody3D
	var hud := current_scene.get_node("TouchHUD") as CanvasLayer
	check(is_instance_valid(forest) and forest.get_child_count() >= 36, "woodland and colliders loaded in main scene")
	check(entry.has_node("ValeDoTrevo") and entry.has_node("AureliaStoneArch") and entry.has_node("AureliaSurveyGate"),
		"village, gate and arch preserved")
	var creatures := 0
	for child in planet.get_node("EcosystemRoot").get_children():
		if child.scene_file_path.ends_with("AlienCreature.tscn"):
			creatures += 1
	check(creatures >= 3, "original wildlife remains near start")
	var start := player.global_position
	check(player.is_on_floor() and state.can_board_ship, "starts on solid ground with boarding available")
	Input.action_press("move_forward")
	await ticks(38)
	Input.action_release("move_forward")
	await ticks(14)
	check(player.global_position.distance_to(start) > 2.0 and player.is_on_floor(), "movement and ground contact")
	player.global_position = start
	await ticks(14)
	player.try_board_ship()
	await ticks(3)
	check(state.current_mode == 1 and ship.is_landed, "boards the parked ship")
	ship.exit_ship()
	await ticks(50)
	check(state.current_mode == 0 and player.is_on_floor(), "disembarks on terrain")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("jump")
	await ticks(50)
	check(not player.is_on_floor() and state.jetpack_energy < 95.0, "sprint jump transitions into jetpack")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Input.action_release("jump")
	await ticks(230)
	check(player.is_on_floor(), "lands after jetpack")

	var camera := root.get_camera_3d()
	var heading := -camera.global_basis.z
	var joy := control_point(hud.get_node("JoystickZone/JoystickBase"), Vector2(0, -60))
	var fire := control_point(hud.get_node("FootControls/FireButton"))
	var look := root.get_visible_rect().size * Vector2(0.61, 0.48)
	tap(hud, 1, joy, true)
	tap(hud, 2, fire, true)
	tap(hud, 3, look, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = look + Vector2(100, 0)
	drag.relative = Vector2(100, 0)
	hud._input(drag)
	await ticks(8)
	check(state.mobile_move_vector.length() > 0.5 and state.mobile_fire_pressed and heading.dot(-camera.global_basis.z) < 0.97,
		"touch movement, fire and camera drag together")
	tap(hud, 1, joy, false)
	tap(hud, 2, fire, false)
	tap(hud, 3, look, false)
	check(state.mobile_move_vector.is_zero_approx() and not state.mobile_fire_pressed, "touch releases clear state")

	var collider := forest.get_child(0) as CollisionShape3D
	var direction := collider.global_basis.x
	var origin := collider.global_position + direction * 2.0
	var ray := PhysicsRayQueryParameters3D.create(origin, origin - direction * 4.0, 32)
	check(planet.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == forest, "forest trunk blocks physics ray")
	var local_site: Vector3 = entry.surface_at_offset(Vector2(12.5, 69))
	var up := local_site.normalized()
	var world := planet.global_position + local_site
	ray = PhysicsRayQueryParameters3D.create(world + up * 20.0, world - up * 20.0, 1)
	var ground := planet.get_world_3d().direct_space_state.intersect_ray(ray)
	player.global_position = ground.get("position", world) + up * 0.35
	await ticks(60)
	var previous_distance := player.global_position.distance_to(ship.global_position)
	var button := control_point(hud.get_node("FootControls/RecallButton"))
	tap(hud, 0, button, true)
	tap(hud, 0, button, false)
	await ticks(9)
	check(ship.is_recalling() and not ship.is_landed and not state.can_board_ship, "recall starts from the woodland clearing")
	for i in range(36):
		await ticks(36)
		if ship.is_landed:
			break
	var distance := ship.global_position.distance_to(player.global_position)
	check(ship.is_landed and not ship.is_recalling() and distance > 6.0 and distance < minf(37.0, previous_distance),
		"recall flies and lands in a nearby clear site")
	print("RECALL distance=", distance)
	quit(1 if failed else 0)
