extends AnimatableBody3D

@export_enum("Static", "Moving", "Crumble", "Spring") var kind: int = 0
@export var size: Vector3 = Vector3(4, 1, 4)
@export var move_range: float = 3.0
@export var move_speed: float = 1.0
@export var rock_color: Color = Color(0.3, 0.3, 0.36)
@export var top_color: Color = Color(0.55, 0.55, 0.62)

var _origin: Vector3
var _time := 0.0
var _crumble_timer := -1.0
var _home_visible := true
var _spring_cooldown := 0.0


func _ready() -> void:
	_origin = position
	if get_child_count() == 0:
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		add_child(collision)

		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = top_color
		mat.roughness = 0.72
		mat.metallic = 0.12
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mesh)

	if kind == 2 or kind == 3:
		var trigger := Area3D.new()
		trigger.name = "PlayerTrigger"
		trigger.position.y = size.y * 0.5 + 0.26
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		trigger.monitoring = true
		var trigger_shape := CollisionShape3D.new()
		var trigger_box := BoxShape3D.new()
		trigger_box.size = Vector3(size.x * 0.92, 0.62, size.z * 0.92)
		trigger_shape.shape = trigger_box
		trigger.add_child(trigger_shape)
		trigger.body_entered.connect(_on_player_entered)
		add_child(trigger)


func _physics_process(delta: float) -> void:
	_time += delta
	_spring_cooldown = maxf(_spring_cooldown - delta, 0.0)

	if kind == 1:
		position = _origin + Vector3(sin(_time * move_speed) * move_range, 0.0, 0.0)
	elif kind == 2 and _crumble_timer >= 0.0:
		_crumble_timer += delta
		if _crumble_timer > 0.65:
			visible = false
			_home_visible = false
			collision_layer = 0
			collision_mask = 0
		if _crumble_timer > 3.5:
			visible = true
			_home_visible = true
			collision_layer = 1
			collision_mask = 1
			_crumble_timer = -1.0
	elif kind == 3:
		rotation.z = sin(_time * 2.0) * 0.06


func _on_player_entered(body: Node3D) -> void:
	if not body is ButtBouncePlayer:
		return
	if kind == 2:
		trigger_crumble()
	elif kind == 3 and _spring_cooldown <= 0.0:
		if body.velocity.y <= 1.0:
			body.apply_spring_boost(20.0, 5.5)
			_spring_cooldown = 0.9


func trigger_crumble() -> void:
	if kind == 2 and _crumble_timer < 0.0:
		_crumble_timer = 0.0
