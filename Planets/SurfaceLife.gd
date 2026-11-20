extends Node3D
## Stream stable canopy positions separately from the more expensive forest floor.
const MEADOW_SHADER := preload("res://Planets/MeadowBlades.gdshader")
const PROXY := preload("res://Planets/CanopyProxy.gd")
var _planet: Node3D
var _tiles := {}
var _pending: Array = []
var _detail_queue: Array[Vector3i] = []
var _models: Array[Mesh] = []
var _compact: Array[Mesh] = []
var _alternate_tree: Array[Mesh] = []
var _tree_mesh: ArrayMesh
var _grass_mesh: ArrayMesh
var _proxies := {}
var _focus := Vector3.ZERO
var _altitude := INF
var _far := 0.0
var _village := Vector3.ZERO
var _planned_focus := Vector3.ZERO
var _planned_lead := Vector3.ZERO
var _planned_height := -INF
var _planned_range := 0.0
var _planned_profile := -1


func initialize(planet: Node3D) -> void:
	_planet = planet
	set_physics_process(false)


func update_tiles(direction: Vector3, velocity: Vector3, clearance: float) -> void:
	_focus = direction
	_altitude = clearance
	var profile := QualityManager.detail_distance_multiplier
	var radius: float = _planet.data.radius
	var speed := velocity.slide(direction).length()
	_far = 230.0 + 190.0 * profile + minf(speed * 0.46, 62.0) + clampf(clearance * 0.23, 0, 96)
	var airborne_distance := maxf(clearance, 0.0) * 0.55
	if _planet.vegetation_grid == null or airborne_distance > _far + 150.0:
		_planned_profile = -1
		for tile: Node in _tiles.values():
			tile.queue_free()
		_tiles.clear()
		_pending.clear()
		_detail_queue.clear()
		set_physics_process(false)
		return
	var lead := (direction * radius + (velocity.slide(direction) * 1.35).limit_length(210.0)).normalized()
	if (_planned_profile == QualityManager.current_preset
			and direction.distance_to(_planned_focus) * radius < 3.0
			and lead.distance_to(_planned_lead) * radius < 10.0
			and absf(clearance - _planned_height) < 4.0
			and absf(_far - _planned_range) < 7.0):
		return
	_planned_profile = QualityManager.current_preset
	_planned_focus = direction
	_planned_lead = lead
	_planned_height = clearance
	_planned_range = _far
	var horizontal_reach := sqrt(maxf(0, pow(_far + 70.0, 2) - airborne_distance * airborne_distance))
	var desired: Dictionary = _planet.vegetation_grid.candidates(direction, lead, horizontal_reach / radius)
	var missing := []
	_detail_queue.clear()
	for key in desired:
		if not _tiles.has(key):
			missing.append(key)
	missing.sort_custom(func(a, b): return desired[a] < desired[b])
	_pending = missing
	for key: Vector3i in _tiles.keys():
		var tile: MultiMeshInstance3D = _tiles[key]
		var distance := _distance(key)
		if distance > _far + 148.0 and not desired.has(key):
			tile.queue_free()
			_tiles.erase(key)
		else:
			_update_tile(key, tile, distance)
	_detail_queue.sort_custom(func(a, b): return _distance(a) < _distance(b))
	set_physics_process(not _pending.is_empty() or not _detail_queue.is_empty())


func _distance(key: Vector3i) -> float:
	var horizontal: float = _focus.distance_to(_planet.vegetation_grid.centers[key]) * _planet.data.radius
	return Vector2(horizontal, maxf(_altitude, 0.0) * 0.55).length()


func _physics_process(_delta: float) -> void:
	if _planet.vegetation_grid == null:
		return
	# At most one undergrowth sector per tick; cheaper canopy sectors lead the flight.
	var began := Time.get_ticks_usec()
	if not _detail_queue.is_empty():
		var key: Vector3i = _detail_queue.pop_front()
		var tile: MultiMeshInstance3D = _tiles[key]
		if not tile.has_meta("details"):
			_add_details(tile, key)
			_update_tile(key, tile, _distance(key))
	for step in range(4):
		if _pending.is_empty() or (step > 0 and Time.get_ticks_usec() - began >= 1600):
			break
		var key: Vector3i = _pending.pop_front()
		var tile := _plant_tile(key)
		_tiles[key] = tile
		_update_tile(key, tile, _distance(key))
	if _pending.is_empty() and _detail_queue.is_empty():
		set_physics_process(false)


func _update_tile(key: Vector3i, tile: MultiMeshInstance3D, distance: float) -> void:
	var profile := QualityManager.detail_distance_multiplier
	var mid_end := PROXY.compact_range(profile)
	var previous := int(tile.get_meta("lod", 2))
	var lod := PROXY.lod_at(distance, previous, profile)
	if previous != lod or not tile.has_meta("lod"):
		tile.multimesh.mesh = tile.get_meta("variants")[lod]
		tile.set_meta("lod", lod)
	tile.visible = distance <= _far + (36.0 if tile.visible else 0.0)
	var mode := QualityManager.current_preset
	var changed: bool = tile.get_meta("profile", -1) != mode
	if changed:
		_set_density(tile)
		tile.set_meta("profile", mode)
	if not tile.has_meta("details"):
		if distance < mid_end + 45.0:
			_detail_queue.append(key)
		return
	for child in tile.get_children():
		if child is MultiMeshInstance3D:
			var end := maxf(float(child.get_meta("reach")) * (0.65 + 0.5 * profile), float(tile.get_meta("extent")) + 58.0)
			child.visible = distance < end + (22.0 if child.visible else 0.0)
			if changed:
				_set_density(child)
		elif child is StaticBody3D:
			child.collision_layer = 32 if distance < 115.0 and _altitude < 75.0 else 0
			if changed:
				_sync_colliders(tile, child)
	if distance > mid_end + 120.0:
		for child in tile.get_children():
			tile.remove_child(child)
			child.queue_free()
		tile.remove_meta("details")


func _set_density(batch: MultiMeshInstance3D) -> void:
	batch.multimesh.visible_instance_count = roundi(batch.multimesh.instance_count * QualityManager.scatter_density_multiplier)


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


func _plant_tile(key: Vector3i) -> MultiMeshInstance3D:
	_prepare_models()
	if _planet.is_aurelia() and _village == Vector3.ZERO:
		_village = _planet._landing.village_direction()
	var original := _models[0]
	var compact := _compact[0]
	if not _alternate_tree.is_empty() and posmod(hash(key), 3) == 0:
		original = _alternate_tree[0]
		compact = _alternate_tree[1]
	if not _proxies.has(original):
		var tint: Color = _planet.data.tree_canopy_color.darkened(0.24)
		var rocky := _models.size() == 3
		if rocky:
			tint = _planet.data.highland_color
		_proxies[original] = PROXY.build(original, tint, _planet.data.landscape == PlanetData.Landscape.GLACIUS, rocky)
	var tile := MultiMeshInstance3D.new()
	var center: Vector3 = _planet.vegetation_grid.centers[key]
	tile.position = center * _planet.data.radius
	var extent := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(2, 0), Vector2(0, 2), Vector2(2, 2)]:
		var edge: Vector3 = _planet.vegetation_grid.point(key, corner.x, corner.y)
		extent = maxf(extent, center.distance_to(edge.normalized()) * _planet.data.radius)
	tile.set_meta("extent", extent)
	tile.set_meta("variants", [original, compact, _proxies[original]])
	var trunk_poses: Array[Transform3D] = []
	tile.multimesh = _batch(key, 0, tile.position, _proxies[original], trunk_poses)
	tile.set_meta("trunk_poses", trunk_poses)
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.hide()
	add_child(tile)
	return tile


func _add_details(tile: MultiMeshInstance3D, key: Vector3i) -> void:
	tile.set_meta("details", true)
	var body := StaticBody3D.new()
	body.name = "Trunks"
	body.collision_mask = 0
	body.collision_layer = 0
	_sync_colliders(tile, body)
	tile.add_child(body)
	for variant in range(1, _models.size() + 1):
		var grass := variant == _models.size()
		if grass and not (_planet.is_aurelia() or _planet.data.landscape == PlanetData.Landscape.VERIDIAN):
			break
		if grass and _grass_mesh == null:
			_grass_mesh = _build_grass()
		var mesh := _grass_mesh if grass else _compact[variant]
		var batch := _batch(key, variant, tile.position, mesh)
		if batch.instance_count == 0:
			continue
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.set_meta("reach", 92.0 if grass else (155.0 if variant <= 2 else 104.0))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.hide()
		tile.add_child(node)
		_set_density(node)


func _sync_colliders(tile: MultiMeshInstance3D, body: StaticBody3D) -> void:
	for i in range(body.get_child_count()):
		body.get_child(i).disabled = i >= tile.multimesh.visible_instance_count
	for i in range(body.get_child_count(), tile.multimesh.visible_instance_count):
		var transform: Transform3D = tile.get_meta("trunk_poses")[i]
		var scale := transform.basis.get_scale()
		var shape := CylinderShape3D.new()
		shape.radius = maxf(scale.x, scale.z) * (0.48 if _models.size() == 3 else 0.31)
		shape.height = scale.y * (0.84 if _models.size() == 3 else 4.12)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = Transform3D(transform.basis.orthonormalized(), transform.origin + transform.basis.y.normalized() * shape.height * 0.5)
		body.add_child(collider)


func _batch(key: Vector3i, variant: int, anchor: Vector3, model: Mesh, transforms: Array[Transform3D] = []) -> MultiMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector4i(key.x, key.y, key.z, variant)) + _planet.data.seed_value
	var grass := variant == _models.size()
	var attempts: int = (240 if _planet.is_aurelia() else 190) if grass else [42, 30, 16, 25, 23][variant]
	var tints := PackedColorArray()
	var radius: float = _planet.data.radius
	for sample in range(attempts):
		var u := rng.randf() * 2.0
		var v := rng.randf() * 2.0
		var point: Vector3 = _planet.vegetation_grid.point(key, u, v)
		var up := point.normalized()
		if _reserved(up, radius):
			continue
		var elevation := point.length() - radius
		if _planet.data.has_ocean and elevation <= _planet.data.ocean_level_offset + 1.4:
			continue
		if grass:
			if sin(u * 10.0) * cos(v * 8.8) < -0.28:
				continue
		elif rng.randf() > _density(variant, _planet.get_biome(up, elevation)):
			continue
		var normal: Vector3 = _planet.vegetation_grid.normal(key, u, v)
		if up.dot(normal) < (0.82 if grass else 0.79):
			continue
		var size := rng.randf_range(0.68, 1.51)
		if variant == 0:
			size *= float(_planet.data.tree_height_multiplier) if _models.size() > 3 else 1.65
		var ref := Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT
		var facing := Basis.looking_at(ref.cross(up), up).rotated(up, rng.randf_range(0.0, TAU))
		var scale := Vector3(rng.randf_range(0.88, 1.24), 1.0, 1.0) * size
		transforms.append(Transform3D(facing * Basis.from_scale(scale), point - anchor - up * (0.055 if grass else 0.14)))
		if grass:
			tints.append(Color("#6d9a44").lerp(Color("#b1bc5d"), rng.randf_range(0.0, 0.75)))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = grass
	batch.mesh = model
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
		if grass:
			batch.set_instance_color(i, tints[i])
	return batch


func _reserved(direction: Vector3, radius: float) -> bool:
	return _planet.is_landmark_area(direction) or (_planet.is_aurelia() and (
		direction.distance_to(Vector3(0.180171244, 0.960913302, 0.210199785)) * radius < 48.0
		or direction.distance_to(_village) * radius < 34.0 or _planet.is_forest_area(direction)))


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
