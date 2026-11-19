extends CharacterBody3D
## Third-person starship supporting seamless surface takeoff, atmospheric flight,
## deep-space cruise, assisted planetary landing, and physical player boarding.

@export var atmospheric_max_speed: float = 95.0
@export var space_cruise_speed: float = 1450.0
@export var max_landing_speed: float = 24.0
@export var max_landing_altitude: float = 30.0
@export var turn_speed: float = 1.65
@export var roll_align_speed: float = 3.5

var is_landed: bool = true
var can_land_now: bool = false
var _current_speed: float = 0.0
var _climb_speed := 0.0
var _takeoff_time := 0.0
var _camera_base: Transform3D
var navigation_target: PlanetBody
var navigation_assist := false
var landing_status := ""
var surface_altitude := 0.0
var _nav_key_held := false
var _assist_key_held := false
var _camera_tracking := false
var _camera_offset := Vector3.ZERO
var _landing_clearance := SphereShape3D.new()
var _thruster_glow: Node3D
var _landing_gear: Node3D
var _chase_cam: Camera3D


func _ready() -> void:
	GameState.ship_node = self
	_landing_clearance.radius = 1.9
	_thruster_glow = get_node_or_null("ShipVisual/ThrusterGlow") as Node3D
	_landing_gear = get_node_or_null("ShipVisual/LandingGear") as Node3D
	_chase_cam = get_node_or_null("ChaseCameraPivot/Camera3D") as Camera3D
	_camera_base = _chase_cam.get_parent().transform * _chase_cam.transform
	_update_landing_gear_visual()


func _physics_process(delta: float) -> void:
	if GameState.current_mode != GameState.ControlMode.IN_SHIP:
		_thruster_glow.hide()
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.ship_thrust_level = 0.0
		_camera_tracking = false
		return

	if not GameState.settings_open and Input.is_action_just_pressed("interact"):
		call_deferred("exit_ship")
		return
	var nav_key := not GameState.settings_open and Input.is_physical_key_pressed(KEY_TAB)
	if nav_key and not _nav_key_held:
		cycle_target()
	_nav_key_held = nav_key
	var assist_key := not GameState.settings_open and Input.is_physical_key_pressed(KEY_F)
	if assist_key and not _assist_key_held:
		toggle_navigation_assist()
	_assist_key_held = assist_key

	var info: Dictionary = GameState.space_system.get_nearest_planet_info(global_position)
	var planet: PlanetBody = info.get("planet")
	var altitude: float = info.get("altitude", INF)
	var radial_up := global_basis.y
	if is_instance_valid(planet):
		radial_up = planet.global_position.direction_to(global_position)
	var space_factor := smoothstep(0.0, float(info.get("atmosphere_height", 500.0)), altitude)
	var lift_up := radial_up.slerp(global_basis.y, space_factor)
	var look := GameState.mobile_look_delta
	GameState.mobile_look_delta = Vector2.ZERO

	var throttle := GameState.mobile_ship_throttle
	if Input.is_action_pressed("move_forward"):
		throttle = 1.0
	elif Input.is_action_pressed("move_backward"):
		throttle = -1.0
	var lift := GameState.mobile_ship_vertical
	if Input.is_action_pressed("jump"):
		lift = 1.0
	elif Input.is_action_pressed("sprint"):
		lift = -1.0
	var steer := GameState.mobile_ship_steer
	steer.x = clampf(steer.x + Input.get_axis("move_left", "move_right"), -1.0, 1.0)
	steer.y = clampf(steer.y + float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN)), -1.0, 1.0)

	if GameState.settings_open:
		throttle = 0.0
		lift = 0.0
		steer = Vector2.ZERO

	if is_landed:
		surface_altitude = 0.0
		landing_status = "Pousada"
		if maxf(throttle, lift) <= 0.1:
			return
		is_landed = false
		_takeoff_time = 0.62
		_update_landing_gear_visual()
		GameState.post_notification("Decolagem iniciada", Color(0.4, 0.9, 1.0))
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.play_board_ship()

	_takeoff_time = maxf(0.0, _takeoff_time - delta)
	if _takeoff_time > 0.0:
		lift = maxf(lift, 0.68)
	if steer.length_squared() > 0.02 or look.length_squared() > 0.3:
		navigation_assist = false
	var turn := turn_speed * lerpf(0.71, 1.0, space_factor)
	rotate_object_local(Vector3.UP, -steer.x * turn * delta - look.x * 0.0028)
	rotate_object_local(Vector3.RIGHT, steer.y * turn * delta - look.y * 0.0028)

	if navigation_assist and is_instance_valid(navigation_target):
		var course := _navigation_course(planet, radial_up, altitude)
		var preferred_up := radial_up if space_factor < 0.9 else global_basis.y
		if absf(course.dot(preferred_up)) > 0.96:
			preferred_up = Vector3.UP if absf(course.y) < 0.9 else Vector3.RIGHT
		var orientation := Basis.looking_at(course, preferred_up)
		global_basis = global_basis.orthonormalized().slerp(orientation, 1.0 - exp(-delta * 2.1))
	elif space_factor < 0.95:
		_soft_align_roll_to_horizon(radial_up, delta * (1.0 - space_factor))
	global_basis = global_basis.orthonormalized()

	surface_altitude = altitude
	if is_instance_valid(planet) and altitude < planet.data.terrain_amplitude + 180.0:
		surface_altitude -= planet.get_surface_radius_at_dir(radial_up) - planet.data.radius
	var near_ground := smoothstep(0.0, 105.0, surface_altitude)
	var speed_limit := lerpf(34.0, atmospheric_max_speed, near_ground)
	speed_limit = lerpf(speed_limit, space_cruise_speed, space_factor * space_factor)
	var forward := -global_basis.z
	if is_instance_valid(planet) and forward.dot(radial_up) < -0.20:
		speed_limit = minf(speed_limit, sqrt(maxf(surface_altitude + 14.0, 0.0) * 545.0))
	if navigation_assist and is_instance_valid(navigation_target):
		var distance := global_position.distance_to(navigation_target.global_position) - navigation_target.data.radius
		speed_limit = minf(speed_limit, sqrt(maxf(distance - 75.0, 0.0) * 200.0))
		var alignment := forward.dot(_navigation_course(planet, radial_up, altitude))
		speed_limit *= smoothstep(0.25, 0.95, alignment)

	if throttle < 0.0:
		_current_speed = move_toward(_current_speed, 0.0, lerpf(85.0, 330.0, space_factor) * -throttle * delta)
	elif throttle > 0.0 or _current_speed > speed_limit:
		var desired := speed_limit * clampf(throttle, 0.0, 1.0) if throttle > 0.0 else speed_limit
		var acceleration := lerpf(39.0, 245.0, space_factor) if _current_speed < desired else lerpf(85.0, 330.0, space_factor)
		_current_speed = move_toward(_current_speed, desired, acceleration * delta)
	else:
		_current_speed = move_toward(_current_speed, 0.0, lerpf(23.0, 3.0, space_factor) * delta)
	_climb_speed = move_toward(_climb_speed, lift * lerpf(23.0, 48.0, space_factor), delta * 39.0)
	var requested_velocity := forward * _current_speed + lift_up * _climb_speed
	if surface_altitude < 9.0 and requested_velocity.dot(radial_up) < 0.0:
		requested_velocity = requested_velocity.slide(radial_up) + radial_up * maxf(0.0, (4.0 - surface_altitude) * 3.0)
	velocity = velocity.lerp(requested_velocity, 1.0 - exp(-delta * lerpf(9.0, 3.3, space_factor)))
	_thruster_glow.visible = _current_speed > 4.0 or absf(_climb_speed) > 2.0
	if is_instance_valid(GameState.audio_system):
		var power := maxf(maxf(throttle, 0.0), absf(lift) * 0.65)
		GameState.audio_system.ship_thrust_level = power * lerpf(0.52, 0.27, space_factor)
	var plume_length := clampf((_current_speed + absf(_climb_speed)) / 45.0, 0.35, 1.8)
	for plume: MeshInstance3D in _thruster_glow.get_children():
		plume.scale.y = plume_length
		plume.position.z = 2.23 + plume_length * 0.75

	move_and_slide()
	if get_slide_collision_count() > 0:
		_current_speed = minf(_current_speed, velocity.length())
	can_land_now = false
	landing_status = "Aproxime-se do solo"
	if is_instance_valid(planet) and surface_altitude < max_landing_altitude + 3.0:
		var ground := _ground_below(planet, global_position)
		landing_status = _check_landing(planet, ground)
		can_land_now = landing_status.is_empty()
		if can_land_now:
			landing_status = "Pouso disponível"


func _process(delta: float) -> void:
	if GameState.current_mode != GameState.ControlMode.IN_SHIP:
		return
	var target_offset := global_basis * (_camera_base.origin + Vector3(0, 0, clampf(_current_speed / 75.0, 0.0, 9.0)))
	var target_orientation := global_basis * _camera_base.basis
	if not _camera_tracking:
		_camera_offset = target_offset
		_chase_cam.global_basis = target_orientation
	else:
		_camera_offset = _camera_offset.lerp(target_offset, 1.0 - exp(-delta * 8.0))
		_chase_cam.global_basis = _chase_cam.global_basis.orthonormalized().slerp(target_orientation, 1.0 - exp(-delta * 8.0))
	var origin := global_position + global_basis.y * 1.1
	var destination := global_position + _camera_offset
	var ray := PhysicsRayQueryParameters3D.create(origin, destination, 33, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		destination = hit["position"] - origin.direction_to(destination) * 0.35
	_chase_cam.global_position = destination
	if not _chase_cam.current:
		_chase_cam.make_current()
	_camera_tracking = true


func cycle_target() -> void:
	var planets: Array = GameState.space_system.planets
	if planets.is_empty():
		return
	var index := planets.find(navigation_target)
	if index < 0:
		var nearby: Dictionary = GameState.space_system.get_nearest_planet_info(global_position)
		index = planets.find(nearby.get("planet"))
	navigation_target = planets[(index + 1) % planets.size()]
	navigation_assist = false


func toggle_navigation_assist() -> void:
	if not is_instance_valid(navigation_target):
		cycle_target()
	navigation_assist = not navigation_assist and is_instance_valid(navigation_target)


func _navigation_course(nearby: PlanetBody, up: Vector3, altitude: float) -> Vector3:
	var course := global_position.direction_to(navigation_target.global_position)
	if not is_instance_valid(nearby) or nearby == navigation_target:
		return course
	var center_offset := nearby.global_position - global_position
	var along_course := center_offset.dot(course)
	var safety_radius := nearby.data.radius + 180.0
	if altitude < 185.0 or (along_course > 0.0 and center_offset.slide(course).length() < safety_radius):
		var tangent := course.slide(up)
		if tangent.length_squared() < 0.01:
			tangent = global_basis.x.slide(up)
		return (tangent.normalized() * 0.64 + up * 0.77).normalized()
	return course


func _ground_below(planet: PlanetBody, position: Vector3) -> Dictionary:
	var up := planet.global_position.direction_to(position)
	var ray := PhysicsRayQueryParameters3D.create(position + up * 4.0, position - up * 112.0, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray)


func _check_landing(planet: PlanetBody, ground: Dictionary) -> String:
	if ground.is_empty():
		return "Solo fora de alcance"
	var point: Vector3 = ground["position"]
	var up := planet.global_position.direction_to(point)
	var height := (global_position - point).dot(up)
	if height > max_landing_altitude:
		return "Aproxime-se do solo"
	if velocity.length() > max_landing_speed:
		return "Freie para pousar"
	if planet.data.has_ocean and planet.global_position.distance_to(point) <= planet.data.radius + planet.data.ocean_level_offset + 1.4:
		return "Procure terra firme"
	if up.dot(ground["normal"]) < 0.88:
		return "Procure terreno plano"
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _landing_clearance
	query.transform.origin = point + up * 1.9
	query.collision_mask = 32
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return "Área obstruída · procure uma clareira"
	return ""


func board_ship(player: CharacterBody3D) -> void:
	if GameState.current_mode == GameState.ControlMode.IN_SHIP:
		return
	player.visible = false
	GameState.set_ship_proximity(false)
	GameState.set_interactable(null, "")
	GameState.set_control_mode(GameState.ControlMode.IN_SHIP)
	GameState.post_notification("Acelere para decolar. Escolha um destino no painel.", Color(0.35, 0.95, 1.0))
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

	var ground := _ground_below(planet, global_position)
	var reason := _check_landing(planet, ground)
	if not reason.is_empty():
		GameState.post_notification(reason, Color(1.0, 0.78, 0.3))
		return false
	var surf_pos: Vector3 = ground["position"]
	var surf_normal: Vector3 = ground["normal"]

	var fwd: Vector3 = -global_transform.basis.z
	fwd = (fwd - surf_normal * fwd.dot(surf_normal)).normalized()
	if fwd.length_squared() < 0.001:
		fwd = global_basis.x.cross(surf_normal).normalized()
	var right: Vector3 = fwd.cross(surf_normal).normalized()
	global_transform.basis = Basis(right, surf_normal, -fwd).orthonormalized()
	global_position = surf_pos + surf_normal * 1.45

	_current_speed = 0.0
	_climb_speed = 0.0
	velocity = Vector3.ZERO
	navigation_assist = false
	_thruster_glow.hide()
	if is_instance_valid(GameState.audio_system):
		GameState.audio_system.ship_thrust_level = 0.0
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

		var info: Dictionary = GameState.space_system.get_nearest_planet_info(raw_exit_pos)
		var planet: PlanetBody = info.get("planet")
		if is_instance_valid(planet):
			var found := false
			for side: Vector3 in [right, -right, global_basis.z]:
				var candidate := global_position + side * 4.8 + up
				var ground := _ground_below(planet, candidate)
				if ground.is_empty():
					continue
				var point: Vector3 = ground["position"]
				exit_up = planet.global_position.direction_to(point)
				if exit_up.dot(ground["normal"]) < 0.75:
					continue
				if planet.data.has_ocean and point.distance_to(planet.global_position) <= planet.data.radius + planet.data.ocean_level_offset:
					continue
				raw_exit_pos = point + exit_up * 0.42
				found = true
				break
			if not found:
				GameState.post_notification("Sem terreno seguro para desembarcar", Color(1.0, 0.78, 0.3))
				return

		var fwd: Vector3 = -global_transform.basis.z
		fwd = (fwd - exit_up * fwd.dot(exit_up)).normalized()
		if fwd.length_squared() < 0.001:
			fwd = right.cross(exit_up).normalized()
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
