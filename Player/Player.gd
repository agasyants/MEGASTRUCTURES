extends CharacterBody3D

# --- MOVEMENT SETTINGS ---
var move_acceleration := 10.0        # how fast we accelerate toward input direction
var move_max_speed := 6.0            # top walking speed
var move_friction := 40.0            # how quickly we slow down when no input is given
var air_friction := 9.0              # how quickly we slow down in air
var air_control := 0.9               # how much control we have in the air
var gravity := 24.0
var jump_speed := 10.0
var on_ground := false

var vector := Vector3(0,1,0)
var target_vector := Vector3(0,1,0)
var rotator := 0.0

# --- PLATFORMER FEEL IMPROVEMENTS ---
var coyote_time := 0.15
var coyote_timer := 0.0
var jump_buffer_time := 0.1
var jump_buffer_timer := 0.0

# --- MOUSE LOOK SETTINGS ---
var mouse_sensitivity := 0.12
var camera_pitch := 0.0
var camera_pitch_min := -85.0
var camera_pitch_max := 85.0

# --- JETPACK SETTINGS ---
var jetpack_fuel := 100.0
var jetpack_fuel_max := 100.0
var jetpack_thrust_up := 30.0           # force of thrust
var jetpack_thrust_down := 43.0
var first_fuel_consumption := 0.0
var jetpack_fuel_consumption := 45.0    # fuel units per second
var jetpack_recharge_rate := 20.0       # recharge speed on ground
var jetpack_recharge_delay := 1.5       # delay before recharge starts
var jetpack_recharge_timer := 0.0       # just timer
var jetpack_max_velocity := 20.0        # cap on total velocity when using jetpack
var is_using_jetpack := false
var is_recharging := false

var grabbing := false
var was_grabbing := false

const JUMP_CUT_MULTIPLIER := 0.6
const LEDGE_GRAB_VELOCITY_THRESHOLD := 1.2


@onready var cam := $Camera3D
@onready var fuel_bar := $CanvasLayer/FuelBar
@onready var boots := $Boots
@onready var gu = $GrabUp
@onready var gd = $GrabDown

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# setup fuel bar
	if fuel_bar:
		fuel_bar.max_value = 100.0
		fuel_bar.value = 100.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_object_local(Vector3.UP, deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, camera_pitch_min, camera_pitch_max)
		cam.rotation.x = deg_to_rad(camera_pitch)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		if coyote_timer > 0.0:
			jump()
		else:
			start_jetpack()
		get_viewport().set_input_as_handled()

	elif event.is_action_released("jump"):
		# Cut jump
		if velocity.y > 0 and !is_using_jetpack:
			velocity.y *= JUMP_CUT_MULTIPLIER
		end_jetpack()
		get_viewport().set_input_as_handled()

func jump():
	if boots.boots_enabled:
		velocity = velocity + vector * jump_speed * 1.2
		boots.disable_boots()
	else:
		velocity = velocity + vector * jump_speed
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

func start_jetpack():
	if jetpack_fuel > 0:
		jetpack_fuel -= first_fuel_consumption
		is_recharging = false
		is_using_jetpack = true

func end_jetpack():
	if is_using_jetpack:
		is_using_jetpack = false
		is_recharging = true

func _physics_process(delta: float) -> void:
	_update_ledge_grab(delta)
	_update_rotation(delta)
	_update_timers(delta)
	_apply_jetpack(delta)
	_apply_movement(delta)
	_apply_gravity(delta)
	move_and_slide()

func _process(_delta: float) -> void:
	_update_ui()
	DebugLayer.Log(Engine.get_frames_per_second(), "FPS: ")


func _update_rotation(delta: float):
	# 1. Интерполируем вектор гравитации (как у вас было, но чуть быстрее для отзывчивости)
	vector = vector.lerp(target_vector, delta * 5.0).normalized()
	
	# 2. Вычисляем текущий "верх" персонажа
	var current_up = transform.basis.y
	
	# 3. Если векторы уже почти равны, ничего не делаем (избегаем дрожания)
	if current_up.distance_squared_to(vector) < 0.00001:
		return

	# 4. Находим кватернион, который поворачивает current_up в vector по кратчайшему пути.
	# cross product дает ось вращения
	var axis = current_up.cross(vector)
	
	# Если ось нулевая (векторы параллельны или противоположны), обрабатываем отдельно
	if axis.length_squared() < 0.00001:
		# Если векторы противоположны (переход на потолок с пола одним прыжком),
		# нужно повернуть на 180 вокруг любой перпендикулярной оси (например, Z)
		if current_up.dot(vector) < 0:
			transform.basis = transform.basis.rotated(transform.basis.z, PI)
	else:
		axis = axis.normalized()
		# acos от скалярного произведения дает угол
		var angle = acos(clamp(current_up.dot(vector), -1.0, 1.0))
		var q = Quaternion(axis, angle)
		# 5. Применяем этот поворот к текущему базису
		transform.basis = Basis(q) * transform.basis
		
	# 6. Обязательно ортонормируем, чтобы избежать искажений масштаба со временем
	transform.basis = transform.basis.orthonormalized()

func _update_ledge_grab(_delta: float) -> void:
	if !gu.is_colliding() and gd.is_colliding():
		var angle: float = gd.get_collision_normal().angle_to(vector)
		if 1.4 < angle and angle < 1.7 and !boots.boots_enabled:
			if !was_grabbing and velocity.dot(vector) <= LEDGE_GRAB_VELOCITY_THRESHOLD:
				grabbing = true
			was_grabbing = true
	else:
		if was_grabbing:
			velocity -= vector * 3
			grabbing = false
		was_grabbing = false

func _update_timers(delta: float) -> void:
	# coyote time: grace period after leaving platform
	if is_on_floor() or boots.boots_enabled:
		coyote_timer = coyote_time
		if !on_ground:
			on_ground = true
			landed()
	else:
		coyote_timer -= delta
		if on_ground:
			on_ground = false
	
	# jump buffer: pressed jump slightly before landing
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	if is_recharging:
		jetpack_recharge_timer += delta
		if jetpack_recharge_timer >= jetpack_recharge_delay:
			jetpack_fuel = min(jetpack_fuel + jetpack_recharge_rate * delta, jetpack_fuel_max)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		if boots.boots_enabled:
			velocity -=  vector * gravity * delta * 4
		else:
			velocity -=  vector * gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		
		# if jump was buffered, execute it immediately on landing
		if jump_buffer_timer > 0.0:
			velocity.y = jump_speed
			jump_buffer_timer = 0.0
			coyote_timer = 0.0

func landed():
	if !is_using_jetpack:
		jetpack_recharge_timer = jetpack_recharge_delay

func _apply_jetpack(delta: float) -> void:
	if is_using_jetpack:
		jetpack_recharge_timer = 0.0
		jetpack_fuel -= jetpack_fuel_consumption * delta
		if jetpack_fuel <= 0:
			end_jetpack()
		jetpack_fuel = max(jetpack_fuel, 0.0)
		
		var look_dir = -cam.global_transform.basis.z
		var thrust_dir = look_dir.lerp(vector, 0.8).normalized()
		var dot = velocity.dot(vector)
		var thrust = jetpack_thrust_down - dot
		if dot > 0.0:
			thrust = jetpack_thrust_up - dot
		velocity += thrust_dir * thrust * delta
		
		if velocity.length() > jetpack_max_velocity:
			velocity = velocity.normalized() * jetpack_max_velocity
		
		# TODO: add particle effects and sound here
		# Example: $JetpackParticles.emitting = true
		# Example: if not $JetpackSound.playing: $JetpackSound.play()


func _apply_movement(delta: float) -> void:
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var input_dir := Vector3.ZERO
	
	if input_vec.length() > 0.0:
		var forward := -transform.basis.z
		var right := transform.basis.x
		input_dir = (forward * input_vec.y + right * input_vec.x).normalized()
		boots.rotation.y = input_vec.angle() - PI/2
	
	var accel := move_acceleration
	var friction := move_friction
	
	if not on_ground:
		accel *= air_control
		friction = air_friction
	
	if boots.boots_enabled:
		if input_dir != Vector3.ZERO:
			velocity = lerp(velocity, input_dir * move_max_speed, accel * delta)
		else:
			velocity = lerp(velocity, Vector3.ZERO, friction * delta)
	else:
		if input_dir != Vector3.ZERO:
			velocity.x = move_toward(velocity.x, input_dir.x * move_max_speed, accel * delta)
			velocity.z = move_toward(velocity.z, input_dir.z * move_max_speed, accel * delta)
			if grabbing:
				velocity = 500 * vector * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _update_ui() -> void:
	if fuel_bar:
		fuel_bar.value = (jetpack_fuel / jetpack_fuel_max) * 100.0
