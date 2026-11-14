extends Node3D

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PLATFORM_SCRIPT: Script = preload("res://scripts/platform.gd")
const HAZARD_SCRIPT: Script = preload("res://scripts/hazard.gd")

var world: Node3D
var player: ButtBouncePlayer
var camera: Camera3D
var charge_bar: ProgressBar
var message_label: Label
var distance_label: Label
var won := false
var _detail_time := 0.0
var _rotating_details: Array[Node3D] = []
var _warning_lights: Array[OmniLight3D] = []

var _camera_yaw := PI
var _camera_pitch := 0.34
var _camera_distance := 10.0
var _mouse_sensitivity := 0.003
var _min_camera_distance := 5.0
var _max_camera_distance := 16.0


func _ready() -> void:
	world = WORLD_SCENE.instantiate()
	add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_upgrade_rooftop_environment()
	_add_rooftop_details()
	_add_extra_rooftop_challenges()

	player = PLAYER_SCENE.instantiate() as ButtBouncePlayer
	add_child(player)
	var start_marker: Marker3D = world.get_node("Markers/PlayerStart")
	player.global_position = start_marker.global_position + Vector3(0.0, 0.95, 0.0)
	_camera_yaw = player.visual.rotation.y
	player.set_camera_yaw(_camera_yaw)
	player.player_fell.connect(_on_player_fell)
	player.charge_updated.connect(_on_charge_updated)
	player.bounce_launched.connect(_on_bounce_launched)
	_create_camera()
	_create_hud()
	var goal: Area3D = world.get_node("Markers/GoalZone")
	goal.body_entered.connect(_on_goal_entered)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * _mouse_sensitivity
		_camera_pitch = clampf(
			_camera_pitch - event.relative.y * _mouse_sensitivity,
			-0.28,
			0.88
		)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(_min_camera_distance, _camera_distance - 0.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(_max_camera_distance, _camera_distance + 0.8)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = (
				Input.MOUSE_MODE_VISIBLE
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				else Input.MOUSE_MODE_CAPTURED
			)


func _process(delta: float) -> void:
	if player == null or camera == null:
		return

	_detail_time += delta
	for rotor in _rotating_details:
		rotor.rotate_y(delta * 2.2)
	for warning_light in _warning_lights:
		warning_light.light_energy = 0.65 + 0.45 * (0.5 + 0.5 * sin(_detail_time * 3.2))

	player.set_camera_yaw(_camera_yaw)
	var target := player.global_position + Vector3.UP * 0.9
	var horizontal_distance := _camera_distance * cos(_camera_pitch)
	var vertical_distance := _camera_distance * sin(_camera_pitch)
	var camera_offset := Vector3(
		-sin(_camera_yaw) * horizontal_distance,
		vertical_distance,
		-cos(_camera_yaw) * horizontal_distance
	)
	var desired_camera_position := target + camera_offset
	camera.global_position = camera.global_position.lerp(
		desired_camera_position,
		1.0 - exp(-10.0 * delta)
	)
	camera.look_at(target, Vector3.UP)
	var travelled := int(maxf(0.0, -player.global_position.z))
	distance_label.text = "ROOFTOP RUN   •   %dm" % travelled


func _upgrade_rooftop_environment() -> void:
	var world_environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		# The authored scene had ambient light disabled. Sky-based ambient light
		# makes the shaded sides of buildings and rooftop props readable.
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.ambient_light_energy = 0.72
		environment.fog_density = 0.0022
		environment.glow_intensity = 0.38

	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 1.45
		sun.light_color = Color(1.0, 0.84, 0.72)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 120.0


func _add_rooftop_details() -> void:
	var metal := _make_detail_material(Color(0.28, 0.34, 0.40), 0.72, 0.34)
	var painted_metal := _make_detail_material(Color(0.78, 0.34, 0.16), 0.48, 0.46)
	var warning := _make_detail_material(Color(1.0, 0.58, 0.12), 0.25, 0.3)
	warning.emission_enabled = true
	warning.emission = Color(1.0, 0.24, 0.05)
	warning.emission_energy_multiplier = 0.75

	# Additional ducts and exhaust stacks make each roof feel like a working
	# city building rather than a bare blockout.
	_add_horizontal_pipe(Vector3(8.4, 3.12, -27.4), 3.2, metal)
	_add_horizontal_pipe(Vector3(-2.0, 6.12, -54.0), 3.0, metal)
	_add_horizontal_pipe(Vector3(-22.0, 12.62, -74.0), 3.6, metal)
	_add_vertical_vent(Vector3(-15.8, 7.5, -54.5), 1.8, 0.38, metal)
	_add_vertical_vent(Vector3(-5.8, 26.5, -91.6), 2.0, 0.42, metal)
	_add_vertical_vent(Vector3(18.8, 31.0, -114.0), 2.3, 0.48, metal)

	# Animated extractor fans and pulsing aircraft warning beacons.
	_add_rooftop_fan(Vector3(8.3, 3.0, -24.8), metal)
	_add_rooftop_fan(Vector3(-1.2, 6.0, -52.4), metal)
	_add_rooftop_fan(Vector3(-21.7, 12.5, -72.0), metal)
	_add_rooftop_fan(Vector3(17.0, 31.0, -112.0), metal)

	_add_warning_beacon(Vector3(-16.0, 7.5, -49.5), warning)
	_add_warning_beacon(Vector3(4.6, 28.0, -94.0), warning)
	_add_warning_beacon(Vector3(20.3, 31.0, -108.0), warning)

	# Small painted safety barriers help frame the edges without closing the
	# jumps between rooftops.
	_add_safety_barrier(Vector3(-4.0, 6.05, -48.2), 4.0, painted_metal)
	_add_safety_barrier(Vector3(-24.0, 12.55, -68.1), 4.0, painted_metal)


func _add_extra_rooftop_challenges() -> void:
	# A moving transfer pad bridges the first rooftop gap.
	_add_platform("MovingTransfer_01", Vector3(2.0, 2.55, -19.5), Vector3(3.4, 0.55, 3.2), 1, 2.2, 0.85, Color(0.36, 0.47, 0.56))
	# A second moving pad creates a side-to-side landing between the mid roofs.
	_add_platform("MovingTransfer_02", Vector3(-9.2, 6.85, -52.0), Vector3(3.0, 0.55, 3.0), 1, 1.8, 0.72, Color(0.38, 0.48, 0.56))
	# This high transfer platform makes the climb to the upper city roofs a
	# readable two-stage jump instead of an abrupt, nearly impossible gap.
	_add_platform("MovingTransfer_03", Vector3(-19.5, 18.6, -79.0), Vector3(3.2, 0.6, 3.2), 1, 1.55, 0.68, Color(0.39, 0.49, 0.56))

	# New swinging wrecking balls occupy the early and middle sections too.
	_add_swing_hazard("RooftopMace_03", Vector3(6.0, 6.5, -37.0), 2.7, 1.45)
	_add_swing_hazard("RooftopMace_04", Vector3(-4.0, 9.6, -52.0), 2.8, 1.2)
	_add_swing_hazard("RooftopMace_05", Vector3(-24.0, 16.3, -70.0), 3.0, 1.35)
	_add_swing_hazard("RooftopMace_06", Vector3(-14.0, 28.8, -84.0), 3.0, 1.6)


func _add_platform(
	platform_name: String,
	world_position: Vector3,
	platform_size: Vector3,
	platform_kind: int,
	travel_range: float,
	speed: float,
	color: Color
) -> void:
	var platform := AnimatableBody3D.new()
	platform.name = platform_name
	platform.position = world_position
	platform.set_script(PLATFORM_SCRIPT)
	platform.set("kind", platform_kind)
	platform.set("size", platform_size)
	platform.set("move_range", travel_range)
	platform.set("move_speed", speed)
	platform.set("top_color", color)
	world.add_child(platform)


func _add_swing_hazard(hazard_name: String, world_position: Vector3, chain_length: float, swing_speed: float) -> void:
	var hazard := Node3D.new()
	hazard.name = hazard_name
	hazard.position = world_position
	hazard.set_script(HAZARD_SCRIPT)
	hazard.set("length", chain_length)
	hazard.set("speed", swing_speed)
	world.add_child(hazard)


func _add_rooftop_fan(world_position: Vector3, material: Material) -> void:
	var fan := Node3D.new()
	fan.name = "AnimatedRoofExtractor"
	fan.position = world_position
	world.add_child(fan)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.72
	base_mesh.bottom_radius = 0.82
	base_mesh.height = 0.28
	base.mesh = base_mesh
	base.material_override = material
	base.position.y = 0.14
	fan.add_child(base)

	var rotor := Node3D.new()
	rotor.name = "FanRotor"
	rotor.position.y = 0.32
	fan.add_child(rotor)
	for blade_index in range(4):
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(1.22, 0.09, 0.24)
		blade.mesh = blade_mesh
		blade.material_override = material
		blade.rotation.y = float(blade_index) * PI * 0.5
		rotor.add_child(blade)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.2
	hub_mesh.bottom_radius = 0.2
	hub_mesh.height = 0.28
	hub.mesh = hub_mesh
	hub.material_override = material
	rotor.add_child(hub)
	_rotating_details.append(rotor)


func _add_horizontal_pipe(world_position: Vector3, pipe_length: float, material: Material) -> void:
	var pipe := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.09
	mesh.height = pipe_length
	mesh.radial_segments = 16
	pipe.mesh = mesh
	pipe.material_override = material
	pipe.position = world_position
	pipe.rotation.x = PI * 0.5
	world.add_child(pipe)
	for side in [-1.0, 1.0]:
		var support := MeshInstance3D.new()
		var support_mesh := BoxMesh.new()
		support_mesh.size = Vector3(0.16, 0.28, 0.16)
		support.mesh = support_mesh
		support.material_override = material
		support.position = world_position + Vector3(0.0, -0.13, side * pipe_length * 0.32)
		world.add_child(support)


func _add_vertical_vent(world_position: Vector3, vent_height: float, radius: float, material: Material) -> void:
	var vent := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.86
	mesh.height = vent_height
	mesh.radial_segments = 20
	vent.mesh = mesh
	vent.material_override = material
	vent.position = world_position + Vector3(0.0, vent_height * 0.5, 0.0)
	world.add_child(vent)

	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = radius * 1.18
	cap_mesh.bottom_radius = radius * 1.18
	cap_mesh.height = 0.12
	cap.mesh = cap_mesh
	cap.material_override = material
	cap.position = world_position + Vector3(0.0, vent_height, 0.0)
	world.add_child(cap)


func _add_warning_beacon(world_position: Vector3, material: Material) -> void:
	var beacon := OmniLight3D.new()
	beacon.name = "PulsingRoofBeacon"
	beacon.position = world_position + Vector3(0.0, 1.1, 0.0)
	beacon.light_color = Color(1.0, 0.32, 0.12)
	beacon.light_energy = 0.9
	beacon.omni_range = 6.0
	world.add_child(beacon)
	_warning_lights.append(beacon)

	var lamp := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	lamp.mesh = mesh
	lamp.material_override = material
	lamp.position = beacon.position
	world.add_child(lamp)


func _add_safety_barrier(world_position: Vector3, barrier_length: float, material: Material) -> void:
	var top_rail := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(barrier_length, 0.10, 0.10)
	top_rail.mesh = top_mesh
	top_rail.material_override = material
	top_rail.position = world_position + Vector3(0.0, 1.05, 0.0)
	world.add_child(top_rail)

	for end in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.10, 1.05, 0.10)
		post.mesh = post_mesh
		post.material_override = material
		post.position = world_position + Vector3(end * barrier_length * 0.5, 0.52, 0.0)
		world.add_child(post)


func _make_detail_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.fov = 68.0
	add_child(camera)
	camera.current = true
	_camera_yaw = player.visual.rotation.y
	var target := player.global_position + Vector3.UP * 0.9
	var horizontal_distance := _camera_distance * cos(_camera_pitch)
	var vertical_distance := _camera_distance * sin(_camera_pitch)
	var camera_offset := Vector3(
		-sin(_camera_yaw) * horizontal_distance,
		vertical_distance,
		-cos(_camera_yaw) * horizontal_distance
	)
	camera.global_position = target + camera_offset
	camera.look_at(target, Vector3.UP)


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.custom_minimum_size = Vector2(350, 112)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "BUTT BOUNCE  /  ROOFTOP RUSH"
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	distance_label = Label.new()
	distance_label.text = "ROOFTOP RUN"
	column.add_child(distance_label)
	charge_bar = ProgressBar.new()
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.value = 0.0
	charge_bar.custom_minimum_size = Vector2(310, 18)
	charge_bar.show_percentage = false
	column.add_child(charge_bar)
	message_label = Label.new()
	message_label.text = "WASD / ARROWS: MOVE  •  HOLD SPACE / LEFT CLICK: CHARGE"
	column.add_child(message_label)
	var camera_help := Label.new()
	camera_help.text = "MOUSE: LOOK  •  WHEEL: ZOOM  •  ESC: RELEASE MOUSE"
	camera_help.add_theme_font_size_override("font_size", 12)
	column.add_child(camera_help)


func _on_charge_updated(amount: float) -> void:
	if charge_bar:
		charge_bar.value = amount
	if message_label:
		if amount >= 0.98:
			message_label.text = "FULL CHARGE!  RELEASE SPACE TO LAUNCH!"
		elif amount > 0.02:
			message_label.text = "CHARGING... RELEASE SPACE / LEFT CLICK TO BOUNCE!"
		else:
			message_label.text = "WASD / ARROWS: MOVE  •  HOLD SPACE / LEFT CLICK: CHARGE"


func _on_bounce_launched() -> void:
	if message_label:
		message_label.text = "BUTT BOUNCE!  STEER WITH WASD"


func _on_player_fell() -> void:
	if message_label:
		message_label.text = "OOF! BACK TO CHECKPOINT"


func _on_goal_entered(body: Node3D) -> void:
	if body == player and not won:
		won = true
		message_label.text = "ROOFTOP RUSH COMPLETE!  NICE BOUNCING!"
