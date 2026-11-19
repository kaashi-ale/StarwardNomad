extends Node
## Calls an empty ship to a nearby clearing on the same world.

enum Phase { IDLE, CLIMB, CRUISE, DESCEND }

var phase := Phase.IDLE
var _ship: CharacterBody3D
var _planet: PlanetBody
var _target := Vector3.ZERO
var _target_normal := Vector3.UP
var _cruise_radius := 0.0
var _speed := 0.0
var _clearance := SphereShape3D.new()
var _player_position := Vector3.ZERO


func _ready() -> void:
	_ship = get_parent()
	_clearance.radius = 3.45


func request(player: CharacterBody3D) -> void:
	if phase != Phase.IDLE or not _ship.is_landed:
		return
	if player.global_position.distance_to(_ship.global_position) <= player.ship_board_distance:
		GameState.post_notification("A nave já está ao seu alcance.", Color("#a3eed9"))
		return
	var system := GameState.space_system
	var player_site: Dictionary = system.get_nearest_planet_info(player.global_position)
	var ship_site: Dictionary = system.get_nearest_planet_info(_ship.global_position)
	_planet = player_site.get("planet")
	if not is_instance_valid(_planet) or ship_site.get("planet") != _planet:
		GameState.post_notification("A chamada da nave funciona no mesmo planeta.", Color("#ffcb92"))
		return
	if not _find_landing_site(player):
		GameState.post_notification("Sem clareira próxima. Experimente chamar de um campo aberto.", Color("#ffcb92"))
		return
	_cruise_radius = _planet.data.radius + _planet.data.terrain_amplitude * 1.3 + 32.0
	_speed = 0.0
	phase = Phase.CLIMB
	_ship.is_landed = false
	_ship._update_landing_gear_visual()
	GameState.post_notification("Chamada recebida. A nave está a caminho.", Color("#a3eed9"))


func advance(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	var local := _ship.global_position - _planet.global_position
	var up := local.normalized()
	var goal_up := _target.normalized()
	var tangent := goal_up.slide(up)
	if tangent.length_squared() < 0.000001:
		tangent = (-_ship.global_basis.z).slide(up)
	if tangent.length_squared() < 0.000001:
		tangent = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.UP)
	var facing := Basis.looking_at(tangent, up)
	_ship.global_basis = _ship.global_basis.orthonormalized().slerp(facing, 1.0 - exp(-delta * 5.0))

	var next := local
	match phase:
		Phase.CLIMB:
			next = up * move_toward(local.length(), _cruise_radius, delta * 31.0)
			if next.length() >= _cruise_radius - 0.05:
				phase = Phase.CRUISE
		Phase.CRUISE:
			var angle := up.angle_to(goal_up)
			if angle * _cruise_radius < 0.9:
				var player := GameState.player_node
				if is_instance_valid(player) and player.global_position.distance_to(_planet.global_position + _player_position) > 10.0:
					if _find_landing_site(player):
						return
				phase = Phase.DESCEND
			else:
				var speed_limit := clampf(sqrt(angle * _cruise_radius * 112.0), 18.0, 135.0)
				_speed = move_toward(_speed, speed_limit, delta * 75.0)
				var turn_axis := up.cross(tangent.normalized()).normalized()
				next = up.rotated(turn_axis, minf(angle, _speed * delta / _cruise_radius)) * _cruise_radius
		Phase.DESCEND:
			var touchdown := _target + _target_normal * 1.45
			next = local.move_toward(touchdown, delta * clampf(local.distance_to(touchdown) * 1.4, 3.0, 24.0))
			if next.distance_to(touchdown) < 0.08:
				if not _site_open(_planet.global_position + _target, goal_up):
					var player := GameState.player_node
					if is_instance_valid(player):
						_find_landing_site(player)
					phase = Phase.CLIMB
					return
				phase = Phase.IDLE
				_ship.finish_landing(_planet, _planet.global_position + _target, _target_normal)
				GameState.post_notification("Sua nave pousou na clareira marcada no HUD.", Color("#a3eed9"))
				return
	_ship.velocity = (next - local) / maxf(delta, 0.001)
	_ship.update_thruster_visual(clampf(_ship.velocity.length() / 39.0, 0.45, 1.6), 0.30)
	# The route follows the sphere above the highest relief. A body sweep still guards ascent and descent.
	if _ship.move_and_collide(next - local) != null:
		if phase == Phase.DESCEND:
			phase = Phase.CLIMB
			var player := GameState.player_node
			if is_instance_valid(player):
				_find_landing_site(player)
		else:
			# A shallow contact during takeoff can occur on the lowest hull edge.
			_ship.global_position += up * minf(0.15, delta * 8.0)


func _find_landing_site(player: CharacterBody3D) -> bool:
	var center := _planet.global_position
	var relative := player.global_position - center
	var up := relative.normalized()
	var forward := (-player.global_basis.z).slide(up).normalized()
	if forward.is_zero_approx():
		forward = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.UP).normalized()
	var state := _ship.get_world_3d().direct_space_state
	for distance: float in [8.5, 12.0, 17.0, 24.0, 33.0]:
		for step in range(8):
			var side := forward.rotated(up, step * TAU / 8.0)
			var direction := (relative + side * distance).normalized()
			var surface_radius := _planet.get_surface_radius_at_dir(direction)
			var point := center + direction * surface_radius
			var ray := PhysicsRayQueryParameters3D.create(point + direction * 52.0, point - direction * 52.0, 1)
			var hit := state.intersect_ray(ray)
			if hit.get("collider") != _planet:
				continue
			var contact: Vector3 = hit["position"]
			var normal: Vector3 = hit["normal"]
			if direction.dot(normal) < 0.92 or contact.distance_to(player.global_position) < 7.5:
				continue
			if _planet.data.has_ocean and contact.distance_to(center) < _planet.data.radius + _planet.data.ocean_level_offset + 2.0:
				continue
			if not _site_open(contact, direction):
				continue
			_target = contact - center
			_target_normal = normal
			_player_position = relative
			return true
	return false


func _site_open(contact: Vector3, up: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance
	query.collision_mask = 34
	query.transform.origin = contact + up * 3.72
	var state := _ship.get_world_3d().direct_space_state
	return state.intersect_shape(query, 1).is_empty()
