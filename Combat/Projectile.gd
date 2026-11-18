extends Area3D
## Lightweight energy bolt for player blaster and hostile sentinel drones.

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 20.0
var _from_player: bool = true
var _lifetime: float = 2.2


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(direction: Vector3, speed: float, dmg: float, from_player: bool) -> void:
	_velocity = direction.normalized() * speed
	_damage = dmg
	_from_player = from_player

	var mesh_inst := get_node_or_null("BoltMesh") as MeshInstance3D
	if mesh_inst:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.25, 0.95, 1.0) if from_player else Color(1.0, 0.28, 0.18)
		mesh_inst.material_override = mat


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _from_player and body == GameState.player_node:
		return
	if not _from_player and body == GameState.player_node:
		GameState.damage_player(_damage)
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.play_hit()
		queue_free()
		return

	if body.has_method("take_damage"):
		body.take_damage(_damage)
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.play_hit()
	queue_free()
