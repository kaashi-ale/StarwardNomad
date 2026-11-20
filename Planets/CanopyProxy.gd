extends RefCounted
## Opaque, single-surface crown and trunk fitted to the source model bounds.
static func lod_at(distance: float, previous: int, profile: float) -> int:
	if distance < 18.0 + 39.0 * profile + (15.0 if previous == 0 else 0.0):
		return 0
	if distance < compact_range(profile) + (30.0 if previous <= 1 else 0.0):
		return 1
	return 2


static func compact_range(profile: float) -> float:
	return 70.0 + 88.0 * profile


static func build(source: Mesh, leaves: Color, pine: bool, stone := false) -> ArrayMesh:
	var bounds := source.get_aabb()
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := bounds.get_center()
	var base := Vector3(center.x, bounds.position.y, center.z)
	if not stone:
		_shell(mesh, base, bounds.size, [Vector2(0, 0.045), Vector2(0.66, 0.025)], Color("#665749"))
	var rings := [Vector2(0.39, 0.26), Vector2(0.57, 0.48), Vector2(0.85, 0.42), Vector2(1, 0.08)]
	if pine:
		rings = [Vector2(0.22, 0.36), Vector2(0.34, 0.46), Vector2(0.61, 0.30), Vector2(1.0, 0.01)]
	elif stone:
		rings = [Vector2(0, 0.42), Vector2(0.55, 0.49), Vector2(0.93, 0.29), Vector2(1, 0.08)]
	_shell(mesh, base, bounds.size, rings, leaves)
	mesh.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.set_material(material)
	return mesh.commit()


static func _shell(mesh: SurfaceTool, base: Vector3, size: Vector3, rings: Array, tint: Color) -> void:
	var prev := PackedVector3Array()
	for level in range(rings.size()):
		var ring := PackedVector3Array()
		for side in range(6):
			var angle := TAU * side / 6.0
			var r: Vector2 = rings[level]
			ring.append(base + Vector3(cos(angle)*r.y, r.x, sin(angle)*r.y) * size)
		mesh.set_color(tint.darkened(0.13 * (1.0 - float(level) / rings.size())))
		if not prev.is_empty():
			for i in range(6):
				var j := (i + 1) % 6
				for vertex: Vector3 in [prev[i], prev[j], ring[i], prev[j], ring[j], ring[i]]:
					mesh.add_vertex(vertex)
		prev = ring
	for i in range(1, 5):
		for vertex: Vector3 in [prev[0], prev[i], prev[i+1]]:
			mesh.add_vertex(vertex)
