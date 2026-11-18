extends CanvasLayer
## Mobile-first responsive HUD with multi-touch Virtual Joystick, dedicated Camera
## drag region (excluding action buttons), context-aware On-Foot & Starship controls,
## 3D Planet Waypoint markers, and live Graphics Quality settings for Moto G04s.

@onready var location_label: Label = $TopBar/HBox/LocationLabel
@onready var telemetry_label: Label = $TopBar/HBox/TelemetryLabel
@onready var health_bar: ProgressBar = $TopBar/HBox/HealthBar
@onready var energy_bar: ProgressBar = $TopBar/HBox/EnergyBar
@onready var notification_label: Label = $NotificationLabel

@onready var joystick_base: Control = $JoystickZone/JoystickBase
@onready var joystick_knob: Control = $JoystickZone/JoystickBase/Knob

@onready var foot_controls: Control = $FootControls
@onready var ship_controls: Control = $ShipControls
@onready var board_ship_btn: Button = $FootControls/BoardShipButton
@onready var interact_btn: Button = $FootControls/InteractButton
@onready var land_ship_btn: Button = $ShipControls/LandShipButton
@onready var exit_ship_btn: Button = $ShipControls/ExitShipButton

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var preset_option: OptionButton = $SettingsPanel/VBox/PresetOption
@onready var fps_option: OptionButton = $SettingsPanel/VBox/FpsOption
@onready var waypoint_layer: Control = $WaypointLayer

var _joy_touch_index: int = -1
var _look_touch_index: int = -1
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

	_setup_buttons()
	_setup_settings_ui()
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


func _input(event: InputEvent) -> void:
	if settings_panel.visible:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var screen_w: float = get_viewport().get_visible_rect().size.x
		if touch.pressed:
			# Left 42% of screen = Virtual Joystick; Right 58% (excluding action buttons) = Camera Look
			if touch.position.x < screen_w * 0.42 and _joy_touch_index == -1:
				_joy_touch_index = touch.index
				_update_joystick(touch.position)
			elif touch.position.x >= screen_w * 0.42 and _look_touch_index == -1:
				if not _is_touch_over_ui_buttons(touch.position):
					_look_touch_index = touch.index
		else:
			if touch.index == _joy_touch_index:
				_joy_touch_index = -1
				_reset_joystick()
			elif touch.index == _look_touch_index:
				_look_touch_index = -1

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_touch_index:
			_update_joystick(drag.position)
		elif drag.index == _look_touch_index:
			GameState.mobile_look_delta += drag.relative

	# Desktop mouse fallback when holding right mouse button
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		GameState.mobile_look_delta += event.relative


func _is_touch_over_ui_buttons(pos: Vector2) -> bool:
	var top_bar := get_node_or_null("TopBar") as Control
	if is_instance_valid(top_bar) and top_bar.get_global_rect().has_point(pos):
		return true

	var active_group: Control = foot_controls if foot_controls.visible else ship_controls
	if is_instance_valid(active_group):
		for child in active_group.get_children():
			if child is Control and child.visible:
				if child.get_global_rect().grow(8.0).has_point(pos):
					return true
	return false


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


func _setup_buttons() -> void:
	# On-Foot buttons
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
	fire_btn.button_down.connect(func(): GameState.mobile_fire_pressed = true)
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
	var thrust_btn := $ShipControls/ThrustButton as Button
	thrust_btn.button_down.connect(func(): GameState.mobile_ship_throttle = 1.0)
	thrust_btn.button_up.connect(func(): GameState.mobile_ship_throttle = 0.0)

	var brake_btn := $ShipControls/BrakeButton as Button
	brake_btn.button_down.connect(func(): GameState.mobile_ship_throttle = -1.0)
	brake_btn.button_up.connect(func(): GameState.mobile_ship_throttle = 0.0)

	var ascend_btn := $ShipControls/AscendButton as Button
	ascend_btn.button_down.connect(func(): GameState.mobile_ship_vertical = 1.0)
	ascend_btn.button_up.connect(func(): GameState.mobile_ship_vertical = 0.0)

	var descend_btn := $ShipControls/DescendButton as Button
	descend_btn.button_down.connect(func(): GameState.mobile_ship_vertical = -1.0)
	descend_btn.button_up.connect(func(): GameState.mobile_ship_vertical = 0.0)

	land_ship_btn.pressed.connect(func():
		if is_instance_valid(GameState.ship_node):
			GameState.ship_node.try_land_ship()
	)

	exit_ship_btn.pressed.connect(func():
		if is_instance_valid(GameState.ship_node):
			GameState.ship_node.exit_ship()
	)

	var settings_btn := $TopBar/HBox/SettingsButton as Button
	settings_btn.pressed.connect(func(): settings_panel.visible = not settings_panel.visible)


func _setup_settings_ui() -> void:
	preset_option.clear()
	preset_option.add_item("Baixo (Moto G04s)", QualityManager.Preset.LOW)
	preset_option.add_item("Médio (Balanceado)", QualityManager.Preset.MEDIUM)
	preset_option.add_item("Alto (Visual Máximo)", QualityManager.Preset.HIGH)
	preset_option.select(QualityManager.current_preset)
	preset_option.item_selected.connect(func(idx: int): QualityManager.apply_preset(idx))

	fps_option.clear()
	fps_option.add_item("30 FPS (Estável)", 0)
	fps_option.add_item("45 FPS", 1)
	fps_option.add_item("60 FPS", 2)
	fps_option.select(0)
	fps_option.item_selected.connect(func(idx: int):
		var map := [30, 45, 60]
		QualityManager.set_target_fps(map[idx])
	)

	var close_btn := $SettingsPanel/VBox/CloseButton as Button
	close_btn.pressed.connect(func(): settings_panel.visible = false)


func _update_planet_waypoints() -> void:
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


func _on_mode_changed(new_mode: int) -> void:
	var on_foot: bool = (new_mode == GameState.ControlMode.ON_FOOT)
	foot_controls.visible = on_foot
	ship_controls.visible = not on_foot
	GameState.mobile_ship_throttle = 0.0
	GameState.mobile_ship_vertical = 0.0
	_reset_joystick()


func _on_altitude_updated(altitude: float, _ratio: float, loc_label: String) -> void:
	location_label.text = loc_label
	var spd: float = 0.0
	if GameState.current_mode == GameState.ControlMode.IN_SHIP and is_instance_valid(GameState.ship_node):
		spd = GameState.ship_node.velocity.length()
	elif is_instance_valid(GameState.player_node):
		spd = GameState.player_node.velocity.length()
	telemetry_label.text = "ALT: %dm | VEL: %dm/s | FPS: %d" % [int(altitude), int(spd), Engine.get_frames_per_second()]


func _on_ship_proximity_changed(can_board: bool) -> void:
	board_ship_btn.visible = can_board


func _on_interaction_changed(can_interact: bool, prompt: String) -> void:
	interact_btn.visible = can_interact
	if can_interact:
		interact_btn.text = prompt


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
