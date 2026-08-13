class_name BlockPaletteItem
extends PanelContainer

var scene_path := ""
var shape_index := 0
var material_index := 0
var display_name := ""


func configure(
	new_scene_path: String,
	new_shape_index: int,
	new_material_index: int,
	new_display_name: String
) -> void:
	scene_path = new_scene_path
	shape_index = new_shape_index
	material_index = new_material_index
	display_name = new_display_name
	custom_minimum_size = Vector2(112, 116)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "%s 블록을 끌어서 배치하세요" % display_name

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202734")
	style.border_color = Color("#414b5d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	queue_redraw()


func _draw() -> void:
	var points := _get_icon_polygon()
	var color: Color = PhysicsBlock.MATERIAL_COLORS[material_index]
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, color.lightened(0.3), 2.0, true)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if scene_path.is_empty():
		return null
	var preview := BlockPaletteItem.new()
	preview.configure(scene_path, shape_index, material_index, display_name)
	preview.custom_minimum_size = Vector2(100, 104)
	preview.size = Vector2(100, 104)
	preview.modulate.a = 0.86
	set_drag_preview(preview)
	return {
		"kind": "construction_block",
		"scene_path": scene_path,
		"display_name": display_name,
	}


func _get_icon_polygon() -> PackedVector2Array:
	var dimensions := _get_dimensions()
	var scale_factor: float = minf(66.0 / dimensions.x, 58.0 / dimensions.y)
	var half := dimensions * scale_factor * 0.5
	var center := Vector2(size.x * 0.5, 38.0)
	if shape_index == PhysicsBlock.BlockShape.SLOPE:
		return PackedVector2Array([
			center + Vector2(-half.x, half.y),
			center + Vector2(half.x, half.y),
			center + Vector2(half.x, -half.y),
		])
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])


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
