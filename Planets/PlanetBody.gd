class_name PlanetBody
extends StaticBody3D
## Spherical procedural planet with cube-sphere geometry, vertex biome coloring,
## 2-tier distance LOD, Fresnel atmosphere shell, optional ocean sphere,
## MultiMesh flora/rock scatter, and local ecosystem spawned on approach.

const CREATURE_SCENE := preload("res://Creatures/AlienCreature.tscn")
const SENTINEL_SCENE := preload("res://Creatures/HostileSentinel.tscn")
const MONOLITH_SCENE := preload("res://Combat/AncientMonolith.tscn")

const AURELIA_START_DIRECTION := Vector3(0.180171244, 0.960913302, 0.210199785)
const AURELIA_LANDING := preload("res://Planets/AureliaLanding.gd")
const AURELIA_TERRAIN := preload("res://Planets/AureliaTerrain.gdshader")

var _landing: Node3D
var data: PlanetData
var planet_name: String = "Planet"

var _noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _terrain_mesh_inst: Node3D
var _terrain_building := false
var _terrain_chunks: Array[MeshInstance3D] = []
var _chunk_directions: Array[Vector3] = []
var _chunk_extents: Array[float] = []
var _sky_obscuration := 0.0
var _orbital_material: StandardMaterial3D
var _distant_proxy_inst: MeshInstance3D
var _terrain_collider: CollisionShape3D
var _ocean_mesh_inst: MeshInstance3D
var _atmosphere_mesh_inst: MeshInstance3D

const SURFACE_LIFE := preload("res://Planets/SurfaceLife.gd")
var _surface_life: Node3D
var _moisture := FastNoiseLite.new()
var _ecosystem_direction := Vector3.ZERO
var _ecosystem_root: Node3D
var _ecosystem_active: bool = false
var _check_timer: float = 0.45


func initialize(planet_data: PlanetData) -> void:
	data = planet_data
	planet_name = data.planet_name
	name = planet_name.replace(" ", "_")

	_noise = FastNoiseLite.new()
	_noise.seed = data.seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.05
	_noise.fractal_gain = 0.48
	_noise.frequency = data.noise_frequency

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = data.seed_value + 777
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.fractal_octaves = 2
	_detail_noise.frequency = data.noise_frequency * 4.5

	_moisture.seed = data.seed_value + 81
	_moisture.frequency = 0.008
	_moisture.fractal_octaves = 2
	_build_distant_proxy()
	if is_aurelia():
		_build_terrain()
	if data.has_ocean:
		_build_ocean()
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
	if _check_timer < 0.45:
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
	_distant_proxy_inst.visible = _sky_obscuration < 0.97 and not (near_detail and is_instance_valid(_terrain_mesh_inst))
	if is_instance_valid(_ocean_mesh_inst):
		_ocean_mesh_inst.visible = near_detail and is_instance_valid(_terrain_mesh_inst)

	var near_surface := altitude < 210.0 and is_instance_valid(_terrain_mesh_inst)
	_surface_life.visible = near_surface
	if near_surface:
		_surface_life.update_tiles(direction)
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


func is_aurelia() -> bool:
	return planet_name == "Aurelia Prime"


func get_surface_radius_at_dir(unit_dir: Vector3) -> float:
	var dir: Vector3 = unit_dir.normalized()
	var sample_pos: Vector3 = dir * data.radius
	var n1: float = _noise.get_noise_3dv(sample_pos)
	var n2: float = _detail_noise.get_noise_3dv(sample_pos) * 0.22
	var h: float = (n1 + n2) * data.terrain_amplitude
	if h < 0.0:
		h *= 0.65
	if is_aurelia():
		var site := AURELIA_START_DIRECTION
		var site_distance := site.distance_to(dir) * data.radius
		var shelf := 9.0 + n1 * 3.2 + n2 * 9.0
		var ridge_distance := (site + Vector3(0.055, -0.013, 0.032)).normalized().distance_to(dir) * data.radius
		h += (1.0 - smoothstep(7.0, 64.0, ridge_distance)) * 26.0
		h = lerpf(shelf, h, smoothstep(45.0, 140.0, site_distance))
	return data.radius + h


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

	var eps: float = 0.015
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
	var resolution := 53 if is_aurelia() else 45
	var mesh: ArrayMesh = await _make_surface_mesh(resolution, false, staggered)
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
	_terrain_mesh_inst = Node3D.new()
	_terrain_mesh_inst.name = "TerrainMesh"
	add_child(_terrain_mesh_inst)
	_build_terrain_chunks(mesh.surface_get_arrays(0), resolution, material)

	_terrain_collider = CollisionShape3D.new()
	_terrain_collider.name = "TerrainCollider"
	_terrain_collider.shape = mesh.create_trimesh_shape()
	add_child(_terrain_collider)
	_terrain_building = false


func _build_terrain_chunks(source: Array, resolution: int, material: Material) -> void:
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = source[Mesh.ARRAY_COLOR]
	var half_face := (resolution - 1) >> 1
	var stride := half_face + 1
	var grid := PackedInt32Array()
	for y in range(half_face):
		for x in range(half_face):
			var index := y * stride + x
			grid.append(index)
			grid.append(index + stride)
			grid.append(index + 1)
			grid.append(index + 1)
			grid.append(index + stride)
			grid.append(index + stride + 1)
	for face in range(6):
		for row in range(2):
			for col in range(2):
				var start := face * resolution * resolution + row * half_face * resolution + col * half_face
				var center := vertices[start + (half_face >> 1) * (resolution + 1)].normalized()
				var extent := 0.0
				var points := PackedVector3Array()
				var gradients := PackedVector3Array()
				var tints := PackedColorArray()
				for y in range(stride):
					var first := start + y * resolution
					points.append_array(vertices.slice(first, first + stride))
					gradients.append_array(normals.slice(first, first + stride))
					tints.append_array(colors.slice(first, first + stride))
				for corner: int in [0, half_face, half_face * stride, points.size() - 1]:
					extent = maxf(extent, center.angle_to(points[corner].normalized()))
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = points
				arrays[Mesh.ARRAY_NORMAL] = gradients
				arrays[Mesh.ARRAY_COLOR] = tints
				arrays[Mesh.ARRAY_INDEX] = grid
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.surface_set_material(0, material)
				var tile := MeshInstance3D.new()
				tile.mesh = mesh
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_terrain_mesh_inst.add_child(tile)
				_terrain_chunks.append(tile)
				_chunk_directions.append(center)
				_chunk_extents.append(extent)


func _update_terrain_visibility(direction: Vector3, altitude: float) -> void:
	var horizon := acos(data.radius / (data.radius + maxf(altitude, 0.0)))
	# Include the tallest ridges behind the nominal horizon.
	var ridge_margin := acos(data.radius / (data.radius + data.terrain_amplitude)) + 0.045
	for index in range(_terrain_chunks.size()):
		var angle := horizon + ridge_margin + _chunk_extents[index]
		_terrain_chunks[index].visible = direction.dot(_chunk_directions[index]) >= cos(angle)


func _make_surface_mesh(resolution: int, orbital := false, staggered := false) -> ArrayMesh:
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
			await get_tree().process_frame
		var normal := faces[face_index]
		var horizontal := Vector3(normal.y, normal.z, normal.x)
		var vertical := normal.cross(horizontal)
		var base := face_index * face_size
		for y in range(resolution):
			for x in range(resolution):
				var cube := normal + horizontal * (2.0 * x / (resolution - 1) - 1.0) + vertical * (2.0 * y / (resolution - 1) - 1.0)
				var direction := _cube_to_sphere(cube)
				var radius := get_surface_radius_at_dir(direction)
				var index := base + y * resolution + x
				var display_radius := maxf(radius, data.radius + data.ocean_level_offset) if orbital and data.has_ocean else radius
				vertices[index] = direction * display_radius
				colors[index] = _evaluate_biome_color(direction, radius - data.radius, orbital)
		for y in range(resolution):
			for x in range(resolution):
				var index := base + y * resolution + x
				var tangent := vertices[base + y * resolution + mini(x + 1, resolution - 1)] - vertices[base + y * resolution + maxi(x - 1, 0)]
				var bitangent := vertices[base + mini(y + 1, resolution - 1) * resolution + x] - vertices[base + maxi(y - 1, 0) * resolution + x]
				normals[index] = tangent.cross(bitangent).normalized().lerp(vertices[index].normalized(), 0.22).normalized()
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


func _build_distant_proxy() -> void:
	var mesh: ArrayMesh = await _make_surface_mesh(13, true)
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


func _cube_to_sphere(p: Vector3) -> Vector3:
	var x2: float = p.x * p.x
	var y2: float = p.y * p.y
	var z2: float = p.z * p.z
	var sx: float = p.x * sqrt(maxf(0.0, 1.0 - y2 * 0.5 - z2 * 0.5 + (y2 * z2) / 3.0))
	var sy: float = p.y * sqrt(maxf(0.0, 1.0 - z2 * 0.5 - x2 * 0.5 + (z2 * x2) / 3.0))
	var sz: float = p.z * sqrt(maxf(0.0, 1.0 - x2 * 0.5 - y2 * 0.5 + (x2 * y2) / 3.0))
	return Vector3(sx, sy, sz).normalized()


func get_biome(direction: Vector3, height: float) -> int:
	if height > data.terrain_amplitude * 0.23:
		return 2
	return 1 if _moisture.get_noise_3dv(direction * data.radius) > -0.12 else 0


func _evaluate_biome_color(direction: Vector3, height: float, orbital: bool) -> Color:
	if data.has_ocean and height < data.ocean_level_offset + 2.4:
		return data.ocean_color if orbital and height < data.ocean_level_offset else data.shore_color
	var moisture := _moisture.get_noise_3dv(direction * data.radius)
	var woodland := data.lowland_color.lerp(data.tree_canopy_color.darkened(0.17), 0.62)
	var lowlands := data.lowland_color.lerp(woodland, smoothstep(-0.30, 0.35, moisture))
	var hills := lowlands.lerp(data.highland_color, smoothstep(0.13, 0.39, height / data.terrain_amplitude))
	return hills.lerp(data.peak_color, smoothstep(0.29, 0.67, height / data.terrain_amplitude))


func _build_ocean() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = data.radius + data.ocean_level_offset
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 72
	sphere.rings = 36

	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.ocean_color
	if data.ocean_color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.18
	mat.metallic = 0.25
	sphere.material = mat

	_ocean_mesh_inst = MeshInstance3D.new()
	_ocean_mesh_inst.name = "OceanSphere"
	_ocean_mesh_inst.mesh = sphere
	_ocean_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ocean_mesh_inst)


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
