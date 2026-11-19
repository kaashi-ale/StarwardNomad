extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failed += 1

func walk_to(player: CharacterBody3D, state: Node, anchor: Node3D, target: Vector3, precise := 0.90) -> bool:
	for tick in range(380):
		var up := player.up_direction
		var toward := (anchor.to_global(target) - player.global_position).slide(up)
		if toward.length() < precise:
			state.mobile_move_vector = Vector2.ZERO
			return true
		var forward: Vector3 = player.get_node("CameraRig").get_horizontal_forward(up)
		var right := forward.cross(up).normalized()
		var direction := toward.normalized()
		state.mobile_move_vector = Vector2(direction.dot(right), direction.dot(forward))
		await physics_frame
	state.mobile_move_vector = Vector2.ZERO
	print("blocked at ", player.global_position, " expected ", target)
	return false

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await ticks(125)
	Engine.max_fps = 0
	var state := root.get_node("GameState")
	var quality := root.get_node("QualityManager")
	var planet: Node3D = state.space_system.planets[0]
	var landing: Node3D = planet.get_node("AureliaLanding")
	var explorer: CharacterBody3D = state.player_node
	var ship: CharacterBody3D = state.ship_node
	check(explorer.is_on_floor() and state.can_board_ship, "ship and astronaut start on stable ground")
	var trail: Script = load("res://Planets/AureliaForest.gd")
	var village: Node3D = landing.get_node("ValeDoTrevo")
	var start := planet.to_local(explorer.global_position)
	for quality_preset: int in [3, 0]:
		quality.apply_preset(quality_preset)
		Engine.max_fps = 0
		explorer.global_position = planet.to_global(start)
		await ticks(52)
		for y: float in [8.0, 21.0, 34.0, 46.0, 55.0, 61.0, 68.0, 78.0, 89.0, 97.0]:
			var position: Vector3 = landing.surface_at_offset(Vector2(trail.trail_x(y), y))
			check(await walk_to(explorer, state, planet, position),
				"walks to trail %d, profile %d" % [int(y), quality_preset])
		check(explorer.global_position.distance_to(village.global_position) < 14.0, "arrives in village on foot")
	var residents := 0
	var cows := 0
	for node in village.get_children():
		if node.is_in_group("interactables"):
			residents += 1
		elif node.name.begins_with("Vaquinha"):
			cows += 1
	check(residents == 3 and cows == 2, "resident and cow counts preserved")
	var lina := village.get_node("Lina") as Node3D
	check(await walk_to(explorer, state, lina, Vector3.ZERO, 2.1), "approaches Lina without teleporting")
	await ticks(10)
	check(state.current_interactable == lina, "location interaction registered")
	explorer.try_interact()
	check(current_scene.get_node("TouchHUD/NotificationLabel").text.contains("Vale do Trevo"), "dialogue remains functional")
	var arch := landing.get_node("AureliaStoneArch") as StaticBody3D
	var ray := PhysicsRayQueryParameters3D.create(arch.to_global(Vector3(0, 16, 0)), arch.to_global(Vector3(0, 3, 0)), 32)
	check(planet.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == arch, "solid arch crown")
	var house := village.get_child(0) as StaticBody3D
	ray = PhysicsRayQueryParameters3D.create(house.to_global(Vector3(0, 15, 0)), house.to_global(Vector3(0, -1, 0)), 32)
	check(planet.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == house, "house has collision")
	ship.recall_ship()
	await ticks(10)
	check(ship.is_recalling(), "starts recall near village")
	for step in range(35):
		await ticks(34)
		if ship.is_landed:
			break
	var distance := ship.global_position.distance_to(explorer.global_position)
	check(ship.is_landed and distance < 37 and distance > 6, "recall lands in clearing near village")
	print("RECALL ", distance)
	quit(1 if failed > 0 else 0)
