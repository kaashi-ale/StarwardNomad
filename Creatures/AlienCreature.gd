extends CharacterBody3D
## Campospring. A small, curious herbivore that gives an approaching explorer room.

var _planet: PlanetBody
var _health := 40.0
var _heading := Vector3.FORWARD
var _state_timer := 0.0
var _running := false
var _wandering := true
var _phase := 0.0
var _pace := 0.0
var _vertical := 0.0
var _limbs: Array[MeshInstance3D] = []

@onready var _visual: Node3D = $Visual


func setup_planet(planet: PlanetBody, tint: Color, size: float) -> void:
	_planet = planet
	var collider: CollisionShape3D = $CollisionShape3D
	var capsule := collider.shape.duplicate() as CapsuleShape3D
	capsule.height *= size
	capsule.radius *= size
	collider.shape = capsule
	collider.position.y *= size
	_visual.scale = Vector3.ONE * size
	_heading = -basis.z
	_state_timer = randf_range(1.0, 3.0)
	_build_body(tint)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_planet):
		return
	var up := _planet.global_position.direction_to(global_position)
	up_direction = up
	_state_timer -= delta
	if _state_timer <= 0.0:
		_wandering = not _wandering
		_state_timer = randf_range(1.7, 4.1)
		_heading = _heading.rotated(up, randf_range(-1.1, 1.1))

	_running = false
	var player := GameState.player_node
	if is_instance_valid(player) and GameState.current_mode == GameState.ControlMode.ON_FOOT:
		var away := global_position - player.global_position
		if away.length_squared() < 15.0 and away.slide(up).length_squared() > 0.001:
			_heading = away.slide(up).normalized()
			_running = true
	_heading = _heading.slide(up).normalized()
	if _heading.is_zero_approx():
		_heading = global_basis.x.slide(up).normalized()
	var speed := 4.1 if _running else (1.75 if _wandering else 0.0)
	_pace = move_toward(_pace, speed, delta * 7.0)
	_vertical = -1.0 if is_on_floor() else maxf(-22.0, _vertical - 16.0 * delta)
	velocity = _heading * _pace + up * _vertical
	move_and_slide()
	global_basis = global_basis.orthonormalized().slerp(Basis.looking_at(_heading, up), 1.0 - exp(-delta * 9.0))
	_phase = fmod(_phase + delta * (2.1 + _pace * 3.3), TAU)
	var gait := clampf(_pace / 2.7, 0.0, 1.0)
	_visual.position.y = sin(_phase * 2.0) * 0.018 + absf(sin(_phase)) * gait * 0.11
	_visual.rotation.z = sin(_phase) * gait * 0.07
	for i in range(_limbs.size()):
		_limbs[i].rotation.x = sin(_phase + PI * i) * 0.62 * gait


func take_damage(amount: float) -> void:
	_health -= amount
	_wandering = true
	_state_timer = 4.0
	if _health <= 0.0:
		GameState.post_notification("Organismo alienígena neutralizado.", Color(1.0, 0.7, 0.4))
		queue_free()


func _build_body(tint: Color) -> void:
	var coat := Color("#bd7349").lerp(tint, 0.27)
	var cream := Color("#f8deac")
	var brown := Color("#4b3027")
	var berry := Color("#d98d70")
	var face := Color("#241f23")
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.83
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	var mesh_arrays := sphere.get_mesh_arrays()
	var surface := _surface(material)
	_oval(surface, mesh_arrays, Vector3(0, 0.55, 0.16), Vector3(0.83, 0.72, 1.05), coat)
	_oval(surface, mesh_arrays, Vector3(0, 0.70, -0.34), Vector3(0.77, 0.72, 0.63), coat.lightened(0.12))
	_oval(surface, mesh_arrays, Vector3(0, 0.56, -0.56), Vector3(0.53, 0.34, 0.42), cream)
	_oval(surface, mesh_arrays, Vector3(0, 0.61, -0.74), Vector3(0.16, 0.11, 0.09), face)
	_oval(surface, mesh_arrays, Vector3(0, 0.70, 0.67), Vector3(0.37, 0.35, 0.51), cream)
	for side: float in [-1.0, 1.0]:
		_oval(surface, mesh_arrays, Vector3(side * 0.25, 1.08, -0.28), Vector3(0.21, 0.47, 0.17), coat, side * -0.37)
		_oval(surface, mesh_arrays, Vector3(side * 0.25, 1.10, -0.358), Vector3(0.13, 0.32, 0.055), berry, side * -0.37)
		_oval(surface, mesh_arrays, Vector3(side * 0.23, 0.77, -0.582), Vector3(0.19, 0.24, 0.11), face)
		_oval(surface, mesh_arrays, Vector3(side * 0.23 - 0.025, 0.815, -0.637), Vector3(0.063, 0.073, 0.034), Color.WHITE)
		_oval(surface, mesh_arrays, Vector3(side * 0.32, 0.62, -0.514), Vector3(0.13, 0.08, 0.09), berry)
	_commit(surface, Vector3.ZERO)
	for pair: int in range(2):
		surface = _surface(material)
		var side := -1.0 if pair == 0 else 1.0
		_oval(surface, mesh_arrays, Vector3(side * 0.24, -0.17, -0.28), Vector3(0.19, 0.36, 0.25), brown)
		_oval(surface, mesh_arrays, Vector3(-side * 0.24, -0.15, 0.31), Vector3(0.23, 0.34, 0.28), brown)
		_limbs.append(_commit(surface, Vector3(0, 0.33, 0)))


func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface


func _oval(surface: SurfaceTool, arrays: Array, position: Vector3, size: Vector3, tint: Color, tilt := 0.0) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rotation := Basis(Vector3.BACK, tilt)
	for index in indices:
		surface.set_color(tint)
		surface.set_normal((rotation * (normals[index] / size)).normalized())
		surface.add_vertex(rotation * (vertices[index] * size) + position)


func _commit(surface: SurfaceTool, position: Vector3) -> MeshInstance3D:
	surface.index()
	var part := MeshInstance3D.new()
	part.mesh = surface.commit()
	part.position = position
	_visual.add_child(part)
	return part
