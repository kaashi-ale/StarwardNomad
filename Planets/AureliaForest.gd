extends StaticBody3D
## A hand-shaped grove along the curved survey trail between the gate and arch.

const PROXY := preload("res://Planets/CanopyProxy.gd")
const MODELS := preload("res://Planets/AureliaForestMeshes.gd")
const TREES := [
	"res://Assets/Environment/Trees/quaternius-broadleaf.gltf",
	"res://Assets/Environment/Trees/quaternius-grove-tree.gltf",
	"res://Assets/Environment/Trees/quaternius-woodland-pine.gltf",
]
const TRUNK_RADII := [0.38, 0.40, 0.36]
const SHRUB := "res://Assets/Environment/Shrubs/quaternius-leaf-bush.gltf"
const FERN := "res://Assets/Environment/Plants/woodland-fern.gltf"
const WILDFLOWER := "res://Assets/Environment/Flowers/trail-wildflower.gltf"
const STONE := "res://Assets/Environment/Rocks/quaternius-mossy-rock.gltf"
const CENTER := Vector2(12.0, 66.0)
const EXTENT := Vector2(69.0, 77.0)
const ARCH := Vector2(25.0, 61.0)
const VILLAGE := Vector2(28.0, 104.0)
const LANDING_MEADOW := Vector2(56.0, 88.0)
const CLEARING := Vector2(12.5, 69.0)

var _landing: Node3D
var _planet: Node3D
var _ground: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _cover: Array[MultiMeshInstance3D] = []
var _canopy: Array[MultiMeshInstance3D] = []
var _stone: Mesh
var _tree_variants: Array[Array] = []
var _shrub_variants: Array[Mesh] = []
var _lod_timer := 0.0
var _shrub_batch: MultiMeshInstance3D


static func contains_offset(offset: Vector2) -> bool:
	return ((offset - CENTER) / EXTENT).length_squared() < 1.0


static func trail_x(y: float) -> float:
	return 5.0 + 20.0 * smoothstep(7.0, ARCH.y, y) + 3.0 * smoothstep(ARCH.y, VILLAGE.y, y)


static func is_village_open(offset: Vector2) -> bool:
	return ((offset - VILLAGE) / Vector2(23.0, 28.0)).length_squared() < 1.0


static func is_corridor_open(offset: Vector2) -> bool:
	return (offset.length() < 18.0
		or absf(offset.x - trail_x(offset.y)) < 3.8
		or offset.distance_to(ARCH) < 8.2
		or offset.distance_to(Vector2(-2, 37)) < 8.2
		or offset.distance_to(LANDING_MEADOW) < 10.5
		or is_village_open(offset))


func build(landing: Node3D, planet: Node3D) -> void:
	_landing = landing
	_planet = planet
	_ground = get_world_3d().direct_space_state
	_rng.seed = 55102
	_stone = _import_mesh(STONE)
	_build_canopy()
	_build_understory()
	_build_deadwood()
	_apply_quality(QualityManager.current_preset)
	QualityManager.quality_changed.connect(_apply_quality)


func _build_canopy() -> void:
	var tree_sites: Array[Vector2] = []
	var centers: Array[Vector2] = [
		Vector2(-12, 19), Vector2(23, 21), Vector2(-28, 39), Vector2(38, 41),
		Vector2(-19, 61), Vector2(5, 54), Vector2(35, 55), Vector2(56, 64),
		Vector2(-17, 85), Vector2(4, 83), Vector2(44, 76), Vector2(49, 105),
		Vector2(-1, 107), Vector2(2, 119), Vector2(18, 130), Vector2(47, 125), Vector2(58, 116),
	]
	for center in centers:
		var added := 0
		for attempt in range(17):
			var offset := center + Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-10, 10))
			if not contains_offset(offset) or is_corridor_open(offset) or offset.distance_to(CLEARING) < 5.9:
				continue
			var spaced := true
			for planted in tree_sites:
				if offset.distance_squared_to(planted) < 15.0:
					spaced = false
					break
			if spaced:
				tree_sites.append(offset)
				added += 1
				if added == 5:
					break

	for path: String in TREES:
		var variants := _import_mesh_variants(path)
		variants.append(PROXY.build(variants[0], _planet.data.tree_canopy_color.darkened(0.24), path == TREES[2]))
		_tree_variants.append(variants)
	for section in range(2):
		for variant in range(3):
			var transforms: Array[Transform3D] = []
			for index in range(variant, tree_sites.size(), 3):
				var offset := tree_sites[index]
				if int(offset.y >= 76.0) != section:
					continue
				var ground := _ground_pose(offset)
				var size := _rng.randf_range(0.70, 1.27)
				var proportions := Vector3(size * _rng.randf_range(0.85, 1.15), size, size)
				transforms.append(Transform3D(ground.basis * Basis.from_scale(proportions), ground.origin))
				var trunk := CylinderShape3D.new()
				trunk.radius = TRUNK_RADII[variant] * maxf(proportions.x, proportions.z)
				trunk.height = 4.35 * size
				_add_collision(trunk, ground.translated_local(Vector3.UP * (trunk.height * 0.5 - 0.12)))
			var batch_name := "Canopy%d_%d" % [section, variant]
			_canopy.append(_batch(batch_name, _tree_variants[variant][_mesh_profile(QualityManager.current_preset)], transforms))


func _import_mesh(path: String) -> Mesh:
	# The catalog contains static, single-mesh scenes with baked dimensions.
	var scene := load(path) as PackedScene
	var model := scene.instantiate()
	var instance := model as MeshInstance3D
	if instance == null:
		instance = model.get_child(0) as MeshInstance3D
	var mesh := instance.mesh
	model.free()
	return mesh


func _import_mesh_variants(path: String) -> Array[Mesh]:
	var original := _import_mesh(path)
	var compact := load(path.get_basename() + "-compact.res") as ArrayMesh
	for surface in range(compact.get_surface_count()):
		compact.surface_set_material(surface, original.surface_get_material(surface))
	return [original, compact]


func _mesh_profile(preset: int) -> int:
	return 1 if preset == QualityManager.Preset.ECONOMY or preset == QualityManager.Preset.LOW else 0


func _build_understory() -> void:
	var shrubs: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var blossoms: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	for y: float in [21.0, 29.0, 42.0, 46.0, 49.0, 54.0, 71.0, 78.0, 87.0]:
		var x := trail_x(y)
		blossoms.append(_scaled_pose(Vector2(x + 2.9, y), _rng.randf_range(1.1, 1.5)))
		blossoms.append(_scaled_pose(Vector2(x + 3.4, y + 0.53), _rng.randf_range(0.74, 1.1)))
		ferns.append(_scaled_pose(Vector2(x - 3.1, y + 0.3), _rng.randf_range(1.12, 1.52)))
	for i in range(530):
		var angle := _rng.randf_range(0, TAU)
		var radial := sqrt(_rng.randf())
		var offset := CENTER + Vector2(cos(angle), sin(angle)) * EXTENT * radial
		if not contains_offset(offset) or is_village_open(offset) or offset.length() < 16.0 or offset.distance_to(LANDING_MEADOW) < 10.5:
			continue
		var trail_distance := absf(offset.x - trail_x(offset.y))
		var clearing_distance := offset.distance_to(CLEARING)
		if trail_distance < 2.55 or clearing_distance < 3.6 or offset.distance_to(ARCH) < 3.8:
			continue
		var patch := sin(offset.x * 0.43 + offset.y * 0.11) + cos(offset.y * 0.46 - offset.x * 0.18)
		var roll := _rng.randf()
		if trail_distance < 5.4 or clearing_distance < 7.0:
			if roll < 0.62:
				blossoms.append(_scaled_pose(offset, _rng.randf_range(0.78, 1.48)))
			elif roll < 0.86:
				ferns.append(_scaled_pose(offset, _rng.randf_range(0.76, 1.28)))
			else:
				stones.append(_scaled_pose(offset, _rng.randf_range(0.29, 0.72)))
		elif patch > -0.24:
			if roll < 0.22 and shrubs.size() < 45:
				shrubs.append(_scaled_pose(offset, _rng.randf_range(0.55, 1.05)))
			elif roll < 0.86:
				ferns.append(_scaled_pose(offset, _rng.randf_range(0.78, 1.45)))
			else:
				stones.append(_scaled_pose(offset, _rng.randf_range(0.35, 0.77)))
	_shrub_variants = _import_mesh_variants(SHRUB)
	_shrub_batch = _batch("Understory", _shrub_variants[_mesh_profile(QualityManager.current_preset)], shrubs)
	_cover.append(_shrub_batch)
	_cover.append(_batch("FernBanks", _import_mesh(FERN), ferns))
	_cover.append(_batch("Wildflowers", _import_mesh(WILDFLOWER), blossoms))
	_cover.append(_batch("LooseStone", _stone, stones))


func _build_deadwood() -> void:
	var logs: Array[Transform3D] = []
	for offset: Vector2 in [Vector2(11, 65), Vector2(35, 59), Vector2(38, 82), Vector2(-18, 30), Vector2(5, 102), Vector2(54, 112)]:
		var pose := _ground_pose(offset)
		var size := _rng.randf_range(0.97, 1.30)
		logs.append(Transform3D(pose.basis.scaled(Vector3.ONE * size), pose.origin))
		var log_shape := CapsuleShape3D.new()
		log_shape.radius = 0.32 * size
		log_shape.height = 3.03 * size
		var transform := pose.translated_local(Vector3.UP * 0.33 * size).rotated_local(Vector3.BACK, PI * 0.5)
		_add_collision(log_shape, transform)
	_batch("FallenWood", MODELS.new().log_model(), logs)

	var formations: Array[Transform3D] = []
	for offset: Vector2 in [Vector2(8, 57), Vector2(17, 71), Vector2(37, 52), Vector2(35, 70), Vector2(15, 78), Vector2(-13, 46), Vector2(6, 22), Vector2(57, 74)]:
		var pose := _ground_pose(offset)
		var size := _rng.randf_range(1.1, 1.7)
		formations.append(Transform3D(pose.basis.scaled(Vector3.ONE * size), pose.origin))
		var boulder := SphereShape3D.new()
		boulder.radius = size * 0.54
		_add_collision(boulder, pose.translated_local(Vector3.UP * 0.16 * size))
	_batch("WeatheredBoulders", _stone, formations)


func _scaled_pose(offset: Vector2, size: float) -> Transform3D:
	var pose := _ground_pose(offset)
	pose.basis = pose.basis.scaled(Vector3.ONE * size)
	return pose


func _ground_pose(offset: Vector2) -> Transform3D:
	var point: Vector3 = _landing.surface_at_offset(offset)
	var up := point.normalized()
	var center: Vector3 = _planet.global_position
	var world := center + point
	var ray := PhysicsRayQueryParameters3D.create(world + up * 22.0, world - up * 22.0, 1)
	var hit := _ground.intersect_ray(ray)
	if not hit.is_empty():
		world = hit["position"]
	var reference := Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.UP
	var basis := Basis.looking_at(reference.slide(up), up).rotated(up, _rng.randf_range(0.0, TAU))
	return Transform3D(basis, to_local(world - up * 0.048))


func _add_collision(shape: Shape3D, placement: Transform3D) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	collider.transform = placement


func _batch(label: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	var anchor := Vector3.ZERO
	for pose in transforms:
		anchor += pose.origin
	anchor /= maxf(1.0, transforms.size())
	for i in range(transforms.size()):
		var pose := transforms[i]
		pose.origin -= anchor
		instances.set_instance_transform(i, pose)
		instances.set_instance_color(i, Color("#c5cdaf").lerp(Color.WHITE, _rng.randf_range(0.37, 1.0)))
	var display := MultiMeshInstance3D.new()
	display.name = label
	display.multimesh = instances
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.position = anchor
	display.visibility_range_end = 126.0
	display.visibility_range_end_margin = 12.0
	add_child(display)
	return display


func _apply_quality(preset: int) -> void:
	var economy := preset == QualityManager.Preset.ECONOMY
	var mesh_profile := _mesh_profile(preset)
	for batch in _canopy:
		batch.visibility_range_end = 0.0
	_update_canopies()
	_shrub_batch.multimesh.mesh = _shrub_variants[mesh_profile]
	var visible_fraction := 1.0
	if preset == QualityManager.Preset.ECONOMY:
		visible_fraction = 0.44
	elif preset == QualityManager.Preset.LOW:
		visible_fraction = 0.65
	for batch: MultiMeshInstance3D in _cover:
		batch.lod_bias = 0.55 if economy else 0.85
		batch.visibility_range_end = 86.0 if economy else 108.0
		var instances := batch.multimesh
		instances.visible_instance_count = roundi(instances.instance_count * visible_fraction)

func _process(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.24
		_update_canopies()


func _update_canopies() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var profile := QualityManager.detail_distance_multiplier
	for index in range(_canopy.size()):
		var batch := _canopy[index]
		var distance := camera.global_position.distance_to(batch.global_position)
		var previous := int(batch.get_meta("lod", 1))
		var lod := PROXY.lod_at(distance, previous, profile)
		if not batch.has_meta("lod") or previous != lod:
			batch.multimesh.mesh = _tree_variants[index % TREES.size()][lod]
			batch.set_meta("lod", lod)
		batch.visible = distance < 330.0 + 190.0 * profile + (42.0 if batch.visible else 0.0)
