extends Node3D

@export var speed: float = 1.3
@export var length: float = 4.0
var _time := 0.0
var _pivot: Node3D

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "SwingPivot"
	add_child(_pivot)
	var chain := MeshInstance3D.new()
	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.06
	chain_mesh.bottom_radius = 0.06
	chain_mesh.height = length
	chain.mesh = chain_mesh
	chain.position.y = -length * 0.5
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.18, 0.2, 0.25)
	chain_mat.metallic = 0.8
	chain.material_override = chain_mat
	_pivot.add_child(chain)
	var ball := RigidBody3D.new()
	ball.name = "WreckingBall"
	ball.position.y = -length
	var sphere := SphereMesh.new()
	sphere.radius = 0.85
	sphere.height = 1.7
	var ball_mesh := MeshInstance3D.new()
	ball_mesh.mesh = sphere
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.9, 0.28, 0.18)
	ball_mat.metallic = 0.65
	ball_mat.roughness = 0.25
	ball_mesh.material_override = ball_mat
	ball.add_child(ball_mesh)
	var hit_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.85
	hit_shape.shape = sphere_shape
	ball.add_child(hit_shape)
	_pivot.add_child(ball)

func _process(delta: float) -> void:
	_time += delta
	if _pivot:
		_pivot.rotation.z = sin(_time * speed) * 0.52
