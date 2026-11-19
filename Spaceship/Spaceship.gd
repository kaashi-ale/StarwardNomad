extends CharacterBody3D
## Third-person starship supporting seamless surface takeoff, atmospheric flight,
## deep-space cruise, assisted planetary landing, and physical player boarding.

@export var atmospheric_max_speed: float = 95.0
@export var space_cruise_speed: float = 440.0
@export var max_landing_speed: float = 55.0
@export var max_landing_altitude: float = 42.0
@export var turn_speed: float = 1.65
@export var roll_align_speed: float = 3.5

var is_landed: bool = true
var can_land_now: bool = false
var _current_speed: float = 0.0
var _thruster_glow: Node3D
var _landing_gear: Node3D
var _chase_cam: Camera3D


func _ready() -> void:
	GameState.ship_node = self
	_thruster_glow = get_node_or_null("ShipVisual/ThrusterGlow") as Node3D
	_landing_gear = get_node_or_null("ShipVisual/LandingGear") as Node3D
	_chase_cam = get_node_or_null("ChaseCameraPivot/Camera3D") as Camera3D
	_update_landing_gear_visual()


func _physics_process(delta: float) -> void:
	if GameState.current_mode != GameState.ControlMode.IN_SHIP:
		if is_instance_valid(_thruster_glow):
			_thruster_glow.visible = false
		return

	if is_instance_valid(_chase_cam) and not _chase_cam.current:
		_chase_cam.make_current()

	if Input.is_action_just_pressed("interact"):
		call_deferred("exit_ship")
		return

	var altitude: float = 9999.0
	var atmo_h: float = 300.0
	var nearest_planet: PlanetBody = null
	if is_instance_valid(GameState.space_system):
		var info: Dictionary = GameState.space_system.get_nearest_planet_info(global_position)
		nearest_planet = info.get("planet", null)
		altitude = info.get("altitude", 9999.0)
		atmo_h = info.get("atmosphere_height", 300.0)

	var space_factor: float = clampf(altitude / maxf(atmo_h, 1.0), 0.0, 1.0)
	var max_allowed_speed: float = lerpf(atmospheric_max_speed, space_cruise_speed, space_factor * space_factor)

	var throttle_in: float = GameState.mobile_ship_throttle
	var vert_in: float = GameState.mobile_ship_vertical
	var steer_in: Vector2 = GameState.mobile_ship_steer

	if Input.is_action_pressed("move_forward"):
		throttle_in = 1.0
	elif Input.is_action_pressed("move_backward"):
		throttle_in = -0.6

	if Input.is_action_pressed("move_left"):
		steer_in.x = -1.0
	elif Input.is_action_pressed("move_right"):
		steer_in.x = 1.0

	if Input.is_action_pressed("jump"):
		vert_in = 1.0
	elif Input.is_action_pressed("sprint"):
		vert_in = -1.0

	if is_landed:
		_current_speed = 0.0
		velocity = Vector3.ZERO
		if throttle_in > 0.15 or vert_in > 0.15:
			is_landed = false
			_update_landing_gear_visual()
			var lift_up: Vector3 = global_transform.basis.y.normalized()
			global_position += lift_up * 2.2
			_current_speed = 24.0
			GameState.post_notification("Decolagem iniciada!", Color(0.4, 0.9, 1.0))
			if is_instance_valid(GameState.audio_system):
				GameState.audio_system.play_board_ship()
		return

	var yaw_rate: float = -steer_in.x * turn_speed * delta
	var pitch_rate: float = (steer_in.y + vert_in * 0.65) * (turn_speed * 0.85) * delta

	rotate_object_local(Vector3.UP, yaw_rate)
	rotate_object_local(Vector3.RIGHT, pitch_rate)

	if is_instance_valid(nearest_planet) and space_factor < 0.85:
		var radial_up: Vector3 = (global_position - nearest_planet.global_position).normalized()
		_soft_align_roll_to_horizon(radial_up, delta * (1.0 - space_factor))

	if throttle_in > 0.05:
		var accel: float = lerpf(48.0, 210.0, space_factor)
		_current_speed = minf(max_allowed_speed, _current_speed + throttle_in * accel * delta)
	elif throttle_in < -0.05:
		var brake: float = lerpf(55.0, 240.0, space_factor)
		_current_speed = maxf(0.0, _current_speed + throttle_in * brake * delta)
	else:
		var drag: float = lerpf(12.0, 1.5, space_factor)
		_current_speed = maxf(0.0, _current_speed - drag * delta)

	var fwd: Vector3 = -global_transform.basis.z.normalized()
	var up: Vector3 = global_transform.basis.y.normalized()
	velocity = fwd * _current_speed + up * (vert_in * 24.0 * (1.0 - space_factor * 0.5))

	if is_instance_valid(_thruster_glow):
		_thruster_glow.visible = (_current_speed > 5.0 or throttle_in > 0.1)
		var pulse: float = 0.85 + 0.3 * sin(Time.get_ticks_msec() * 0.02)
		var length := clampf(_current_speed / 45.0, 0.5, 2.0) * pulse
		for plume: MeshInstance3D in _thruster_glow.get_children():
			plume.scale.y = length
			plume.position.z = 2.23 + length * 0.75

	move_and_slide()

	if is_instance_valid(nearest_planet):
		var surf_info: Dictionary = nearest_planet.get_surface_point_and_normal(global_position)
		var surf_pos: Vector3 = surf_info["position"]
		var radial_up: Vector3 = surf_info["radial_up"]
		var clearance: float = (global_position - surf_pos).dot(radial_up)
		if clearance < 2.2:
			global_position = surf_pos + radial_up * 2.2
			_current_speed = minf(_current_speed, 28.0)

		can_land_now = (clearance <= max_landing_altitude and _current_speed <= max_landing_speed)
	else:
		can_land_now = false


func board_ship(player: CharacterBody3D) -> void:
	if GameState.current_mode == GameState.ControlMode.IN_SHIP:
		return
	player.visible = false
	GameState.set_ship_proximity(false)
	GameState.set_interactable(null, "")
	GameState.set_control_mode(GameState.ControlMode.IN_SHIP)
	GameState.post_notification("Sistemas da nave online. Acelere para decolar!", Color(0.35, 0.95, 1.0))
	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.play_board_ship()


func try_land_ship() -> bool:
	if is_landed:
		return true
	if not is_instance_valid(GameState.space_system):
		return false

	var info: Dictionary = GameState.space_system.get_nearest_planet_info(global_position)
	var planet: PlanetBody = info.get("planet", null)
	if not is_instance_valid(planet):
		GameState.post_notification("Nenhum planeta próximo para pouso.", Color(1.0, 0.55, 0.35))
		return false

	var surf: Dictionary = planet.get_surface_point_and_normal(global_position)
	var surf_pos: Vector3 = surf["position"]
	var surf_normal: Vector3 = surf["normal"]
	var radial_up: Vector3 = surf["radial_up"]
	var clearance: float = (global_position - surf_pos).dot(radial_up)

	if clearance > max_landing_altitude:
		GameState.post_notification("Aproxime-se mais do solo para pousar (%d m)." % int(clearance), Color(1.0, 0.78, 0.3))
		return false

	if _current_speed > max_landing_speed:
		GameState.post_notification("Reduza a velocidade para pousar (%d m/s)." % int(_current_speed), Color(1.0, 0.68, 0.25))
		return false

	var fwd: Vector3 = -global_transform.basis.z
	fwd = (fwd - surf_normal * fwd.dot(surf_normal)).normalized()
	if fwd.length_squared() < 0.001:
		fwd = surf_normal.cross(Vector3.RIGHT).normalized()
	var right: Vector3 = fwd.cross(surf_normal).normalized()
	global_transform.basis = Basis(right, surf_normal, -fwd).orthonormalized()
	global_position = surf_pos + surf_normal * 1.45

	_current_speed = 0.0
	velocity = Vector3.ZERO
	is_landed = true
	can_land_now = false
	_update_landing_gear_visual()

	GameState.post_notification("Pouso concluído em %s!" % planet.planet_name, Color(0.35, 1.0, 0.65))
	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.play_board_ship()
	return true


func exit_ship() -> void:
	if GameState.current_mode != GameState.ControlMode.IN_SHIP:
		return
	if not is_landed:
		if not try_land_ship():
			return

	if is_instance_valid(GameState.player_node):
		var up: Vector3 = global_transform.basis.y.normalized()
		var right: Vector3 = global_transform.basis.x.normalized()
		var raw_exit_pos: Vector3 = global_position + right * 4.2 + up * 1.2
		var exit_up: Vector3 = up

		# Query exact terrain surface at exit offset so player never clips into slopes
		if is_instance_valid(GameState.space_system):
			var info: Dictionary = GameState.space_system.get_nearest_planet_info(raw_exit_pos)
			var planet: PlanetBody = info.get("planet", null)
			if is_instance_valid(planet):
				var surf: Dictionary = planet.get_surface_point_and_normal(raw_exit_pos)
				exit_up = surf["radial_up"]
				raw_exit_pos = surf["position"] + exit_up * 1.15

		var fwd: Vector3 = -global_transform.basis.z
		fwd = (fwd - exit_up * fwd.dot(exit_up)).normalized()
		if fwd.length_squared() < 0.001:
			fwd = exit_up.cross(Vector3.RIGHT).normalized()
		var exit_right: Vector3 = fwd.cross(exit_up).normalized()

		GameState.player_node.global_transform.basis = Basis(exit_right, exit_up, -fwd).orthonormalized()
		GameState.player_node.global_position = raw_exit_pos
		GameState.player_node.velocity = Vector3.ZERO
		GameState.player_node.visible = true

	GameState.set_control_mode(GameState.ControlMode.ON_FOOT)
	GameState.post_notification("Explorando a pé.", Color(0.65, 0.95, 1.0))
	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.play_board_ship()


func _update_landing_gear_visual() -> void:
	if is_instance_valid(_landing_gear):
		_landing_gear.visible = is_landed


func _soft_align_roll_to_horizon(planet_up: Vector3, weight: float) -> void:
	var fwd: Vector3 = -global_transform.basis.z.normalized()
	if absf(fwd.dot(planet_up)) > 0.92:
		return
	var right: Vector3 = fwd.cross(planet_up).normalized()
	var ortho_up: Vector3 = right.cross(fwd).normalized()
	var desired := Basis(right, ortho_up, -fwd).orthonormalized()
	global_transform.basis = global_transform.basis.orthonormalized().slerp(desired, clampf(weight * roll_align_speed, 0.0, 1.0))
