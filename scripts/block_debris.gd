extends RigidBody2D

const LIFETIME_SECONDS := 1.0
const DEBRIS_COLLISION_LAYER := 2

var _particle_size := 6.0
var _age := 0.0
var _texture: Texture2D


func configure(texture: Texture2D, material_density: float, particle_size: float) -> void:
	_texture = texture
	_particle_size = particle_size
	mass = maxf(0.03, material_density * 0.025)
	collision_layer = DEBRIS_COLLISION_LAYER
	collision_mask = DEBRIS_COLLISION_LAYER
	gravity_scale = 1.0
	linear_damp = 0.4
	angular_damp = 0.25
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * _particle_size
	collision.shape = shape
	add_child(collision)
	queue_redraw()


func _ready() -> void:
	add_to_group("block_debris")
	reset_physics_interpolation()


func _process(delta: float) -> void:
	_age += delta
	modulate.a = 1.0 - clampf(_age / LIFETIME_SECONDS, 0.0, 1.0)
	if _age >= LIFETIME_SECONDS:
		queue_free()


func _draw() -> void:
	if _texture == null:
		return
	var rect := Rect2(Vector2.ONE * _particle_size * -0.5, Vector2.ONE * _particle_size)
	draw_texture_rect(_texture, rect, false)
