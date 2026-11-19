extends Node3D
## Short routines for villagers and the cows at Aurelia's farm.

const MESH_BUILDER := preload("res://Planets/VillageMesh.gd")
var resident_name := ""
var dialogue := ""
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _walking := false
var _towards_end := true
var _pause := 0.0
var _speed := 1.15
var _gait_phase := 0.0
var _body: MeshInstance3D
var _legs: Array[MeshInstance3D] = []


func initialize(start: Vector3, destination: Vector3, display_name: String, line: String, tint: Color) -> void:
	_start = start
	_end = destination
	position = start
	resident_name = display_name
	dialogue = line
	_pause = randf_range(0.6, 3.0)
	if resident_name.is_empty():
		_speed = 0.72
		_build_cow(tint)
	else:
		add_to_group("interactables")
		_build_resident(tint)
	for part: MeshInstance3D in get_children():
		part.visibility_range_end = 180.0
		part.visibility_range_end_margin = 12.0


func get_prompt() -> String:
	return "Conversar com " + resident_name


func interact(_player: Node3D) -> void:
	_pause = 4.2
	_walking = false
	GameState.post_notification("%s · %s" % [resident_name, dialogue], Color("#ffe2ac"))


func _process(delta: float) -> void:
	var explorer := GameState.player_node if GameState.current_mode == GameState.ControlMode.ON_FOOT else GameState.ship_node
	if not is_instance_valid(explorer) or global_position.distance_squared_to(explorer.global_position) > 140.0 * 140.0:
		return
	if not _walking:
		_pause -= delta
		if _pause <= 0.0:
			_walking = true
	var goal := _end if _towards_end else _start
	if _walking:
		var direction := goal - position
		if direction.length_squared() < 0.035:
			_walking = false
			_pause = randf_range(1.8, 4.7)
			_towards_end = not _towards_end
		else:
			position = position.move_toward(goal, _speed * delta)
			var yaw := atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 6.0))
	_gait_phase += delta * 7.0
	_body.position.y = absf(sin(_gait_phase)) * 0.035 if _walking else sin(_gait_phase * 0.37) * 0.009
	for i in range(_legs.size()):
		var pose := sin(_gait_phase + float(i) * PI) * 0.40 if _walking else 0.0
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, pose, 1.0 - exp(-delta * 12.0))


func _build_resident(tint: Color) -> void:
	var fabric := tint
	var skin := Color("#d8a176").lerp(tint.lightened(0.5), 0.08)
	var leather := Color("#503b34")
	var mesh := MESH_BUILDER.new()
	mesh.oval(Vector3(0, 1.17, 0), Vector3(0.63, 0.74, 0.44), fabric)
	mesh.box(Vector3(0, 0.92, -0.02), Vector3(0.56, 0.09, 0.43), leather)
	mesh.box(Vector3(0, 0.92, -0.246), Vector3(0.11, 0.09, 0.035), Color("#e7ba76"))
	mesh.oval(Vector3(0, 1.69, -0.035), Vector3(0.39, 0.44, 0.40), skin)
	mesh.oval(Vector3(0, 1.86, 0.01), Vector3(0.47, 0.21, 0.50), fabric.darkened(0.35))
	mesh.oval(Vector3(0, 1.86, 0.01), Vector3(0.63, 0.095, 0.61), leather)
	for side: float in [-1.0, 1.0]:
		mesh.oval(Vector3(side * 0.37, 1.24, -0.025), Vector3(0.19, 0.42, 0.21), fabric.darkened(0.12), side * 0.20)
		mesh.oval(Vector3(side * 0.41, 1.02, -0.04), Vector3(0.13, 0.16, 0.14), skin)
		mesh.oval(Vector3(side * 0.087, 1.71, -0.228), Vector3(0.045, 0.061, 0.04), leather)
	_body = mesh.bake(self)
	for side: float in [-1.0, 1.0]:
		mesh = MESH_BUILDER.new()
		mesh.oval(Vector3(0, -0.29, 0), Vector3(0.22, 0.64, 0.27), fabric.darkened(0.48))
		mesh.box(Vector3(0, -0.57, -0.05), Vector3(0.24, 0.17, 0.34), leather)
		_legs.append(mesh.bake(self, Vector3(side * 0.155, 0.65, 0)))


func _build_cow(patch: Color) -> void:
	var ivory := Color("#f7ead1")
	var pink := Color("#e5a494")
	var hooves := Color("#493b38")
	var mesh := MESH_BUILDER.new()
	mesh.oval(Vector3(0, 0.86, 0.24), Vector3(1.02, 0.91, 1.88), ivory)
	mesh.oval(Vector3(0, 1.04, -0.61), Vector3(0.81, 0.73, 0.72), patch)
	mesh.oval(Vector3(0, 0.89, -0.92), Vector3(0.72, 0.37, 0.38), pink)
	mesh.oval(Vector3(0, 0.63, 1.13), Vector3(0.17, 0.53, 0.19), patch, 0.34)
	for side: float in [-1.0, 1.0]:
		mesh.oval(Vector3(side * 0.43, 0.93, 0.31 + side * 0.18), Vector3(0.20, 0.46, 0.64), patch, side * 0.25)
		mesh.oval(Vector3(side * 0.35, 1.30, -0.59), Vector3(0.40, 0.17, 0.24), patch, side * -0.21)
		mesh.oval(Vector3(side * 0.23, 1.37, -0.53), Vector3(0.13, 0.28, 0.13), ivory, side * -0.25)
		mesh.oval(Vector3(side * 0.25, 1.12, -0.88), Vector3(0.115, 0.13, 0.071), hooves)
		mesh.oval(Vector3(side * 0.15, 0.92, -1.083), Vector3(0.062, 0.043, 0.028), patch)
	_body = mesh.bake(self)
	for side: float in [-1.0, 1.0]:
		mesh = MESH_BUILDER.new()
		for at: Vector3 in [Vector3(side * 0.31, -0.25, -0.32), Vector3(-side * 0.31, -0.25, 0.77)]:
			mesh.oval(at, Vector3(0.22, 0.58, 0.28), ivory)
			mesh.box(at - Vector3(0, 0.26, 0.01), Vector3(0.24, 0.16, 0.29), hooves)
		_legs.append(mesh.bake(self, Vector3(0, 0.59, 0)))
