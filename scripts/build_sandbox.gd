extends Control

const SHAPE_FILES := [
	"square", "half_square", "rectangle", "large", "platform", "rod", "slope"
]
const SHAPE_NAMES := ["정사각형", "반사각형", "직사각형", "대형", "발판", "막대", "경사"]
const MATERIAL_FILES := ["wood", "stone", "metal"]
const MATERIAL_NAMES := ["나무", "석재", "금속"]
const BUILD_AREA_BOTTOM := 540.0
const ROTATION_STEP_RADIANS := PI / 12.0

@onready var world: Node2D = %World
@onready var palette: HBoxContainer = %Palette
@onready var block_count: Label = %BlockCount
@onready var clear_button: Button = %ClearButton

var placed_objects: Array[Node2D] = []


func _ready() -> void:
	_create_palette()
	clear_button.pressed.connect(_clear_blocks)
	_update_block_count()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#111722"))
	var grid_color := Color(0.22, 0.27, 0.35, 0.28)
	for x in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(x, 0), Vector2(x, BUILD_AREA_BOTTOM), grid_color, 1.0)
	for y in range(0, int(BUILD_AREA_BOTTOM) + 1, 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
	draw_rect(Rect2(0, 532, size.x, 16), Color("#596273"))
	draw_line(Vector2(0, 532), Vector2(size.x, 532), Color("#aab1bd"), 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not get_viewport().gui_is_dragging():
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var data: Variant = get_viewport().gui_get_drag_data()
	if not data is Dictionary or data.get("kind", "") != "sandbox_placeable":
		return
	var preview := data.get("preview") as BlockDragPreview
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		data["rotation_steps"] = int(data.get("rotation_steps", 0)) + direction
		if is_instance_valid(preview):
			preview.set_angle(float(data["rotation_steps"]) * ROTATION_STEP_RADIANS)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and data.get("item_kind", "") == "block":
		data["flipped"] = not bool(data.get("flipped", false))
		if is_instance_valid(preview):
			preview.set_flipped(bool(data["flipped"]))
		get_viewport().set_input_as_handled()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("kind", "") == "sandbox_placeable"
		and at_position.y < BUILD_AREA_BOTTOM
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var packed_scene := load(data["scene_path"]) as PackedScene
	if packed_scene == null:
		return
	var placed_object := packed_scene.instantiate() as Node2D
	if placed_object == null:
		return
	world.add_child(placed_object)
	placed_object.global_position = Vector2(
		clampf(at_position.x, 16.0, size.x - 16.0),
		clampf(at_position.y, 16.0, BUILD_AREA_BOTTOM - 16.0)
	)
	placed_object.rotation = float(data.get("rotation_steps", 0)) * ROTATION_STEP_RADIANS
	if placed_object is PhysicsBlock:
		placed_object.flipped_horizontally = bool(data.get("flipped", false))
	placed_object.reset_physics_interpolation()
	placed_objects.append(placed_object)
	placed_object.tree_exiting.connect(_on_object_removed.bind(placed_object))
	_update_block_count()


func _create_palette() -> void:
	var pearl_item := BlockPaletteItem.new()
	pearl_item.configure("res://objects/pearl.tscn", 0, 0, "진주", "pearl")
	palette.add_child(pearl_item)

	var catapult_item := BlockPaletteItem.new()
	catapult_item.configure("res://objects/catapult.tscn", 0, 0, "투석기", "catapult")
	palette.add_child(catapult_item)

	for material_index in MATERIAL_FILES.size():
		for shape_index in SHAPE_FILES.size():
			var item := BlockPaletteItem.new()
			var scene_path := "res://blocks/%s_%s.tscn" % [
				MATERIAL_FILES[material_index], SHAPE_FILES[shape_index]
			]
			var display_name := "%s · %s" % [
				MATERIAL_NAMES[material_index], SHAPE_NAMES[shape_index]
			]
			item.configure(scene_path, shape_index, material_index, display_name)
			palette.add_child(item)


func _clear_blocks() -> void:
	for placed_object in placed_objects.duplicate():
		if is_instance_valid(placed_object):
			placed_object.queue_free()
	placed_objects.clear()
	for stone in get_tree().get_nodes_in_group("catapult_stones"):
		if is_instance_valid(stone):
			stone.queue_free()
	_update_block_count()


func _on_object_removed(placed_object: Node2D) -> void:
	placed_objects.erase(placed_object)
	_update_block_count()


func _update_block_count() -> void:
	if block_count != null:
		block_count.text = "배치된 오브젝트: %d" % placed_objects.size()
