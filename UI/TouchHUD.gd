extends CanvasLayer
## Mobile-first responsive HUD with multi-touch Virtual Joystick, dedicated Camera
## drag region (excluding action buttons), context-aware On-Foot & Starship controls,
## 3D Planet Waypoint markers, and live Graphics Quality settings for Moto G04s.

const GRAPHICS_PRESETS := [
	QualityManager.Preset.ECONOMY,
	QualityManager.Preset.LOW,
	QualityManager.Preset.MEDIUM,
	QualityManager.Preset.HIGH,
]
const FPS_OPTIONS := [30, 45, 60]

@onready var location_label: Label = $TopBar/HBox/LocationLabel
@onready var telemetry_label: Label = $TopBar/HBox/TelemetryLabel
@onready var health_bar: ProgressBar = $TopBar/HBox/HealthBar
@onready var energy_bar: ProgressBar = $TopBar/HBox/EnergyBar
@onready var notification_label: Label = $NotificationLabel

@onready var joystick_base: Control = $JoystickZone/JoystickBase
@onready var joystick_knob: Control = $JoystickZone/JoystickBase/Knob
@onready var top_bar: Control = $TopBar
@onready var settings_btn: Button = $TopBar/HBox/SettingsButton

@onready var foot_controls: Control = $FootControls
@onready var ship_controls: Control = $ShipControls
@onready var recall_button: Button = $FootControls/RecallButton
@onready var ship_beacon: Label = $WaypointLayer/ShipBeacon
@onready var board_ship_btn: Button = $FootControls/BoardShipButton
@onready var interact_btn: Button = $FootControls/InteractButton
@onready var land_ship_btn: Button = $ShipControls/LandShipButton
@onready var exit_ship_btn: Button = $ShipControls/ExitShipButton

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var close_settings_btn: Button = $SettingsPanel/VBox/CloseButton
@onready var waypoint_layer: Control = $WaypointLayer

@onready var nav_panel: PanelContainer = $NavigationPanel
@onready var nav_status: Label = $NavigationPanel/Status

var _joy_touch_index: int = -1
var _look_touch_index: int = -1
var _button_touches: Dictionary = {}
var _settings_buttons: Array[Button] = []
var _held_ship_buttons: Array[Button] = []
var _joy_radius: float = 68.0
var _notif_timer: float = 0.0
var _waypoint_timer: float = 0.0
var _waypoint_labels: Array[Label] = []


func _ready() -> void:
	GameState.mode_changed.connect(_on_mode_changed)
	GameState.altitude_updated.connect(_on_altitude_updated)
	GameState.ship_proximity_changed.connect(_on_ship_proximity_changed)
	GameState.interaction_changed.connect(_on_interaction_changed)
	GameState.stats_updated.connect(_on_stats_updated)
	GameState.notification_requested.connect(_on_notification_requested)

	if not OS.has_feature("mobile"):
		board_ship_btn.text = "E  ·  EMBARCAR"
	_setup_buttons()
	_setup_settings_ui()
	_set_settings_open(false)
	get_window().focus_exited.connect(_reset_touch_inputs)
	_on_mode_changed(GameState.current_mode)
	GameState.emit_current_stats()


func _process(delta: float) -> void:
	if _notif_timer > 0.0:
		_notif_timer -= delta
		if _notif_timer <= 0.0:
			notification_label.visible = false

	# Update dynamic Ship Landing / Exit button availability
	if GameState.current_mode == GameState.ControlMode.IN_SHIP and is_instance_valid(GameState.ship_node):
		var ship := GameState.ship_node
		exit_ship_btn.visible = ship.is_landed
		land_ship_btn.visible = not ship.is_landed
		land_ship_btn.modulate = Color(0.4, 1.0, 0.55) if ship.can_land_now else Color(0.85, 0.85, 0.85, 0.75)

	# Sync virtual joystick with ship steering when in ship mode
	if GameState.current_mode == GameState.ControlMode.IN_SHIP:
		GameState.mobile_ship_steer = GameState.mobile_move_vector
	else:
		GameState.mobile_ship_steer = Vector2.ZERO

	_waypoint_timer += delta
	if _waypoint_timer >= 0.05:
		_waypoint_timer = 0.0
		_update_planet_waypoints()
		_update_navigation()
		_update_ship_beacon()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch_index:
			_update_joystick(event.position)
		elif event.index == _look_touch_index:
			GameState.mobile_look_delta += event.relative
		get_viewport().set_input_as_handled()
	elif not settings_panel.visible and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		GameState.mobile_look_delta += event.relative


func _handle_screen_touch(touch: InputEventScreenTouch) -> void:
	# Each finger keeps its original control until release or cancellation.
	if touch.canceled or not touch.pressed:
		var button := _button_touches.get(touch.index) as Button
		if button != null:
			_button_touches.erase(touch.index)
			button.self_modulate = Color.WHITE
			button.button_up.emit()
			if not touch.canceled and not button.disabled and _touch_hits(button, touch.position):
				if button.toggle_mode:
					button.button_pressed = button.button_group != null or not button.button_pressed
				button.pressed.emit()
		elif touch.index == _joy_touch_index:
			_joy_touch_index = -1
			_reset_joystick()
		elif touch.index == _look_touch_index:
			_look_touch_index = -1
		return

	var button := _find_touch_button(touch.position)
	if button != null:
		if not button.disabled and button not in _button_touches.values():
			_button_touches[touch.index] = button
			button.self_modulate = Color(0.72, 0.88, 1.0)
			button.button_down.emit()
		return
	if settings_panel.visible or _touch_hits(top_bar, touch.position):
		return

	var left_side := touch.position.x < get_viewport().get_visible_rect().size.x * 0.42
	if left_side and _joy_touch_index == -1:
		_joy_touch_index = touch.index
		_update_joystick(touch.position)
	elif not left_side and _look_touch_index == -1:
		_look_touch_index = touch.index


func _find_touch_button(pos: Vector2) -> Button:
	if _touch_hits(settings_btn, pos):
		return settings_btn

	var active_group := foot_controls if foot_controls.visible else ship_controls
	var buttons: Array = _settings_buttons if settings_panel.visible else active_group.get_children()
	for button in buttons:
		if button is Button and _touch_hits(button, pos):
			return button
	return null


func _touch_hits(control: Control, pos: Vector2) -> bool:
	var local_pos := control.get_global_transform_with_canvas().affine_inverse() * pos
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO, control.size).has_point(local_pos)


func _update_joystick(touch_pos: Vector2) -> void:
	var center: Vector2 = joystick_base.global_position + joystick_base.size * 0.5
	var offset: Vector2 = touch_pos - center
	if offset.length() > _joy_radius:
		offset = offset.normalized() * _joy_radius
	joystick_knob.position = (joystick_base.size * 0.5) + offset - (joystick_knob.size * 0.5)
	var norm: Vector2 = offset / _joy_radius
	GameState.mobile_move_vector = Vector2(norm.x, -norm.y)


func _reset_joystick() -> void:
	joystick_knob.position = (joystick_base.size * 0.5) - (joystick_knob.size * 0.5)
	GameState.mobile_move_vector = Vector2.ZERO
	GameState.mobile_ship_steer = Vector2.ZERO


func _reset_touch_inputs() -> void:
	for button in _button_touches.values():
		button.self_modulate = Color.WHITE
		button.button_up.emit()
	_button_touches.clear()
	_held_ship_buttons.clear()
	_joy_touch_index = -1
	_look_touch_index = -1
	_reset_joystick()
	GameState.mobile_look_delta = Vector2.ZERO
	GameState.mobile_jump_pressed = false
	GameState.mobile_fire_pressed = false
	GameState.mobile_ship_throttle = 0.0
	GameState.mobile_ship_vertical = 0.0


func _setup_buttons() -> void:
	# On-Foot buttons
	recall_button.pressed.connect(func():
		if is_instance_valid(GameState.ship_node):
			GameState.ship_node.recall_ship())
	var jump_btn := $FootControls/JumpButton as Button
	jump_btn.button_down.connect(func():
		GameState.mobile_jump_pressed = true
		if is_instance_valid(GameState.player_node):
			GameState.player_node.trigger_jump_or_jetpack()
	)
	jump_btn.button_up.connect(func(): GameState.mobile_jump_pressed = false)

	var sprint_btn := $FootControls/SprintButton as Button
	sprint_btn.toggled.connect(func(pressed: bool): GameState.mobile_sprint_active = pressed)

	var fire_btn := $FootControls/FireButton as Button
	fire_btn.button_down.connect(func():
		GameState.mobile_fire_pressed = true
		if is_instance_valid(GameState.player_node):
			GameState.player_node.request_fire()
	)
	fire_btn.button_up.connect(func(): GameState.mobile_fire_pressed = false)

	interact_btn.pressed.connect(func():
		if is_instance_valid(GameState.player_node):
			GameState.player_node.try_interact()
	)

	board_ship_btn.pressed.connect(func():
		if is_instance_valid(GameState.player_node):
			GameState.player_node.try_board_ship()
	)

	# Spaceship buttons
	$ShipControls/DestinationButton.pressed.connect(func(): GameState.ship_node.cycle_target())
	$ShipControls/CourseButton.pressed.connect(func(): GameState.ship_node.toggle_navigation_assist())
	_bind_ship_axis($ShipControls/ThrustButton, $ShipControls/BrakeButton,
		func(value: float): GameState.mobile_ship_throttle = value)
	_bind_ship_axis($ShipControls/AscendButton, $ShipControls/DescendButton,
		func(value: float): GameState.mobile_ship_vertical = value)

	land_ship_btn.pressed.connect(func():
		if is_instance_valid(GameState.ship_node):
			GameState.ship_node.try_land_ship()
	)

	exit_ship_btn.pressed.connect(func():
		if is_instance_valid(GameState.ship_node):
			GameState.ship_node.exit_ship()
	)

	settings_btn.pressed.connect(func(): _set_settings_open(not settings_panel.visible))


func _bind_ship_axis(positive: Button, negative: Button, update: Callable) -> void:
	var update_axis := func():
		update.call(float(positive in _held_ship_buttons) - float(negative in _held_ship_buttons))
	for button: Button in [positive, negative]:
		button.button_down.connect(func():
			if button not in _held_ship_buttons:
				_held_ship_buttons.append(button)
			update_axis.call()
		)
		button.button_up.connect(func():
			_held_ship_buttons.erase(button)
			update_axis.call()
		)


func _setup_settings_ui() -> void:
	var fps_row: HBoxContainer = $SettingsPanel/VBox/FpsOptions
	_add_settings_choices($SettingsPanel/VBox/PresetOptions, ["Econômico", "Baixo", "Médio", "Alto"],
		GRAPHICS_PRESETS.find(QualityManager.current_preset),
		func(index: int): QualityManager.select_preset(GRAPHICS_PRESETS[index]))
	_add_settings_choices(fps_row, ["30 FPS", "45 FPS", "60 FPS"],
		FPS_OPTIONS.find(QualityManager.target_fps),
		func(index: int): QualityManager.set_target_fps(FPS_OPTIONS[index]))
	QualityManager.quality_changed.connect(func(_preset: int):
		var index := FPS_OPTIONS.find(QualityManager.target_fps)
		if index >= 0:
			var button := fps_row.get_child(index) as Button
			button.button_pressed = true
	)
	var audio_row := $SettingsPanel/VBox/AudioOptions
	var lower: Button = audio_row.get_node("Lower")
	var raise_volume: Button = audio_row.get_node("Raise")
	var mute: Button = audio_row.get_node("Mute")
	var refresh_volume := func():
		audio_row.get_node("Level").text = "%d%%" % QualityManager.volume_percent
		mute.text = "Reativar som" if QualityManager.sound_muted else "Silenciar"
		lower.disabled = QualityManager.volume_percent == 0
		raise_volume.disabled = QualityManager.volume_percent == 100
	lower.pressed.connect(func():
		QualityManager.set_audio(QualityManager.volume_percent - 10, QualityManager.sound_muted)
		refresh_volume.call())
	raise_volume.pressed.connect(func():
		QualityManager.set_audio(QualityManager.volume_percent + 10, QualityManager.sound_muted)
		refresh_volume.call())
	mute.pressed.connect(func():
		QualityManager.set_audio(QualityManager.volume_percent, not QualityManager.sound_muted)
		refresh_volume.call())
	_settings_buttons.append_array([lower, raise_volume, mute])
	refresh_volume.call()
	_settings_buttons.append(close_settings_btn)
	close_settings_btn.pressed.connect(func(): _set_settings_open(false))


func _set_settings_open(open: bool) -> void:
	if open:
		_reset_touch_inputs()
	settings_panel.visible = open
	GameState.settings_open = open


func _update_navigation() -> void:
	if not nav_panel.visible or not is_instance_valid(GameState.ship_node):
		return
	var ship := GameState.ship_node
	var target: Node3D = ship.navigation_target
	var course := "Escolha um destino"
	if is_instance_valid(target):
		var distance := ship.global_position.distance_to(target.global_position) - float(target.data.radius)
		var direction := ship.global_position.direction_to(target.global_position)
		var bearing := rad_to_deg((-ship.global_basis.z).angle_to(direction))
		course = "%s  ·  %.1f km  ·  %d°" % [target.planet_name, maxf(0.0, distance) / 1000.0, roundi(bearing)]
	var assist := "  ·  Curso assistido" if ship.navigation_assist else ""
	nav_status.text = "%s%s\n%s" % [course, assist, ship.landing_status]
	$ShipControls/CourseButton.modulate = Color("#8ff0cf") if ship.navigation_assist else Color.WHITE


func _add_settings_choices(row: HBoxContainer, labels: Array, selected: int, on_selected: Callable) -> void:
	var group := ButtonGroup.new()
	for index in range(labels.size()):
		var button := Button.new()
		button.text = labels[index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		row.add_child(button)
		button.button_pressed = index == selected
		button.pressed.connect(on_selected.bind(index))
		_settings_buttons.append(button)


func _update_planet_waypoints() -> void:
	if GameState.current_mode == GameState.ControlMode.ON_FOOT:
		for label in _waypoint_labels:
			label.hide()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(GameState.space_system):
		return

	var targets: Array[Dictionary] = GameState.space_system.get_navigation_targets()
	while _waypoint_labels.size() < targets.size():
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		waypoint_layer.add_child(lbl)
		_waypoint_labels.append(lbl)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for i in range(_waypoint_labels.size()):
		var lbl := _waypoint_labels[i]
		if i >= targets.size():
			lbl.visible = false
			continue
		var t: Dictionary = targets[i]
		var target_pos: Vector3 = t["position"]
		var dist: float = cam.global_position.distance_to(target_pos) - float(t["radius"])
		if dist < 120.0 or cam.is_position_behind(target_pos):
			lbl.visible = false
			continue

		var screen_pos: Vector2 = cam.unproject_position(target_pos)
		if screen_pos.x < 10.0 or screen_pos.x > vp_size.x - 120.0 or screen_pos.y < 52.0 or screen_pos.y > vp_size.y - 40.0:
			lbl.visible = false
			continue

		lbl.visible = true
		lbl.position = screen_pos
		lbl.modulate = t["color"]
		lbl.text = "◆ %s (%dm)" % [t["name"], int(maxf(0.0, dist))]


func _update_ship_beacon() -> void:
	ship_beacon.hide()
	var ship := GameState.ship_node
	var explorer := GameState.player_node
	if not foot_controls.visible or not is_instance_valid(ship) or not is_instance_valid(explorer):
		return
	var distance := roundi(explorer.global_position.distance_to(ship.global_position))
	recall_button.disabled = ship.is_recalling()
	var desktop := "R  ·  " if not OS.has_feature("mobile") else ""
	recall_button.text = "A CAMINHO  ·  %d m" % distance if ship.is_recalling() else "%sCHAMAR NAVE  ·  %d m" % [desktop, distance]
	var camera := get_viewport().get_camera_3d()
	var position := ship.global_position + ship.global_basis.y * 4.0
	if distance < 8 or distance > 850 or not is_instance_valid(camera) or camera.is_position_behind(position):
		return
	var projected := camera.unproject_position(position)
	var bounds := get_viewport().get_visible_rect().size
	if Rect2(Vector2(15, 60), bounds - Vector2(105, 132)).has_point(projected):
		ship_beacon.position = projected - Vector2(27, 11)
		ship_beacon.show()


func _on_mode_changed(new_mode: int) -> void:
	var on_foot: bool = (new_mode == GameState.ControlMode.ON_FOOT)
	_reset_touch_inputs()
	$AimPoint.visible = on_foot
	foot_controls.visible = on_foot
	ship_controls.visible = not on_foot
	nav_panel.visible = not on_foot


func _on_altitude_updated(altitude: float, _ratio: float, loc_label: String) -> void:
	location_label.text = loc_label
	var spd: float = 0.0
	if GameState.current_mode == GameState.ControlMode.IN_SHIP and is_instance_valid(GameState.ship_node):
		spd = GameState.ship_node.velocity.length()
		altitude = maxf(0.0, GameState.ship_node.surface_altitude)
	elif is_instance_valid(GameState.player_node):
		spd = GameState.player_node.velocity.length()
	telemetry_label.text = "ALT: %dm | VEL: %dm/s | FPS: %d" % [int(altitude), int(spd), Engine.get_frames_per_second()]


func _on_ship_proximity_changed(can_board: bool) -> void:
	board_ship_btn.visible = can_board


func _on_interaction_changed(can_interact: bool, prompt: String) -> void:
	interact_btn.visible = can_interact
	if can_interact:
		interact_btn.text = prompt if OS.has_feature("mobile") else "E  ·  " + prompt


func _on_stats_updated(hp: float, max_hp: float, energy: float, max_energy: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp
	energy_bar.max_value = max_energy
	energy_bar.value = energy


func _on_notification_requested(msg: String, color: Color) -> void:
	notification_label.text = msg
	notification_label.modulate = color
	notification_label.visible = true
	_notif_timer = 3.6
