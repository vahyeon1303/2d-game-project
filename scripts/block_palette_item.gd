class_name BlockPaletteItem
extends PanelContainer

signal purchase_requested(item_id: String)

var scene_path := ""
var shape_index := 0
var material_index := 0
var display_name := ""
var item_kind := "block"
var item_id := ""
var drag_kind := "sandbox_placeable"
var price := -1
var inventory_count := 0
var shop_enabled := false
var purchasable := true

var _press_position := Vector2.ZERO
var _price_label: Label
var _count_label: Label


func configure(
	new_scene_path: String,
	new_shape_index: int,
	new_material_index: int,
	new_display_name: String,
	new_item_kind := "block"
) -> void:
	scene_path = new_scene_path
	shape_index = new_shape_index
	material_index = new_material_index
	display_name = new_display_name
	item_kind = new_item_kind
	item_id = new_scene_path
	custom_minimum_size = Vector2(76, 76)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s" % display_name
	clip_contents = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202734")
	style.border_color = Color("#414b5d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	queue_redraw()


func configure_shop(
	new_item_id: String,
	new_price: int,
	new_count := 0,
	new_purchasable := true
) -> void:
	shop_enabled = true
	item_id = new_item_id
	price = new_price
	inventory_count = new_count
	purchasable = new_purchasable
	drag_kind = "level_placeable"
	tooltip_text = (
		"%s · 가격 %d" % [display_name, price]
		if purchasable
		else "%s · 기본 지급" % display_name
	)
	_create_shop_labels()
	_update_shop_labels()


func set_inventory_count(new_count: int) -> void:
	inventory_count = maxi(0, new_count)
	_update_shop_labels()
	queue_redraw()


func _create_shop_labels() -> void:
	if _price_label != null:
		return
	_price_label = Label.new()
	_price_label.position = Vector2(5, 53)
	_price_label.size = Vector2(43, 18)
	_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_label.add_theme_font_size_override("font_size", 12)
	_price_label.add_theme_color_override("font_color", Color("#ffd36a"))
	add_child(_price_label)

	_count_label = Label.new()
	_count_label.position = Vector2(46, 4)
	_count_label.size = Vector2(25, 18)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_count_label)


func _update_shop_labels() -> void:
	if _price_label == null:
		return
	_price_label.text = "%d" % price if purchasable else "필수"
	_count_label.text = "×%d" % inventory_count


func _gui_input(event: InputEvent) -> void:
	if not shop_enabled or not purchasable or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_press_position = event.position
	elif event.position.distance_to(_press_position) < 8.0:
		purchase_requested.emit(item_id)
		accept_event()


func _draw() -> void:
	if item_kind == "pearl":
		_draw_pearl_icon()
	elif item_kind == "catapult":
		_draw_catapult_icon()
	else:
		var points := _get_icon_polygon()
		var color: Color = PhysicsBlock.MATERIAL_COLORS[material_index]
		draw_colored_polygon(points, color)
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, color.lightened(0.3), 2.0, true)
	if shop_enabled and inventory_count <= 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.22), true)


func _draw_pearl_icon() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.46)
	draw_circle(center, 17.0, Color("#ddd5f4"))
	draw_circle(center + Vector2(-5, -6), 4.0, Color(1, 1, 1, 0.72))
	draw_arc(center, 17.0, 0.0, TAU, 24, Color("#fffaf0"), 2.0, true)


func _draw_catapult_icon() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.43)
	draw_rect(Rect2(center + Vector2(-23, 7), Vector2(46, 13)), Color("#8f5929"), true)
	draw_circle(center + Vector2(-15, 19), 6.0, Color("#343941"))
	draw_circle(center + Vector2(15, 19), 6.0, Color("#343941"))
	draw_line(center + Vector2(0, 8), center + Vector2(22, -21), Color("#bd7d3e"), 5.0, true)
	draw_circle(center, 4.0, Color("#4a5059"))
	draw_circle(center + Vector2(23, -22), 5.0, Color("#59606a"))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if scene_path.is_empty() or (shop_enabled and inventory_count <= 0):
		return null
	var preview_anchor := Control.new()
	preview_anchor.size = Vector2.ZERO
	preview_anchor.custom_minimum_size = Vector2.ZERO
	preview_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := BlockDragPreview.new()
	preview.configure(shape_index, material_index, item_kind)
	preview.modulate.a = 0.86
	preview_anchor.add_child(preview)
	set_drag_preview(preview_anchor)
	return {
		"kind": drag_kind,
		"item_kind": item_kind,
		"item_id": item_id,
		"scene_path": scene_path,
		"display_name": display_name,
		"shape_index": shape_index,
		"rotation_steps": 0,
		"flipped": false,
		"preview": preview,
	}


func _get_icon_polygon() -> PackedVector2Array:
	var dimensions := _get_dimensions()
	var scale_factor: float = minf(52.0 / dimensions.x, 46.0 / dimensions.y)
	var half := dimensions * scale_factor * 0.5
	var center := Vector2(size.x * 0.5, size.y * 0.43)
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
