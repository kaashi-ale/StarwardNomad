extends Node3D
## Root bootstrapper: places the Spaceship and Player safely on Aurelia Prime's
## exact surface height and applies hardware quality settings once scene is live.

@onready var space_system: Node3D = $UniverseRoot/SpaceSystem
@onready var ship: CharacterBody3D = $UniverseRoot/Spaceship
@onready var player: CharacterBody3D = $UniverseRoot/Player


func _ready() -> void:
	QualityManager.refresh_scene_settings()
	call_deferred("_place_starting_expedition")


func _place_starting_expedition() -> void:
	if not is_instance_valid(space_system) or space_system.planets.is_empty():
		return

	var start_planet: PlanetBody = space_system.planets[0]
	var spawn_dir := PlanetBody.AURELIA_START_DIRECTION
	var ship_world_query: Vector3 = start_planet.global_position + spawn_dir * start_planet.data.radius
	var ship_surf: Dictionary = start_planet.get_surface_point_and_normal(ship_world_query)
	var ship_pos: Vector3 = ship_surf["position"]
	var ship_normal: Vector3 = ship_surf["normal"]

	var ref: Vector3 = Vector3.RIGHT
	var right: Vector3 = ref.cross(ship_normal).normalized()
	var fwd: Vector3 = ship_normal.cross(right).normalized()
	var ship_basis := Basis(right, ship_normal, -fwd).orthonormalized()

	if is_instance_valid(ship):
		ship.global_transform.basis = ship_basis
		ship.global_position = ship_pos + ship_normal * 1.45
		ship.is_landed = true

	# Query exact terrain height at the player's displaced spawn spot (MÉDIO-1)
	if is_instance_valid(player):
		var raw_player_pos: Vector3 = ship_pos + right * 4.5 - fwd * 4.0
		var player_surf: Dictionary = start_planet.get_surface_point_and_normal(raw_player_pos)
		var p_pos: Vector3 = player_surf["position"]
		var p_up: Vector3 = player_surf["radial_up"]
		var p_right: Vector3 = ref.cross(p_up).normalized()
		var p_fwd: Vector3 = p_up.cross(p_right).normalized()
		player.global_transform.basis = Basis(p_right, p_up, -p_fwd).orthonormalized()
		player.global_position = p_pos + p_up * 0.38

	GameState.post_notification("Aurelia Prime · O pórtico adiante abriga um relé de pesquisa.", Color(0.4, 0.95, 1.0))
