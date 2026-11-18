extends Node3D
## Third-person orbital camera aligned to local planetary up-direction.
## Supports touch-drag rotation on Android and mouse-look on Desktop.

@export var distance: float = 6.2
@export var height_offset: float = 2.1
@export var pitch_limits_deg: Vector2 = Vector2(-55.0, 68.0)

var _yaw: float = 0.0
var _pitch: float = -16.0
var _smoothed_up: Vector3 = Vector3.UP


func _process(delta: float) -> void:
	if GameState.current_mode != GameState.ControlMode.ON_FOOT:
		return

	var parent_body := get_parent() as Node3D
	if parent_body == null:
		return

	var look: Vector2 = GameState.mobile_look_delta
	GameState.mobile_look_delta = Vector2.ZERO

	var sens: float = 0.24 * QualityManager.touch_sensitivity
	_yaw -= look.x * sens
	_pitch = clampf(_pitch - look.y * sens, pitch_limits_deg.x, pitch_limits_deg.y)

	var target_up: Vector3 = parent_body.global_transform.basis.y.normalized()
	_smoothed_up = _smoothed_up.slerp(target_up, clampf(delta * 10.0, 0.0, 1.0)).normalized()

	var ref_fwd: Vector3 = -parent_body.global_transform.basis.z
	ref_fwd = (ref_fwd - _smoothed_up * ref_fwd.dot(_smoothed_up)).normalized()
	if ref_fwd.length_squared() < 0.001:
		ref_fwd = _smoothed_up.cross(Vector3.RIGHT).normalized()

	var yaw_basis := Basis(_smoothed_up, deg_to_rad(_yaw))
	var cam_fwd: Vector3 = (yaw_basis * ref_fwd).normalized()
	var cam_right: Vector3 = cam_fwd.cross(_smoothed_up).normalized()
	var pitch_basis := Basis(cam_right, deg_to_rad(_pitch))
	var final_fwd: Vector3 = (pitch_basis * cam_fwd).normalized()

	var pivot: Vector3 = parent_body.global_position + _smoothed_up * height_offset
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam:
		if not cam.current:
			cam.make_current()
		cam.global_position = pivot - final_fwd * distance
		cam.look_at(pivot + final_fwd * 2.0, _smoothed_up)


func get_horizontal_forward(up_vec: Vector3) -> Vector3:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return -global_transform.basis.z
	var f: Vector3 = -cam.global_transform.basis.z
	f = (f - up_vec * f.dot(up_vec)).normalized()
	if f.length_squared() < 0.001:
		f = up_vec.cross(Vector3.RIGHT).normalized()
	return f
