extends Node
## Global game state coordinator for seamless On-Foot <-> Spaceship <-> Space transitions.

enum ControlMode {
	ON_FOOT,
	IN_SHIP
}

signal mode_changed(new_mode: int)
signal planet_changed(planet_node: Node3D, planet_name: String)
signal altitude_updated(altitude: float, atmosphere_ratio: float, location_label: String)
signal ship_proximity_changed(can_board: bool)
signal interaction_changed(can_interact: bool, prompt_text: String)
signal stats_updated(health: float, max_health: float, energy: float, max_energy: float)
signal notification_requested(message: String, color: Color)
signal discovery_unlocked(planet_name: String, item_name: String)

var settings_open := false
var current_mode: int = ControlMode.ON_FOOT
var active_planet: Node3D = null
var active_planet_name: String = "Aurelia Prime"

var player_node: CharacterBody3D = null
var ship_node: CharacterBody3D = null
var space_system: Node3D = null
var audio_system: Node = null

var player_health: float = 100.0
var player_max_health: float = 100.0
var jetpack_energy: float = 100.0
var jetpack_max_energy: float = 100.0

var ship_integrity: float = 100.0
var ship_max_integrity: float = 100.0

var can_board_ship: bool = false
var current_interactable: Node3D = null
var discovered_sites: Dictionary = {}

# Virtual mobile input state updated by TouchHUD
var mobile_move_vector: Vector2 = Vector2.ZERO
var mobile_look_delta: Vector2 = Vector2.ZERO
var mobile_sprint_active: bool = false
var mobile_jump_pressed: bool = false
var mobile_fire_pressed: bool = false
var mobile_ship_throttle: float = 0.0   # -1.0 to 1.0
var mobile_ship_vertical: float = 0.0   # -1.0 to 1.0
var mobile_ship_steer: Vector2 = Vector2.ZERO


func set_control_mode(new_mode: int) -> void:
	if current_mode == new_mode:
		return
	current_mode = new_mode
	mode_changed.emit(current_mode)
	emit_current_stats()


func set_active_planet(planet: Node3D, p_name: String) -> void:
	if active_planet == planet and active_planet_name == p_name:
		return
	active_planet = planet
	active_planet_name = p_name
	planet_changed.emit(planet, p_name)


func set_ship_proximity(near_ship: bool) -> void:
	if can_board_ship != near_ship:
		can_board_ship = near_ship
		ship_proximity_changed.emit(can_board_ship)


func set_interactable(target: Node3D, prompt: String = "") -> void:
	current_interactable = target
	interaction_changed.emit(target != null, prompt)


func damage_player(amount: float) -> void:
	if current_mode != ControlMode.ON_FOOT:
		return
	player_health = maxf(0.0, player_health - amount)
	emit_current_stats()
	if player_health <= 0.0:
		respawn_player_at_ship()


func heal_player(amount: float) -> void:
	player_health = minf(player_max_health, player_health + amount)
	jetpack_energy = minf(jetpack_max_energy, jetpack_energy + amount * 0.5)
	emit_current_stats()


func respawn_player_at_ship() -> void:
	player_health = player_max_health
	jetpack_energy = jetpack_max_energy
	emit_current_stats()
	post_notification("Traje restaurado na nave de emergência!", Color(0.35, 0.9, 1.0))
	if is_instance_valid(player_node) and is_instance_valid(ship_node):
		var up_dir: Vector3 = ship_node.global_transform.basis.y.normalized()
		var right_dir: Vector3 = ship_node.global_transform.basis.x.normalized()
		var raw_pos: Vector3 = ship_node.global_position + right_dir * 4.5 + up_dir * 1.5
		if is_instance_valid(space_system):
			var info: Dictionary = space_system.get_nearest_planet_info(raw_pos)
			var planet: PlanetBody = info.get("planet", null)
			if is_instance_valid(planet):
				var surf: Dictionary = planet.get_surface_point_and_normal(raw_pos)
				raw_pos = surf["position"] + surf["radial_up"] * 1.2
		player_node.global_position = raw_pos
		player_node.velocity = Vector3.ZERO


func register_discovery(planet_name: String, site_id: String, display_title: String) -> bool:
	var key := "%s::%s" % [planet_name, site_id]
	if discovered_sites.has(key):
		return false
	discovered_sites[key] = display_title
	discovery_unlocked.emit(planet_name, display_title)
	post_notification("Descoberta registrada: %s (%s)" % [display_title, planet_name], Color(0.3, 1.0, 0.7))
	if is_instance_valid(audio_system) and audio_system.has_method("play_discovery"):
		audio_system.play_discovery()
	return true


func post_notification(msg: String, col: Color = Color.WHITE) -> void:
	notification_requested.emit(msg, col)


func emit_current_stats() -> void:
	if current_mode == ControlMode.ON_FOOT:
		stats_updated.emit(player_health, player_max_health, jetpack_energy, jetpack_max_energy)
	else:
		stats_updated.emit(ship_integrity, ship_max_integrity, 100.0, 100.0)
