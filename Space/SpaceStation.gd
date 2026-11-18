extends Node3D
## Orbital Space Station / Derelict Relay discoverable in deep space between planets.

@export var station_name: String = "Estação Orbital Helios-7"
var _ring: Node3D
var _discovered: bool = false


func _ready() -> void:
	_ring = get_node_or_null("RotatingRing") as Node3D


func _process(delta: float) -> void:
	if is_instance_valid(_ring):
		_ring.rotate_y(delta * 0.25)

	if _discovered:
		return

	var focus: Node3D = GameState.ship_node if GameState.current_mode == GameState.ControlMode.IN_SHIP else GameState.player_node
	if is_instance_valid(focus) and global_position.distance_to(focus.global_position) < 220.0:
		_discovered = true
		GameState.register_discovery("Espaço Profundo", "station_helios", station_name)
