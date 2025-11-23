extends Node3D
class_name Boots

@onready var f_cast = $ForwardCast
@onready var b_cast = $BackCast
@onready var player: CharacterBody3D = get_parent()
@onready var boots_ui = get_node("../CanvasLayer/Boots")

var boots_enabled: bool = false
var attached: bool = false
var attach_timer: float = 0.0

func enable_boots() -> void:
	boots_enabled = true
	f_cast.enabled = true
	b_cast.enabled = true
	boots_ui.color = Color(0.0, 1.0, 0.0, 0.58)

func disable_boots() -> void:
	boots_enabled = false
	player.target_vector = Vector3(0,1,0)
	f_cast.enabled = false
	b_cast.enabled = false
	boots_ui.color = Color(0.824, 0.827, 0.827, 0.302)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("boots"):
		if boots_enabled:
			disable_boots()
		else:
			enable_boots()

func _process(delta: float) -> void:
	if boots_enabled:
		attached = false
		if b_cast.is_colliding():
			var collision_normal: Vector3 = b_cast.get_collision_normal()
			if player.target_vector != collision_normal:
				start_transition(collision_normal)
			attached = true
		
		if f_cast.is_colliding():
			var collision_normal: Vector3 = f_cast.get_collision_normal()
			if player.target_vector != collision_normal:
				start_transition(collision_normal)
			attached = true
		
		if not attached:
			attach_timer += delta
			if attach_timer >= 0.5:
				disable_boots()
		else:
			attach_timer = 0.0

func start_transition(normal: Vector3):
	player.target_vector = normal
