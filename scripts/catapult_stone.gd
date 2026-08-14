class_name CatapultStone
extends RigidBody2D

const RADIUS := 12.0
const LIFETIME_SECONDS := 12.0


func _ready() -> void:
	add_to_group("catapult_stones")
	queue_redraw()
	get_tree().create_timer(LIFETIME_SECONDS).timeout.connect(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("#656b73"))
	draw_circle(Vector2(-3, -4), 3.0, Color("#858b93"))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("#a4a9af"), 2.0, true)
