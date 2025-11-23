class_name Blob
extends StaticBody3D

@export var lifetime: float = 20.0
@export var shake_intensity: float = 0.1
@onready var visual = $CSGBox3D

var original_position: Vector3
var timer: float = 0.0

var noise := FastNoiseLite.new()

func _ready() -> void:
	timer = lifetime
	# Initial scale-in animation
	scale = Vector3(0.01, 0.01, 0.01)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE)

	# Noise settings for smooth jitter
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0

func setup(pos: Vector3, normal: Vector3) -> void:
	global_position = pos
	align_up_with_normal(normal)

func _process(delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		if timer <= 0.0:
			_on_timeout()
			return

		if timer <= 5.0:
			var t := 1.0 - (timer / 5.0)
			var amplitude := t * shake_intensity
			var freq = lerp(1.0, 12.0, t)
			var time := float(Time.get_ticks_msec()) * 0.001
			var x_off := noise.get_noise_2d(time * freq, 0.0) * amplitude
			var z_off := noise.get_noise_2d(0.0, time * freq) * amplitude
			visual.global_position = global_position + Vector3(x_off, 0.0, z_off)

# Destroy animation
func _on_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 1.0).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_callback(queue_free)

func align_up_with_normal(normal: Vector3) -> void:
	if normal.is_equal_approx(Vector3.UP):
		rotation = Vector3.ZERO
		return

	if normal.is_equal_approx(Vector3.DOWN):
		rotation_degrees = Vector3(180, 0, 0)
		return

	var target_basis = Basis()
	target_basis.y = normal
	target_basis.x = normal.cross(Vector3.UP).normalized() if abs(normal.dot(Vector3.UP)) < 0.99 else normal.cross(Vector3.RIGHT).normalized()
	target_basis.z = target_basis.x.cross(normal).normalized()

	transform.basis = target_basis
