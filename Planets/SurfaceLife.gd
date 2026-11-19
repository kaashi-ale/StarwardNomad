extends Node3D
## Small, deterministic vegetation tiles around the observer on a cube sphere.

const TILE_SIZE := 78.0
const MEADOW_SHADER := preload("res://Planets/MeadowBlades.gdshader")
var _planet: Node3D
var _tiles: Dictionary = {}
var _tree_mesh: ArrayMesh
var _grass_mesh: ArrayMesh
var _quality := -1


func initialize(planet: Node3D) -> void:
	_planet = planet


func update_tiles(direction: Vector3) -> void:
	if _quality != QualityManager.current_preset:
		for tile: MultiMeshInstance3D in _tiles.values():
			tile.queue_free()
		_tiles.clear()
		_quality = QualityManager.current_preset
	if _tree_mesh == null:
		_tree_mesh = _build_tree()

	var resolution := ceili(_planet.data.radius / TILE_SIZE)
	var face := _leading_axis(direction)
	var axis_a := Vector3(face.y, face.z, face.x)
	var axis_b := face.cross(axis_a)
	var planar := direction / direction.dot(face)
	var grid := Vector2i(roundi(planar.dot(axis_a) * resolution), roundi(planar.dot(axis_b) * resolution))
	var desired := {}
	var created := 0
	# Center first, so the nearest grove is available immediately after landing.
	for step: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var coord := grid + step
		var key := Vector3i(face * resolution + coord.x * axis_a + coord.y * axis_b)
		desired[key] = true
		if not _tiles.has(key) and created < 3:
			var center := Vector3(key).normalized()
			_tiles[key] = _plant_tile(key, center)
			created += 1
	for key in _tiles.keys():
		if not desired.has(key):
			_tiles[key].queue_free()
			_tiles.erase(key)


func _leading_axis(direction: Vector3) -> Vector3:
	var absolute := direction.abs()
	if absolute.x >= maxf(absolute.y, absolute.z):
		return Vector3(signf(direction.x), 0, 0)
	if absolute.y >= absolute.z:
		return Vector3(0, signf(direction.y), 0)
	return Vector3(0, 0, signf(direction.z))


func _plant_tile(key: Vector3i, center: Vector3) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + _planet.data.seed_value
	var count := roundi(42.0 * QualityManager.scatter_density_multiplier * _planet.data.vegetation_density)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = _tree_mesh
	batch.instance_count = count
	var trunks := StaticBody3D.new()
	trunks.collision_layer = 32
	trunks.collision_mask = 0
	var planted := 0
	var reference := Vector3.UP if absf(center.y) < 0.94 else Vector3.RIGHT
	var right := reference.cross(center).normalized()
	var tangent := center.cross(right)
	var radius: float = _planet.data.radius
	var terrain := _planet.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	for sample in range(count):
		var offset := right * rng.randf_range(-35.0, 35.0) + tangent * rng.randf_range(-35.0, 35.0)
		var direction := (center * radius + offset).normalized()
		if _planet.is_aurelia() and (direction.distance_to(Vector3(0.180171244, 0.960913302, 0.210199785)) * radius < 48.0 or _planet.is_village_area(direction)):
			continue
		var surface: float = _planet.get_surface_radius_at_dir(direction)
		var biome: int = _planet.get_biome(direction, surface - radius)
		if biome != 1 and rng.randf() > (0.74 if biome == 0 else 0.26):
			continue
		var world_point: Vector3 = _planet.global_position + direction * surface
		var ray := PhysicsRayQueryParameters3D.create(world_point + direction * 60.0, world_point - direction * 60.0, 1)
		var hit := terrain.intersect_ray(ray)
		if not hit.is_empty():
			world_point = hit["position"]
		if _planet.data.has_ocean and world_point.distance_to(_planet.global_position) < radius + _planet.data.ocean_level_offset + 1.2:
			continue

		var size := rng.randf_range(0.62, 1.93)
		if sample % 4 == 0:
			size *= 0.30
		if biome == 2:
			size *= 0.53
		elif biome == 0:
			size *= 0.76
		var basis := Basis.looking_at(tangent.slide(direction), direction).rotated(direction, rng.randf_range(0.0, TAU))
		var scale := Vector3(size * rng.randf_range(0.8, 1.38), size * float(_planet.data.tree_height_multiplier), size)
		var position: Vector3 = world_point - _planet.global_position - direction * 0.18
		batch.set_instance_transform(planted, Transform3D(basis * Basis.from_scale(scale), position))
		var leaf: Color = _planet.data.tree_canopy_color
		batch.set_instance_color(planted, leaf.lerp(Color("#c5ae69"), rng.randf_range(0.0, 0.42)).lightened(0.21))
		var shape := CylinderShape3D.new()
		shape.radius = maxf(scale.x, scale.z) * 0.31
		shape.height = scale.y * 4.12
		var collider := CollisionShape3D.new()
		collider.shape = shape
		trunks.add_child(collider)
		collider.transform = Transform3D(basis, position + direction * shape.height * 0.5)
		planted += 1
	batch.visible_instance_count = planted

	var tile := MultiMeshInstance3D.new()
	tile.multimesh = batch
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(trunks)
	add_child(tile)
	if _planet.is_aurelia() or _planet.planet_name == "Veridian Mire":
		_plant_ground_cover(tile, center, right, tangent, rng, terrain)
	return tile


func _plant_ground_cover(tile: Node3D, center: Vector3, right: Vector3, tangent: Vector3,
		rng: RandomNumberGenerator, terrain: PhysicsDirectSpaceState3D) -> void:
	if _grass_mesh == null:
		_grass_mesh = _build_grass()
	var count := roundi((535.0 if _planet.is_aurelia() else 340.0) * QualityManager.scatter_density_multiplier)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = _grass_mesh
	batch.instance_count = count
	var planet_radius: float = _planet.data.radius
	var anchor := center * planet_radius
	var planted := 0
	for i in range(count):
		# Groups of tufts leave space for bare paths and expose the grass texture between blades.
		var x := rng.randf_range(-37.5, 37.5)
		var y := rng.randf_range(-37.5, 37.5)
		if sin(x * 0.27) * cos(y * 0.23) < -0.28:
			continue
		var direction := (anchor + right * x + tangent * y).normalized()
		var altitude: float = _planet.get_surface_radius_at_dir(direction)
		var world: Vector3 = _planet.global_position + direction * altitude
		var ray := PhysicsRayQueryParameters3D.create(world + direction * 55.0, world - direction * 55.0, 1)
		var hit := terrain.intersect_ray(ray)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"] - _planet.global_position
		if point.length() <= planet_radius + _planet.data.ocean_level_offset + 1.4:
			continue
		if direction.dot(hit["normal"]) < 0.82:
			continue
		var size := rng.randf_range(0.60, 1.58)
		var basis := Basis.looking_at(tangent.slide(direction), direction).rotated(direction, rng.randf_range(0.0, TAU))
		batch.set_instance_transform(planted, Transform3D(basis.scaled(Vector3.ONE * size), point - anchor - direction * 0.055))
		batch.set_instance_color(planted, Color("#6d9a44").lerp(Color("#b1bc5d"), rng.randf_range(0.0, 0.75)))
		planted += 1
	batch.visible_instance_count = planted
	var grass := MultiMeshInstance3D.new()
	grass.multimesh = batch
	grass.position = anchor
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = 76.0 * QualityManager.detail_distance_multiplier
	grass.visibility_range_end_margin = 6.0
	tile.add_child(grass)


func _build_grass() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(4):
		var yaw := Basis(Vector3.UP, blade * TAU / 4.0)
		var height := 0.31 + 0.07 * blade
		surface.set_color(Color.WHITE)
		surface.add_vertex(yaw * Vector3(-0.065, 0, 0.02))
		surface.add_vertex(yaw * Vector3(0.065, 0, 0.02))
		surface.add_vertex(yaw * Vector3(0.10, height, 0.12))
	surface.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = MEADOW_SHADER
	surface.set_material(material)
	return surface.commit()


func _build_tree() -> ArrayMesh:
	var stem := CylinderMesh.new()
	stem.top_radius = 0.12
	stem.bottom_radius = 0.36
	stem.height = 4.4
	stem.radial_segments = 5
	stem.rings = 0
	var crown := SphereMesh.new()
	crown.radial_segments = 5
	crown.rings = 2

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	_append_piece(surface, stem, Vector3(0, 2.02, 0), Vector3.ONE, Color("#8f6742"))
	if _planet.data.tree_shape == PlanetData.TreeShape.NEEDLE:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.08
		cone.bottom_radius = 1.2
		cone.height = 2.75
		cone.radial_segments = 6
		cone.rings = 0
		_append_piece(surface, cone, Vector3(0, 3.5, 0), Vector3(1.45, 1.0, 1.45), Color("#bfd0c8"))
		_append_piece(surface, cone, Vector3(0, 4.95, 0), Vector3.ONE, Color.WHITE)
	elif _planet.data.tree_shape == PlanetData.TreeShape.UMBRELLA:
		_append_piece(surface, crown, Vector3(0, 4.7, 0), Vector3(4.8, 1.9, 4.1), Color.WHITE)
		_append_piece(surface, crown, Vector3(0.75, 3.9, 0.26), Vector3(2.7, 1.25, 2.6), Color("#aacc9c"))
	else:
		_append_piece(surface, stem, Vector3(0.54, 3.08, -0.19), Vector3(0.71, 0.56, 0.72), Color("#8f6742"), -0.52)
		_append_piece(surface, crown, Vector3(0.80, 4.31, -0.27), Vector3(3.8, 3.1, 3.6), Color.WHITE)
		_append_piece(surface, crown, Vector3(-0.13, 5.65, 0.4), Vector3(3.1, 2.65, 2.7), Color("#f3f1b2"))
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	surface.set_material(material)
	return surface.commit()


func _append_piece(surface: SurfaceTool, mesh: PrimitiveMesh, position: Vector3, scale: Vector3, color: Color, tilt := 0.0) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rotation := Basis(Vector3.BACK, tilt)
	for index in indices:
		surface.set_color(color)
		surface.add_vertex(rotation * (vertices[index] * scale) + position)
