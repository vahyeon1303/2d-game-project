extends Control

const SHAPE_FILES := [
	"square", "half_square", "rectangle", "large", "platform", "rod", "slope"
]
const SHAPE_NAMES := ["정사각형", "반사각형", "직사각형", "대형", "발판", "막대", "경사"]
const MATERIAL_FILES := ["wood", "stone", "metal"]
const MATERIAL_NAMES := ["나무", "석재", "금속"]
const BUILD_AREA_BOTTOM := 540.0

@onready var world: Node2D = %World
@onready var palette: HBoxContainer = %Palette
@onready var block_count: Label = %BlockCount
@onready var clear_button: Button = %ClearButton

var placed_blocks: Array[PhysicsBlock] = []


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


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("kind", "") == "construction_block"
		and at_position.y < BUILD_AREA_BOTTOM
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var packed_scene := load(data["scene_path"]) as PackedScene
	if packed_scene == null:
		return
	var block := packed_scene.instantiate() as PhysicsBlock
	if block == null:
		return
	world.add_child(block)
	block.global_position = Vector2(
		clampf(at_position.x, 16.0, size.x - 16.0),
		clampf(at_position.y, 16.0, BUILD_AREA_BOTTOM - 16.0)
	)
	placed_blocks.append(block)
	block.tree_exiting.connect(_on_block_removed.bind(block))
	_update_block_count()


func _create_palette() -> void:
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
	for block in placed_blocks.duplicate():
		if is_instance_valid(block):
			block.queue_free()
	placed_blocks.clear()
	_update_block_count()


func _on_block_removed(block: PhysicsBlock) -> void:
	placed_blocks.erase(block)
	_update_block_count()


func _update_block_count() -> void:
	if block_count != null:
		block_count.text = "배치된 블록: %d" % placed_blocks.size()
