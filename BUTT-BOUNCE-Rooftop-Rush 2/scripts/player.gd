class_name ButtBouncePlayer
extends CharacterBody3D

signal charge_updated(amount: float)
signal bounce_launched
signal player_fell

@export var gravity: float = 25.0
@export var max_charge_time: float = 1.45
@export var min_launch_up: float = 10.0
@export var max_launch_up: float = 17.0
@export var min_launch_forward: float = 9.0
@export var max_launch_forward: float = 17.0
@export var walk_speed: float = 6.2
@export var ground_acceleration: float = 34.0
@export var ground_braking: float = 48.0
@export var air_steering: float = 18.0
@export var air_braking: float = 7.0

@onready var visual: Node3D = $Visual
@onready var launch_audio: AudioStreamPlayer = $LaunchAudio
@onready var fail_audio: AudioStreamPlayer = $FailAudio

var _charging := false
var _charge_time := 0.0
var _last_direction := Vector3(0, 0, -1)
var _spawn_position := Vector3(0, 1.05, 4.0)
var _checkpoint_position := Vector3(0, 1.05, 4.0)
var _checkpoint_active := false
var _base_visual_scale := Vector3.ONE
var _was_below_world := false

func _ready() -> void:
	global_position = _spawn_position

func _physics_process(delta: float) -> void:
	var input_dir := _read_movement_input()
	if input_dir.length_squared() > 0.001:
		_last_direction = input_dir.normalized()

	var on_floor := is_on_floor()
	var charge_held := Input.is_key_pressed(KEY_SPACE)

	if on_floor:
		velocity.y = minf(velocity.y, 0.0)
		if charge_held:
			_charging = true
			_charge_time = minf(_charge_time + delta, max_charge_time)
			charge_updated.emit(_charge_time / max_charge_time)
			# Charging anchors the character: no unwanted ground drift.
			velocity.x = move_toward(velocity.x, 0.0, ground_braking * delta)
			velocity.z = move_toward(velocity.z, 0.0, ground_braking * delta)
			_update_squash(_charge_time / max_charge_time)
		elif _charging:
			_launch_bounce(input_dir)
		else:
			if input_dir.length_squared() > 0.001:
				var target := input_dir * walk_speed
				velocity.x = move_toward(velocity.x, target.x, ground_acceleration * delta)
				velocity.z = move_toward(velocity.z, target.z, ground_acceleration * delta)
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(input_dir.x, input_dir.z), 12.0 * delta)
			else:
				# Strong braking stops the old skating/sliding feeling.
				velocity.x = move_toward(velocity.x, 0.0, ground_braking * delta)
				velocity.z = move_toward(velocity.z, 0.0, ground_braking * delta)
			charge_updated.emit(0.0)
			_update_squash(0.0)
	else:
		_charging = false
		_charge_time = 0.0
		charge_updated.emit(0.0)
		velocity.y -= gravity * delta
		if input_dir.length_squared() > 0.001:
			var air_target := input_dir * (min_launch_forward + 4.0)
			velocity.x = move_toward(velocity.x, air_target.x, air_steering * delta)
			velocity.z = move_toward(velocity.z, air_target.z, air_steering * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, air_braking * delta)
			velocity.z = move_toward(velocity.z, 0.0, air_braking * delta)
		_update_squash(0.0)

	move_and_slide()

	if global_position.y < -35.0 and not _was_below_world:
		_was_below_world = true
		player_fell.emit()
		_respawn(true)
	elif global_position.y >= -35.0:
		_was_below_world = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
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
	var launch_direction := input_direction.normalized() if input_direction.length_squared() > 0.001 else _last_direction
	if launch_direction.length_squared() < 0.001:
		launch_direction = Vector3(0, 0, -1)
	var forward_power := lerpf(min_launch_forward, max_launch_forward, ratio)
	var upward_power := lerpf(min_launch_up, max_launch_up, ratio)
	visual.rotation.y = atan2(launch_direction.x, launch_direction.z)
	velocity.x = launch_direction.x * forward_power
	velocity.z = launch_direction.z * forward_power
	velocity.y = upward_power
	_reset_charge()
	launch_audio.stop()
	launch_audio.play()
	bounce_launched.emit()

func apply_spring_boost(upward_power: float = 17.0, forward_power: float = 4.0) -> void:
	velocity.y = maxf(velocity.y, upward_power)
	velocity.x += _last_direction.x * forward_power
	velocity.z += _last_direction.z * forward_power
	_reset_charge()
	launch_audio.stop()
	launch_audio.play()
	bounce_launched.emit()

func set_checkpoint(position: Vector3) -> void:
	_checkpoint_position = position + Vector3.UP * 1.0
	_checkpoint_active = true

func _respawn(play_fail: bool) -> void:
	global_position = _checkpoint_position if _checkpoint_active else _spawn_position
	velocity = Vector3.ZERO
	_reset_charge()
	if play_fail:
		fail_audio.stop()
		fail_audio.play()

func _reset_charge() -> void:
	_charging = false
	_charge_time = 0.0
	charge_updated.emit(0.0)
	_update_squash(0.0)

func _update_squash(amount: float) -> void:
	var squash := clampf(amount, 0.0, 1.0)
	visual.scale = Vector3(1.0 + 0.06 * squash, 1.0 - 0.16 * squash, 1.0 + 0.06 * squash)
	visual.position.y = -0.04 * squash
