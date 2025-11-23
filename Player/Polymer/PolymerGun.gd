extends Node3D

@export var projectile_scene: PackedScene
@export var launch_force: float = 20.0
@export var fire_rate: float = 0.5
@onready var player: CharacterBody3D = get_parent().get_parent()

var can_fire: bool = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("fire_blob") and can_fire:
		shoot()

func shoot() -> void:
	can_fire = false
	
	var proj = projectile_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(proj)
	proj.global_transform = global_transform
	
	# Применяем импульс вперед
	proj.add_collision_exception_with(player)
	proj.apply_central_impulse(-global_transform.basis.z * launch_force)
	
	# Кулдаун
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true
