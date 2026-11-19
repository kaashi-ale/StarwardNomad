extends Node3D
## Articulated hard-shell explorer. The movement controller supplies the actual gait speed.

var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _nozzles: Array[MeshInstance3D] = []
var _chassis: Node3D
var _phase := 0.0
var _breath := 0.0
var _landing := 0.0
var _recoil := 0.0
var _shell := _material(Color("#eadfc9"), 0.48)
var _fabric := _material(Color("#202d3c"), 0.92)
var _orange := _material(Color("#d16135"), 0.55)
var _glass := _material(Color("#194659"), 0.18, 0.55)
var _light := _material(Color("#7cece4"), 0.33, 0.0, 0.8)


func _ready() -> void:
	_chassis = _joint(self, Vector3.ZERO)
	_oval(_chassis, Vector3(0, 1.24, 0), Vector3(0.65, 0.68, 0.43), _fabric)
	_armor(_chassis, Vector3(0, 1.36, -0.07), Vector3(0.59, 0.39, 0.40), _shell)
	_armor(_chassis, Vector3(0, 0.99, 0), Vector3(0.49, 0.16, 0.35), _orange)
	_oval(_chassis, Vector3(0, 1.79, -0.015), Vector3(0.59, 0.56, 0.56), _shell)
	_oval(_chassis, Vector3(0, 1.80, -0.168), Vector3(0.52, 0.31, 0.37), _glass)
	_armor(_chassis, Vector3(0, 1.38, 0.27), Vector3(0.48, 0.55, 0.25), _fabric)
	_armor(_chassis, Vector3(0, 1.42, 0.42), Vector3(0.29, 0.40, 0.13), _orange)
	_armor(_chassis, Vector3(0, 1.54, 0.495), Vector3(0.21, 0.04, 0.025), _light)
	for side: float in [-1.0, 1.0]:
		_oval(_chassis, Vector3(side * 0.275, 1.79, 0.025), Vector3(0.105, 0.22, 0.22), _orange)
		_armor(_chassis, Vector3(side * 0.245, 1.31, 0.37), Vector3(0.18, 0.49, 0.24), _shell)
		_armor(_chassis, Vector3(side * 0.245, 1.105, 0.385), Vector3(0.13, 0.08, 0.16), _fabric)
		var flame := _oval(_chassis, Vector3(side * 0.245, 0.93, 0.39), Vector3(0.10, 0.33, 0.10), _light)
		flame.hide()
		_nozzles.append(flame)
		var arm := _joint(_chassis, Vector3(side * 0.38, 1.49, 0))
		_arms.append(arm)
		_oval(arm, Vector3(0, -0.09, 0), Vector3(0.25, 0.31, 0.25), _shell)
		_oval(arm, Vector3(0, -0.32, -0.025), Vector3(0.19, 0.37, 0.19), _fabric)
		_armor(arm, Vector3(0, -0.37, 0.024), Vector3(0.18, 0.21, 0.16), _shell)
		_oval(arm, Vector3(0, -0.53, -0.055), Vector3(0.16, 0.17, 0.16), _orange)
		if side > 0.0:
			_armor(arm, Vector3(0.02, -0.50, -0.17), Vector3(0.13, 0.16, 0.30), _fabric)
			_armor(arm, Vector3(0.02, -0.485, -0.325), Vector3(0.10, 0.06, 0.025), _light)
		var hip := _joint(_chassis, Vector3(side * 0.165, 0.96, 0))
		_hips.append(hip)
		_oval(hip, Vector3(0, -0.20, 0), Vector3(0.28, 0.49, 0.27), _fabric)
		_armor(hip, Vector3(0, -0.18, -0.06), Vector3(0.22, 0.32, 0.22), _shell)
		var knee := _joint(hip, Vector3(0, -0.45, 0))
		_knees.append(knee)
		_oval(knee, Vector3(0, -0.03, -0.07), Vector3(0.22, 0.22, 0.19), _orange)
		_armor(knee, Vector3(0, -0.23, 0), Vector3(0.21, 0.34, 0.22), _shell)
		_armor(knee, Vector3(0, -0.43, -0.05), Vector3(0.25, 0.16, 0.37), _fabric)


func animate(delta: float, ground_speed: float, grounded: bool, rising: bool, thrust: bool, landed: bool) -> void:
	if landed:
		_landing = 1.0
	_landing = move_toward(_landing, 0.0, delta * 4.2)
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	var gait := clampf(ground_speed / 8.0, 0.0, 1.0)
	_phase = fmod(_phase + ground_speed * 1.5 * delta, TAU)
	_breath = fmod(_breath + delta * 2.3, TAU)
	var blend := 1.0 - exp(-delta * 17.0)
	var bob := (absf(sin(_phase)) * gait * 0.06 + sin(_breath) * (1.0 - gait) * 0.018) if grounded else 0.0
	_chassis.position.y = lerpf(_chassis.position.y, bob - _landing * 0.15, blend)
	_chassis.rotation.x = lerpf(_chassis.rotation.x, -gait * 0.14 if grounded else (-0.19 if thrust else 0.04), blend)
	for index in range(2):
		var stride := sin(_phase + PI * index) * gait
		var thigh := stride * 0.88 if grounded else (-0.48 if rising else -0.17)
		var knee := maxf(0.0, -stride) * 0.96 + _landing * 0.48 if grounded else (0.82 if thrust else 0.48)
		var arm := -stride * 0.65 if grounded else -0.24
		if index == 1 and _recoil > 0.0:
			arm = -1.0 - _recoil * 0.38
		_hips[index].rotation.x = lerpf(_hips[index].rotation.x, thigh, blend)
		_knees[index].rotation.x = lerpf(_knees[index].rotation.x, knee, blend)
		_arms[index].rotation.x = lerpf(_arms[index].rotation.x, arm, blend)
		_nozzles[index].visible = thrust


func recoil() -> void:
	_recoil = 1.0


func _joint(parent: Node3D, offset: Vector3) -> Node3D:
	var joint := Node3D.new()
	parent.add_child(joint)
	joint.position = offset
	return joint


func _material(color: Color, roughness: float, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material


func _oval(parent: Node3D, offset: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	var piece := _piece(parent, offset, mesh, material)
	piece.scale = dimensions
	return piece


func _armor(parent: Node3D, offset: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_piece(parent, offset, mesh, material)


func _piece(parent: Node3D, offset: Vector3, mesh: PrimitiveMesh, material: Material) -> MeshInstance3D:
	mesh.material = material
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	parent.add_child(piece)
	piece.position = offset
	return piece
