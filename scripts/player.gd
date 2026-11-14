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
@export var butt_landing_duration: float = 0.82

@onready var visual: Node3D = $Visual
@onready var launch_audio: AudioStreamPlayer = $LaunchAudio
@onready var fail_audio: AudioStreamPlayer = $FailAudio
@onready var source_character: Node3D = $Visual/ParkourCharacter

var _charging := false
var _space_down := false
var _charge_time := 0.0
var _last_direction := Vector3(0, 0, -1)
var _spawn_position := Vector3(0, 1.05, 4.0)
var _checkpoint_position := Vector3(0, 1.05, 4.0)
var _checkpoint_active := false
var _was_below_world := false
var _bounce_in_air := false
var _landing_timer := 0.0
var _animation_time := 0.0

# A lightweight articulated replacement rig is generated because the supplied
# GLB is a single static mesh: it contains no skeleton or animation clips.
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

	# Keep the original model in the project as the source asset, but do not
	# render it because it is unrigged and has the stiff airplane-arm pose.
	source_character.visible = false
	_build_character_rig()


func _physics_process(delta: float) -> void:
	_animation_time += delta

	var input_dir := _read_movement_input()
	if input_dir.length_squared() > 0.001:
		_last_direction = input_dir.normalized()

	var was_on_floor := is_on_floor()
	var charge_held := _space_down

	if was_on_floor:
		velocity.y = minf(velocity.y, 0.0)

		if _landing_timer > 0.0:
			# Briefly finish the butt landing and stand-up recovery before
			# accepting movement or another bounce charge.
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
	if _bounce_in_air and is_on_floor() and vertical_speed_before_slide <= 0.0:
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

	return direction.normalized() if direction.length_squared() > 1.0 else direction


func _launch_bounce(input_direction: Vector3) -> void:
	var ratio := clampf(_charge_time / max_charge_time, 0.0, 1.0)
	var launch_direction := (
		input_direction.normalized()
		if input_direction.length_squared() > 0.001
		else _last_direction
	)

	if launch_direction.length_squared() < 0.001:
		launch_direction = Vector3(0, 0, -1)

	var forward_power := lerpf(min_launch_forward, max_launch_forward, ratio)
	var upward_power := lerpf(min_launch_up, max_launch_up, ratio)

	floor_snap_length = 0.0
	visual.rotation.y = atan2(launch_direction.x, launch_direction.z)
	velocity.x = launch_direction.x * forward_power
	velocity.z = launch_direction.z * forward_power
	velocity.y = upward_power

	_charging = false
	_charge_time = 0.0
	_bounce_in_air = true
	_landing_timer = 0.0
	charge_updated.emit(0.0)

	launch_audio.stop()
	launch_audio.play()
	bounce_launched.emit()


func apply_spring_boost(upward_power: float = 17.0, forward_power: float = 4.0) -> void:
	velocity.y = maxf(velocity.y, upward_power)
	velocity.x += _last_direction.x * forward_power
	velocity.z += _last_direction.z * forward_power
	_charging = false
	_charge_time = 0.0
	_bounce_in_air = true
	_landing_timer = 0.0
	charge_updated.emit(0.0)

	launch_audio.stop()
	launch_audio.play()
	bounce_launched.emit()


func _begin_butt_landing() -> void:
	floor_snap_length = 0.22
	_bounce_in_air = false
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
	global_position = _checkpoint_position if _checkpoint_active else _spawn_position
	velocity = Vector3.ZERO
	_charging = false
	_charge_time = 0.0
	_bounce_in_air = false
	_landing_timer = 0.0
	charge_updated.emit(0.0)

	if play_fail:
		fail_audio.stop()
		fail_audio.play()


# ---------------------------------------------------------------------------
# Procedural character rig
# ---------------------------------------------------------------------------

func _build_character_rig() -> void:
	_rig_root = Node3D.new()
	_rig_root.name = "AnimatedCharacterRig"
	_rig_root.scale = Vector3(0.72, 0.72, 0.72)
	_rig_root.position.y = 0.32
	visual.add_child(_rig_root)

	var skin_material := _make_material(SKIN)
	var shirt_material := _make_material(SHIRT)
	var shirt_light_material := _make_material(SHIRT_LIGHT)
	var pants_material := _make_material(PANTS)
	var pants_light_material := _make_material(PANTS_LIGHT)
	var shoe_material := _make_material(SHOE)
	var sole_material := _make_material(SHOE_SOLE)
	var hair_material := _make_material(HAIR)
	var eye_material := _make_material(EYE)

	# Pelvis and torso.
	var pelvis := _make_sphere(_rig_root, "Pelvis", 0.30, 0.38, pants_material)
	pelvis.position = Vector3(0.0, 0.72, 0.0)
	pelvis.scale = Vector3(1.05, 0.85, 0.92)

	_torso_pivot = Node3D.new()
	_torso_pivot.name = "TorsoPivot"
	_torso_pivot.position = Vector3(0.0, 1.12, 0.0)
	_rig_root.add_child(_torso_pivot)

	var torso := _make_capsule(_torso_pivot, "ShirtBody", 0.32, 0.88, shirt_material)
	torso.position = Vector3(0.0, 0.10, 0.0)
	torso.scale = Vector3(1.0, 1.0, 0.82)

	var shirt_panel := _make_sphere(_torso_pivot, "ShirtFrontPanel", 0.20, 0.46, shirt_light_material)
	shirt_panel.position = Vector3(0.0, 0.12, 0.245)
	shirt_panel.scale = Vector3(0.92, 1.0, 0.20)

	var neck := _make_capsule(_torso_pivot, "Neck", 0.12, 0.24, skin_material)
	neck.position = Vector3(0.0, 0.59, 0.0)

	# Head and a simple readable face looking toward local +Z.
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0.0, 1.76, 0.02)
	_rig_root.add_child(_head_pivot)

	var head := _make_sphere(_head_pivot, "Head", 0.31, 0.68, skin_material)
	head.scale = Vector3(0.94, 1.0, 0.90)

	var hair := _make_sphere(_head_pivot, "Hair", 0.30, 0.32, hair_material)
	hair.position = Vector3(0.0, 0.24, -0.045)
	hair.scale = Vector3(1.02, 0.57, 0.98)

	for side in [-1.0, 1.0]:
		var ear := _make_sphere(_head_pivot, "Ear", 0.095, 0.15, skin_material)
		ear.position = Vector3(side * 0.285, 0.015, 0.0)

		var eye_white := _make_sphere(_head_pivot, "EyeWhite", 0.055, 0.07, _make_material(Color.WHITE))
		eye_white.position = Vector3(side * 0.105, 0.045, 0.263)

		var pupil := _make_sphere(_head_pivot, "Pupil", 0.025, 0.035, eye_material)
		pupil.position = Vector3(side * 0.105, 0.04, 0.315)

	var nose := _make_sphere(_head_pivot, "Nose", 0.045, 0.055, skin_material)
	nose.position = Vector3(0.0, -0.035, 0.30)

	# Arms are two-segment articulated limbs. The default pose hangs down
	# beside the torso instead of sticking straight out like airplane wings.
	_left_shoulder = _make_arm(-1.0, skin_material, shirt_material)
	_right_shoulder = _make_arm(1.0, skin_material, shirt_material)

	# Legs with independent hips and knees for a walk cycle and seated pose.
	_left_hip = _make_leg(-1.0, pants_material, pants_light_material, shoe_material, sole_material)
	_right_hip = _make_leg(1.0, pants_material, pants_light_material, shoe_material, sole_material)

	_update_character_animation(0.0, Vector3.ZERO)


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

	_rig_root.position.y = lerpf(_rig_root.position.y, 0.32 + 0.012 * sin(_animation_time * 2.0), blend)


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
	_rig_root.position.y = lerpf(_rig_root.position.y, 0.32, blend)


func _apply_jump_pose(blend: float) -> void:
	var air_cycle := sin(_animation_time * 7.5)

	# Keep the arms bent and pumping; tuck the knees instead of spreading
	# the arms horizontally like airplane wings.
	_set_rotation(_left_shoulder, Vector3(-0.78 + air_cycle * 0.12, 0.0, -0.10), blend)
	_set_rotation(_right_shoulder, Vector3(-0.78 - air_cycle * 0.12, 0.0, 0.10), blend)
	_set_rotation(_left_elbow, Vector3(-0.85, 0.0, 0.0), blend)
	_set_rotation(_right_elbow, Vector3(-0.85, 0.0, 0.0), blend)

	_set_rotation(_left_hip, Vector3(-0.55 + air_cycle * 0.10, 0.0, 0.0), blend)
	_set_rotation(_right_hip, Vector3(-0.55 - air_cycle * 0.10, 0.0, 0.0), blend)
	_set_rotation(_left_knee, Vector3(0.82, 0.0, 0.0), blend)
	_set_rotation(_right_knee, Vector3(0.82, 0.0, 0.0), blend)

	_set_rotation(_torso_pivot, Vector3(-0.12, 0.0, 0.0), blend)
	_set_rotation(_head_pivot, Vector3(0.04, 0.0, 0.0), blend)
	_rig_root.position.y = lerpf(_rig_root.position.y, 0.34 + 0.025 * sin(_animation_time * 7.5), blend)


func _apply_sit_pose(weight: float, charge_ratio: float, blend: float) -> void:
	var sit := clampf(weight, 0.0, 1.0)

	# Lower the pelvis, bring thighs forward and bend the knees so the
	# character visibly sits on his backside while charging / after landing.
	_set_rotation(_torso_pivot, Vector3(0.18 * sit, 0.0, 0.0), blend)
	_set_rotation(_head_pivot, Vector3(-0.06 * sit, 0.0, 0.0), blend)

	_set_rotation(_left_hip, Vector3(-1.08 * sit, 0.0, 0.0), blend)
	_set_rotation(_right_hip, Vector3(-1.08 * sit, 0.0, 0.0), blend)
	_set_rotation(_left_knee, Vector3(1.30 * sit, 0.0, 0.0), blend)
	_set_rotation(_right_knee, Vector3(1.30 * sit, 0.0, 0.0), blend)

	# Hands move forward for balance, with elbows bent.
	var arm_reach := 0.65 + 0.16 * charge_ratio
	_set_rotation(_left_shoulder, Vector3(-arm_reach * sit, 0.0, -0.08), blend)
	_set_rotation(_right_shoulder, Vector3(-arm_reach * sit, 0.0, 0.08), blend)
	_set_rotation(_left_elbow, Vector3(-0.70 * sit, 0.0, 0.0), blend)
	_set_rotation(_right_elbow, Vector3(-0.70 * sit, 0.0, 0.0), blend)

	_rig_root.position.y = lerpf(_rig_root.position.y, lerpf(0.32, 0.16, sit), blend)


func _set_rotation(node: Node3D, target: Vector3, blend: float) -> void:
	if node == null:
		return

	node.rotation.x = lerp_angle(node.rotation.x, target.x, blend)
	node.rotation.y = lerp_angle(node.rotation.y, target.y, blend)
	node.rotation.z = lerp_angle(node.rotation.z, target.z, blend)


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
