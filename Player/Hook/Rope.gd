extends Node3D

# Параметры сегментов
@export var segment_length := 1.0
@export var segment_radius := 0.05
@export var segment_mass := 1.0

var segment1: RigidBody3D
var segment2: RigidBody3D
var joint: PinJoint3D

func _ready():
	create_simple_rope()

func create_simple_rope():
	# === ПЕРВЫЙ СЕГМЕНТ ===
	segment1 = RigidBody3D.new()
	segment1.name = "Segment1"
	segment1.mass = segment_mass
	#segment1.can_sleep = false
	#segment1.gravity_scale = 1.0
	segment1.contact_monitor = true
	segment1.max_contacts_reported = 4
	segment1.linear_damp = 0.1  # Небольшое затухание
	segment1.angular_damp = 0.1
	add_child(segment1)
	
	# Визуал первого сегмента (капсула)
	var mesh1 = MeshInstance3D.new()
	var capsule_mesh1 = CapsuleMesh.new()
	capsule_mesh1.radius = segment_radius
	capsule_mesh1.height = segment_length
	mesh1.mesh = capsule_mesh1
	
	# Добавим цветной материал
	var material1 = StandardMaterial3D.new()
	material1.albedo_color = Color(1.0, 0.3, 0.3)  # Красноватый
	mesh1.material_override = material1
	
	segment1.add_child(mesh1)
	
	# Коллизия первого сегмента
	var collision1 = CollisionShape3D.new()
	var capsule_shape1 = CapsuleShape3D.new()
	capsule_shape1.radius = segment_radius
	capsule_shape1.height = segment_length
	collision1.shape = capsule_shape1
	segment1.add_child(collision1)
	
	# Позиция первого сегмента (повыше, чтобы было видно)
	segment1.position = Vector3(0, 5, 0)
	
	
	# === ВТОРОЙ СЕГМЕНТ ===
	segment2 = RigidBody3D.new()
	segment2.name = "Segment2"
	segment2.mass = segment_mass
	#segment2.can_sleep = false
	#segment2.gravity_scale = 1.0
	segment2.contact_monitor = true
	segment2.max_contacts_reported = 4
	segment2.linear_damp = 0.1  # Небольшое затухание
	segment2.angular_damp = 0.1
	add_child(segment2)
	
	# Визуал второго сегмента
	var mesh2 = MeshInstance3D.new()
	var capsule_mesh2 = CapsuleMesh.new()
	capsule_mesh2.radius = segment_radius
	capsule_mesh2.height = segment_length
	mesh2.mesh = capsule_mesh2
	
	# Добавим цветной материал
	var material2 = StandardMaterial3D.new()
	material2.albedo_color = Color(0.3, 0.3, 1.0)  # Синеватый
	mesh2.material_override = material2
	
	segment2.add_child(mesh2)
	
	# Коллизия второго сегмента
	var collision2 = CollisionShape3D.new()
	var capsule_shape2 = CapsuleShape3D.new()
	capsule_shape2.radius = segment_radius
	capsule_shape2.height = segment_length
	collision2.shape = capsule_shape2
	segment2.add_child(collision2)
	
	# Позиция второго сегмента (ниже первого)
	segment2.position = Vector3(0, 5 - segment_length, 0)
	
	
	# === ШАРНИР (СОЕДИНЕНИЕ) ===
	# Ждём один кадр, чтобы физика инициализировалась
	await get_tree().process_frame
	
	joint = PinJoint3D.new()
	joint.name = "Joint"
	add_child(joint)
	
	# Соединяем два сегмента
	joint.node_a = segment1.get_path()
	joint.node_b = segment2.get_path()
	
	# Точка соединения - между двумя сегментами
	joint.position = Vector3(0, 5 - segment_length / 2, 0)
	
	print("Верёвка создана! Два сегмента соединены шарниром.")
	print("Segment1 позиция: ", segment1.position)
	print("Segment2 позиция: ", segment2.position)
	print("Joint позиция: ", joint.position)
	
	# Диагностика
	print("--- ДИАГНОСТИКА ---")
	print("Гравитация в мире: ", PhysicsServer3D.area_get_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY))
	print("Segment1 gravity_scale: ", segment1.gravity_scale)
	print("Segment2 gravity_scale: ", segment2.gravity_scale)

func _process(delta):
	# Для отладки - выводим позиции каждый кадр
	if segment1 and segment2:
		if Engine.get_frames_drawn() % 60 == 0:  # Каждую секунду
			print("Seg1 Y: %.2f, Seg2 Y: %.2f" % [segment1.global_position.y, segment2.global_position.y])
