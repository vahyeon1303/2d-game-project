extends RigidBody2D

const BLOCK_SIZE := 44.8
const VISUAL_SCALE := 4.0
const COLLISION_LAYER := 2
const MIN_LIFETIME_SECONDS := 0.5
const MAX_LIFETIME_SECONDS := 3.0
const EXPLOSION_TEXTURE := preload("res://Asset/VFX/Generated/explosion_sheet.png")
const SEQUENCE_PLAYER_SCRIPT := preload("res://scripts/vfx_sequence_player.gd")

var _lifetime_seconds := 1.0
var _age_seconds := 0.0


func _ready() -> void:
	_lifetime_seconds = randf_range(MIN_LIFETIME_SECONDS, MAX_LIFETIME_SECONDS)
	_ignore_other_explosion_effects()
	add_to_group("explosion_vfx_particles")
	collision_layer = COLLISION_LAYER
	collision_mask = COLLISION_LAYER
	mass = 0.18
	gravity_scale = 1.0
	linear_damp = 0.45
	angular_damp = 0.3
	lock_rotation = true

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * BLOCK_SIZE
	collision.shape = shape
	add_child(collision)

	var animation := SEQUENCE_PLAYER_SCRIPT.new()
	animation.z_index = 12
	add_child(animation)
	animation.configure(
		EXPLOSION_TEXTURE,
		Vector2i(64, 64),
		16,
		145,
		30.0,
		Vector2.ONE * BLOCK_SIZE * VISUAL_SCALE
	)
	reset_physics_interpolation()


func _process(delta: float) -> void:
	_age_seconds += delta
	modulate.a = 1.0 - clampf(_age_seconds / _lifetime_seconds, 0.0, 1.0)
	if _age_seconds >= _lifetime_seconds:
		queue_free()


func _ignore_other_explosion_effects() -> void:
	for other in get_tree().get_nodes_in_group("explosion_vfx_particles"):
		if not other is PhysicsBody2D or not is_instance_valid(other):
			continue
		add_collision_exception_with(other)
		other.add_collision_exception_with(self)
