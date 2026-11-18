class_name PlanetBody
extends StaticBody3D
## Spherical procedural planet with cube-sphere geometry, vertex biome coloring,
## 2-tier distance LOD, Fresnel atmosphere shell, optional ocean sphere,
## MultiMesh flora/rock scatter, and local ecosystem spawned on approach.

const CREATURE_SCENE := preload("res://Creatures/AlienCreature.tscn")
const SENTINEL_SCENE := preload("res://Creatures/HostileSentinel.tscn")
const MONOLITH_SCENE := preload("res://Combat/AncientMonolith.tscn")

var data: PlanetData
var planet_name: String = "Planet"

var _noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _terrain_mesh_inst: MeshInstance3D
var _distant_proxy_inst: MeshInstance3D
var _terrain_collider: CollisionShape3D
var _ocean_mesh_inst: MeshInstance3D
var _atmosphere_mesh_inst: MeshInstance3D

var _flora_multimesh: MultiMeshInstance3D
var _rock_multimesh: MultiMeshInstance3D
var _ecosystem_root: Node3D
var _ecosystem_active: bool = false
var _check_timer: float = 0.0


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

	_build_terrain()
	_build_distant_proxy()
	if data.has_ocean:
		_build_ocean()
	_build_atmosphere_shell()
	_build_scatter_multimeshes()

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

	# 1. Ecosystem lifecycle (spawns only inside/near atmosphere)
	var activation_radius: float = atmo_edge + 160.0
	if dist <= activation_radius and not _ecosystem_active:
		_activate_ecosystem()
	elif dist > activation_radius + 140.0 and _ecosystem_active:
		_deactivate_ecosystem()

	# 2. 2-tier Terrain LOD + Overdraw Reduction for Mali-G57 MP1
	var near_detail: bool = dist <= (atmo_edge + 550.0)
	if is_instance_valid(_terrain_mesh_inst):
		_terrain_mesh_inst.visible = near_detail
	if is_instance_valid(_distant_proxy_inst):
		_distant_proxy_inst.visible = not near_detail
	if is_instance_valid(_ocean_mesh_inst):
		_ocean_mesh_inst.visible = near_detail
	if is_instance_valid(_atmosphere_mesh_inst):
		_atmosphere_mesh_inst.visible = dist <= (atmo_edge + 2600.0)


func get_surface_radius_at_dir(unit_dir: Vector3) -> float:
	var dir: Vector3 = unit_dir.normalized()
	var sample_pos: Vector3 = dir * data.radius
	var n1: float = _noise.get_noise_3dv(sample_pos)
	var n2: float = _detail_noise.get_noise_3dv(sample_pos) * 0.22
	var h: float = (n1 + n2) * data.terrain_amplitude
	if h < 0.0:
		h *= 0.65
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


func _build_terrain() -> void:
	# 34x34 grid per cube-sphere face = 6,534 quads (13,068 tris) per planet
	var res: int = 34
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var faces: Array[Vector3] = [
		Vector3.UP, Vector3.DOWN,
		Vector3.LEFT, Vector3.RIGHT,
		Vector3.FORWARD, Vector3.BACK
	]

	for face_normal in faces:
		var axis_a := Vector3(face_normal.y, face_normal.z, face_normal.x)
		var axis_b: Vector3 = face_normal.cross(axis_a)

		var verts: PackedVector3Array = PackedVector3Array()
		var cols: PackedColorArray = PackedColorArray()
		verts.resize(res * res)
		cols.resize(res * res)

		for y in range(res):
			var ty: float = (float(y) / float(res - 1) - 0.5) * 2.0
			for x in range(res):
				var tx: float = (float(x) / float(res - 1) - 0.5) * 2.0
				var cube_pt: Vector3 = face_normal + axis_a * tx + axis_b * ty
				var sphere_dir: Vector3 = _cube_to_sphere(cube_pt)
				var r: float = get_surface_radius_at_dir(sphere_dir)
				var idx: int = y * res + x
				verts[idx] = sphere_dir * r
				cols[idx] = _evaluate_biome_color(r - data.radius)

		# Godot 4 uses Clockwise front-face winding when viewed from outside:
		# (v2 - v0) x (v1 - v0) points along +face_normal (outward).
		for y in range(res - 1):
			for x in range(res - 1):
				var i0: int = y * res + x
				var i1: int = i0 + 1
				var i2: int = (y + 1) * res + x
				var i3: int = i2 + 1

				st.set_color(cols[i0])
				st.add_vertex(verts[i0])
				st.set_color(cols[i2])
				st.add_vertex(verts[i2])
				st.set_color(cols[i1])
				st.add_vertex(verts[i1])

				st.set_color(cols[i1])
				st.add_vertex(verts[i1])
				st.set_color(cols[i2])
				st.add_vertex(verts[i2])
				st.set_color(cols[i3])
				st.add_vertex(verts[i3])

	st.index()
	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.88
	mat.metallic = 0.04
	array_mesh.surface_set_material(0, mat)

	_terrain_mesh_inst = MeshInstance3D.new()
	_terrain_mesh_inst.name = "TerrainMesh"
	_terrain_mesh_inst.mesh = array_mesh
	add_child(_terrain_mesh_inst)

	_terrain_collider = CollisionShape3D.new()
	_terrain_collider.name = "TerrainCollider"
	_terrain_collider.shape = array_mesh.create_trimesh_shape()
	add_child(_terrain_collider)


func _build_distant_proxy() -> void:
	# Ultra-lightweight LOD sphere (~384 tris) used when viewing planet from deep space
	var sphere := SphereMesh.new()
	sphere.radius = data.radius
	sphere.height = data.radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 10

	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.lowland_color.lerp(data.ocean_color, 0.35 if data.has_ocean else 0.0)
	mat.roughness = 0.82
	sphere.material = mat

	_distant_proxy_inst = MeshInstance3D.new()
	_distant_proxy_inst.name = "DistantProxyMesh"
	_distant_proxy_inst.mesh = sphere
	_distant_proxy_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_distant_proxy_inst.visible = false
	add_child(_distant_proxy_inst)


func _cube_to_sphere(p: Vector3) -> Vector3:
	var x2: float = p.x * p.x
	var y2: float = p.y * p.y
	var z2: float = p.z * p.z
	var sx: float = p.x * sqrt(maxf(0.0, 1.0 - y2 * 0.5 - z2 * 0.5 + (y2 * z2) / 3.0))
	var sy: float = p.y * sqrt(maxf(0.0, 1.0 - z2 * 0.5 - x2 * 0.5 + (z2 * x2) / 3.0))
	var sz: float = p.z * sqrt(maxf(0.0, 1.0 - x2 * 0.5 - y2 * 0.5 + (x2 * y2) / 3.0))
	return Vector3(sx, sy, sz).normalized()


func _evaluate_biome_color(height_offset: float) -> Color:
	var h_norm: float = clampf(height_offset / maxf(data.terrain_amplitude, 1.0), -1.0, 1.0)
	if data.has_ocean and height_offset < data.ocean_level_offset + 2.2:
		return data.shore_color
	if h_norm < 0.25:
		return data.lowland_color.lerp(data.highland_color, clampf((h_norm + 0.2) / 0.45, 0.0, 1.0))
	elif h_norm < 0.62:
		return data.highland_color
	else:
		return data.highland_color.lerp(data.peak_color, clampf((h_norm - 0.62) / 0.35, 0.0, 1.0))


func _build_ocean() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = data.radius + data.ocean_level_offset
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 14

	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.ocean_color
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
render_mode blend_add, depth_draw_never, cull_front, unshaded;

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


func _build_scatter_multimeshes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed_value + 303

	# 1. Alien Trees / Exotic Flora (1 draw call via MultiMesh)
	var tree_count: int = int(260 * QualityManager.scatter_density_multiplier)
	var tree_mesh := _create_stylized_tree_mesh()
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	tree_mm.use_colors = true
	tree_mm.mesh = tree_mesh
	tree_mm.instance_count = tree_count

	var placed_trees: int = 0
	for _i in range(tree_count * 2):
		if placed_trees >= tree_count:
			break
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var r: float = get_surface_radius_at_dir(dir)
		var h_off: float = r - data.radius
		if data.has_ocean and h_off <= data.ocean_level_offset + 1.5:
			continue
		if h_off > data.terrain_amplitude * 0.55:
			continue
		var up: Vector3 = dir
		var ref: Vector3 = Vector3.RIGHT if absf(up.y) > 0.9 else Vector3.UP
		var right: Vector3 = ref.cross(up).normalized()
		var fwd: Vector3 = up.cross(right).normalized()
		var b := Basis(right, up, fwd).rotated(up, rng.randf_range(0.0, TAU))
		var sc: float = rng.randf_range(0.75, 1.55)
		b = b.scaled(Vector3.ONE * sc)
		tree_mm.set_instance_transform(placed_trees, Transform3D(b, dir * (r - 0.25)))
		tree_mm.set_instance_color(placed_trees, data.tree_canopy_color.lerp(data.crystal_color, rng.randf_range(0.0, 0.35)))
		placed_trees += 1
	tree_mm.visible_instance_count = placed_trees

	_flora_multimesh = MultiMeshInstance3D.new()
	_flora_multimesh.name = "FloraMultiMesh"
	_flora_multimesh.multimesh = tree_mm
	_flora_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flora_multimesh.visibility_range_end = 190.0 * QualityManager.detail_distance_multiplier
	_flora_multimesh.visibility_range_end_margin = 25.0
	add_child(_flora_multimesh)

	# 2. Rocks & Crystalline Outcrops (1 draw call via MultiMesh)
	var rock_count: int = int(220 * QualityManager.scatter_density_multiplier)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.6
	rock_mesh.height = 2.4
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 4
	var rock_mat := StandardMaterial3D.new()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.roughness = 0.85
	rock_mesh.material = rock_mat

	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.use_colors = true
	rock_mm.mesh = rock_mesh
	rock_mm.instance_count = rock_count

	for i in range(rock_count):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var r: float = get_surface_radius_at_dir(dir)
		var up: Vector3 = dir
		var ref: Vector3 = Vector3.RIGHT if absf(up.y) > 0.9 else Vector3.UP
		var right: Vector3 = ref.cross(up).normalized()
		var fwd: Vector3 = up.cross(right).normalized()
		var b := Basis(right, up, fwd).rotated(up, rng.randf_range(0.0, TAU))
		b = b.scaled(Vector3(rng.randf_range(0.7, 2.2), rng.randf_range(0.6, 1.8), rng.randf_range(0.7, 2.2)))
		rock_mm.set_instance_transform(i, Transform3D(b, dir * (r - 0.3)))
		var is_crystal: bool = (i % 5 == 0)
		rock_mm.set_instance_color(i, data.crystal_color if is_crystal else data.highland_color.darkened(0.15))

	_rock_multimesh = MultiMeshInstance3D.new()
	_rock_multimesh.name = "RockMultiMesh"
	_rock_multimesh.multimesh = rock_mm
	_rock_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rock_multimesh.visibility_range_end = 180.0 * QualityManager.detail_distance_multiplier
	_rock_multimesh.visibility_range_end_margin = 20.0
	add_child(_rock_multimesh)


func _create_stylized_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk_h: float = 3.2
	var canopy_r: float = 2.4
	var canopy_top: float = 6.8
	var sides: int = 5

	for i in range(sides):
		var a0: float = float(i) / float(sides) * TAU
		var a1: float = float(i + 1) / float(sides) * TAU
		var p0 := Vector3(cos(a0) * 0.35, 0.0, sin(a0) * 0.35)
		var p1 := Vector3(cos(a1) * 0.35, 0.0, sin(a1) * 0.35)
		var p2 := Vector3(cos(a0) * 0.22, trunk_h, sin(a0) * 0.22)
		var p3 := Vector3(cos(a1) * 0.22, trunk_h, sin(a1) * 0.22)

		st.set_color(Color(0.32, 0.24, 0.20))
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)

		st.add_vertex(p1)
		st.add_vertex(p3)
		st.add_vertex(p2)

		var c0 := Vector3(cos(a0) * canopy_r, trunk_h - 0.3, sin(a0) * canopy_r)
		var c1 := Vector3(cos(a1) * canopy_r, trunk_h - 0.3, sin(a1) * canopy_r)
		var apex := Vector3(0.0, canopy_top, 0.0)

		st.set_color(Color.WHITE)
		st.add_vertex(c0)
		st.add_vertex(c1)
		st.add_vertex(apex)

	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.72
	m.surface_set_material(0, mat)
	return m


func _activate_ecosystem() -> void:
	_ecosystem_active = true
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed_value + 999

	for i in range(data.ruin_count):
		var dir := _pick_land_direction(rng)
		var r: float = get_surface_radius_at_dir(dir)
		var monolith := MONOLITH_SCENE.instantiate()
		_ecosystem_root.add_child(monolith)
		monolith.position = dir * r
		_align_node_to_up(monolith, dir)
		if monolith.has_method("setup"):
			monolith.setup(planet_name, "monolith_%d" % i, "Monólito Ancestral #%d" % (i + 1), data.crystal_color)

	var creature_limit: int = int(data.wildlife_count * QualityManager.scatter_density_multiplier) + 3
	for i in range(creature_limit):
		var dir := _pick_land_direction(rng)
		var r: float = get_surface_radius_at_dir(dir)
		var creature := CREATURE_SCENE.instantiate()
		_ecosystem_root.add_child(creature)
		creature.position = dir * (r + 1.0)
		_align_node_to_up(creature, dir)
		if creature.has_method("setup_planet"):
			creature.setup_planet(self, data.crystal_color, rng.randf_range(0.85, 1.45))

	if data.has_hostiles:
		for i in range(4):
			var dir := _pick_land_direction(rng)
			var r: float = get_surface_radius_at_dir(dir)
			var sentinel := SENTINEL_SCENE.instantiate()
			_ecosystem_root.add_child(sentinel)
			sentinel.position = dir * (r + 4.5)
			_align_node_to_up(sentinel, dir)
			if sentinel.has_method("setup_planet"):
				sentinel.setup_planet(self)


func _deactivate_ecosystem() -> void:
	_ecosystem_active = false
	for child in _ecosystem_root.get_children():
		child.queue_free()


func _pick_land_direction(rng: RandomNumberGenerator) -> Vector3:
	for _attempt in range(25):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		if not data.has_ocean:
			return dir
		var r: float = get_surface_radius_at_dir(dir)
		if (r - data.radius) > data.ocean_level_offset + 2.0:
			return dir
	return Vector3.UP


func _align_node_to_up(node: Node3D, up_dir: Vector3) -> void:
	var up: Vector3 = up_dir.normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(up.y) > 0.9 else Vector3.UP
	var right: Vector3 = ref.cross(up).normalized()
	var fwd: Vector3 = up.cross(right).normalized()
	node.basis = Basis(right, up, fwd)
