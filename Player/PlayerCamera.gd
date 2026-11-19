extends Node3D
## The heading lives independently of the avatar's animation and movement facing.

@export var distance := 4.25
@export var height_offset := 1.58

@onready var _camera: Camera3D = $Camera3D
@onready var _body: CharacterBody3D = get_parent()
var _heading := Vector3.FORWARD
var _up := Vector3.UP
var _pivot := Vector3.ZERO
var _pitch := -0.19
var _arm := 4.25
var _tracking := false


func _process(delta: float) -> void:
	if GameState.current_mode != GameState.ControlMode.ON_FOOT:
		_tracking = false
		return

	var target_up := _body.global_basis.y.normalized()
	var snap := not _tracking or _pivot.distance_squared_to(_body.global_position) > 64.0
	if snap:
		_heading = -_body.global_basis.z.normalized()
		_up = target_up
		_arm = distance
		_pitch = -0.19
	else:
		var next_up := _up.slerp(target_up, 1.0 - exp(-delta * 10.0)).normalized()
		_heading = Quaternion(_up, next_up) * _heading
		_up = next_up

	var look := GameState.mobile_look_delta
	GameState.mobile_look_delta = Vector2.ZERO
	var sensitivity := 0.0042 * QualityManager.touch_sensitivity
	_heading = _heading.rotated(_up, -look.x * sensitivity).slide(_up).normalized()
	_pitch = clampf(_pitch - look.y * sensitivity, -0.99, 1.05)

	var right := _heading.cross(_up).normalized()
	var aim := _heading.rotated(right, _pitch)
	var target := _body.global_position + _up * height_offset
	_pivot = target if snap else _pivot.lerp(target, 1.0 - exp(-delta * 19.0))
	var shoulder := right * 0.52
	var offset := -aim * distance + shoulder
	var camera_path := _pivot + offset - target
	var ray := PhysicsRayQueryParameters3D.create(target, target + camera_path, 37, [_body.get_rid()])
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(ray)
	var allowed := camera_path.length()
	if not hit.is_empty():
		allowed = maxf(0.18, target.distance_to(hit["position"]) - 0.32)
	_arm = minf(allowed, lerpf(_arm, allowed, 1.0 - exp(-delta * 8.0)))
	_camera.global_position = target + camera_path.normalized() * _arm
	_camera.global_basis = Basis.looking_at(aim, _up)
	if not _camera.current:
		_camera.make_current()
	_tracking = true


func get_horizontal_forward(up: Vector3) -> Vector3:
	var forward := _heading if _tracking else -_body.global_basis.z
	return forward.slide(up).normalized()
