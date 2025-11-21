# test_rope.gd
extends Node3D

@onready var rope = $RopeSimulation
@onready var camera = $Camera3D

var time := 0.0

func _ready() -> void:
	camera.position = Vector3(0, 5, 15)
	camera.look_at(Vector3(0, 0, 0))
	
	# Создаём несколько препятствий для теста коллизий
	create_obstacle(Vector3(-2, -3, 0), Vector3(2, 0.5, 2))
	create_obstacle(Vector3(2, -6, 0), Vector3(2, 0.5, 2))
	create_obstacle(Vector3(0, -9, 0), Vector3(3, 0.5, 2))

func create_obstacle(pos: Vector3, size: Vector3) -> void:
	"""Создаём StaticBody3D с коллизией"""
	var body = StaticBody3D.new()
	body.position = pos
	
	# Визуал
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	mesh_instance.material_override = mat
	
	# Коллизия
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	
	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)

func _process(delta: float) -> void:
	time += delta
	
	# Двигаем верёвку чтобы она задевала препятствия
	rope.global_position.x = sin(time * 1.5) * 4.0
	
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
