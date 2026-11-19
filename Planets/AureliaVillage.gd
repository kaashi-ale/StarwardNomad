extends Node3D
## Vale do Trevo, a small timber settlement beside the survey trail.

const MODEL := preload("res://Planets/VillageMesh.gd")
const WALKER := preload("res://Planets/VillageWalker.gd")

var _planet: Node3D


func build(planet: Node3D) -> void:
	_planet = planet
	_build_house(Vector3(-12, 0, 0), Vector3(8.7, 4.15, 7.4), Color("#975e44"), Color("#ddbd83"))
	_build_house(Vector3(9.4, 0, -1.0), Vector3(8.0, 3.7, 6.7), Color("#486b62"), Color("#f0d1a8"))
	_build_house(Vector3(-5.3, 0, -15.0), Vector3(11.5, 4.5, 8.5), Color("#744d43"), Color("#e5cda2"))
	_build_well(Vector3(0.1, 0, 1.6))
	_build_entry_path()
	_build_gardens()
	_build_daily_props()
	_build_pasture(Vector3(11.5, 0, -18.0))
	_add_walker(Vector3(-2.6, 0, 7.5), Vector3(-8.9, 0, 6.2), "Lina",
		"Bem-vindo ao Vale do Trevo! O poço fica no meio da vila.", Color("#387a75"))
	_add_walker(Vector3(3.5, 0, -5.0), Vector3(2.0, 0, -12.0), "Tomé",
		"A gente montou o curral num lugar calmo. Passe lá para ver as vaquinhas.", Color("#a96643"))
	_add_walker(Vector3(6.8, 0, -13.0), Vector3(16.0, 0, -11.0), "Iara",
		"A de manchas castanhas é a Canela. A outra, a Lua, vive atrás dela.", Color("#826491"))
	_add_walker(Vector3(9.2, 0, -19.7), Vector3(14.2, 0, -19.1), "", "", Color("#865841"))
	_add_walker(Vector3(16.0, 0, -17.7), Vector3(13.5, 0, -14.9), "", "", Color("#403a3d"))


func _build_house(at: Vector3, dimensions: Vector3, shingles: Color, plaster: Color) -> void:
	var house := _solid(_ground(at))
	var mesh := MODEL.new()
	var half := dimensions * 0.5
	var wood := Color("#695046")
	var dark := Color("#443c3a")
	mesh.box(Vector3(0, -0.17, 0), Vector3(dimensions.x + 0.44, 0.90, dimensions.z + 0.36), Color("#8c8872"))
	mesh.box(Vector3(0, half.y, 0), dimensions, plaster)
	mesh.roof(Vector3(0, dimensions.y + 1.25, 0), Vector3(dimensions.x + 0.88, 2.62, dimensions.z + 0.76), shingles)
	mesh.box(Vector3(-half.x * 0.51, dimensions.y + 1.2, -half.z * 0.43), Vector3(0.70, 2.4, 0.84), Color("#8d7765"))
	mesh.box(Vector3(-half.x * 0.51, dimensions.y + 2.37, -half.z * 0.43), Vector3(0.86, 0.24, 0.99), dark)
	var facade := half.z + 0.046
	for side: float in [-1.0, 1.0]:
		mesh.box(Vector3(side * (half.x - 0.16), half.y, facade), Vector3(0.27, dimensions.y, 0.22), wood)
		mesh.box(Vector3(side * half.x * 0.52, 2.2, facade), Vector3(1.09, 1.24, 0.22), dark)
		mesh.box(Vector3(side * half.x * 0.52, 2.21, facade + 0.124), Vector3(0.78, 0.93, 0.045), Color("#d9bb78"))
		mesh.box(Vector3(side * half.x * 0.52, 2.21, facade + 0.15), Vector3(0.085, 0.96, 0.044), wood)
		mesh.box(Vector3(side * half.x * 0.52, 2.21, facade + 0.15), Vector3(0.80, 0.08, 0.044), wood)
		mesh.box(Vector3(side * half.x * 0.74, 2.83, facade), Vector3(0.21, 2.0, 0.13), wood, -side * 0.57)
		var window_x := side * half.x * 0.52
		for shutter_side: float in [-1.0, 1.0]:
			var shutter_x := window_x + shutter_side * 0.70
			mesh.box(Vector3(shutter_x, 2.22, facade + 0.055), Vector3(0.32, 1.04, 0.10), shingles.darkened(0.18))
			mesh.box(Vector3(shutter_x, 2.02, facade + 0.114), Vector3(0.30, 0.095, 0.06), wood)
		mesh.box(Vector3(window_x, 1.61, facade + 0.17), Vector3(1.22, 0.16, 0.34), wood.lightened(0.13))
		# Keep the roof edge and exposed rafters visible against the wall.
		mesh.box(Vector3(side * (half.x + 0.38), dimensions.y + 0.09, 0),
			Vector3(0.18, 0.23, dimensions.z + 0.90), wood)
		for i in range(5):
			var z := lerpf(-half.z + 0.42, half.z - 0.42, float(i) / 4.0)
			mesh.box(Vector3(side * (half.x + 0.12), dimensions.y - 0.02, z),
				Vector3(0.55, 0.20, 0.18), wood.darkened(0.12))
		var roof_slope := atan2(2.62, half.x + 0.44)
		var gable_width := Vector2(half.x + 0.51, 2.62).length()
		mesh.box(Vector3(side * (half.x + 0.44) * 0.51, dimensions.y + 1.23, half.z + 0.43),
			Vector3(gable_width, 0.15, 0.15), wood.lightened(0.18), -side * roof_slope)
	mesh.box(Vector3(0, dimensions.y - 0.15, facade), Vector3(dimensions.x, 0.28, 0.22), wood)
	mesh.box(Vector3(0, 1.21, facade + 0.06), Vector3(1.33, 2.42, 0.20), wood)
	mesh.box(Vector3(0, 1.17, facade + 0.18), Vector3(1.12, 2.30, 0.08), wood.lightened(0.11))
	for slat: float in [-0.36, -0.12, 0.12, 0.36]:
		mesh.box(Vector3(slat, 1.17, facade + 0.228), Vector3(0.021, 2.23, 0.015), dark)
	for hinge: float in [0.64, 1.72]:
		mesh.box(Vector3(-0.28, hinge, facade + 0.24), Vector3(0.47, 0.075, 0.05), dark)
	mesh.oval(Vector3(0.36, 1.13, facade + 0.24), Vector3(0.14, 0.14, 0.12), Color("#ddad61"))
	mesh.box(Vector3(0, 0.12, facade + 0.27), Vector3(1.83, 0.33, 0.84), Color("#a79a7f"))
	mesh.bake(house)
	_box_collision(house, Vector3(0, (dimensions.y - 0.5) * 0.5, 0), dimensions + Vector3(0, 0.50, 0))


func _build_well(at: Vector3) -> void:
	var well := _solid(_ground(at))
	var mesh := MODEL.new()
	var stone := Color("#858976")
	var wood := Color("#6a4d36")
	for i in range(10):
		var phase := TAU * i / 10.0
		mesh.oval(Vector3(cos(phase) * 0.94, 0.41, sin(phase) * 0.94), Vector3(0.80, 0.98, 0.72), stone.lightened(0.045 * (i % 3)))
	mesh.box(Vector3(0, 0.13, 0), Vector3(1.69, 0.14, 1.53), Color("#436d6a"))
	for side: float in [-1.0, 1.0]:
		mesh.box(Vector3(side * 1.00, 1.50, 0), Vector3(0.21, 2.97, 0.22), wood)
	mesh.roof(Vector3(0, 2.96, 0), Vector3(2.73, 1.08, 2.05), Color("#94624b"))
	mesh.bake(well)
	_box_collision(well, Vector3(0, 0.48, 0), Vector3(2.17, 0.96, 2.1))


func _build_entry_path() -> void:
	var mesh := MODEL.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 14087
	for row in range(19):
		for lane in range(3):
			var x := lane * 0.73 - 0.73 + 0.42 * sin(row * 0.28)
			var z := 3.1 + row * 0.69
			var at := _ground(Vector3(x, 0, z) + Vector3(rng.randf_range(-0.19, 0.19), 0, rng.randf_range(-0.11, 0.11)))
			var tint := Color("#a4a088").lerp(Color("#bca987"), rng.randf())
			mesh.oval(at + Vector3.UP * 0.017, Vector3(rng.randf_range(0.40, 0.72), 0.14, rng.randf_range(0.39, 0.68)), tint)
	mesh.bake(self, Vector3.ZERO)


func _build_gardens() -> void:
	var garden := _solid(Vector3.ZERO)
	var mesh := MODEL.new()
	var wood := Color("#81664b")
	for bed in range(2):
		var center := _ground(Vector3(-8.7 + bed * 3.7, 0, -6.5))
		mesh.box(center + Vector3.UP * 0.11, Vector3(2.65, 0.30, 3.9), Color("#66503e"))
		for side: float in [-1.0, 1.0]:
			mesh.box(center + Vector3(side * 1.29, 0.20, 0), Vector3(0.15, 0.28, 4.0), wood)
			mesh.box(center + Vector3(0, 0.20, side * 1.91), Vector3(2.68, 0.28, 0.15), wood)
		_box_collision(garden, center + Vector3.UP * 0.075, Vector3(2.70, 0.24, 4.0))
		for row in range(4):
			for column in range(3):
				var at := center + Vector3((column - 1) * 0.66, 0.32, (row - 1.5) * 0.80)
				var leaf := Color("#67884b").lightened(0.06 * float((row + column) % 3))
				mesh.oval(at + Vector3.UP * 0.09, Vector3(0.46, 0.31, 0.45), leaf)
				if bed == 1 and (row + column) % 2 == 0:
					mesh.oval(at + Vector3.UP * 0.23, Vector3(0.16, 0.14, 0.16), Color("#bf8252"))
	for x: float in [-10.7, -8.2, -5.7, -3.2]:
		var post := _ground(Vector3(x, 0, -8.8))
		mesh.box(post + Vector3.UP * 0.41, Vector3(0.17, 1.02, 0.17), wood)
	for x: float in [-9.45, -6.95, -4.45]:
		_fence_segment(garden, mesh, _ground(Vector3(x, 0, -8.8)), Vector3(2.53, 0.96, 0.15), wood)
	mesh.bake(garden)


func _build_daily_props() -> void:
	var props := _solid(Vector3.ZERO)
	var mesh := MODEL.new()
	var oak := Color("#9b7750")
	var bench := _ground(Vector3(-4.4, 0, 2.35))
	for side: float in [-1.0, 1.0]:
		mesh.box(bench + Vector3(side * 0.68, 0.29, 0), Vector3(0.15, 0.59, 0.48), oak.darkened(0.20))
		mesh.box(bench + Vector3(side * 0.68, 0.60, -0.19), Vector3(0.14, 1.03, 0.13), oak.darkened(0.23))
	mesh.box(bench + Vector3.UP * 0.54, Vector3(1.77, 0.13, 0.57), oak)
	mesh.box(bench + Vector3(0, 0.91, -0.21), Vector3(1.68, 0.20, 0.10), oak.lightened(0.08))
	_box_collision(props, bench + Vector3.UP * 0.28, Vector3(1.73, 0.58, 0.52))
	for offset: Vector3 in [Vector3(-8.41, 0, 4.05), Vector3(-7.69, 0, 3.61), Vector3(14.1, 0, 1.25)]:
		var at := _ground(offset)
		mesh.oval(at + Vector3.UP * 0.44, Vector3(0.66, 0.86, 0.66), oak.darkened(0.13))
		for ring: float in [0.20, 0.67]:
			mesh.oval(at + Vector3.UP * ring, Vector3(0.64, 0.084, 0.64), Color("#62594c"))
		mesh.oval(at + Vector3.UP * 0.84, Vector3(0.53, 0.10, 0.53), oak.lightened(0.09))
		_box_collision(props, at + Vector3.UP * 0.43, Vector3(0.57, 0.86, 0.57))
	mesh.bake(props)


func _build_pasture(center: Vector3) -> void:
	var pasture := _solid(Vector3.ZERO)
	var mesh := MODEL.new()
	var wood := Color("#91734e")
	for x: float in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
		for z: float in [-5, 5]:
			var at := _ground(center + Vector3(x, 0, z))
			mesh.box(at + Vector3.UP * 0.57, Vector3(0.22, 1.36, 0.25), wood)
	for x: float in [-7.5, 7.5]:
		for z: float in [-2.5, 0, 2.5]:
			var at := _ground(center + Vector3(x, 0, z))
			mesh.box(at + Vector3.UP * 0.57, Vector3(0.22, 1.36, 0.25), wood)
	for z: float in [5, -5]:
		for x: float in [-6, -3, 0, 3, 6]:
			if x == 0.0 and z == 5.0:
				continue
			var at := _ground(center + Vector3(x, 0, z))
			_fence_segment(pasture, mesh, at, Vector3(3.12, 1.1, 0.22), wood)
	for x: float in [-7.5, 7.5]:
		for z: float in [-3.75, -1.25, 1.25, 3.75]:
			var at := _ground(center + Vector3(x, 0, z))
			_fence_segment(pasture, mesh, at, Vector3(0.22, 1.1, 2.62), wood)
	var hay := _ground(center + Vector3(5.9, 0, -3.3))
	mesh.oval(hay + Vector3.UP * 0.57, Vector3(1.9, 1.3, 1.54), Color("#ccac62"))
	mesh.bake(pasture)


func _fence_segment(body: StaticBody3D, mesh: RefCounted, at: Vector3, size: Vector3, tint: Color) -> void:
	for height: float in [0.40, 0.93]:
		mesh.box(at + Vector3.UP * height, Vector3(size.x, 0.16, size.z), tint)
	_box_collision(body, at + Vector3.UP * 0.54, size)


func _add_walker(start: Vector3, finish: Vector3, resident: String, line: String, tint: Color) -> void:
	var walker := WALKER.new()
	if resident.is_empty():
		walker.name = "Vaquinha"
	else:
		walker.name = resident
	add_child(walker, true)
	walker.initialize(_ground(start) + Vector3.UP * 0.045, _ground(finish) + Vector3.UP * 0.045,
		resident, line, tint)


func _solid(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 32
	body.collision_mask = 0
	add_child(body)
	body.position = at
	return body


func _box_collision(parent: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	parent.add_child(hitbox)
	hitbox.position = at


func _ground(at: Vector3) -> Vector3:
	var world := to_global(at)
	var up := _planet.global_position.direction_to(world)
	var ray := PhysicsRayQueryParameters3D.create(world + up * 35.0, world - up * 35.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return at if hit.is_empty() else to_local(hit["position"])
