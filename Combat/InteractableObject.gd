extends StaticBody3D
## Interactive ancient alien monolith / beacon on planet surfaces.

var _planet_name: String = "Unknown"
var _site_id: String = "site_0"
var _title: String = "Monólito Ancestral"
var _scanned: bool = false
var _crystal: MeshInstance3D


func _ready() -> void:
	add_to_group("interactables")
	_crystal = get_node_or_null("CoreCrystal") as MeshInstance3D


func setup(p_name: String, s_id: String, title: String, glow_color: Color) -> void:
	_planet_name = p_name
	_site_id = s_id
	_title = title
	if is_instance_valid(_crystal):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = glow_color
		_crystal.material_override = mat


func _process(delta: float) -> void:
	if is_instance_valid(_crystal):
		_crystal.rotate_y(delta * 1.4)


func get_prompt() -> String:
	return "Reativar %s" % _title if _scanned else "Escanear %s" % _title


func interact(_actor: Node3D) -> void:
	_scanned = true
	GameState.heal_player(35.0)
	if not GameState.register_discovery(_planet_name, _site_id, _title):
		GameState.post_notification("Energia do traje recarregada (+35).", Color(0.35, 0.95, 1.0))
		if is_instance_valid(GameState.audio_system):
			GameState.audio_system.play_discovery()
