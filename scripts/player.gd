class_name ButtBouncePlayer
extends CharacterBody3D

signal charge_updated(amount: float)
signal bounce_launched
signal player_fell

@export var gravity: float = 25.0
@export var max_charge_time: float = 1.45
@export var min_launch_up: float = 13.0
@export var max_launch_up: float = 22.0
@export var min_launch_forward: float = 9.0
@export var max_launch_forward: float = 17.0
@export var walk_speed: float = 4.8
@export var ground_acceleration: float = 48.0
@export var ground_braking: float = 70.0
@export var air_steering: float = 13.0
@export var air_braking: float = 10.0
@export var butt_landing_duration: float = 0.38

@onready var visual: Node3D = $Visual
@onready var fart_audio: AudioStreamPlayer = $FartAudio
@onready var fail_audio: AudioStreamPlayer = $FailAudio
@onready var source_character: Node3D = $Visual/ParkourCharacter

var _charging := false
var _space_down := false
var _left_mouse_down := false
var _charge_time := 0.0
var _last_direction := Vector3(0, 0, -1)
var _camera_yaw := PI
var _spawn_position := Vector3(0, 1.05, 4.0)
var _checkpoint_position := Vector3(0, 1.05, 4.0)
var _checkpoint_active := false
var _was_below_world := false
var _bounce_in_air := false
var _has_left_floor_since_bounce := false
var _landing_timer := 0.0
var _animation_time := 0.0

# The uploaded character is a grouped mesh. Runtime pivots animate its
# existing separate arm and leg pieces without replacing the supplied model.
var _rig_root: Node3D
var _torso_pivot: Node3D
var _head_pivot: Node3D
var _left_shoulder: Node3D
var _right_shoulder: Node3D
var _left_elbow: Node3D
var _right_elbow: Node3D
var _left_hip: Node3D
var _right_hip: Node3D
var _left_knee: Node3D
var _right_knee: Node3D

const SKIN := Color(0.78, 0.48, 0.32)
const SHIRT := Color(0.96, 0.34, 0.19)
const SHIRT_LIGHT := Color(1.0, 0.53, 0.31)
const PANTS := Color(0.10, 0.18, 0.30)
const PANTS_LIGHT := Color(0.17, 0.28, 0.43)
const SHOE := Color(0.91, 0.91, 0.82)
const SHOE_SOLE := Color(0.10, 0.11, 0.13)
const HAIR := Color(0.15, 0.10, 0.08)
const EYE := Color(0.035, 0.025, 0.02)

func _ready() -> void:
	global_position = _spawn_position
	visual.rotation.y = atan2(_last_direction.x, _last_direction.z)
	_build_character_rig()


func _physics_process(delta: float) -> void:
	_animation_time += delta

	var input_dir := _read_movement_input()
	if input_dir.length_squared() > 0.001:
		_last_direction = input_dir.normalized()

	var was_on_floor := is_on_floor()
	var charge_held := _space_down or _left_mouse_down

	if was_on_floor:
		if not _bounce_in_air:
			velocity.y = minf(velocity.y, 0.0)

		if _landing_timer > 0.0:
			# Finish the seated landing and stand-up recovery before taking input.
			velocity.x = move_toward(velocity.x, 0.0, ground_braking * delta)
			velocity.z = move_toward(velocity.z, 0.0, ground_braking * delta)
			_charging = false
			_charge_time = 0.0
			charge_updated.emit(0.0)

		elif charge_held:
			_charging = true
			_charge_time = minf(_charge_time + delta, max_charge_time)
			charge_updated.emit(_charge_time / max_charge_time)

			# Space makes the character sit on the ground while the bounce
			# charges. Releasing Space launches according to charge duration.
			velocity.x = move_toward(velocity.x, 0.0, ground_braking * delta)
			velocity.z = move_toward(velocity.z, 0.0, ground_braking * delta)

		elif _charging:
			_launch_bounce(input_dir)

		else:
			if input_dir.length_squared() > 0.001:
				var target := input_dir * walk_speed
				velocity.x = move_toward(velocity.x, target.x, ground_acceleration * delta)
				velocity.z = move_toward(velocity.z, target.z, ground_acceleration * delta)
				visual.rotation.y = lerp_angle(
					visual.rotation.y,
					atan2(input_dir.x, input_dir.z),
					12.0 * delta
				)
			else:
				velocity.x = move_toward(velocity.x, 0.0, ground_braking * delta)
				velocity.z = move_toward(velocity.z, 0.0, ground_braking * delta)

			charge_updated.emit(0.0)

	else:
		_charging = false
		_charge_time = 0.0
		charge_updated.emit(0.0)
		velocity.y -= gravity * delta

		if input_dir.length_squared() > 0.001:
			var air_target := input_dir * (min_launch_forward + 4.0)
			velocity.x = move_toward(velocity.x, air_target.x, air_steering * delta)
			velocity.z = move_toward(velocity.z, air_target.z, air_steering * delta)
			visual.rotation.y = lerp_angle(
				visual.rotation.y,
				atan2(input_dir.x, input_dir.z),
				7.0 * delta
			)
		else:
			velocity.x = move_toward(velocity.x, 0.0, air_braking * delta)
			velocity.z = move_toward(velocity.z, 0.0, air_braking * delta)

	var vertical_speed_before_slide := velocity.y
	move_and_slide()

	# Detect the first frame the bouncing player touches the floor while
	# descending. Start the seated landing, then blend back to standing.
	if _bounce_in_air and not is_on_floor():
		_has_left_floor_since_bounce = true
	if _bounce_in_air and _has_left_floor_since_bounce and is_on_floor() and vertical_speed_before_slide <= 0.0:
		_begin_butt_landing()

	_update_character_animation(delta, input_dir)

	if global_position.y < -35.0 and not _was_below_world:
		_was_below_world = true
		player_fell.emit()
		_respawn(true)
	elif global_position.y >= -35.0:
		_was_below_world = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			_space_down = event.pressed
		if event.pressed and not event.echo and event.keycode == KEY_R:
			_respawn(false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Only begin charging when the cursor is captured for gameplay.
		# Always clear on release, even if the cursor mode changed meanwhile.
		if event.pressed:
			_left_mouse_down = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		else:
			_left_mouse_down = false


func set_camera_yaw(yaw: float) -> void:
	_camera_yaw = yaw


func _read_movement_input() -> Vector3:
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction.rotated(Vector3.UP, _camera_yaw - PI)


func _launch_bounce(input_direction: Vector3) -> void:
	var ratio := clampf(_charge_time / max_charge_time, 0.0, 1.0)
	var launch_direction := (
		input_direction.normalized()
		if input_direction.length_squared() > 0.001
		else _last_direction
	)

	if launch_direction.length_squared() < 0.001:
		launch_direction = Vector3(0.0, 0.0, -1.0)

	var forward_power := lerpf(min_launch_forward, max_launch_forward, ratio)
	var upward_power := lerpf(min_launch_up, max_launch_up, ratio)

	floor_snap_length = 0.0
	visual.rotation.y = atan2(launch_direction.x, launch_direction.z)
	_last_direction = launch_direction
	velocity.x = launch_direction.x * forward_power
	velocity.z = launch_direction.z * forward_power
	velocity.y = upward_power

	_charging = false
	_charge_time = 0.0
	_bounce_in_air = true
	_has_left_floor_since_bounce = false
	_landing_timer = 0.0
	charge_updated.emit(0.0)
	bounce_launched.emit()


func apply_spring_boost(upward_power: float = 17.0, forward_power: float = 4.0) -> void:
	floor_snap_length = 0.0
	velocity.y = maxf(velocity.y, upward_power)
	velocity.x += _last_direction.x * forward_power
	velocity.z += _last_direction.z * forward_power
	_charging = false
	_charge_time = 0.0
	_bounce_in_air = true
	_has_left_floor_since_bounce = false
	_landing_timer = 0.0
	charge_updated.emit(0.0)

	bounce_launched.emit()


func _begin_butt_landing() -> void:
	# Play the FartAudio stream at the first physics frame of ground contact,
	# skipping its silent MP3 lead-in so the sound lines up with the impact.
	# The MP3 begins with about 0.7 seconds of silence; skip that lead-in so
	# the fart is heard immediately on the first physics frame of butt impact.
	fart_audio.stop()
	fart_audio.play(0.74)
	floor_snap_length = 0.22
	_bounce_in_air = false
	_has_left_floor_since_bounce = false
	_charging = false
	_charge_time = 0.0
	_landing_timer = butt_landing_duration
	velocity.y = 0.0
	charge_updated.emit(0.0)


func take_hazard_hit() -> void:
	# Called by rooftop hazard Area3D nodes.
	_respawn(true)


func set_checkpoint(position: Vector3) -> void:
	_checkpoint_position = position + Vector3.UP * 1.0
	_checkpoint_active = true


func _respawn(play_fail: bool) -> void:
	floor_snap_length = 0.22
	_space_down = false
	_left_mouse_down = false
	global_position = _checkpoint_position if _checkpoint_active else _spawn_position
	velocity = Vector3.ZERO
	_charging = false
	_charge_time = 0.0
	_bounce_in_air = false
	_has_left_floor_since_bounce = false
	_landing_timer = 0.0
	charge_updated.emit(0.0)

	if play_fail:
		fail_audio.stop()
		fail_audio.play()


# ---------------------------------------------------------------------------
# Procedural character rig
# ---------------------------------------------------------------------------

func _build_character_rig() -> void:
	# Instance the character scene exactly as supplied by the user.
	# Only apply a root transform so it fits the existing player controller.
	_rig_root = source_character
	_rig_root.visible = true
	_rig_root.position = Vector3(0.0, 0.94, 0.0)
	_rig_root.rotation = Vector3.ZERO
	_rig_root.scale = Vector3.ONE * 0.82

	# The uploaded scene is a grouped mesh rather than a skeleton. Create
	# small pivots around its existing separate hand and leg meshes so they
	# can swing without replacing or reshaping the supplied model.
	_torso_pivot = null
	_head_pivot = null
	_left_elbow = null
	_right_elbow = null
	_left_knee = null
	_right_knee = null

	_left_shoulder = _make_part_pivot(
		"AnimatedLeftArm",
		Vector3(-0.6687, -0.3224, 0.0669),
		["hand2", "FINGER", "FINGER2", "FINGER3", "FINGER4"]
	)
	_right_shoulder = _make_part_pivot(
		"AnimatedRightArm",
		Vector3(0.5419, -0.3142, 0.0178),
		["hand1", "FINGER5", "FINGER6", "FINGER7", "FINGER8"]
	)

	# The two leg cylinders were authored as a parent/child pair. Detach the
	# child first so each leg and its shoe can swing independently.
	_left_hip = _make_part_pivot(
		"AnimatedLeftLeg",
		Vector3(-0.2523, -0.7928, 0.0233),
		["leg1/leg1", "MeshInstance3D2"]
	)
	_right_hip = _make_part_pivot(
		"AnimatedRightLeg",
		Vector3(0.1474, -0.8018, 0.0023),
		["leg1", "MeshInstance3D"]
	)

	_apply_uploaded_character_colors()
	_update_character_animation(0.0, Vector3.ZERO)


func _make_part_pivot(pivot_name: String, local_position: Vector3, part_paths: Array[String]) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = local_position
	source_character.add_child(pivot)

	for part_path in part_paths:
		var part := source_character.get_node_or_null(NodePath(part_path))
		if part != null:
			part.reparent(pivot, true)

	return pivot


func _apply_uploaded_character_colors() -> void:
	# The exact supplied model is retained; only per-part material colors change.
	for mesh_value in source_character.find_children("*", "MeshInstance3D", true, false):
		var part := mesh_value as MeshInstance3D
		if part == null:
			continue

		var part_name := String(part.name).to_lower()
		var color := Color(0.65, 0.65, 0.68)

		match part_name:
			"body":
				color = Color(0.12, 0.78, 0.25) # Green body
			"butt", "butt2":
				color = Color(0.95, 0.12, 0.16) # Red butt cheeks
			"leg1":
				color = Color(0.12, 0.30, 0.95) # Blue legs
			"meshinstance3d", "meshinstance3d2":
				color = Color(0.025, 0.025, 0.035) # Black shoes
			"hand1", "hand2", "finger", "finger2", "finger3", "finger4", "finger5", "finger6", "finger7", "finger8":
				color = Color(1.0, 0.78, 0.06) # Yellow hands
			"eye1", "eye2":
				color = Color(0.008, 0.008, 0.012) # Black eyes
			"mouth":
				color = Color(1.0, 0.78, 0.06) # Yellow lips
			_:
				continue

		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.68
		part.material_override = material


func _make_arm(side: float, skin_material: StandardMaterial3D, sleeve_material: StandardMaterial3D) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = "LeftShoulder" if side < 0.0 else "RightShoulder"
	shoulder.position = Vector3(side * 0.37, 1.34, 0.0)
	_rig_root.add_child(shoulder)

	var upper_arm := _make_capsule(shoulder, "UpperArm", 0.115, 0.58, sleeve_material)
	upper_arm.position = Vector3(0.0, -0.265, 0.0)

	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0, -0.53, 0.0)
	shoulder.add_child(elbow)

	var forearm := _make_capsule(elbow, "Forearm", 0.092, 0.49, skin_material)
	forearm.position = Vector3(0.0, -0.225, 0.0)

	var hand := _make_sphere(elbow, "Hand", 0.105, 0.16, skin_material)
	hand.position = Vector3(0.0, -0.47, 0.015)
	hand.scale = Vector3(0.95, 0.75, 1.0)

	if side < 0.0:
		_left_elbow = elbow
	else:
		_right_elbow = elbow

	return shoulder


func _make_leg(
	side: float,
	pants_material: StandardMaterial3D,
	pants_light_material: StandardMaterial3D,
	shoe_material: StandardMaterial3D,
	sole_material: StandardMaterial3D
) -> Node3D:
	var hip := Node3D.new()
	hip.name = "LeftHip" if side < 0.0 else "RightHip"
	hip.position = Vector3(side * 0.16, 0.73, 0.0)
	_rig_root.add_child(hip)

	var thigh := _make_capsule(hip, "Thigh", 0.145, 0.62, pants_material)
	thigh.position = Vector3(0.0, -0.29, 0.0)

	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = Vector3(0.0, -0.57, 0.0)
	hip.add_child(knee)

	var shin := _make_capsule(knee, "Shin", 0.115, 0.54, pants_light_material)
	shin.position = Vector3(0.0, -0.25, 0.0)

	var shoe := _make_box(knee, "Shoe", Vector3(0.29, 0.15, 0.43), shoe_material)
	shoe.position = Vector3(0.0, -0.52, 0.105)

	var sole := _make_box(knee, "ShoeSole", Vector3(0.30, 0.055, 0.44), sole_material)
	sole.position = Vector3(0.0, -0.59, 0.11)

	if side < 0.0:
		_left_knee = knee
	else:
		_right_knee = knee

	return hip


func _make_material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	return result


func _make_capsule(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	material: Material
) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _make_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	material: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 12

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _make_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


# ---------------------------------------------------------------------------
# Pose blending
# ---------------------------------------------------------------------------

func _update_character_animation(delta: float, input_dir: Vector3) -> void:
	if _rig_root == null:
		return

	var blend := 1.0 - exp(-14.0 * maxf(delta, 0.0))

	if _landing_timer > 0.0:
		_landing_timer = maxf(_landing_timer - delta, 0.0)
		var landing_ratio := clampf(_landing_timer / butt_landing_duration, 0.0, 1.0)
		var sit_weight := _smoothstep(landing_ratio)
		_apply_sit_pose(sit_weight, 0.0, blend)
		return

	if _charging and is_on_floor():
		var charge_ratio := clampf(_charge_time / max_charge_time, 0.0, 1.0)
		_apply_sit_pose(0.72 + 0.28 * charge_ratio, charge_ratio, blend)
		return

	if not is_on_floor():
		_apply_jump_pose(blend)
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.35 and input_dir.length_squared() > 0.001:
		_apply_walk_pose(horizontal_speed, blend)
	else:
		_apply_idle_pose(blend)


func _apply_idle_pose(blend: float) -> void:
	_set_rotation(_torso_pivot, Vector3(0.0, 0.0, 0.0), blend)
	_set_rotation(_head_pivot, Vector3(0.0, 0.0, 0.0), blend)

	# Relaxed hands rest beside the hips.
	_set_rotation(_left_shoulder, Vector3(0.0, 0.0, -0.055), blend)
	_set_rotation(_right_shoulder, Vector3(0.0, 0.0, 0.055), blend)
	_set_rotation(_left_elbow, Vector3(0.08, 0.0, 0.0), blend)
	_set_rotation(_right_elbow, Vector3(0.08, 0.0, 0.0), blend)

	_set_rotation(_left_hip, Vector3.ZERO, blend)
	_set_rotation(_right_hip, Vector3.ZERO, blend)
	_set_rotation(_left_knee, Vector3.ZERO, blend)
	_set_rotation(_right_knee, Vector3.ZERO, blend)

	# Stand upright when idle.
	_rig_root.rotation.x = lerp_angle(_rig_root.rotation.x, 0.0, blend)
	_rig_root.position.y = lerpf(_rig_root.position.y, 0.94 + 0.012 * sin(_animation_time * 2.0), blend)


func _apply_walk_pose(speed: float, blend: float) -> void:
	var gait_speed := lerpf(8.0, 12.0, clampf(speed / walk_speed, 0.0, 1.0))
	var stride := sin(_animation_time * gait_speed)
	var opposite_stride := -stride

	# Alternating legs and counter-swinging arms create a natural run cycle.
	_set_rotation(_left_hip, Vector3(stride * 0.58, 0.0, 0.0), blend)
	_set_rotation(_right_hip, Vector3(opposite_stride * 0.58, 0.0, 0.0), blend)
	_set_rotation(_left_knee, Vector3(maxf(0.0, -stride) * 0.78, 0.0, 0.0), blend)
	_set_rotation(_right_knee, Vector3(maxf(0.0, stride) * 0.78, 0.0, 0.0), blend)

	_set_rotation(_left_shoulder, Vector3(-stride * 0.72, 0.0, -0.06), blend)
	_set_rotation(_right_shoulder, Vector3(stride * 0.72, 0.0, 0.06), blend)
	_set_rotation(_left_elbow, Vector3(-0.58, 0.0, 0.0), blend)
	_set_rotation(_right_elbow, Vector3(-0.58, 0.0, 0.0), blend)

	_set_rotation(_torso_pivot, Vector3(-0.10, 0.0, 0.0), blend)
	_set_rotation(_head_pivot, Vector3(0.04, 0.0, 0.0), blend)
	_rig_root.rotation.x = lerp_angle(_rig_root.rotation.x, 0.0, blend)
	_rig_root.position.y = lerpf(_rig_root.position.y, 0.94, blend)


func _apply_jump_pose(blend: float) -> void:
	var air_cycle := sin(_animation_time * 6.8)

	# Stay seated throughout the bounce: thighs project forward, shins fold
	# forward from the knees, and the chest leans back so the backside leads.
	_set_rotation(_torso_pivot, Vector3(-0.52, 0.0, 0.0), blend)
	_set_rotation(_head_pivot, Vector3(0.16, 0.0, 0.0), blend)

	_set_rotation(_left_hip, Vector3(-1.34 + air_cycle * 0.07, 0.0, 0.0), blend)
	_set_rotation(_right_hip, Vector3(-1.34 - air_cycle * 0.07, 0.0, 0.0), blend)
	_set_rotation(_left_knee, Vector3(0.62 + maxf(0.0, air_cycle) * 0.12, 0.0, 0.0), blend)
	_set_rotation(_right_knee, Vector3(0.62 + maxf(0.0, -air_cycle) * 0.12, 0.0, 0.0), blend)

	# Arms reach forward for balance rather than spreading sideways.
	_set_rotation(_left_shoulder, Vector3(-0.92 + air_cycle * 0.08, 0.0, -0.08), blend)
	_set_rotation(_right_shoulder, Vector3(-0.92 - air_cycle * 0.08, 0.0, 0.08), blend)
	_set_rotation(_left_elbow, Vector3(-0.52, 0.0, 0.0), blend)
	_set_rotation(_right_elbow, Vector3(-0.52, 0.0, 0.0), blend)

	# Rotate the entire rig backward into a seated airborne posture. The
	# hidden physics capsule stays upright, but the visible body is butt-first.
	_rig_root.rotation.x = lerp_angle(_rig_root.rotation.x, -1.10, blend)
	_rig_root.position.y = lerpf(_rig_root.position.y, 0.40 + 0.018 * sin(_animation_time * 6.8), blend)

func _apply_sit_pose(weight: float, charge_ratio: float, blend: float) -> void:
	var sit := clampf(weight, 0.0, 1.0)

	# Lower the pelvis, bring thighs forward and bend the knees so the
	# character visibly sits on his backside while charging / after landing.
	_set_rotation(_torso_pivot, Vector3(-0.16 * sit, 0.0, 0.0), blend)
	_set_rotation(_head_pivot, Vector3(0.08 * sit, 0.0, 0.0), blend)

	_set_rotation(_left_hip, Vector3(-1.34 * sit, 0.0, 0.0), blend)
	_set_rotation(_right_hip, Vector3(-1.34 * sit, 0.0, 0.0), blend)
	_set_rotation(_left_knee, Vector3(0.62 * sit, 0.0, 0.0), blend)
	_set_rotation(_right_knee, Vector3(0.62 * sit, 0.0, 0.0), blend)

	# Hands move forward for balance, with elbows bent.
	var arm_reach := 0.65 + 0.16 * charge_ratio
	_set_rotation(_left_shoulder, Vector3(-arm_reach * sit, 0.0, -0.08), blend)
	_set_rotation(_right_shoulder, Vector3(-arm_reach * sit, 0.0, 0.08), blend)
	_set_rotation(_left_elbow, Vector3(-0.70 * sit, 0.0, 0.0), blend)
	_set_rotation(_right_elbow, Vector3(-0.70 * sit, 0.0, 0.0), blend)

	# Tilt the whole character backward so the backside is the lowest point
	# during charge and impact, then rise smoothly as the sit weight fades.
	_rig_root.rotation.x = lerp_angle(_rig_root.rotation.x, -1.10 * sit, blend)
	_rig_root.position.y = lerpf(_rig_root.position.y, lerpf(0.94, 0.35, sit), blend)


func _set_rotation(node: Node3D, target: Vector3, blend: float) -> void:
	if node == null:
		return

	node.rotation.x = lerp_angle(node.rotation.x, target.x, blend)
	node.rotation.y = lerp_angle(node.rotation.y, target.y, blend)
	node.rotation.z = lerp_angle(node.rotation.z, target.z, blend)


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
