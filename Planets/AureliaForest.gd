extends StaticBody3D
## A hand-shaped grove along the curved survey trail between the gate and arch.

const MODELS := preload("res://Planets/AureliaForestMeshes.gd")
const CENTER := Vector2(25.0, 63.0)
const CLEARING := Vector2(12.5, 69.0)

var _landing: Node3D
var _planet: Node3D
var _ground: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _cover: Array[MultiMesh] = []
var _canopy: Array[MultiMesh] = []
var _compact_canopy := false


static func contains_offset(offset: Vector2) -> bool:
	return ((offset - CENTER) / Vector2(28.0, 29.0)).length_squared() < 1.0 and offset.x > 1.5


static func trail_x(y: float) -> float:
	var distance := y - 61.0
	return 25.0 + distance * 0.68 + 3.1 * sin(distance * 0.105)


func build(landing: Node3D, planet: Node3D) -> void:
	_landing = landing
	_planet = planet
	_ground = get_world_3d().direct_space_state
	_rng.seed = 55102
	_compact_canopy = QualityManager.current_preset == QualityManager.Preset.ECONOMY
	_build_canopy()
	_build_understory()
	_build_deadwood()
	_apply_quality(QualityManager.current_preset)
	QualityManager.quality_changed.connect(_apply_quality)


func _build_canopy() -> void:
	# A staggered canopy on both sides preserves sightlines to the arch and the clearing.
	var tree_sites: Array[Vector2] = [
		Vector2(5, 45), Vector2(16, 44), Vector2(20, 42), Vector2(23, 46),
		Vector2(7, 52), Vector2(11, 54), Vector2(30, 48), Vector2(35, 51),
		Vector2(6, 59), Vector2(13, 60), Vector2(17, 64), Vector2(38, 55),
		Vector2(6, 68), Vector2(20, 72), Vector2(23, 75), Vector2(39, 64),
		Vector2(10, 78), Vector2(14, 81), Vector2(20, 85), Vector2(29, 86),
		Vector2(25, 80), Vector2(35, 80), Vector2(44, 74), Vector2(47, 67),
		Vector2(43, 58), Vector2(33, 56), Vector2(48, 59),
	]
	for variant in range(3):
		var transforms: Array[Transform3D] = []
		for index in range(variant, tree_sites.size(), 3):
			var ground := _ground_pose(tree_sites[index])
			var size := _rng.randf_range(0.72, 1.24)
			var proportions := Vector3(size * _rng.randf_range(0.91, 1.12), size, size)
			transforms.append(Transform3D(ground.basis * Basis.from_scale(proportions), ground.origin))
			var trunk := CylinderShape3D.new()
			trunk.radius = 0.37 * maxf(proportions.x, proportions.z)
			trunk.height = 4.35 * size
			_add_collision(trunk, ground.translated_local(Vector3.UP * (trunk.height * 0.5 - 0.12)))
		_canopy.append(_batch("Canopy%d" % variant, MODELS.new().tree(variant, _compact_canopy), transforms))


func _build_understory() -> void:
	var shrubs: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var blossoms: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	for y: float in [42.0, 46.0, 49.0, 54.0, 71.0, 75.0]:
		var x := trail_x(y)
		blossoms.append(_scaled_pose(Vector2(x + 2.9, y), _rng.randf_range(1.1, 1.5)))
		blossoms.append(_scaled_pose(Vector2(x + 3.4, y + 0.53), _rng.randf_range(0.74, 1.1)))
		ferns.append(_scaled_pose(Vector2(x - 3.1, y + 0.3), _rng.randf_range(1.12, 1.52)))
	for i in range(330):
		var angle := _rng.randf_range(0, TAU)
		var radial := sqrt(_rng.randf())
		var offset := CENTER + Vector2(cos(angle) * 27.0, sin(angle) * 27.0) * radial
		if not contains_offset(offset) or offset.distance_to(Vector2(25, 61)) < 7.6:
			continue
		var trail_distance := absf(offset.x - trail_x(offset.y))
		var clearing_distance := offset.distance_to(CLEARING)
		if trail_distance < 2.5 or clearing_distance < 3.6:
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
	_cover.append(_batch("Understory", MODELS.new().shrub(), shrubs))
	_cover.append(_batch("FernBanks", MODELS.new().fern(), ferns))
	_cover.append(_batch("Wildflowers", MODELS.new().flowers(), blossoms))
	_cover.append(_batch("LooseStone", MODELS.new().stone(), stones))


func _build_deadwood() -> void:
	var logs: Array[Transform3D] = []
	for offset: Vector2 in [Vector2(11, 65), Vector2(35, 59), Vector2(28, 82)]:
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
	for offset: Vector2 in [Vector2(8, 57), Vector2(17, 71), Vector2(37, 52), Vector2(35, 70), Vector2(15, 78)]:
		var pose := _ground_pose(offset)
		var size := _rng.randf_range(1.1, 1.7)
		formations.append(Transform3D(pose.basis.scaled(Vector3.ONE * size), pose.origin))
		var boulder := SphereShape3D.new()
		boulder.radius = size * 0.54
		_add_collision(boulder, pose.translated_local(Vector3.UP * 0.16 * size))
	_batch("WeatheredBoulders", MODELS.new().stone(), formations)


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


func _batch(label: String, mesh: ArrayMesh, transforms: Array[Transform3D]) -> MultiMesh:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i, transforms[i])
		instances.set_instance_color(i, Color("#c5cdaf").lerp(Color.WHITE, _rng.randf_range(0.37, 1.0)))
	var display := MultiMeshInstance3D.new()
	display.name = label
	display.multimesh = instances
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.visibility_range_end = 175.0
	display.visibility_range_end_margin = 12.0
	add_child(display)
	return instances


func _apply_quality(preset: int) -> void:
	var compact := preset == QualityManager.Preset.ECONOMY
	if compact != _compact_canopy:
		_compact_canopy = compact
		for variant in range(_canopy.size()):
			_canopy[variant].mesh = MODELS.new().tree(variant, compact)
	var visible_fraction := 1.0
	if preset == QualityManager.Preset.ECONOMY:
		visible_fraction = 0.56
	elif preset == QualityManager.Preset.LOW:
		visible_fraction = 0.77
	for batch: MultiMesh in _cover:
		batch.visible_instance_count = roundi(batch.instance_count * visible_fraction)
