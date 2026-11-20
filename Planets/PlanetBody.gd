class_name PlanetBody
extends StaticBody3D
## Spherical procedural planet with cube-sphere geometry, vertex biome coloring,
## edge-locked regional LOD, Fresnel atmosphere shell, terrain-aligned water,
## MultiMesh flora/rock scatter, and local ecosystem spawned on approach.

const CREATURE_SCENE := preload("res://Creatures/AlienCreature.tscn")
const SENTINEL_SCENE := preload("res://Creatures/HostileSentinel.tscn")
const MONOLITH_SCENE := preload("res://Combat/AncientMonolith.tscn")

const AURELIA_START_DIRECTION := Vector3(0.180171244, 0.960913302, 0.210199785)
const AURELIA_LANDING := preload("res://Planets/AureliaLanding.gd")
const LANDSCAPE := preload("res://Planets/PlanetLandscape.gd")
const MESH_BUILDER := preload("res://Planets/PlanetTerrainMesh.gd")
const LANDMARK := preload("res://Planets/PlanetLandmark.gd")
const OCEAN := preload("res://Planets/PlanetOcean.gdshader")
const AURELIA_TERRAIN := preload("res://Planets/AureliaTerrain.gdshader")

var _landmark: Node3D
var _landing: Node3D
var landscape: RefCounted
var data: PlanetData
var planet_name: String = "Planet"

var _terrain_mesh_inst: Node3D
var vegetation_grid: RefCounted
var _terrain_building := false
var _terrain_chunks: Array[MeshInstance3D] = []
var _chunk_directions: Array[Vector3] = []
var _chunk_extents: Array[float] = []
var _sky_obscuration := 0.0
var _orbital_material: StandardMaterial3D
var _distant_proxy_inst: MeshInstance3D
var _terrain_collider: CollisionShape3D
var _water_material: ShaderMaterial
var _water_chunks: Array[MeshInstance3D] = []
var _atmosphere_mesh_inst: MeshInstance3D

const SURFACE_LIFE := preload("res://Planets/SurfaceLife.gd")
var _surface_life: Node3D
var _ecosystem_direction := Vector3.ZERO
var _ecosystem_root: Node3D
var _ecosystem_active: bool = false
var _check_timer: float = 0.18


func initialize(planet_data: PlanetData) -> void:
	data = planet_data
	planet_name = data.planet_name
	name = planet_name.replace(" ", "_")
	landscape = LANDSCAPE.new(data)
	_landmark = LANDMARK.new()
	_landmark.choose(self)
	add_child(_landmark)
	_build_distant_proxy()
	if is_aurelia():
		_build_terrain()
	_build_atmosphere_shell()
	_surface_life = SURFACE_LIFE.new()
	_surface_life.name = "SurfaceLife"
	add_child(_surface_life)
	_surface_life.initialize(self)

	if is_aurelia():
		_landing = AURELIA_LANDING.new()
		_landing.name = "AureliaLanding"
		add_child(_landing)
		_landing.build(self, AURELIA_START_DIRECTION)

	_ecosystem_root = Node3D.new()
	_ecosystem_root.name = "EcosystemRoot"
	add_child(_ecosystem_root)


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer < 0.18:
		return
	_check_timer = 0.0

	var focus: Node3D = GameState.ship_node if GameState.current_mode == GameState.ControlMode.IN_SHIP else GameState.player_node
	if not is_instance_valid(focus) or data == null:
		return

	var dist: float = global_position.distance_to(focus.global_position)
	var atmo_edge: float = data.radius + data.atmosphere_height

	var direction := global_position.direction_to(focus.global_position)
	var altitude := dist - data.radius
	var near_detail := dist < atmo_edge + 1100.0
	if near_detail and not _terrain_building and not is_instance_valid(_terrain_mesh_inst):
		_build_terrain(true)
	if is_instance_valid(_terrain_mesh_inst):
		_terrain_mesh_inst.visible = near_detail
		if near_detail:
			_update_terrain_visibility(direction, altitude)
		elif dist > atmo_edge + 2400.0 and not is_aurelia():
			_terrain_mesh_inst.queue_free()
			_terrain_collider.queue_free()
			_terrain_mesh_inst = null
			vegetation_grid = null
			_terrain_collider = null
			_terrain_chunks.clear()
			_chunk_directions.clear()
			_chunk_extents.clear()
			_water_chunks.clear()
	_distant_proxy_inst.visible = _sky_obscuration < 0.97 and not (near_detail and is_instance_valid(_terrain_mesh_inst))

	var clearance := dist - get_surface_radius_at_dir(direction) if near_detail else INF
	var near_surface := clearance < 210.0 and is_instance_valid(_terrain_mesh_inst)
	var velocity := (focus as CharacterBody3D).velocity
	if is_instance_valid(_terrain_collider):
		_surface_life.update_tiles(direction, velocity, clearance)
		if _landmark.get_child_count() == 0 and _landmark.direction != Vector3.ZERO and clearance < 430.0:
			_place_landmark()
	else:
		_surface_life.update_tiles(direction, Vector3.ZERO, INF)
	var exploring: bool = near_surface and (GameState.current_mode == GameState.ControlMode.ON_FOOT or GameState.ship_node.is_landed)
	if exploring and (not _ecosystem_active or direction.distance_to(_ecosystem_direction) * data.radius > 255.0):
		_deactivate_ecosystem()
		_activate_ecosystem(direction)
	elif not near_surface and _ecosystem_active:
		_deactivate_ecosystem()

	if is_instance_valid(_atmosphere_mesh_inst):
		_atmosphere_mesh_inst.visible = dist > data.radius + data.atmosphere_height * 0.42 and dist <= (atmo_edge + 2600.0)


func set_sky_obscuration(weight: float) -> void:
	if not is_instance_valid(_orbital_material) or is_equal_approx(_sky_obscuration, weight):
		return
	_sky_obscuration = weight
	var opacity := 1.0 - smoothstep(0.55, 0.97, weight)
	_orbital_material.albedo_color.a = opacity
	_orbital_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if opacity < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if weight >= 0.97:
		_distant_proxy_inst.hide()


func is_landmark_area(direction: Vector3) -> bool:
	return _landmark.direction.distance_to(direction) * data.radius < 22.0


func _place_landmark() -> void:
	var direction: Vector3 = _landmark.direction
	var sample := global_position + direction * get_surface_radius_at_dir(direction)
	var ray := PhysicsRayQueryParameters3D.create(sample + direction * 65.0, sample - direction * 65.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		_landmark.build(self, hit["position"])


func is_forest_area(direction: Vector3) -> bool:
	return is_instance_valid(_landing) and _landing.is_forest_direction(direction)


func is_village_area(direction: Vector3) -> bool:
	return is_instance_valid(_landing) and direction.distance_to(_landing.village_direction()) * data.radius < 34.0


func is_aurelia() -> bool:
	return planet_name == "Aurelia Prime"


func get_surface_radius_at_dir(unit_dir: Vector3) -> float:
	return data.radius + landscape.height(unit_dir.normalized())


func get_surface_point_and_normal(world_pos: Vector3) -> Dictionary:
	var local_dir: Vector3 = (world_pos - global_position).normalized()
	if local_dir.length_squared() < 0.001:
		local_dir = Vector3.UP
	var r: float = get_surface_radius_at_dir(local_dir)
	var surface_world: Vector3 = global_position + local_dir * r

	var tangent: Vector3 = local_dir.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = local_dir.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent: Vector3 = local_dir.cross(tangent).normalized()

	var eps: float = 0.0035
	var d1: Vector3 = (local_dir + tangent * eps).normalized()
	var d2: Vector3 = (local_dir + bitangent * eps).normalized()
	var p0: Vector3 = local_dir * r
	var p1: Vector3 = d1 * get_surface_radius_at_dir(d1)
	var p2: Vector3 = d2 * get_surface_radius_at_dir(d2)
	var n: Vector3 = (p2 - p0).cross(p1 - p0).normalized()
	if n.dot(local_dir) < 0.0:
		n = -n

	return {
		"position": surface_world,
		"normal": n,
		"radial_up": local_dir,
		"radius": r
	}


func get_gravity_vector_at(world_pos: Vector3) -> Vector3:
	var to_center: Vector3 = global_position - world_pos
	var dist: float = to_center.length()
	var max_g_dist: float = data.radius + data.atmosphere_height
	if dist >= max_g_dist or dist < 0.01:
		return Vector3.ZERO
	var falloff: float = 1.0 - smoothstep(data.radius + data.atmosphere_height * 0.55, max_g_dist, dist)
	return to_center.normalized() * data.gravity_strength * falloff


func get_sky_colors() -> Dictionary:
	return {
		"zenith": data.sky_zenith,
		"horizon": data.sky_horizon,
		"ground": data.lowland_color.darkened(0.45)
	}


func _build_terrain(staggered := false) -> void:
	_terrain_building = true
	var resolution := 65
	var mesh: ArrayMesh = await MESH_BUILDER.new().build(self, resolution, false, staggered)
	var material := ShaderMaterial.new()
	material.shader = AURELIA_TERRAIN
	var grain := NoiseTexture2D.new()
	grain.width = 128
	grain.height = 128
	grain.seamless = true
	var texture_noise := FastNoiseLite.new()
	texture_noise.seed = data.seed_value
	texture_noise.frequency = 0.065
	grain.noise = texture_noise
	material.set_shader_parameter("surface_grain", grain)
	material.set_shader_parameter("meadow", 1.0 if is_aurelia() else (0.82 if planet_name == "Veridian Mire" else 0.0))
	if is_aurelia():
		var up := AURELIA_START_DIRECTION
		var right := Vector3.RIGHT.cross(up).normalized()
		material.set_shader_parameter("grove_enabled", true)
		material.set_shader_parameter("grove_right", right)
		material.set_shader_parameter("grove_forward", up.cross(right))
	_terrain_mesh_inst = Node3D.new()
	_terrain_mesh_inst.name = "TerrainMesh"
	add_child(_terrain_mesh_inst)
	var arrays := mesh.surface_get_arrays(0)
	vegetation_grid = preload("res://Planets/VegetationGrid.gd").new(arrays[Mesh.ARRAY_VERTEX], resolution)
	_build_terrain_chunks(arrays, resolution, material)

	_terrain_collider = CollisionShape3D.new()
	_terrain_collider.name = "TerrainCollider"
	_terrain_collider.shape = mesh.create_trimesh_shape()
	add_child(_terrain_collider)
	_terrain_building = false


func _build_terrain_chunks(source: Array, resolution: int, material: Material) -> void:
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = source[Mesh.ARRAY_COLOR]
	var patch_size := (resolution - 1) >> 2
	var stride := patch_size + 1
	var coarse := _edge_preserving_lod(patch_size)
	if data.has_ocean:
		_water_material = ShaderMaterial.new()
		_water_material.shader = OCEAN
		_water_material.set_shader_parameter("deep", data.ocean_color.darkened(0.33))
		_water_material.set_shader_parameter("shallows", data.ocean_color.lightened(0.30))
		_water_material.set_shader_parameter("ice", data.landscape == PlanetData.Landscape.GLACIUS)
	var grid := PackedInt32Array()
	for y in range(patch_size):
		for x in range(patch_size):
			var index := y * stride + x
			grid.append(index)
			grid.append(index + stride)
			grid.append(index + 1)
			grid.append(index + 1)
			grid.append(index + stride)
			grid.append(index + stride + 1)
	for face in range(6):
		for row in range(4):
			for col in range(4):
				var start := face * resolution * resolution + row * patch_size * resolution + col * patch_size
				var center := vertices[start + (patch_size >> 1) * (resolution + 1)].normalized()
				var extent := 0.0
				var points := PackedVector3Array()
				var gradients := PackedVector3Array()
				var tints := PackedColorArray()
				for y in range(stride):
					var first := start + y * resolution
					points.append_array(vertices.slice(first, first + stride))
					gradients.append_array(normals.slice(first, first + stride))
					tints.append_array(colors.slice(first, first + stride))
				for corner: int in [0, patch_size, patch_size * stride, points.size() - 1]:
					extent = maxf(extent, center.angle_to(points[corner].normalized()))
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = points
				arrays[Mesh.ARRAY_NORMAL] = gradients
				arrays[Mesh.ARRAY_COLOR] = tints
				arrays[Mesh.ARRAY_INDEX] = grid
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {7.0: coarse})
				mesh.surface_set_material(0, material)
				var tile := MeshInstance3D.new()
				tile.mesh = mesh
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_terrain_mesh_inst.add_child(tile)
				_terrain_chunks.append(tile)
				_chunk_directions.append(center)
				_chunk_extents.append(extent)
				_water_chunks.append(_make_water_patch(points, grid) if data.has_ocean else null)


func _update_terrain_visibility(direction: Vector3, altitude: float) -> void:
	var horizon := acos(data.radius / (data.radius + maxf(altitude, 0.0)))
	# Include the tallest ridges behind the nominal horizon.
	var ridge_margin := acos(data.radius / (data.radius + data.terrain_amplitude)) + 0.045
	for index in range(_terrain_chunks.size()):
		var angle := horizon + ridge_margin + _chunk_extents[index]
		var patch := _terrain_chunks[index]
		var dot_product := direction.dot(_chunk_directions[index])
		patch.visible = dot_product >= cos(angle)
		patch.lod_bias = 48.0 if altitude < 140.0 and dot_product > cos(_chunk_extents[index] + 0.115) else 0.7
		if is_instance_valid(_water_chunks[index]):
			_water_chunks[index].visible = patch.visible


func _edge_preserving_lod(size: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var stride := size + 1
	for y in range(0, size, 2):
		for x in range(0, size, 2):
			var a := y * stride + x
			var b := a + 2 * stride
			var c := b + 2
			var d := a + 2
			if x > 0 and y > 0 and x + 2 < size and y + 2 < size:
				indices.append_array(PackedInt32Array([a, b, d, d, b, c]))
				continue
			var ring := PackedInt32Array([a])
			if x == 0:
				ring.append(a + stride)
			ring.append(b)
			if y + 2 == size:
				ring.append(b + 1)
			ring.append(c)
			if x + 2 == size:
				ring.append(d + stride)
			ring.append(d)
			if y == 0:
				ring.append(a + 1)
			var center := a + stride + 1
			for i in range(ring.size()):
				indices.append_array(PackedInt32Array([center, ring[i], ring[(i + 1) % ring.size()]]))
	return indices


func _make_water_patch(points: PackedVector3Array, terrain_indices: PackedInt32Array) -> MeshInstance3D:
	var surface_radius := data.radius + data.ocean_level_offset
	var depths := PackedFloat32Array()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for point in points:
		var depth := surface_radius - point.length()
		var up := point.normalized()
		depths.append(depth)
		vertices.append(up * surface_radius)
		normals.append(up)
		colors.append(Color(clampf((depth + 32.0) / 105.0, 0.0, 1.0), 0, 0))
	var indices := PackedInt32Array()
	for i in range(0, terrain_indices.size(), 3):
		var a := terrain_indices[i]
		var b := terrain_indices[i + 1]
		var c := terrain_indices[i + 2]
		if maxf(depths[a], maxf(depths[b], depths[c])) > 0.0:
			indices.append_array(PackedInt32Array([a, b, c]))
	if indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _water_material)
	var patch := MeshInstance3D.new()
	patch.mesh = mesh
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_mesh_inst.add_child(patch)
	return patch


func _build_distant_proxy() -> void:
	var mesh: ArrayMesh = await MESH_BUILDER.new().build(self, 17, true)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.disable_fog = true
	_orbital_material = mat
	mesh.surface_set_material(0, mat)
	_distant_proxy_inst = MeshInstance3D.new()
	_distant_proxy_inst.name = "DistantProxyMesh"
	_distant_proxy_inst.mesh = mesh
	_distant_proxy_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_distant_proxy_inst)


func get_biome(direction: Vector3, height: float) -> int:
	return landscape.biome(direction, height)


func _build_atmosphere_shell() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = data.radius + data.atmosphere_height * 0.42
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 14

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded, fog_disabled;

uniform vec4 rim_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.6);
	ALBEDO = rim_color.rgb;
	ALPHA = clamp(fresnel * 0.65, 0.0, 0.75);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("rim_color", data.atmosphere_rim)
	sphere.material = mat

	_atmosphere_mesh_inst = MeshInstance3D.new()
	_atmosphere_mesh_inst.name = "AtmosphereHalo"
	_atmosphere_mesh_inst.mesh = sphere
	_atmosphere_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_atmosphere_mesh_inst)


func _activate_ecosystem(direction: Vector3) -> void:
	_ecosystem_active = true
	_ecosystem_direction = direction
	if is_instance_valid(_landing) and direction.distance_to(AURELIA_START_DIRECTION) * data.radius < 175.0:
		for offset: Vector2 in [Vector2(8, 15), Vector2(12, 19), Vector2(-10, 24)]:
			var local_point: Vector3 = _landing.surface_at_offset(offset)
			_spawn_creature(local_point.normalized(), 2.0, data.tree_canopy_color, 0.82 + offset.length() * 0.009)
	var rng := RandomNumberGenerator.new()
	var grid := Vector3i((direction * data.radius / 180.0).round())
	rng.seed = data.seed_value + hash(grid)
	var right := direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.1:
		right = direction.cross(Vector3.RIGHT).normalized()
	var forward := direction.cross(right)
	for i in range(10):
		var angle := float(i) * TAU / 10.0 + rng.randf_range(-0.3, 0.3)
		var offset := (right * cos(angle) + forward * sin(angle)) * rng.randf_range(30.0, 96.0)
		var dir := (direction * data.radius + offset).normalized()
		var point := get_surface_radius_at_dir(dir)
		if data.has_ocean and point <= data.radius + data.ocean_level_offset + 2.0:
			continue
		if i == 0 or i == 5:
			var relay := MONOLITH_SCENE.instantiate() as StaticBody3D
			_ecosystem_root.add_child(relay)
			relay.position = dir * (point - 0.7)
			_align_node_to_up(relay, dir)
			relay.setup(planet_name, "%s_relay_%d" % [str(grid), i], "Relé de %s" % data.biome_names[get_biome(dir, point - data.radius)], data.crystal_color)
		elif i == 6 and data.has_hostiles:
			var sentinel := SENTINEL_SCENE.instantiate() as Node3D
			_ecosystem_root.add_child(sentinel)
			sentinel.position = dir * (point + 4.5)
			_align_node_to_up(sentinel, dir)
			sentinel.setup_planet(self)
		elif i % 2 == 0:
			_spawn_creature(dir, 2.0, data.crystal_color, rng.randf_range(0.9, 1.28))


func _spawn_creature(direction: Vector3, clearance: float, tint: Color, size: float) -> void:
	var creature := CREATURE_SCENE.instantiate() as CharacterBody3D
	_ecosystem_root.add_child(creature)
	creature.position = direction * (get_surface_radius_at_dir(direction) + clearance)
	_align_node_to_up(creature, direction)
	creature.setup_planet(self, tint, size)


func _deactivate_ecosystem() -> void:
	_ecosystem_active = false
	for child in _ecosystem_root.get_children():
		child.queue_free()


func _align_node_to_up(node: Node3D, up_dir: Vector3) -> void:
	var up: Vector3 = up_dir.normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(up.y) > 0.9 else Vector3.UP
	var right: Vector3 = ref.cross(up).normalized()
	var fwd: Vector3 = up.cross(right).normalized()
	node.basis = Basis(right, up, -fwd)
