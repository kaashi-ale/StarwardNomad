extends Node3D
## Dunes, copper fans and the remains of a survey gate around the first landing site.

const FOREST := preload("res://Planets/AureliaForest.gd")
const VILLAGE := preload("res://Planets/AureliaVillage.gd")
const VILLAGE_CENTER := FOREST.VILLAGE
const MONOLITH := preload("res://Combat/AncientMonolith.tscn")

var _planet: Node3D
var _origin: Vector3
var _right: Vector3
var _forward: Vector3


func build(planet: Node3D, up: Vector3) -> void:
	_planet = planet
	_right = Vector3.RIGHT.cross(up).normalized()
	_forward = up.cross(_right)
	_origin = up * _planet.get_surface_radius_at_dir(up)
	_build_grove.call_deferred()
	_build_gate()
	_build_stone_arch()
	_build_village.call_deferred()
	_build_forest.call_deferred()


func is_forest_direction(direction: Vector3) -> bool:
	var up := _origin.normalized()
	var projection := direction.dot(up)
	if projection < 0.95:
		return false
	var point := direction * (_origin.length() / projection)
	return FOREST.contains_offset(Vector2(point.dot(_right), point.dot(_forward)))


func _build_forest() -> void:
	await get_tree().physics_frame
	var forest := FOREST.new()
	forest.name = "BosqueDoArco"
	forest.collision_layer = 32
	forest.collision_mask = 0
	add_child(forest)
	forest.position = surface_at_offset(FOREST.CENTER)
	forest.build(self, _planet)


func village_direction() -> Vector3:
	return surface_at_offset(VILLAGE_CENTER).normalized()


func _build_village() -> void:
	await get_tree().physics_frame
	var point := surface_at_offset(VILLAGE_CENTER)
	var village := VILLAGE.new()
	village.name = "ValeDoTrevo"
	add_child(village)
	village.transform = Transform3D(_surface_basis(point), point)
	village.build(_planet)


func _build_grove() -> void:
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 1042
	var rock := SphereMesh.new()
	rock.radial_segments = 5
	rock.rings = 2
	var fan := CylinderMesh.new()
	fan.top_radius = 0.12
	fan.bottom_radius = 0.52
	fan.height = 1.0
	fan.radial_segments = 6
	var rock_batch := _batch(rock, 108)
	var fans := _batch(fan, 150)
	var outcrops := StaticBody3D.new()
	outcrops.name = "OutcropColliders"
	outcrops.collision_layer = 32
	outcrops.collision_mask = 0
	add_child(outcrops)
	var stone_count := 0
	for i in range(108):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(13.0, 130.0)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		if absf(offset.x + 2.0) < 6.0 and offset.y > 0.0 and offset.y < 45.0:
			offset.x += 9.0
		var size := rng.randf_range(0.4, 2.5)
		var tint := Color("#354447").lerp(Color("#827260"), rng.randf())
		if FOREST.contains_offset(offset) or offset.distance_to(VILLAGE_CENTER) < 29.0:
			continue
		var point := _grounded_offset(offset, space)
		if i % 8 == 0:
			size *= 2.4
		var orientation := _surface_basis(point).rotated(point.normalized(), angle)
		var dimensions := Vector3(size * 1.45, size, size * 0.76)
		var center := point + orientation.y * size * 0.15
		rock_batch.set_instance_transform(stone_count, Transform3D(orientation * Basis.from_scale(dimensions), center))
		if size > 3.6:
			var vertices: PackedVector3Array = rock.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for index in range(vertices.size()):
				vertices[index] *= dimensions
			var hull := ConvexPolygonShape3D.new()
			hull.points = vertices
			var collider := CollisionShape3D.new()
			collider.shape = hull
			outcrops.add_child(collider)
			collider.transform = Transform3D(orientation, center)
		rock_batch.set_instance_color(stone_count, tint)
		stone_count += 1
	rock_batch.visible_instance_count = stone_count

	var fan_count := 0
	for _i in range(50):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(15.0, 103.0)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var height := rng.randf_range(0.55, 2.7)
		var is_open := not FOREST.contains_offset(offset) and offset.distance_to(VILLAGE_CENTER) >= 25.0
		var point := _grounded_offset(offset, space) if is_open else Vector3.ZERO
		for blade in range(3):
			var tint := Color("#a94d32").lerp(Color("#efaf63"), rng.randf())
			if not is_open:
				continue
			var local_rotation := Basis(Vector3.UP, angle + blade * TAU / 3.0) * Basis(Vector3.FORWARD, 0.49)
			var orientation := _surface_basis(point) * local_rotation
			var dimensions := Vector3(height * 0.75, height, height * 0.18)
			fans.set_instance_transform(fan_count, Transform3D(orientation * Basis.from_scale(dimensions), point + orientation.y * height * 0.46))
			fans.set_instance_color(fan_count, tint)
			fan_count += 1
	fans.visible_instance_count = fan_count


func _grounded_offset(offset: Vector2, space: PhysicsDirectSpaceState3D) -> Vector3:
	var local := surface_at_offset(offset)
	var up := local.normalized()
	var world := to_global(local)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(world + up * 29.0, world - up * 29.0, 1))
	return local if hit.is_empty() else to_local(hit["position"])


func _build_stone_arch() -> void:
	var point := surface_at_offset(FOREST.ARCH)
	var arch := StaticBody3D.new()
	arch.name = "AureliaStoneArch"
	arch.collision_layer = 32
	arch.collision_mask = 0
	add_child(arch)
	arch.transform = Transform3D(_surface_basis(point), point)

	var stone := SphereMesh.new()
	stone.radial_segments = 8
	stone.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	var rock_surface := SurfaceTool.new()
	rock_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	rock_surface.set_smooth_group(-1)
	var arrays := stone.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(7):
		var angle := float(i) * PI / 6.0
		var offset := Vector3(cos(angle) * (6.0 + sin(angle * 2.4) * 0.5), sin(angle) * 9.65, sin(angle * 2.0) * 0.90)
		var scale := Vector3(5.5, 8.2, 5.5) if i == 0 or i == 6 else Vector3(6.15, 6.7, 4.65)
		var tilt := Basis(Vector3.BACK, angle * 0.8)
		var vertices := PackedVector3Array()
		for vertex in source:
			var weathering := 1.0 + 0.12 * sin(vertex.x * 11.0 + vertex.y * 9.0 + i) * cos(vertex.z * 10.0 + i)
			vertices.append(tilt * (vertex * scale * weathering) + offset)
		for index in indices:
			var rock_tint := Color("#5e6858").lerp(Color("#a2977c"), smoothstep(0.0, 11.8, vertices[index].y))
			var vertex := vertices[index]
			var moisture := sin(vertex.x * 0.81 + vertex.z) * cos(vertex.z * 1.15 - vertex.y * 0.29)
			var moss := smoothstep(0.05, 0.73, moisture + source[index].y * 0.49) * 0.76
			rock_surface.set_color(rock_tint.darkened(0.065 * float(i % 3)).lerp(Color("#667844"), moss))
			rock_surface.add_vertex(vertices[index])
		var rock_shape := ConvexPolygonShape3D.new()
		rock_shape.points = vertices
		var hitbox := CollisionShape3D.new()
		hitbox.shape = rock_shape
		arch.add_child(hitbox)
	rock_surface.generate_normals()
	rock_surface.set_material(material)
	var model := MeshInstance3D.new()
	model.mesh = rock_surface.commit()
	arch.add_child(model)


func _build_gate() -> void:
	var point := surface_at_offset(Vector2(-2.0, 36.0))
	var gate := StaticBody3D.new()
	gate.name = "AureliaSurveyGate"
	gate.collision_layer = 32
	gate.collision_mask = 0
	add_child(gate)
	gate.transform = Transform3D(_surface_basis(point), point)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#263e49")
	stone.roughness = 0.83
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color("#b46c42")
	copper.roughness = 0.54
	for side: float in [-1.0, 1.0]:
		_gate_block(gate, Vector3(side * 4.0, 0.6, 0), Vector3(3.1, 2.7, 4.2), 0.0, stone, true)
		_gate_block(gate, Vector3(side * 3.65, 4.3, 0), Vector3(2.0, 7.6, 2.8), side * 0.22, stone, true)
		_gate_block(gate, Vector3(side * 3.65, 4.3, 1.43), Vector3(0.26, 6.5, 0.18), side * 0.22, copper)
	_gate_block(gate, Vector3(0, 8.25, 0), Vector3(6.3, 1.35, 2.1), 0.0, stone, true)
	_gate_block(gate, Vector3(0, 8.15, 1.07), Vector3(3.3, 0.28, 0.17), 0.0, copper)

	var relay := MONOLITH.instantiate() as StaticBody3D
	add_child(relay)
	var relay_point := surface_at_offset(Vector2(-2.0, 39.0))
	relay.transform = Transform3D(_surface_basis(relay_point), relay_point - relay_point.normalized() * 0.12)
	relay.setup(_planet.planet_name, "survey_gate", "Relé do Pórtico", Color("#73f5e0"))


func _gate_block(gate: StaticBody3D, offset: Vector3, size: Vector3, tilt: float, material: Material, solid := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	gate.add_child(piece)
	piece.position = offset
	piece.rotation.z = tilt
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		gate.add_child(collider)
		collider.transform = piece.transform


func _batch(mesh: PrimitiveMesh, count: int) -> MultiMesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.88
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = count
	var display := MultiMeshInstance3D.new()
	display.multimesh = instances
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.visibility_range_end = 175.0 * QualityManager.detail_distance_multiplier
	add_child(display)
	return instances


func surface_at_offset(offset: Vector2) -> Vector3:
	var direction := (_origin + _right * offset.x + _forward * offset.y).normalized()
	return direction * _planet.get_surface_radius_at_dir(direction)


func _surface_basis(point: Vector3) -> Basis:
	var up := point.normalized()
	return Basis.looking_at(_forward.slide(up), up)
