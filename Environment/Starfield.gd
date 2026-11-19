extends MultiMeshInstance3D
## Sky-locked procedural starfield using a single MultiMesh draw call.
## Fades smoothly when descending into bright daytime planetary atmospheres.

@export var star_count: int = 460
@export var sky_radius: float = 51000.0

var _star_mat: StandardMaterial3D


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_stars()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position


func set_space_visibility(space_factor: float) -> void:
	if _star_mat:
		visible = space_factor > 0.16
		var alpha := smoothstep(0.16, 1.0, space_factor)
		_star_mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)


func _build_stars() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(115.0, 115.0)

	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_star_mat.vertex_color_use_as_albedo = true
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.disable_fog = true
	quad.material = _star_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = star_count

	var rng := RandomNumberGenerator.new()
	rng.seed = 42099

	var palette: Array[Color] = [
		Color(0.95, 0.97, 1.0, 1.0),
		Color(0.75, 0.88, 1.0, 1.0),
		Color(1.0, 0.92, 0.74, 1.0),
		Color(1.0, 0.76, 0.68, 1.0),
		Color(0.72, 1.0, 0.92, 1.0)
	]

	for i in range(star_count):
		var theta: float = rng.randf_range(0.0, TAU)
		var phi: float = acos(rng.randf_range(-1.0, 1.0))
		var dir := Vector3(
			sin(phi) * cos(theta),
			cos(phi),
			sin(phi) * sin(theta)
		)
		var pos: Vector3 = dir * sky_radius
		var s: float = rng.randf_range(0.55, 1.85)
		var t := Transform3D(Basis().scaled(Vector3.ONE * s), pos)
		mm.set_instance_transform(i, t)
		var c: Color = palette[rng.randi() % palette.size()]
		c.a = rng.randf_range(0.55, 1.0)
		mm.set_instance_color(i, c)

	multimesh = mm
