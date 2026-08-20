class_name Pearl
extends RigidBody2D

const RADIUS := 20.0
const TEXTURE := preload("res://Asset/Pearl.png")
const TEXTURE_REGION := Rect2(49.0, 49.0, 254.0, 254.0)


func _ready() -> void:
	add_to_group("pearls")
	queue_redraw()


func _draw() -> void:
	var diameter := RADIUS * 2.0
	var destination := Rect2(Vector2.ONE * -RADIUS, Vector2.ONE * diameter)
	draw_texture_rect_region(TEXTURE, destination, TEXTURE_REGION)
