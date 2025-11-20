extends Node3D

@export var rotation_speed: float = 6.0
@export var upright_return_speed: float = 3.0

@onready var f_cast = $ForwardCast
@onready var b_cast = $BackCast
@onready var player: CharacterBody3D = get_parent()

var boots_enabled: bool = false
var is_attached: bool = false
var returning_upright: bool = false

func enable_boots() -> void:
	boots_enabled = true
	f_cast.enabled = true
	b_cast.enabled = true

func disable_boots() -> void:
	boots_enabled = false
	is_attached = false
	player.target_vector = Vector3(0,1,0)
	f_cast.enabled = false
	b_cast.enabled = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("boots"):
		if boots_enabled:
			disable_boots()
		else:
			enable_boots()

func _process(_delta: float) -> void:
	if boots_enabled:
		if b_cast.is_colliding():
			var collision_normal: Vector3 = b_cast.get_collision_normal()
			if player.target_vector != collision_normal:
				start_transition(collision_normal)
		
		if f_cast.is_colliding():
			var collision_normal: Vector3 = f_cast.get_collision_normal()
			if player.target_vector != collision_normal:
				start_transition(collision_normal)
		

func start_transition(normal: Vector3):
	player.target_vector = normal
