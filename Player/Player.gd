extends CharacterBody3D
## Third-person planetary explorer with spherical gravity alignment, jetpack assist,
## futuristic plasma blaster, and seamless spaceship boarding.

const PROJECTILE_SCENE := preload("res://Combat/Projectile.tscn")

@export var walk_speed: float = 5.4
@export var sprint_speed: float = 8.6
@export var jump_velocity: float = 7.2
@export var jetpack_thrust: float = 32.0
@export var ship_board_distance: float = 8.0

var _planar_velocity := Vector3.ZERO
var _air_time := 0.0
var _vertical_speed: float = 0.0
var _step_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _jump_requested: bool = false
var _fire_requested := false
var _visual_mesh: Node3D
var _muzzle: Marker3D
var _camera_rig: Node3D


func _ready() -> void:
	GameState.player_node = self
	_visual_mesh = get_node_or_null("VisualRoot") as Node3D
	_muzzle = get_node_or_null("VisualRoot/MuzzlePoint") as Marker3D
	_camera_rig = get_node_or_null("CameraRig") as Node3D


func _physics_process(delta: float) -> void:
	if GameState.current_mode != GameState.ControlMode.ON_FOOT:
		_jump_requested = false
		_fire_requested = false
		_planar_velocity = Vector3.ZERO
		_vertical_speed = 0.0
		_air_time = 0.0
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.jetpack_active = false
		visible = false
		return
	visible = true

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var previous_energy := GameState.jetpack_energy

	# 1. Determine local spherical gravity and surface up direction
	var grav_vec := Vector3.ZERO
	var has_gravity: bool = false
	if is_instance_valid(GameState.space_system):
		var g: Vector3 = GameState.space_system.get_total_gravity_at(global_position)
		if g.length_squared() > 0.01:
			grav_vec = g
			has_gravity = true

	var local_up: Vector3 = -grav_vec.normalized() if has_gravity else global_transform.basis.y.normalized()
	up_direction = local_up
	if has_gravity:
		_align_to_up(local_up, delta)

	# 2. Gather movement input (Mobile virtual joystick + Desktop WASD fallback)
	var input_vec: Vector2 = GameState.mobile_move_vector
	if input_vec.length_squared() < 0.01:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		input_vec.y = -input_vec.y

	var cam_fwd: Vector3 = -global_transform.basis.z
	if is_instance_valid(_camera_rig) and _camera_rig.has_method("get_horizontal_forward"):
		cam_fwd = _camera_rig.get_horizontal_forward(local_up)
	var cam_right: Vector3 = cam_fwd.cross(local_up).normalized()

	var move_dir: Vector3 = (cam_fwd * input_vec.y + cam_right * input_vec.x)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var sprinting: bool = GameState.mobile_sprint_active or Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if sprinting else walk_speed
	var grounded := has_gravity and is_on_floor()
	var acceleration := 35.0 if grounded else 16.0
	if grounded and move_dir.is_zero_approx():
		acceleration = 47.0
	_planar_velocity = _planar_velocity.slide(local_up).move_toward(move_dir * target_speed, acceleration * delta)
	var firing := not GameState.settings_open and (_fire_requested or GameState.mobile_fire_pressed or Input.is_action_pressed("fire"))
	var facing := cam_fwd if firing else _planar_velocity

	# Rotate visual avatar smoothly toward movement direction
	if facing.length_squared() > 0.05 and is_instance_valid(_visual_mesh):
		var target_basis := Basis.looking_at(facing, local_up)
		_visual_mesh.global_transform.basis = _visual_mesh.global_transform.basis.orthonormalized().slerp(target_basis, clampf(delta * 12.0, 0.0, 1.0))

	# 3. Jump & Jetpack vertical physics (supports both planetary gravity and zero-G EVA)
	var jump_held: bool = GameState.mobile_jump_pressed or Input.is_action_pressed("jump")
	var jump_just: bool = Input.is_action_just_pressed("jump") or _jump_requested
	_jump_requested = false

	var thrusting := false
	if grounded:
		if _vertical_speed < 0.0:
			_vertical_speed = -1.5
		if jump_just:
			_vertical_speed = jump_velocity
			if is_instance_valid(GameState.audio_system):
				GameState.audio_system.play_jump()
		else:
			GameState.jetpack_energy = minf(GameState.jetpack_max_energy, GameState.jetpack_energy + 28.0 * delta)
	else:
		if has_gravity:
			_vertical_speed -= grav_vec.length() * delta
		else:
			# Gentle damping in zero-gravity space
			_vertical_speed = lerpf(_vertical_speed, 0.0, clampf(delta * 1.2, 0.0, 1.0))
			GameState.jetpack_energy = minf(GameState.jetpack_max_energy, GameState.jetpack_energy + 12.0 * delta)
		if jump_held and _air_time > 0.24 and GameState.jetpack_energy > 2.0:
			thrusting = true
			_vertical_speed += jetpack_thrust * delta
			_vertical_speed = minf(_vertical_speed, 13.0)
			GameState.jetpack_energy = maxf(0.0, GameState.jetpack_energy - 34.0 * delta)

	if not is_equal_approx(previous_energy, GameState.jetpack_energy):
		GameState.emit_current_stats()

	velocity = _planar_velocity + local_up * _vertical_speed
	move_and_slide()
	var now_grounded := is_on_floor()
	var landed := now_grounded and _air_time > 0.18
	_air_time = 0.0 if now_grounded else _air_time + delta
	if now_grounded and _vertical_speed < 0.0:
		_vertical_speed = -1.5
	elif is_on_ceiling() and _vertical_speed > 0.0:
		_vertical_speed = 0.0
	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.jetpack_active = thrusting
		if landed:
			GameState.audio_system.play_landing()
	var measured_speed := get_real_velocity().slide(local_up).length()
	_visual_mesh.animate(delta, measured_speed, now_grounded, _vertical_speed > 0.0, thrusting, landed)

	# Footstep audio feedback
	if has_gravity and now_grounded and measured_speed > 1.1:
		_step_timer += delta * measured_speed / walk_speed
		if _step_timer >= 0.38:
			_step_timer = 0.0
			if is_instance_valid(GameState.audio_system):
				GameState.audio_system.play_step()

	# 4. Weapon firing
	if firing and _fire_cooldown <= 0.0:
		fire_blaster()
	_fire_requested = false

	# 5. Check proximity to Spaceship & Interactables
	_update_proximities()
	if not GameState.settings_open and Input.is_action_just_pressed("interact"):
		if is_instance_valid(GameState.current_interactable):
			try_interact()
		else:
			try_board_ship()


func trigger_jump_or_jetpack() -> void:
	_jump_requested = true


func request_fire() -> void:
	_fire_requested = true


func fire_blaster() -> void:
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = 0.22
	_visual_mesh.recoil()

	var proj := PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)

	var spawn_pos: Vector3 = _muzzle.global_position if is_instance_valid(_muzzle) else (global_position + global_transform.basis.y * 1.2)
	var shoot_dir: Vector3 = -_visual_mesh.global_transform.basis.z.normalized() if is_instance_valid(_visual_mesh) else -global_transform.basis.z.normalized()
	var cam := get_viewport().get_camera_3d()
	if is_instance_valid(cam):
		var aim := -cam.global_basis.z
		var endpoint := cam.global_position + aim * 100.0
		var ray := PhysicsRayQueryParameters3D.create(cam.global_position, endpoint, 45, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var aim_point: Vector3 = hit.get("position", endpoint)
		# A wall between the camera and the astronaut must not turn bolts backwards.
		if (aim_point - spawn_pos).dot(aim) > 0.0:
			shoot_dir = spawn_pos.direction_to(aim_point)
		else:
			shoot_dir = aim
	proj.global_position = spawn_pos
	if proj.has_method("launch"):
		proj.launch(shoot_dir, 65.0, 25.0, true)

	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.play_laser()


func try_interact() -> void:
	if is_instance_valid(GameState.current_interactable) and GameState.current_interactable.has_method("interact"):
		GameState.current_interactable.interact(self)


func try_board_ship() -> void:
	if not GameState.can_board_ship or not is_instance_valid(GameState.ship_node):
		return
	if GameState.ship_node.has_method("board_ship"):
		GameState.ship_node.board_ship(self)


func _update_proximities() -> void:
	if is_instance_valid(GameState.ship_node):
		var d: float = global_position.distance_to(GameState.ship_node.global_position)
		GameState.set_ship_proximity(GameState.ship_node.is_landed and d <= ship_board_distance)

	var nearest_obj: Node3D = null
	var nearest_dist: float = 6.5
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is Node3D and is_instance_valid(node):
			var d: float = global_position.distance_to(node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_obj = node

	if nearest_obj != null:
		var prompt: String = nearest_obj.get_prompt() if nearest_obj.has_method("get_prompt") else "Escanear Objeto"
		GameState.set_interactable(nearest_obj, prompt)
	else:
		GameState.set_interactable(null, "")


func _align_to_up(target_up: Vector3, delta: float) -> void:
	var cur_up: Vector3 = global_transform.basis.y.normalized()
	if cur_up.dot(target_up) > 0.9999:
		return
	var q := Quaternion(cur_up, target_up)
	var target_basis := Basis(q) * global_transform.basis
	global_transform.basis = global_transform.basis.orthonormalized().slerp(target_basis.orthonormalized(), clampf(delta * 10.0, 0.0, 1.0))
