extends RefCounted
## Compact vertex-colored meshes for the woodland. Each type uses a single surface.

var _surface := SurfaceTool.new()


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


func tree(variant: int, compact: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 271 + variant * 37
	var bark := [Color("#79604b"), Color("#796854"), Color("#655649")][variant] as Color
	var leaf := [Color("#59804a"), Color("#78944b"), Color("#416c52")][variant] as Color
	var height := [7.7, 6.3, 9.5][variant] as float
	var lean := Vector3([0.85, -0.63, 0.44][variant], 0, 0.24)
	var fork := Vector3(0, height * 0.52, 0) + lean * 0.45
	var crown_sides := 6 if compact else 8
	var crown_rows := 3 if compact else 4
	var tip := Vector3.UP * height + lean
	_tube([Vector3(0, -0.24, 0), Vector3(0.05, 0.57, 0.12), fork, tip], [0.50, 0.36, 0.23, 0.068], bark, 7)
	for i in range(4):
		var angle := TAU * i / 4.0 + rng.randf_range(-0.24, 0.24)
		var root := Vector3(cos(angle), 0, sin(angle))
		_tube([root * 0.86 - Vector3.UP * 0.18, root * 0.36 + Vector3.UP * 0.26, Vector3.UP * 0.76], [0.095, 0.14, 0.17], bark.darkened(0.06), 5)
	for i in range(5):
		var angle := i * 2.399 + variant * 0.88
		var direction := Vector3(cos(angle), 0, sin(angle))
		var outward := (2.0 if variant == 1 else 1.6) + rng.randf_range(-0.18, 0.36)
		var end := fork + direction * outward + Vector3.UP * (height * 0.24 + rng.randf_range(-0.5, 0.5))
		var start := fork - Vector3.UP * rng.randf_range(0.15, 0.87)
		_tube([start, start.lerp(end, 0.55) - Vector3.UP * 0.17, end], [0.14, 0.095, 0.039], bark, 5)
		var dimensions := Vector3(2.8, 2.05, 2.3) if variant == 1 else Vector3(2.45, 2.35, 2.15)
		_lobe(end + Vector3.UP * 0.45, dimensions * rng.randf_range(0.82, 1.15), leaf.lightened(rng.randf_range(-0.1, 0.16)), angle, crown_sides, crown_rows)
	_lobe(tip - Vector3.UP * 0.07, Vector3(3.1, 2.15 if variant == 1 else 3.15, 2.73), leaf.lightened(0.12), variant, crown_sides, crown_rows)
	return _finish()


func shrub() -> ArrayMesh:
	_lobe(Vector3(-0.37, 0.45, 0.04), Vector3(1.34, 1.03, 1.16), Color("#506b36"), 1.0, 6, 3)
	_lobe(Vector3(0.35, 0.44, 0.06), Vector3(1.29, 0.89, 1.0), Color("#678644"), 3.0, 6, 3)
	_lobe(Vector3(0.07, 0.67, -0.21), Vector3(1.36, 1.32, 1.16), Color("#758c47"), 0.0, 6, 3)
	return _finish()


func fern() -> ArrayMesh:
	for i in range(5):
		var angle := float(i) * 2.399
		var forward := Vector3(cos(angle), 0, sin(angle))
		var width := forward.cross(Vector3.UP)
		var start := Vector3.UP * 0.045
		var last := start
		var span := 0.68 + (i % 3) * 0.14
		for rib in range(4):
			var t := (rib + 1) / 5.0
			var bend := start + forward * span * t + Vector3.UP * sin(t * 2.45) * 0.49
			var joint := last.lerp(bend, 0.23)
			_triangle(last - width * 0.018, bend, last + width * 0.018, Color("#829d52"), true)
			var reach := sin(t * PI) * 0.22
			for side: float in [-1.0, 1.0]:
				var end := bend + width * reach * side + forward * 0.15
				_triangle(joint, bend + forward * 0.06, end, Color("#789b4e"), true)
			last = bend
		_triangle(last - width * 0.028, start + forward * span * 1.13 + Vector3.UP * 0.36,
			last + width * 0.028, Color("#92a758"), true)
	return _finish()


func flowers() -> ArrayMesh:
	for i in range(4):
		var angle := float(i) * 2.399
		var offset := Vector3(cos(angle), 0, sin(angle)) * 0.22
		var head := offset + Vector3.UP * (0.29 + 0.10 * (i % 3))
		_tube([offset * 0.50, head], [0.019, 0.013], Color("#637638"), 4)
		var petal := Color("#ecce8d") if i % 3 == 0 else Color("#d798a2")
		for p in range(5):
			var direction := Vector3(cos(p * TAU / 5.0), 0, sin(p * TAU / 5.0))
			var side := direction.cross(Vector3.UP)
			var tip := head + direction * 0.115 + Vector3.UP * 0.032
			_triangle(head, tip - side * 0.050, tip + side * 0.050, petal, true)
			var center := head + Vector3.UP * 0.027
			_triangle(center, center + direction * 0.04 - side * 0.019,
				center + direction * 0.04 + side * 0.019, Color("#c99558"), true)
	return _finish()


func stone() -> ArrayMesh:
	_lobe(Vector3.UP * 0.19, Vector3(1.71, 1.13, 1.36), Color("#767a6a"), 2.2, 8, 4)
	return _finish()


func log_model() -> ArrayMesh:
	var bark := Color("#6c5340")
	_tube([Vector3(-1.48, 0.36, -0.10), Vector3(-0.6, 0.38, 0.04), Vector3(0.56, 0.42, 0.08), Vector3(1.46, 0.39, 0)], [0.39, 0.36, 0.32, 0.28], bark, 9)
	_disk(Vector3(-1.49, 0.36, -0.10), 0.34, Color("#aa8056"), -1.0)
	_disk(Vector3(-1.506, 0.36, -0.10), 0.24, Color("#c39b69"), -1.0)
	_disk(Vector3(1.47, 0.39, 0), 0.23, Color("#b99165"), 1.0)
	_tube([Vector3(0.41, 0.46, -0.04), Vector3(0.46, 0.82, -0.14), Vector3(0.63, 0.91, -0.19)], [0.1, 0.077, 0.05], bark, 5)
	_lobe(Vector3(-0.48, 0.66, 0.08), Vector3(1.45, 0.27, 0.55), Color("#75824b"), 1.1, 7, 3)
	return _finish()


func _disk(center: Vector3, radius: float, tint: Color, sign_value: float) -> void:
	for i in range(9):
		var a := TAU * i / 9.0
		var b := TAU * (i + 1) / 9.0
		var first := center + Vector3(0, cos(a), sin(a)) * radius
		var second := center + Vector3(0, cos(b), sin(b)) * radius
		_triangle(center, first, second, tint, false, Vector3.RIGHT * sign_value)


func _tube(points: Array, widths: Array, tint: Color, sides: int) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var axis: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var reference := Vector3.RIGHT if absf(axis.x) < 0.91 else Vector3.UP
		var radial := axis.cross(reference).normalized()
		var tangent := axis.cross(radial)
		var ring := PackedVector3Array()
		for side in range(sides):
			var theta := TAU * side / sides
			var angle := (radial * cos(theta) + tangent * sin(theta)) * float(widths[i])
			ring.append(points[i] + angle * (1.0 + 0.10 * sin(theta * 3.0 + i)))
		rings.append(ring)
	for row in range(rings.size() - 1):
		for side in range(sides):
			var nxt := (side + 1) % sides
			var a := rings[row][side]
			var b := rings[row][nxt]
			var c := rings[row + 1][side]
			var d := rings[row + 1][nxt]
			var outward: Vector3 = (a + b) * 0.5 - points[row]
			var color := tint.darkened(0.085 * (side % 3))
			_triangle(a, c, b, color, false, outward)
			_triangle(b, c, d, color, false, outward)


func _lobe(center: Vector3, dimensions: Vector3, tint: Color, seed_value: float, sides := 8, rows := 4) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = sides
	mesh.rings = rows
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_surface.set_smooth_group(0)
	for index in indices:
		var point := vertices[index]
		# Ripple each crown consistently at its seams and poles.
		var shell := 1.0 + sin(point.x * 14.0 + point.z * 8.0 + seed_value) * sin(point.y * 10.0 + point.z * 9.0) * 0.15
		var color := tint.darkened(maxf(0.0, -point.y) * 0.42).lightened(maxf(0.0, point.y) * 0.16)
		_surface.set_color(color)
		_surface.add_vertex(center + point * dimensions * shell)
	_surface.set_smooth_group(-1)


func _triangle(a: Vector3, b: Vector3, c: Vector3, tint: Color, double_sided := false, outward := Vector3.ZERO) -> void:
	_surface.set_smooth_group(-1)
	_surface.set_color(tint)
	_surface.add_vertex(a)
	var reverse := not outward.is_zero_approx() and (c - a).cross(b - a).dot(outward) < 0.0
	_surface.add_vertex(c if reverse else b)
	_surface.add_vertex(b if reverse else c)
	if double_sided:
		_surface.add_vertex(a)
		_surface.add_vertex(c)
		_surface.add_vertex(b)


func _finish() -> ArrayMesh:
	_surface.generate_normals()
	_surface.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.metallic_specular = 0.13
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_surface.set_material(material)
	return _surface.commit()
