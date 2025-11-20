extends Node3D
class_name TetherHook

# --- SETTINGS ---
@export var max_range := 20.0                    # maximum grapple distance
@export var pull_force := 30.0                   # force of pull toward target
@export var cooldown_time := 3.0                 # cooldown between uses
@export var hook_speed := 80.0                   # visual speed of hook traveling

# --- STATE ---
enum State { IDLE, FIRING, PULLING, COOLDOWN }
var current_state := State.IDLE
var cooldown_timer := 0.0
var pull_timer := 0.0
var hook_point := Vector3.ZERO                   # world position of grapple point
var hook_normal := Vector3.ZERO                  # surface normal at hook point

# --- REFERENCES ---
var player: CharacterBody3D
var camera: Camera3D
@onready var raycast := $RayCast3D
@onready var rope_visual := $RopeVisual         # MeshInstance3D for the rope
@onready var hook_visual := $HookVisual         # MeshInstance3D for the hook projectile
@onready var fire_sound := $FireSound           # AudioStreamPlayer3D
@onready var impact_sound := $ImpactSound
@onready var pull_sound := $PullSound

@onready var checker := get_parent().get_node("./CanvasLayer/ColorRect")

# --- SIGNALS ---
signal hook_fired
signal hook_connected(point: Vector3)
signal hook_released
signal cooldown_started
signal cooldown_finished

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("grapple"):
		try_fire()
	if event.is_action_released("grapple"):
		release()

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	assert(player != null, "TetherHook must be child of CharacterBody3D")
	
	# Setup raycast
	raycast.target_position = Vector3(0, 0, -max_range)
	raycast.enabled = false
	raycast.collision_mask = 1  # any solid surface
	
	# Hide visuals initially
	if rope_visual:
		rope_visual.visible = false
	if hook_visual:
		hook_visual.visible = false
	
	# Get camera reference
	camera = player.get_node_or_null("Camera3D")
	assert(camera != null, "Camera3D not found as child of player")


func _process(delta: float) -> void:
	_update_state(delta)
	_update_visuals()


func _update_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			pass
			
		State.FIRING:
			# Visual hook traveling animation could go here
			# For now, we instant-connect
			pass
			
		State.PULLING:
			pull_timer += delta
			_apply_pull_force(delta)
			
		State.COOLDOWN:
			cooldown_timer += delta
			if cooldown_timer >= cooldown_time:
				current_state = State.IDLE
				cooldown_timer = 0.0
				cooldown_finished.emit()


func _apply_pull_force(delta: float) -> void:
	if not player:
		return
	
	# Calculate direction to hook point
	var to_hook := hook_point - player.global_position
	var distance := to_hook.length()
	
	# Auto-release if too far (max_range * 1.5 for buffer)
	if distance > max_range * 1.5:
		release()
		return
	
	var pull_dir := to_hook.normalized()
	
	# Preserve momentum parallel to pull direction
	#var parallel_vel := player.velocity.project(pull_dir)
	
	# Apply force to player velocity
	# Use easing for smoother feel
	player.velocity += pull_dir * pull_force * delta
	
	# Keep 50% of parallel momentum (allows swinging)
	#player.velocity += parallel_vel * 0.5
	
	# Optional: dampen velocity perpendicular to pull direction
	# This makes the pull feel more "locked on"
	#var perpendicular_vel := player.velocity - player.velocity.project(pull_dir)
	#player.velocity -= perpendicular_vel * 0.3 * delta


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func try_fire() -> bool:
	if current_state != State.IDLE:
		return false
	
	if not camera:
		return false
	
	# Raycast from camera center
	var space_state := get_world_3d().direct_space_state
	var origin := camera.global_position
	var end := origin + (-camera.global_transform.basis.z * max_range)
	
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1  # any solid surface
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result := space_state.intersect_ray(query)
	
	if result.is_empty():
		# No valid hook point
		return false
	
	# Valid hook point found
	hook_point = result.position
	hook_normal = result.normal
	
	current_state = State.FIRING
	hook_fired.emit()
	
	if fire_sound:
		fire_sound.play()
	
	# Transition immediately to pulling (or add delay for animation)
	_start_pulling()
	
	return true


func _start_pulling() -> void:
	current_state = State.PULLING
	pull_timer = 0.0
	hook_connected.emit(hook_point)
	
	if impact_sound:
		impact_sound.play()
	if pull_sound:
		pull_sound.play()


func release() -> void:
	if current_state == State.PULLING or current_state == State.FIRING:
		current_state = State.COOLDOWN
		cooldown_timer = 0.0
		hook_released.emit()
		cooldown_started.emit()
		
		if pull_sound and pull_sound.playing:
			pull_sound.stop()


func _update_visuals() -> void:
	if current_state == State.IDLE:
		var space_state := get_world_3d().direct_space_state
		var origin := camera.global_position
		var end := origin + (-camera.global_transform.basis.z * max_range)
		
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.collision_mask = 1  # any solid surface
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result := space_state.intersect_ray(query)
		
		if result.is_empty():
			checker.color = Color(1.0, 1.0, 1.0, 0.392)
		else:
			checker.color = Color(0.945, 0.0, 0.271, 0.494)
	
	elif current_state == State.PULLING or current_state == State.FIRING:
		checker.color = Color(0.207, 0.609, 0.0, 0.494)
		if rope_visual:
			rope_visual.visible = true
			_update_rope_mesh()
		if hook_visual:
			hook_visual.visible = true
			hook_visual.global_position = hook_point
	else:
		checker.color = Color(0.194, 0.471, 1.0, 0.494)
		if rope_visual:
			rope_visual.visible = false
		if hook_visual:
			hook_visual.visible = false


func _update_rope_mesh() -> void:
	# Simple rope visualization using ImmediateMesh
	if not rope_visual:
		return
	
	var mesh := rope_visual.mesh as ImmediateMesh
	if not mesh:
		return
	
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var start := player.global_position + Vector3(0, 1.5, 0)  # offset from player chest
	var segments := 8
	
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var point := start.lerp(hook_point, t)
		
		# Add slight sag with parabola
		var sag := sin(t * PI) * 0.5
		point.y -= sag
		
		mesh.surface_add_vertex(point)
		if i > 0:
			mesh.surface_add_vertex(point)
	
	mesh.surface_end()
