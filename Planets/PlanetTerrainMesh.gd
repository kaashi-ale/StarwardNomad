extends RefCounted
## Shared cube-sphere mesh builder. Face boundaries sample the same continuous normal field.


func build(planet: Node3D, resolution: int, orbital := false, staggered := false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var face_size := resolution * resolution
	vertices.resize(face_size * 6)
	normals.resize(vertices.size())
	colors.resize(vertices.size())
	var faces: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for face_index in range(faces.size()):
		if staggered:
			await planet.get_tree().process_frame
		var normal := faces[face_index]
		var horizontal := Vector3(normal.y, normal.z, normal.x)
		var vertical := normal.cross(horizontal)
		var base := face_index * face_size
		for y in range(resolution):
			for x in range(resolution):
				var cube := normal + horizontal * (2.0 * x / (resolution - 1) - 1.0) + vertical * (2.0 * y / (resolution - 1) - 1.0)
				var direction := _cube_to_sphere(cube)
				var radius: float = planet.get_surface_radius_at_dir(direction)
				var index := base + y * resolution + x
				var display_radius: float = maxf(radius, planet.data.radius + planet.data.ocean_level_offset) if orbital and planet.data.has_ocean else radius
				vertices[index] = direction * display_radius
				colors[index] = Color.WHITE
		for y in range(resolution):
			for x in range(resolution):
				var index := base + y * resolution + x
				var tangent := vertices[base + y * resolution + mini(x + 1, resolution - 1)] - vertices[base + y * resolution + maxi(x - 1, 0)]
				var bitangent := vertices[base + mini(y + 1, resolution - 1) * resolution + x] - vertices[base + maxi(y - 1, 0) * resolution + x]
				var direction := vertices[index].normalized()
				var normal_at_vertex := tangent.cross(bitangent).normalized()
				if not orbital and (x == 0 or y == 0 or x == resolution - 1 or y == resolution - 1):
					normal_at_vertex = planet.get_surface_point_and_normal(planet.global_position + direction * planet.data.radius)["normal"]
				normals[index] = normal_at_vertex
				var elevation: float = planet.get_surface_radius_at_dir(direction) - planet.data.radius if orbital else vertices[index].length() - planet.data.radius
				colors[index] = planet.landscape.tint(direction, elevation, 1.0 - normal_at_vertex.dot(direction), orbital)
				if x < resolution - 1 and y < resolution - 1:
					indices.append(index)
					indices.append(index + resolution)
					indices.append(index + 1)
					indices.append(index + 1)
					indices.append(index + resolution)
					indices.append(index + resolution + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _cube_to_sphere(p: Vector3) -> Vector3:
	var x2: float = p.x * p.x
	var y2: float = p.y * p.y
	var z2: float = p.z * p.z
	var sx: float = p.x * sqrt(maxf(0.0, 1.0 - y2 * 0.5 - z2 * 0.5 + (y2 * z2) / 3.0))
	var sy: float = p.y * sqrt(maxf(0.0, 1.0 - z2 * 0.5 - x2 * 0.5 + (z2 * x2) / 3.0))
	var sz: float = p.z * sqrt(maxf(0.0, 1.0 - x2 * 0.5 - y2 * 0.5 + (x2 * y2) / 3.0))
	return Vector3(sx, sy, sz).normalized()
