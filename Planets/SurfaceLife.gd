extends Node3D
## Small, deterministic vegetation tiles around the observer on a cube sphere.

const TILE_SIZE := 78.0
const PREFETCH_LIMIT := 280.0
const MEADOW_SHADER := preload("res://Planets/MeadowBlades.gdshader")
var _planet: Node3D
var _tiles: Dictionary = {}
var _tree_mesh: ArrayMesh
var _grass_mesh: ArrayMesh
var _pending: Array[Vector3i] = []
var _clock := 0.0
var _deadline: Dictionary = {}
var _models: Array[Mesh] = []
var _compact: Array[Mesh] = []
var _alternate_tree: Array[Mesh] = []
var _focus := Vector3.ZERO
var _altitude := 0.0
var _quality := -1


func initialize(planet: Node3D) -> void:
	_planet = planet


func update_tiles(direction: Vector3, velocity: Vector3, clearance: float) -> void:
	_focus = direction
	_altitude = clearance
	_pending.clear()
	var draw_distance := _draw_distance()
	var descending := velocity.dot(direction) < -6.0
	if clearance > draw_distance / 0.46 + (105.0 if descending else 28.0):
		return
	var radius: float = _planet.data.radius
	var lead := (velocity.slide(direction) * 0.82).limit_length(PREFETCH_LIMIT)
	var predicted := (direction * radius + lead).normalized()
	var desired := {}
	for center: Vector3 in [direction, predicted]:
		var tangent := center.cross(Vector3.UP if absf(center.y) < 0.9 else Vector3.RIGHT).normalized()
		var right := tangent.cross(center)
		for y in range(-2, 3):
			for x in range(-2, 3):
				if x * x + y * y > 6:
					continue
				var sample := (center * radius + (tangent * x + right * y) * TILE_SIZE).normalized()
				var key := _tile_key(sample)
				var sector_center := Vector3(key).normalized()
				if sector_center.distance_to(center) * radius > draw_distance + TILE_SIZE * 0.35:
					continue
				if desired.has(key):
					continue
				desired[key] = true
				_deadline[key] = _clock + 1.25
				if not _tiles.has(key):
					_pending.append(key)
	_pending.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _priority(a, predicted) > _priority(b, predicted))


func _draw_distance() -> float:
	return 226.0 * QualityManager.detail_distance_multiplier


func _priority(key: Vector3i, predicted: Vector3) -> float:
	var center := Vector3(key).normalized()
	return maxf(center.dot(_focus), center.dot(predicted) - 0.001)


func _tile_key(direction: Vector3) -> Vector3i:
	var resolution := ceili(_planet.data.radius / TILE_SIZE)
	var face := _leading_axis(direction)
	return Vector3i((direction * (resolution / direction.dot(face))).round())


func _physics_process(delta: float) -> void:
	_clock += delta
	if not _pending.is_empty() and Engine.get_physics_frames() % 3 == 0:
		var capacity := 30 + int(15.0 * (QualityManager.detail_distance_multiplier - 0.54))
		if _tiles.size() >= capacity:
			_evict_unwanted()
		if _tiles.size() < capacity:
			var key: Vector3i = _pending.pop_front()
			_tiles[key] = _plant_tile(key, Vector3(key).normalized())
	if Engine.get_physics_frames() % 4 != 0:
		return
	var mode := QualityManager.current_preset
	var quality_changed := mode != _quality
	_quality = mode
	var ratio := QualityManager.scatter_density_multiplier
	for key: Vector3i in _tiles.keys():
		var tile: MultiMeshInstance3D = _tiles[key]
		if _deadline[key] <= _clock:
			tile.queue_free()
			_tiles.erase(key)
			continue
		var horizontal: float = _focus.distance_to(Vector3(key).normalized()) * _planet.data.radius
		var distance := Vector2(horizontal, maxf(_altitude, 0.0) * 0.46).length()
		var limit := _draw_distance()
		var visibility := 1.0 - smoothstep(limit * 0.69, limit, distance)
		var bodies: StaticBody3D = tile.get_node("Trunks")
		var collisions := horizontal < 89.0 and _altitude < 65.0
		var layer := 32 if collisions else 0
		if bodies.collision_layer != layer:
			bodies.collision_layer = layer
		for node: Node in tile.get_children():
			if node is MultiMeshInstance3D:
				_update_batch(node, distance, ratio, visibility, quality_changed)
		_update_batch(tile, distance, ratio, visibility, quality_changed)
		for shape_index in range(bodies.get_child_count()):
			# Collision order matches the primary canopy batch.
			var collider := bodies.get_child(shape_index) as CollisionShape3D
			var inactive := shape_index >= tile.multimesh.visible_instance_count
			if collider.disabled != inactive:
				collider.disabled = inactive
	for key in _deadline.keys():
		if _deadline[key] <= _clock:
			_deadline.erase(key)


func _evict_unwanted() -> void:
	# Retain the overlap while there is room. When full, recycle the sector already
	# outside the view and with the shortest remaining lifetime.
	var candidate := Vector3i.ZERO
	var expiration := _clock + 0.95
	var radius: float = _planet.data.radius
	for key: Vector3i in _tiles:
		var distance := Vector2(_focus.distance_to(Vector3(key).normalized()) * radius, _altitude * 0.46).length()
		if distance > _draw_distance() and float(_deadline[key]) < expiration:
			expiration = _deadline[key]
			candidate = key
	if candidate != Vector3i.ZERO:
		_tiles[candidate].queue_free()
		_tiles.erase(candidate)
		_deadline.erase(candidate)


func _update_batch(node: MultiMeshInstance3D, distance: float, ratio: float, visibility: float, changed: bool) -> void:
	var lod_distance := float(node.get_meta("detail_distance", 120.0))
	if node.has_meta("compact"):
		var compact: bool = _quality == QualityManager.Preset.ECONOMY or distance > lod_distance
		if changed or compact != bool(node.get_meta("low_detail", false)):
			node.multimesh.mesh = node.get_meta("compact") if compact else node.get_meta("original")
			node.set_meta("low_detail", compact)
	if node.has_meta("understory"):
		visibility *= 1.0 - smoothstep(lod_distance * 0.72, lod_distance, distance)
	node.multimesh.visible_instance_count = roundi(float(node.get_meta("planted")) * visibility * ratio)


func _load_mesh(path: String, compact := false) -> Mesh:
	var model := (load(path) as PackedScene).instantiate()
	var instance := model as MeshInstance3D
	if instance == null:
		instance = model.get_child(0) as MeshInstance3D
	var mesh := instance.mesh
	model.free()
	if not compact:
		return mesh
	var simplified := load(path.get_basename() + "-compact.res") as ArrayMesh
	for surface in range(simplified.get_surface_count()):
		simplified.surface_set_material(surface, mesh.surface_get_material(surface))
	return simplified


func _prepare_models() -> void:
	if not _models.is_empty():
		return
	const ROOT := "res://Assets/Environment/"
	var canopy: String
	match _planet.data.landscape:
		PlanetData.Landscape.AURELIA:
			canopy = "Trees/quaternius-broadleaf.gltf"
		PlanetData.Landscape.GLACIUS:
			canopy = "Trees/quaternius-woodland-pine.gltf"
		PlanetData.Landscape.VERIDIAN:
			canopy = "Trees/quaternius-grove-tree.gltf"
	var stone := _load_mesh(ROOT + "Rocks/quaternius-stratified-stone.gltf")
	if canopy.is_empty():
		stone = _colored_rock(stone)
		_tree_mesh = _build_tree()
		_models.assign([stone, _tree_mesh, stone])
		_compact.assign(_models)
		return
	var shrub := "Shrubs/quaternius-leaf-bush.gltf"
	_models.assign([_load_mesh(ROOT + canopy), _load_mesh(ROOT + shrub), _load_mesh(ROOT + "Rocks/quaternius-mossy-rock.gltf"), _load_mesh(ROOT + "Plants/woodland-fern.gltf"), _load_mesh(ROOT + "Flowers/quaternius-field-bloom.gltf")])
	_compact.assign([_load_mesh(ROOT + canopy, true), _load_mesh(ROOT + shrub, true), _models[2], _models[3], _models[4]])
	if _planet.is_aurelia():
		var grove := ROOT + "Trees/quaternius-grove-tree.gltf"
		_alternate_tree.assign([_load_mesh(grove), _load_mesh(grove, true)])


func _colored_rock(original: Mesh) -> Mesh:
	var stone := original.duplicate() as ArrayMesh
	var tint := Color("#686573") if _planet.data.landscape == PlanetData.Landscape.PYROS else Color("#e0a17b")
	for surface in range(stone.get_surface_count()):
		var material := stone.surface_get_material(surface).duplicate() as StandardMaterial3D
		material.albedo_color = tint
		stone.surface_set_material(surface, material)
	return stone


func _leading_axis(direction: Vector3) -> Vector3:
	var absolute := direction.abs()
	if absolute.x >= maxf(absolute.y, absolute.z):
		return Vector3(signf(direction.x), 0, 0)
	if absolute.y >= absolute.z:
		return Vector3(0, signf(direction.y), 0)
	return Vector3(0, 0, signf(direction.z))


func _plant_tile(key: Vector3i, center: Vector3) -> MultiMeshInstance3D:
	_prepare_models()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + _planet.data.seed_value
	var trunks := StaticBody3D.new()
	trunks.name = "Trunks"
	trunks.collision_layer = 0
	trunks.collision_mask = 0
	var reference := Vector3.UP if absf(center.y) < 0.94 else Vector3.RIGHT
	var right := reference.cross(center).normalized()
	var tangent := center.cross(right)
	var radius: float = _planet.data.radius
	var terrain := _planet.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var tile: MultiMeshInstance3D
	for variant in range(_models.size()):
		var count := [42, 30, 16, 25, 23][variant] as int
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		var original := _models[variant]
		var compact := _compact[variant]
		if variant == 0 and not _alternate_tree.is_empty() and posmod(hash(key), 3) == 0:
			original = _alternate_tree[0]
			compact = _alternate_tree[1]
		batch.mesh = compact
		batch.instance_count = count
		var planted := 0
		for _sample in range(count):
			var offset := right * rng.randf_range(-35.0, 35.0) + tangent * rng.randf_range(-35.0, 35.0)
			var direction := (center * radius + offset).normalized()
			if _reserved(direction, radius):
				continue
			var surface: float = _planet.get_surface_radius_at_dir(direction)
			var biome: int = _planet.get_biome(direction, surface - radius)
			var chance := _density(variant, biome)
			if rng.randf() > chance:
				continue
			var world_point: Vector3 = _planet.global_position + direction * surface
			var ray := PhysicsRayQueryParameters3D.create(world_point + direction * 70.0, world_point - direction * 70.0, 1)
			var hit := terrain.intersect_ray(ray)
			if hit.is_empty():
				continue
			world_point = hit["position"]
			if direction.dot(hit["normal"]) < 0.79:
				continue
			if _planet.data.has_ocean and world_point.distance_to(_planet.global_position) < radius + _planet.data.ocean_level_offset + 1.4:
				continue
			var size := rng.randf_range(0.68, 1.51)
			if variant == 0 and _models.size() > 3:
				size *= float(_planet.data.tree_height_multiplier)
			if variant == 0 and _models.size() == 3:
				size *= 1.65
			var basis := Basis.looking_at(tangent.slide(direction), direction).rotated(direction, rng.randf_range(0.0, TAU))
			var scale := Vector3(size * rng.randf_range(0.88, 1.24), size, size)
			var position: Vector3 = world_point - _planet.global_position - direction * 0.14
			batch.set_instance_transform(planted, Transform3D(basis * Basis.from_scale(scale), position))
			if variant == 0:
				var shape := CylinderShape3D.new()
				shape.radius = maxf(scale.x, scale.z) * (0.48 if _models.size() == 3 else 0.31)
				shape.height = scale.y * (0.84 if _models.size() == 3 else 4.12)
				var collider := CollisionShape3D.new()
				collider.shape = shape
				trunks.add_child(collider)
				collider.transform = Transform3D(basis, position + direction * shape.height * 0.5)
			planted += 1
		batch.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.set_meta("planted", planted)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if original != compact:
			node.set_meta("original", original)
			node.set_meta("compact", compact)
			node.set_meta("low_detail", true)
		if variant == 0:
			tile = node
			tile.add_child(trunks)
			add_child(tile)
		elif planted > 0:
			node.set_meta("understory", true)
			node.set_meta("detail_distance", 146.0 if variant == 1 or variant == 2 else 91.0)
			tile.add_child(node)
		else:
			node.free()
	if _planet.is_aurelia() or _planet.data.landscape == PlanetData.Landscape.VERIDIAN:
		_plant_ground_cover(tile, center, right, tangent, rng, terrain)
	return tile


func _reserved(direction: Vector3, radius: float) -> bool:
	return _planet.is_landmark_area(direction) or (_planet.is_aurelia() and (
		direction.distance_to(Vector3(0.180171244, 0.960913302, 0.210199785)) * radius < 48.0
		or _planet.is_village_area(direction) or _planet.is_forest_area(direction)))


func _density(variant: int, biome: int) -> float:
	if _planet.data.landscape == PlanetData.Landscape.GLACIUS and variant != 0 and variant != 2:
		return 0.04
	if _models.size() == 3:
		if variant == 1:
			return 0.18 if biome == 1 else 0.015
		return [0.19, 0.20, 0.85, 0.13, 0.43][biome]
	match variant:
		0: return [0.05, 0.95, 0.035, 0.055, 0.24][biome]
		1: return [0.15, 0.78, 0.10, 0.27, 0.48][biome]
		2: return [0.18, 0.26, 0.70, 0.55, 0.18][biome]
		3: return [0.05, 0.76, 0.03, 0.27, 0.21][biome]
	return [0.30, 0.18, 0.06, 0.12, 0.87][biome]


func _plant_ground_cover(tile: Node3D, center: Vector3, right: Vector3, tangent: Vector3,
		rng: RandomNumberGenerator, terrain: PhysicsDirectSpaceState3D) -> void:
	if _grass_mesh == null:
		_grass_mesh = _build_grass()
	var count := 240 if _planet.is_aurelia() else 190
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
		if _reserved(direction, planet_radius):
			continue
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
	batch.visible_instance_count = 0
	var grass := MultiMeshInstance3D.new()
	grass.multimesh = batch
	grass.position = anchor
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.set_meta("planted", planted)
	grass.set_meta("understory", true)
	grass.set_meta("detail_distance", 78.0)
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
