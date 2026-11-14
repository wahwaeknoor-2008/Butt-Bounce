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
	chain.name = "SteelChain"
	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.055
	chain_mesh.bottom_radius = 0.055
	chain_mesh.height = length
	chain_mesh.radial_segments = 12
	chain.mesh = chain_mesh
	chain.position.y = -length * 0.5
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.12, 0.15, 0.19)
	chain_mat.metallic = 0.85
	chain_mat.roughness = 0.34
	chain.material_override = chain_mat
	_pivot.add_child(chain)

	# An Area3D makes the swinging ball a real gameplay hazard without
	# physically pinning the player against nearby rooftop geometry.
	var ball := Area3D.new()
	ball.name = "WreckingBall"
	ball.position.y = -length
	ball.collision_layer = 0
	ball.collision_mask = 1
	ball.monitoring = true
	ball.body_entered.connect(_on_body_entered)
	_pivot.add_child(ball)

	var sphere := SphereMesh.new()
	sphere.radius = 0.86
	sphere.height = 1.72
	sphere.radial_segments = 32
	sphere.rings = 20
	var ball_mesh := MeshInstance3D.new()
	ball_mesh.name = "SteelBall"
	ball_mesh.mesh = sphere
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.24, 0.29, 0.34)
	ball_mat.metallic = 0.82
	ball_mat.roughness = 0.23
	ball_mesh.material_override = ball_mat
	ball.add_child(ball_mesh)

	var band := MeshInstance3D.new()
	band.name = "SafetyBand"
	var band_mesh := TorusMesh.new()
	band_mesh.inner_radius = 0.78
	band_mesh.outer_radius = 0.88
	band.mesh = band_mesh
	band.rotation.x = PI * 0.5
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(1.0, 0.52, 0.12)
	band_mat.metallic = 0.45
	band_mat.roughness = 0.38
	band.material_override = band_mat
	ball.add_child(band)

	var hit_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.95
	hit_shape.shape = sphere_shape
	ball.add_child(hit_shape)


func _process(delta: float) -> void:
	_time += delta
	if _pivot:
		_pivot.rotation.z = sin(_time * speed) * 0.52


func _on_body_entered(body: Node3D) -> void:
	if body is ButtBouncePlayer:
		body.take_hazard_hit()
