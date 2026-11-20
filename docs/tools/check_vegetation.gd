extends SceneTree
## Replay the same planet-local flight and inspect the actual MultiMesh slots.
## NOMAD_STAGE, NOMAD_PLANET (0,2,3), NOMAD_PRESET (3,0), NOMAD_AUDIT_DIR.

var planet: Node3D
var life: Node3D
var ship: CharacterBody3D
var camera: Camera3D
var start: Vector3
var forward: Vector3
var right: Vector3
var base: String
var previous := {}
var known := {}
var created := 0
var removed := 0
var rebuilt := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i in range(45):
		await physics_frame
	var state := root.get_node("GameState")
	var index := int(OS.get_environment("NOMAD_PLANET"))
	var preset := int(OS.get_environment("NOMAD_PRESET"))
	var stage := OS.get_environment("NOMAD_STAGE")
	var output := OS.get_environment("NOMAD_AUDIT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	base = output.path_join("%s-%d-%d" % [stage, index, preset])
	root.get_node("QualityManager").apply_preset(preset)
	Engine.max_fps = 0
	planet = state.space_system.planets[index]
	life = planet.get_node("SurfaceLife")
	ship = state.ship_node
	ship.board_ship(state.player_node)
	ship.is_landed = false
	ship.set_physics_process(false)
	ship.set_process(false)
	ship.hide()
	current_scene.get_node("TouchHUD").hide()
	camera = Camera3D.new()
	camera.fov = 66
	camera.far = 12000
	ship.add_child(camera)
	camera.make_current()
	start = _woodland()
	forward = Vector3.FORWARD.slide(start).normalized()
	right = forward.cross(start)
	var results := {}
	var shift_count := 0
	var planet_origin := planet.global_position
	var reference := {}
	var last_trees := {}
	var last_cover := {}
	for phase: String in ["warmup", "hover", "yaw", "micro", "out", "high", "return", "settled"]:
		var frames := 150 if phase in ["warmup", "hover", "out", "return"] else 90
		var times := PackedFloat64Array()
		var last := Time.get_ticks_usec()
		var churn := Vector3i(created, removed, rebuilt)
		var cover_changes := 0
		var high_far := 0
		var vanished := 0
		var appeared := 0
		var nearest_birth := INF
		var visible := {}
		var counts := {}
		var cover := {}
		for tick in range(frames):
			var t := float(tick) / (frames - 1)
			var along := 0.0
			var side := 0.0
			var height := 5.0
			var yaw := 0.0
			if phase == "yaw":
				yaw = sin(t * TAU) * 0.85
			elif phase == "micro":
				along = sin(t * TAU * 2.0) * 7.0
				side = sin(t * TAU) * 6.0
			elif phase == "out":
				along = 480.0 * t
			elif phase == "high":
				along = 480.0
				height += 270.0 * sin(PI * t)
			elif phase == "return":
				along = 480.0 * (1.0 - t)
			var up: Vector3 = (start * planet.data.radius + forward * along + right * side).normalized()
			var surface: Vector3 = up * planet.get_surface_radius_at_dir(up)
			if is_instance_valid(planet._terrain_collider):
				var origin := planet.to_global(surface)
				var ray := PhysicsRayQueryParameters3D.create(origin + up * 80.0, origin - up * 80.0, 1)
				var hit := planet.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.get("collider") == planet:
					surface = planet.to_local(hit.position)
			var point := surface + up * height
			var old: Vector3 = planet.to_local(ship.global_position)
			ship.velocity = (point - old) * 30.0 if tick > 0 else Vector3.ZERO
			ship.global_position = planet.to_global(point)
			var heading := forward.slide(up).normalized().rotated(up, yaw)
			camera.global_basis = Basis.looking_at((heading - up * (0.14 + (height - 5.0) / 650.0)).normalized(), up)
			await process_frame
			if planet_origin.distance_to(planet.global_position) > 100:
				shift_count += 1
			planet_origin = planet.global_position
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			_track_tiles()
			if tick % 10 == 0 or tick == frames - 1:
				cover = {}
				visible = _trees(point, counts, cover)
				if phase == "high" and height > 250:
					high_far = maxi(high_far, counts.far)
				for id in cover:
					if not last_cover.has(id) and cover[id] < 35:
							cover_changes += 1
				for id in last_cover:
					if not cover.has(id) and point.distance_to(Vector3(id) / 20.0) < 35.0:
							cover_changes += 1
				last_cover = cover
				for id: Vector3i in visible:
					if not last_trees.has(id):
						nearest_birth = minf(nearest_birth, visible[id])
						if visible[id] < 65.0:
							appeared += 1
				for id: Vector3i in last_trees:
					if not visible.has(id) and point.distance_to(Vector3(id) / 20.0) < 65.0:
						vanished += 1
				last_trees = visible
			if phase in ["hover", "yaw", "micro", "high", "settled"] and tick == (frames / 2 if phase in ["yaw", "high"] else frames - 1):
				await RenderingServer.frame_post_draw
				var frame := root.get_texture().get_image()
				frame.resize(640, 360, Image.INTERPOLATE_LANCZOS)
				frame.save_webp(base + "-" + phase + ".webp", true, 0.76)
			last = Time.get_ticks_usec()
		if phase == "hover":
			for id: Vector3i in visible:
				if visible[id] < 65.0:
					reference[id] = true
		var missing := 0
		for id in reference:
			if not visible.has(id):
				missing += 1
		times.sort()
		var delta := Vector3i(created, removed, rebuilt) - churn
		results[phase] = {"created":delta.x,"removed":delta.y,"rebuilt":delta.z,"tiles":life._tiles.size(),"trees":visible.size(),"farther_230m":counts.far,"all_instances":counts.all,"near_birth":appeared,"near_loss":vanished,"cover_changes_35m":cover_changes,"high_far":high_far,"closest_birth_m":nearest_birth if is_finite(nearest_birth) else -1.0,"missing_ref":missing,"reference":reference.size(),"p50_ms":times[frames/2],"p95_ms":times[int(frames*0.95)],"max_ms":times[-1],"over_50ms":times.size()-times.bsearch(50.0)}
	if stage == "depois" and preset == 3:
		# Look back down on the same woodland, independently of the outbound biome.
		ship.global_position = planet.to_global(start * (planet.get_surface_radius_at_dir(start) + 175.0))
		ship.velocity = Vector3.ZERO
		camera.global_basis = Basis.looking_at((forward * 0.32 - start).normalized(), forward)
		for tick in range(105):
			await process_frame
		await RenderingServer.frame_post_draw
		var overhead := root.get_texture().get_image()
		overhead.resize(800, 450, Image.INTERPOLATE_LANCZOS)
		overhead.save_webp(base + "-copas.webp", true, 0.82)
	var file := FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"direction":str(start),"shifts":shift_count,"phases":results},"\t"))
	print(base, " ", results["settled"])
	if stage == "depois":
		for phase: String in ["hover", "yaw", "micro", "out", "return", "settled"]:
			var sample: Dictionary = results[phase]
			if sample.near_loss > 0 or sample.near_birth > 0:
				push_error("Canopy changed within 65 m during " + phase)
				quit(1)
				return
		if reference.is_empty() or results.settled.missing_ref > 0 or results.high.high_far == 0:
			push_error("Missing near reference or distant canopy")
			quit(1)
			return
	quit()

func _woodland() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.data.seed_value
	for attempt in range(20000):
		# Cross the +X/+Z face boundary on the outbound or lateral leg.
		var up := Vector3(1.0, rng.randf_range(-0.52, 0.52), rng.randf_range(0.965, 1.035)).normalized()
		var elevation: float = planet.get_surface_radius_at_dir(up) - planet.data.radius
		if planet.get_biome(up, elevation) == 1 and elevation > planet.data.ocean_level_offset + 9.0:
			return up
	return Vector3(1,0,1).normalized()

func _track_tiles() -> void:
	var next := {}
	for key in life._tiles:
		var id: int = life._tiles[key].get_instance_id()
		next[key] = id
		if previous.get(key, -1) != id:
			created += 1
			if known.has(key):
				rebuilt += 1
			known[key] = true
	for key in previous:
		if not next.has(key):
			removed += 1
	previous = next

func _trees(point: Vector3, counts: Dictionary, cover: Dictionary) -> Dictionary:
	var trees := {}
	counts.far = 0
	counts.all = 0
	for tile: MultiMeshInstance3D in life._tiles.values():
		if not tile.is_visible_in_tree():
			continue
		var batch := tile.multimesh
		var count := batch.visible_instance_count
		if count < 0:
			count = batch.instance_count
		counts.all += count
		for node in tile.get_children():
			if node is MultiMeshInstance3D and node.visible:
				var cc := maxi(0, node.multimesh.visible_instance_count)
				counts.all += cc
				var anchor: Vector3 = tile.position + node.position
				for j in range(cc):
					var pos: Vector3 = anchor + node.multimesh.get_instance_transform(j).origin
					cover[Vector3i((pos * 20.0).round())] = point.distance_to(pos)
		for i in range(count):
			var origin: Vector3 = tile.position + batch.get_instance_transform(i).origin
			var dist := point.distance_to(origin)
			trees[Vector3i((origin * 20.0).round())] = dist
			if dist > 230.0:
				counts.far += 1
	return trees
