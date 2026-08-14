class_name Pearl
extends RigidBody2D

const RADIUS := 20.0


func _ready() -> void:
	add_to_group("pearls")
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("#f4e8d2"))
	draw_circle(Vector2.ZERO, RADIUS - 3.0, Color("#ddd5f4"))
	draw_circle(Vector2(-6, -7), 5.0, Color(1, 1, 1, 0.72))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color("#fffaf0"), 2.0, true)
