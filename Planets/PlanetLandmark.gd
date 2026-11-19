extends Node3D
## One fixed, visitable formation per world. Placement reserves space in the scatter.

const RELAY := preload("res://Combat/AncientMonolith.tscn")
const NAMES := ["Lapa dos Ventos", "Dentes de Basalto", "Agulhas de Geada", "Raízes da Várzea", "Janela das Mesetas"]
var direction := Vector3.ZERO


func choose(planet: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.data.seed_value + 90417
	for attempt in range(240):
		var candidate := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		if planet.is_aurelia() and candidate.dot(Vector3(0.180171244, 0.960913302, 0.210199785)) > 0.58:
			continue
		var radius: float = planet.get_surface_radius_at_dir(candidate)
		if planet.data.has_ocean and radius < planet.data.radius + planet.data.ocean_level_offset + 12.0:
			continue
		var sample: Dictionary = planet.get_surface_point_and_normal(planet.global_position + candidate * radius)
		if candidate.dot(sample["normal"]) > 0.993:
			direction = candidate
			break


func build(planet: Node3D, point: Vector3) -> void:
	var kind: int = planet.data.landscape
	name = NAMES[kind]
	position = point - planet.global_position
	var front := (Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT).cross(direction).normalized()
	basis = Basis.looking_at(front, direction)
	var palette := [Color("#777567"), Color("#38323a"), Color("#79b1c1"), Color("#535847"), Color("#af7452")]
	var tint: Color = palette[kind]
	# Stone bays are independent of the heightfield and leave a clear passage.
	match kind:
		PlanetData.Landscape.AURELIA, PlanetData.Landscape.DUSTHAVEN:
			_outcrop(Vector3(-5.6, 0, 0), Vector3(3.0, 7.5, 3.1), tint, 2)
			_outcrop(Vector3(5.5, 0, 0), Vector3(3.1, 8.6, 3.0), tint.lightened(0.08), 8)
			_outcrop(Vector3(0.1, 5.8, 0.2), Vector3(8.3, 3.4, 2.75), tint, 12)
			_outcrop(Vector3(-8.3, 0, 1.9), Vector3(2.4, 3.7, 3.6), tint.darkened(0.12), 3)
		PlanetData.Landscape.PYROS, PlanetData.Landscape.GLACIUS:
			for tooth in range(7):
				var size := 4.5 + sin(tooth * 1.6) * 2.5 + tooth * 0.63
				_outcrop(Vector3((tooth - 3) * 3.0, 0.0, sin(tooth * 1.2) * 2.6), Vector3(1.6, size, 1.75), tint.lightened(tooth * 0.045), tooth)
		PlanetData.Landscape.VERIDIAN:
			for root in range(5):
				var x := (root - 2) * 4.0
				_outcrop(Vector3(x, 0.0, cos(root * 1.8) * 4.8), Vector3(1.8, 4.3 + sin(root * 1.1) * 3.5, 2.2), tint.lightened(root * 0.04), root)
			_outcrop(Vector3(-4, 2.8, 0), Vector3(4.6, 1.8, 2.15), tint, 28)
	var relay := RELAY.instantiate() as Node3D
	relay.position = Vector3(0.0, 0.0, -5.8)
	add_child(relay)
	relay.setup(planet.planet_name, "landmark_%d" % kind, NAMES[kind], planet.data.crystal_color)


func _outcrop(base: Vector3, size: Vector3, color: Color, seed_value: int) -> void:
	const SIDES := 7
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := PackedVector3Array()
	var profile := [0.82, 1.0, 0.82, 0.57]
	for level in range(profile.size()):
		var height := lerpf(-2.6, size.y, float(level) / 3.0)
		for side in range(SIDES):
			var angle := TAU * side / SIDES
			var width: float = profile[level] * rng.randf_range(0.78, 1.15)
			points.append(base + Vector3(cos(angle) * size.x * width + level * 0.22, height + rng.randf_range(-0.38, 0.38), sin(angle) * size.z * width))
	var triangles := PackedInt32Array()
	for ring in range(3):
		for side in range(SIDES):
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			triangles.append_array([a, b, a + SIDES, b, b + SIDES, a + SIDES])
	for side in range(1, SIDES - 1):
		triangles.append_array([0, side + 1, side, 3 * SIDES, 3 * SIDES + side, 3 * SIDES + side + 1])
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_smooth_group(-1)
	for i in range(triangles.size()):
		if i % 3 == 0:
			builder.set_color(color.lightened(rng.randf_range(-0.10, 0.13)))
		builder.add_vertex(points[triangles[i]])
	builder.generate_normals()
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.roughness = 0.94
	var model := MeshInstance3D.new()
	model.mesh = builder.commit()
	model.material_override = surface
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
	var body := StaticBody3D.new()
	body.collision_layer = 32
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	collider.shape = hull
	body.add_child(collider)
	add_child(body)
