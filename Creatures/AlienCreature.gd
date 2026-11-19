extends CharacterBody3D
## Peaceful alien fauna roaming planetary surfaces with spherical gravity alignment.

var _planet: PlanetBody = null
var _health: float = 40.0
var _wander_dir: Vector3 = Vector3.FORWARD
var _state_timer: float = 0.0
var _is_walking: bool = true
var _bob_phase: float = 0.0
var _body_mesh: MeshInstance3D


func _ready() -> void:
	_body_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	_state_timer = randf_range(1.0, 4.0)


func setup_planet(planet: PlanetBody, tint: Color, scale_factor: float) -> void:
	_planet = planet
	var collider: CollisionShape3D = $CollisionShape3D
	var capsule := collider.shape.duplicate() as CapsuleShape3D
	capsule.height *= scale_factor
	capsule.radius *= scale_factor
	collider.shape = capsule
	collider.position.y *= scale_factor
	_body_mesh.scale = Vector3.ONE * scale_factor
	if is_instance_valid(_body_mesh):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint.lerp(Color(0.95, 0.92, 0.82), 0.45)
		mat.roughness = 0.65
		_body_mesh.material_override = mat


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_planet):
		return

	var up_dir: Vector3 = (global_position - _planet.global_position).normalized()
	up_direction = up_dir

	_state_timer -= delta
	if _state_timer <= 0.0:
		_is_walking = not _is_walking
		_state_timer = randf_range(2.0, 5.5)
		var rand_angle: float = randf_range(0.0, TAU)
		var ref: Vector3 = Vector3.RIGHT if absf(up_dir.y) > 0.9 else Vector3.UP
		var right: Vector3 = ref.cross(up_dir).normalized()
		var fwd: Vector3 = up_dir.cross(right).normalized()
		_wander_dir = (fwd * cos(rand_angle) + right * sin(rand_angle)).normalized()

	var speed: float = 2.6
	if is_instance_valid(GameState.player_node) and GameState.current_mode == GameState.ControlMode.ON_FOOT:
		var to_player: Vector3 = GameState.player_node.global_position - global_position
		if to_player.length() < 9.0:
			_is_walking = true
			speed = 5.4
			_wander_dir = (-to_player - up_dir * (-to_player).dot(up_dir)).normalized()

	var move_vec: Vector3 = _wander_dir * speed if _is_walking else Vector3.ZERO
	velocity = move_vec - up_dir * 12.0
	move_and_slide()

	if _wander_dir.length_squared() > 0.01:
		var tangent := _wander_dir.slide(up_dir)
		if tangent.length_squared() > 0.01:
			var orientation := Basis.looking_at(tangent, up_dir)
			global_basis = global_basis.orthonormalized().slerp(orientation, clampf(delta * 6.0, 0.0, 1.0))

	if is_instance_valid(_body_mesh) and _is_walking:
		_bob_phase += delta * 9.0
		_body_mesh.position.y = 0.75 + absf(sin(_bob_phase)) * 0.16


func take_damage(amount: float) -> void:
	_health -= amount
	_is_walking = true
	_state_timer = 4.0
	if _health <= 0.0:
		GameState.post_notification("Organismo alienígena neutralizado.", Color(1.0, 0.7, 0.4))
		queue_free()
