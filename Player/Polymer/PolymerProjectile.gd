extends RigidBody3D

@export var blob_scene: PackedScene

var has_hit: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 1

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if has_hit: return
	
	if state.get_contact_count() > 0:
		var normal = state.get_contact_local_normal(0)
		var pos = state.get_contact_local_position(0)
		var collider = state.get_contact_collider_object(0)
		
		# Проверяем, что мы не ударились об уже существующий полимер (если нужно)
		# или проверяем слои коллизии
		
		spawn_blob(pos, normal, collider)
		has_hit = true

func spawn_blob(pos: Vector3, normal: Vector3, hit_body: Object) -> void:
	call_deferred("_deferred_spawn", pos, normal, hit_body)

func _deferred_spawn(pos: Vector3, normal: Vector3, parent_body: Node3D) -> void:
	var blob = blob_scene.instantiate() as Blob
	
	if parent_body:
		parent_body.add_child(blob)
		blob.position = parent_body.to_local(pos + normal * 0.3)
	else:
		get_tree().current_scene.add_child(blob)
		blob.global_position = pos + normal * 0.3
	queue_free()
