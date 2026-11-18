extends Node
## Eliminates 32-bit floating-point jitter across vast interplanetary distances
## by recentering the universe whenever the active avatar strays past THRESHOLD.

@export var universe_root_path: NodePath
@export var recenter_threshold: float = 500.0

var _universe_root: Node3D = null


func _ready() -> void:
	if not universe_root_path.is_empty():
		_universe_root = get_node_or_null(universe_root_path) as Node3D


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_universe_root):
		return

	var focus_body: Node3D = null
	if GameState.current_mode == GameState.ControlMode.IN_SHIP and is_instance_valid(GameState.ship_node):
		focus_body = GameState.ship_node
	elif is_instance_valid(GameState.player_node):
		focus_body = GameState.player_node

	if not is_instance_valid(focus_body):
		return

	var pos: Vector3 = focus_body.global_position
	if pos.length() > recenter_threshold:
		_shift_universe(-pos)


func _shift_universe(offset: Vector3) -> void:
	for child in _universe_root.get_children():
		if child is Node3D:
			child.global_position += offset
