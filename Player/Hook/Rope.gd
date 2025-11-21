extends Node3D
class_name RopeSimulation

# --- Настройки ---
@export_group("Simulation")
@export var rope_length := 10.0
@export var segment_count := 40
@export var gravity := 30.0
@export var damping := 0.95
@export var stiffness := 1.0
@export var constraint_iterations := 4
@export var sub_steps := 3 # Делим физический кадр на части для стабильности

@export_group("Collision")
@export var collision_friction := 0.8 # Повысил для теста
@export var rope_radius := 0.05
@export var check_corners := true 

@export_group("Visuals")
@export var rope_color := Color(0.0, 0.969, 0.444, 1.0)

var segment_length: float
var points: Array[Vector3] = []
var old_points: Array[Vector3] = []

# Оптимизация: переиспользуем параметры запроса
var shape_query: PhysicsShapeQueryParameters3D
var sphere_shape: SphereShape3D
var visual_container: Node3D
var segment_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	segment_length = rope_length / float(segment_count)
	_init_physics_queries()
	
	var start_pos = global_position
	for i in segment_count + 1:
		var pos = start_pos + Vector3.DOWN * (i * segment_length)
		points.append(pos)
		old_points.append(pos)
	
	setup_visual()

func _init_physics_queries() -> void:
	sphere_shape = SphereShape3D.new()
	sphere_shape.radius = rope_radius # Радиус сферы равен толщине веревки
	
	shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere_shape
	shape_query.collision_mask = 1 

func setup_visual() -> void:
	if visual_container:
		visual_container.queue_free()
		segment_meshes.clear()
		
	visual_container = Node3D.new()
	visual_container.top_level = true
	add_child(visual_container)
	
	for i in range(segment_count):
		var segment = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = rope_radius
		cylinder.bottom_radius = rope_radius
		cylinder.height = segment_length
		cylinder.radial_segments = 8
		segment.mesh = cylinder
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = rope_color
		mat.metallic = 0.2
		mat.roughness = 0.6
		segment.material_override = mat
		
		visual_container.add_child(segment)
		segment_meshes.append(segment)

func _physics_process(delta: float) -> void:
	# SUB-STEPPING
	var sub_delta = delta / float(sub_steps)
	
	for step in sub_steps:
		points[0] = global_position
		simulate_rope(sub_delta)
	
	update_visual()

func simulate_rope(dt: float) -> void:
	var space_state = get_world_3d().direct_space_state
	
	# 1. Verlet Integration (с гравитацией)
	for i in range(1, points.size()):
		var velocity = (points[i] - old_points[i])
		old_points[i] = points[i]
		points[i] += velocity * damping + (Vector3.DOWN * gravity * dt * dt)

	# 2. Constraints & Collisions (Чередуем для стабильности)
	for _iter in constraint_iterations:
		points[0] = global_position # Pin start
		
		# Distance Constraints
		_solve_distance_constraints()
		
		# Collisions
		_solve_collisions(space_state)
		
		if check_corners:
			_solve_segment_collisions(space_state)

func _solve_distance_constraints() -> void:
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		var delta_pos = p2 - p1
		var dist = delta_pos.length()
		
		if dist < 0.00001: continue
		
		# Если растянулось или сжалось, возвращаем к segment_length
		var error = dist - segment_length
		var correction = delta_pos.normalized() * error * stiffness
		
		if i == 0:
			# Первая точка закреплена, двигаем только вторую
			points[i + 1] -= correction
		else:
			# Двигаем обе навстречу друг другу
			points[i] += correction * 0.5
			points[i + 1] -= correction * 0.5

func _solve_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	for i in range(1, points.size()):
		# Обновляем позицию запроса
		shape_query.transform = Transform3D(Basis(), points[i])
		
		# ИСПОЛЬЗУЕМ get_rest_info ВМЕСТО intersect_shape
		# Это возвращает информацию о том, как вытолкнуть объект, если он пересекается
		var result = space_state.get_rest_info(shape_query)
		
		if result:
			var normal = result["normal"]
			var contact_point = result["point"]
			var dist_to_surface = (points[i] - contact_point).dot(normal)
			
			# Если мы внутри, dist_to_surface будет отрицательным или меньше радиуса
			var penetration = rope_radius - dist_to_surface
			
			# Добавляем маленький epsilon, чтобы не "дрожало"
			if penetration > 0:
				points[i] += normal * (penetration + 0.001)
				
				# ПРИМЕНЯЕМ ТРЕНИЕ СРАЗУ ПРИ КОЛЛИЗИИ
				_apply_friction(i, normal)

func _solve_segment_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	# Упрощенная логика для сегментов (чтобы не есть много CPU)
	for i in range(points.size() - 1):
		var mid_point = (points[i] + points[i+1]) * 0.5
		shape_query.transform.origin = mid_point
		
		var result = space_state.get_rest_info(shape_query)
		if result:
			var normal = result["normal"]
			var penetration = rope_radius - (mid_point - result["point"]).dot(normal)
			
			if penetration > 0:
				var push = normal * (penetration + 0.001) * 0.5 # Половина силы для мягкости
				if i > 0: points[i] += push
				points[i+1] += push

func _apply_friction(i: int, normal: Vector3) -> void:
	var vel = points[i] - old_points[i]
	
	# Раскладываем скорость на нормальную (в стену) и тангенциальную (вдоль стены)
	var vn = vel.project(normal)
	var vt = vel - vn
	
	# Гасим тангенциальную скорость (трение)
	# Если collision_friction = 1.0, vt полностью обнуляется (прилипает)
	vt *= (1.0 - collision_friction)
	
	# Гасим нормальную скорость (отскок/поглощение удара)
	# Обычно мы не хотим, чтобы веревка пружинила от пола, поэтому гасим сильно
	vn *= 0.2 
	
	# Реконструируем old_points
	old_points[i] = points[i] - (vn + vt)

# --- Визуал и Basis (как у вас) ---
func update_visual() -> void:
	for i in range(segment_meshes.size()):
		var mesh = segment_meshes[i]
		var p1 = points[i]
		var p2 = points[i+1]
		mesh.global_position = (p1 + p2) * 0.5
		var up = p2 - p1
		if up.length_squared() < 0.00001:
			mesh.visible = false
			continue
		mesh.visible = true
		mesh.global_transform.basis = _basis_from_y_vector(up.normalized())

func _basis_from_y_vector(y: Vector3) -> Basis:
	if !y.is_finite(): return Basis()
	var x = y.cross(Vector3.UP)
	if x.length_squared() < 0.01: x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z = x.cross(y).normalized()
	return Basis(x, y, z)
