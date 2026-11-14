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
		mesh.material_override = mat
		add_child(mesh)

func _physics_process(delta: float) -> void:
	_time += delta
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

func trigger_crumble() -> void:
	if kind == 2 and _crumble_timer < 0.0:
		_crumble_timer = 0.0
