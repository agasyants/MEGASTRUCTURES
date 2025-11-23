extends Node3D
class_name RopeSimulationUltimate

# --- Настройки Симуляции ---
@export_group("Simulation")
@export var rope_length := 10.0
@export var segment_count := 30
@export var gravity := 35.0
@export var damping := 0.95
@export var sub_steps := 5 # Увеличил для стабильности коллизий

@export_group("Elasticity")
@export_range(0.01, 1.0) var stiffness := 0.5 # 0.1 = резина, 1.0 = стальной трос
@export var max_stretch := 1.5 # Макс растяжение (1.3 = 30%)

@export_group("Attachments")
@export var attach_start_to: Node3D
@export var attach_end_to: Node3D
@export var pull_force_factor := 50.0 # Сила, с которой веревка тянет объекты

@export_group("Collision")
@export var collision_mask := 1 # Слои, с которыми сталкивается веревка
@export var collision_friction := 0.5
@export var rope_radius := 0.05
@export var check_corners := true

@export_group("Visuals")
@export var rope_color := Color(0.0, 0.969, 0.444, 1.0)

# Внутренние переменные
var segment_length: float
var points: Array[Vector3] = []
var old_points: Array[Vector3] = []

# Для привязок
var start_local_offset := Vector3.ZERO
var end_local_offset := Vector3.ZERO

# Физика и Визуал
var shape_query: PhysicsShapeQueryParameters3D
var sphere_shape: SphereShape3D
var visual_container: Node3D
var segment_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	segment_length = rope_length / float(segment_count)
	_init_physics_queries()
	
	# Инициализация точек
	var start_pos = global_position
	if attach_start_to:
		start_pos = attach_start_to.global_position
		start_local_offset = attach_start_to.to_local(start_pos)
	
	if attach_end_to:
		var end_pos = attach_end_to.global_position
		end_local_offset = attach_end_to.to_local(end_pos)
		var dir = start_pos.direction_to(end_pos)
		var dist = start_pos.distance_to(end_pos)
		# Растягиваем точки равномерно между началом и концом
		for i in segment_count + 1:
			var p = start_pos + dir * (i * (dist / float(segment_count)))
			points.append(p)
			old_points.append(p)
	else:
		for i in segment_count + 1:
			var p = start_pos + Vector3.DOWN * (i * segment_length)
			points.append(p)
			old_points.append(p)
	
	setup_visual()

func _init_physics_queries() -> void:
	sphere_shape = SphereShape3D.new()
	sphere_shape.radius = rope_radius
	
	shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere_shape
	shape_query.collision_mask = collision_mask

func _physics_process(delta: float) -> void:
	var sub_delta = delta / float(sub_steps)
	var space_state = get_world_3d().direct_space_state
	
	for step in sub_steps:
		_update_attachments()     # 1. Двигаем концы за объектами
		_simulate_rope(sub_delta) # 2. Гравитация и инерция
		_solve_constraints(sub_delta) # 3. Эластичность + Влияние на тела
		_solve_collisions(space_state) # 4. Коллизии с миром
		
		if check_corners:
			_solve_segment_collisions(space_state)
	
	update_visual()

# 1. Обновляем позиции привязанных точек
func _update_attachments() -> void:
	if attach_start_to:
		var target = attach_start_to.to_global(start_local_offset)
		points[0] = target
		old_points[0] = target # Убираем инерцию у крепления
		
	if attach_end_to:
		var target = attach_end_to.to_global(end_local_offset)
		var idx = points.size() - 1
		points[idx] = target
		old_points[idx] = target

# 2. Основная физика (Verlet)
func _simulate_rope(dt: float) -> void:
	for i in range(points.size()):
		# Пропускаем закрепленные точки
		if i == 0 and attach_start_to: continue
		if i == points.size() - 1 and attach_end_to: continue
		
		var velocity = (points[i] - old_points[i])
		old_points[i] = points[i]
		points[i] += velocity * damping + (Vector3.DOWN * gravity * dt * dt)

# 3. Эластичность и влияние на объекты
func _solve_constraints(dt: float) -> void:
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		var delta_pos = p2 - p1
		var dist = delta_pos.length()
		
		if dist < 0.00001: continue
		
		# --- Эластичность ---
		var error = dist - segment_length
		var correction_factor = stiffness # Мягкость
		
		# Hard Limit (если растянули слишком сильно — ведем себя как жесткая веревка)
		if dist > segment_length * max_stretch:
			error = dist - (segment_length * max_stretch)
			correction_factor = 1.0
		
		var correction = delta_pos.normalized() * error * correction_factor
		
		# --- Применение ---
		var p1_anchored = (i == 0 and attach_start_to != null)
		var p2_anchored = (i + 1 == points.size() - 1 and attach_end_to != null)
		
		if p1_anchored and !p2_anchored:
			points[i + 1] -= correction
			_apply_force(attach_start_to, correction, dt) # Тянем старт
			
		elif !p1_anchored and p2_anchored:
			points[i] += correction
			_apply_force(attach_end_to, -correction, dt) # Тянем конец
			
		elif !p1_anchored and !p2_anchored:
			points[i] += correction * 0.5
			points[i + 1] -= correction * 0.5
		
		# Если оба закреплены — ничего не делаем (веревка просто натягивается визуально)

# --- ЛОГИКА ВЛИЯНИЯ НА ТЕЛА ---
func _apply_force(body: Node3D, pull_vec: Vector3, dt: float) -> void:
	# pull_vec — вектор смещения, который веревка ХОТЕЛА бы совершить.
	# Он направлен В СТОРОНУ веревки.
	
	if body is RigidBody3D:
		# Для RigidBody используем импульс
		var impulse = pull_vec * pull_force_factor
		body.apply_central_impulse(impulse * dt)
		
	elif body is CharacterBody3D:
		# Для CharacterBody меняем velocity напрямую
		# Нам нужно добавить скорость в сторону веревки
		# pull_vec * pull_force_factor дает примерную "силу"
		
		# Важно: CharacterBody сам управляет своей velocity.
		# Мы добавляем к ней, но в его скрипте он может её сбросить.
		body.velocity += pull_vec * (pull_force_factor * 2.0) * dt 
		# Умножил на 2.0, т.к. CharacterBody обычно тяжелее сдвинуть программно

# 4. Коллизии (возвращено из старого скрипта)
func _solve_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	for i in range(points.size()):
		# Не проверяем коллизии для закрепленных точек (они внутри объектов)
		if i == 0 and attach_start_to: continue
		if i == points.size() - 1 and attach_end_to: continue

		var start_pos = old_points[i]
		var end_pos = points[i]
		var motion = end_pos - start_pos
		
		if motion.length_squared() < 0.000001: continue

		var ray_query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		ray_query.collision_mask = collision_mask
		
		var ray_result = space_state.intersect_ray(ray_query)
		if ray_result:
			points[i] = ray_result["position"] + ray_result["normal"] * (rope_radius + 0.001)
			_apply_friction(i, ray_result["normal"])
		else:
			# Если рэйкаст чист, проверим, не вошли ли мы внутрь геометрии сферой
			shape_query.transform.origin = points[i]
			var rest = space_state.get_rest_info(shape_query)
			if rest:
				var normal = rest["normal"]
				var penetration = rope_radius - (points[i] - rest["point"]).dot(normal)
				if penetration > 0:
					points[i] += normal * (penetration + 0.001)
					_apply_friction(i, normal)

func _solve_segment_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	# Проверка середины сегментов (чтобы не проваливаться углами)
	for i in range(points.size() - 1):
		var mid = (points[i] + points[i+1]) * 0.5
		shape_query.transform.origin = mid
		var result = space_state.get_rest_info(shape_query)
		if result:
			var normal = result["normal"]
			var push = normal * 0.02 # Небольшой пуш
			if i > 0: points[i] += push
			points[i+1] += push

func _apply_friction(i: int, normal: Vector3) -> void:
	var vel = points[i] - old_points[i]
	var vn = vel.project(normal)
	var vt = vel - vn
	vt *= (1.0 - collision_friction)
	vn *= 0.0 # Нет отскока, полное поглощение
	old_points[i] = points[i] - (vn + vt)

# --- Визуал ---
func setup_visual() -> void:
	if visual_container: visual_container.queue_free()
	visual_container = Node3D.new()
	visual_container.top_level = true
	add_child(visual_container)
	segment_meshes.clear()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = rope_color
	mat.roughness = 0.8
	
	for i in range(segment_count):
		var m = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = rope_radius
		cyl.bottom_radius = rope_radius
		cyl.height = 1.0
		cyl.radial_segments = 6
		m.mesh = cyl
		m.material_override = mat
		visual_container.add_child(m)
		segment_meshes.append(m)

func update_visual() -> void:
	for i in range(segment_meshes.size()):
		var m = segment_meshes[i]
		var p1 = points[i]
		var p2 = points[i+1]
		var center = (p1 + p2) * 0.5
		var diff = p2 - p1
		var length = diff.length()
		
		if length > 0.001:
			m.visible = true
			m.global_position = center
			# Правильный поворот цилиндра (он по Y, look_at по -Z)
			m.look_at(p2, Vector3.UP if abs(diff.normalized().y) < 0.99 else Vector3.RIGHT)
			m.rotate_object_local(Vector3.RIGHT, -PI/2)
			m.scale = Vector3(1, length, 1)
		else:
			m.visible = false
