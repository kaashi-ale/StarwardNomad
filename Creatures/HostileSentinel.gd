extends CharacterBody3D
## Hovering alien defense drone patrolling hazardous planets and firing plasma bolts.

const PROJECTILE_SCENE := preload("res://Combat/Projectile.tscn")

var _planet: PlanetBody = null
var _health: float = 60.0
var _fire_timer: float = 1.5
var _orbit_angle: float = 0.0


func _ready() -> void:
	_orbit_angle = randf_range(0.0, TAU)


func setup_planet(planet: PlanetBody) -> void:
	_planet = planet


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_planet):
		return

	var surf: Dictionary = _planet.get_surface_point_and_normal(global_position)
	var surf_pos: Vector3 = surf["position"]
	var up_dir: Vector3 = surf["radial_up"]
	var desired_pos: Vector3 = surf_pos + up_dir * 3.8

	var move_vel := Vector3.ZERO
	var player_in_range: bool = false

	if is_instance_valid(GameState.player_node) and GameState.current_mode == GameState.ControlMode.ON_FOOT:
		var to_player: Vector3 = GameState.player_node.global_position - global_position
		var dist: float = to_player.length()
		if dist < 28.0:
			player_in_range = true
			var tangent_to_player: Vector3 = (to_player - up_dir * to_player.dot(up_dir)).normalized()
			if dist > 11.0:
				move_vel = tangent_to_player * 5.2
			else:
				var strafe: Vector3 = tangent_to_player.cross(up_dir).normalized()
				move_vel = strafe * 4.5

			if tangent_to_player.length_squared() > 0.01:
				var right: Vector3 = tangent_to_player.cross(up_dir).normalized()
				global_transform.basis = global_transform.basis.orthonormalized().slerp(Basis(right, up_dir, -tangent_to_player), clampf(delta * 8.0, 0.0, 1.0))

			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.65
				_fire_at_player(to_player.normalized())

	if not player_in_range:
		_orbit_angle += delta * 0.9
		var ref: Vector3 = Vector3.RIGHT if absf(up_dir.y) > 0.9 else Vector3.UP
		var right: Vector3 = ref.cross(up_dir).normalized()
		var fwd: Vector3 = up_dir.cross(right).normalized()
		move_vel = (right * cos(_orbit_angle) + fwd * sin(_orbit_angle)) * 3.2

	var height_correction: Vector3 = (desired_pos - global_position) * 4.0
	velocity = move_vel + height_correction
	move_and_slide()


func _fire_at_player(dir: Vector3) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + dir * 1.4
	if proj.has_method("launch"):
		proj.launch(dir, 34.0, 12.0, false)


func take_damage(amount: float) -> void:
	_health -= amount
	if _health <= 0.0:
		GameState.heal_player(20.0)
		GameState.post_notification("Sentinela destruída! (+20 Energia do Traje)", Color(0.4, 1.0, 0.65))
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.play_discovery()
		queue_free()
