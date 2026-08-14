class_name BlockDragPreview
extends Control

const PREVIEW_UNIT := 64.0

var shape_index := 0
var material_index := 0
var preview_kind := "block"
var angle_radians := 0.0
var flipped_horizontally := false


func configure(new_shape_index: int, new_material_index: int, new_preview_kind := "block") -> void:
	shape_index = new_shape_index
	material_index = new_material_index
	preview_kind = new_preview_kind
	custom_minimum_size = Vector2(280, 280)
	size = Vector2(280, 280)
	position = -size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_angle(new_angle_radians: float) -> void:
	angle_radians = new_angle_radians
	queue_redraw()


func set_flipped(new_flipped: bool) -> void:
	flipped_horizontally = new_flipped
	queue_redraw()


func _draw() -> void:
	if preview_kind == "pearl":
		_draw_pearl()
		return
	if preview_kind == "catapult":
		_draw_catapult()
		return
	var points := _get_polygon()
	var color: Color = PhysicsBlock.MATERIAL_COLORS[material_index]
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, color.lightened(0.3), 3.0, true)


func _draw_pearl() -> void:
	var center := size * 0.5
	draw_circle(center, 20.0, Color("#ddd5f4"))
	draw_circle(center + Vector2(-6, -7), 5.0, Color(1, 1, 1, 0.72))
	draw_arc(center, 20.0, 0.0, TAU, 32, Color("#fffaf0"), 2.0, true)


func _draw_catapult() -> void:
	var center := size * 0.5
	var transform := Transform2D(angle_radians, center)
	draw_set_transform_matrix(transform)
	draw_rect(Rect2(-24, 8, 48, 14), Color("#8f5929"), true)
	draw_circle(Vector2(-16, 21), 7.0, Color("#343941"))
	draw_circle(Vector2(16, 21), 7.0, Color("#343941"))
	draw_line(Vector2(0, 10), Vector2(25, -25), Color("#bd7d3e"), 6.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color("#4a5059"))
	draw_circle(Vector2(27, -27), 6.0, Color("#59606a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_polygon() -> PackedVector2Array:
	var dimensions := _get_dimensions() * PREVIEW_UNIT
	var half := dimensions * 0.5
	var center := size * 0.5
	var points: PackedVector2Array
	if shape_index == PhysicsBlock.BlockShape.SLOPE:
		points = PackedVector2Array([
			Vector2(-half.x, half.y),
			Vector2(half.x, half.y),
			Vector2(half.x, -half.y),
		])
	else:
		points = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])
	for index in points.size():
		var point := points[index]
		if flipped_horizontally:
			point.x *= -1.0
		points[index] = center + point.rotated(angle_radians)
	return points


func _get_dimensions() -> Vector2:
	match shape_index:
		PhysicsBlock.BlockShape.SQUARE:
			return Vector2(1.0, 1.0)
		PhysicsBlock.BlockShape.HALF_SQUARE:
			return Vector2(1.0, 0.5)
		PhysicsBlock.BlockShape.RECTANGLE:
			return Vector2(2.0, 1.0)
		PhysicsBlock.BlockShape.LARGE:
			return Vector2(2.0, 2.0)
		PhysicsBlock.BlockShape.PLATFORM:
			return Vector2(0.5, 3.0)
		PhysicsBlock.BlockShape.ROD:
			return Vector2(0.25, 3.0)
		PhysicsBlock.BlockShape.SLOPE:
			return Vector2(3.0, 2.0)
	return Vector2.ONE
