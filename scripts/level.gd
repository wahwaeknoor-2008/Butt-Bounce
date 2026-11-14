extends Node3D

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var world: Node3D
var player: ButtBouncePlayer
var camera: Camera3D
var charge_bar: ProgressBar
var message_label: Label
var distance_label: Label
var won := false

func _ready() -> void:
	world = WORLD_SCENE.instantiate()
	add_child(world)
	player = PLAYER_SCENE.instantiate() as ButtBouncePlayer
	add_child(player)
	var start_marker: Marker3D = world.get_node("Markers/PlayerStart")
	player.global_position = start_marker.global_position + Vector3(0.0, 0.95, 0.0)
	player.player_fell.connect(_on_player_fell)
	player.charge_updated.connect(_on_charge_updated)
	_create_camera()
	_create_hud()
	var goal: Area3D = world.get_node("Markers/GoalZone")
	goal.body_entered.connect(_on_goal_entered)

func _process(delta: float) -> void:
	if player == null or camera == null:
		return
	var target := player.global_position + Vector3(0.0, 4.2, 10.0)
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.0 * delta))
	camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	var travelled := int(maxf(0.0, -player.global_position.z))
	distance_label.text = "ROOFTOP RUN   •   %dm" % travelled

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.fov = 72.0
	camera.position = player.global_position + Vector3(0.0, 4.2, 10.0)
	add_child(camera)
	camera.current = true
	camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.custom_minimum_size = Vector2(330, 110)
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
	charge_bar.custom_minimum_size = Vector2(290, 18)
	charge_bar.show_percentage = false
	column.add_child(charge_bar)
	message_label = Label.new()
	message_label.text = "WASD / ARROWS: MOVE    •    HOLD SPACE: CHARGE"
	column.add_child(message_label)

func _on_charge_updated(amount: float) -> void:
	if charge_bar:
		charge_bar.value = amount
	if message_label:
		message_label.text = "RELEASE SPACE TO BOUNCE!" if amount >= 0.98 else "CHARGING BOUNCE..." if amount > 0.02 else "WASD / ARROWS: MOVE  •  HOLD SPACE: CHARGE"

func _on_player_fell() -> void:
	if message_label:
		message_label.text = "OOF! BACK TO CHECKPOINT"

func _on_goal_entered(body: Node3D) -> void:
	if body == player and not won:
		won = true
		message_label.text = "ROOFTOP RUSH COMPLETE!  NICE BOUNCING!"
