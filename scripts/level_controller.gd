class_name LevelController
extends Node2D

const SHAPE_FILES := [
	"square", "half_square", "rectangle", "large", "platform", "rod", "slope"
]
const SHAPE_NAMES := ["정사각형", "반사각형", "직사각형", "대형", "발판", "막대", "경사"]
const MATERIAL_FILES := ["wood", "stone", "metal"]
const MATERIAL_NAMES := ["나무", "석재", "금속"]
const MATERIAL_PRICE_PER_AREA := [8.0, 14.0, 22.0]
const ROTATION_STEP_RADIANS := PI / 12.0
const WORLD_WIDTH := 2400.0
const VIEWPORT_WIDTH := 1280.0
const GROUND_TOP := 620.0
const BUILD_MIN_X := 760.0
const UI_TOP := 608.0
const SUCCESS_HEIGHT_MARGIN := 55.0

@export_range(1, 3, 1) var level_number := 1
@export var starting_balance := 500
@export_category("승패 설정")
## Godot에서는 화면 아래쪽일수록 Y값이 커집니다. 진주가 이 값 이상이면 즉시 실패합니다.
@export var pearl_game_over_y: float = 620.0

@onready var world: Node2D = %World
@onready var camera: Camera2D = %Camera2D
@onready var catapult: Catapult = %Catapult
@onready var tower_platform: StaticBody2D = %TowerPlatform
@onready var palette: HBoxContainer = %Palette
@onready var balance_label: Label = %BalanceLabel
@onready var start_button: Button = %RaidButton
@onready var status_label: Label = %StatusLabel
@onready var result_overlay: Control = %ResultOverlay
@onready var result_text: Label = %ResultText
@onready var result_button: Button = %ResultButton

var balance := 0
var inventory: Dictionary = {}
var shop_items: Dictionary = {}
var placed_objects: Array[CollisionObject2D] = []
var raid_started := false
var raid_finished := false
var raid_paused := false


func _ready() -> void:
	Engine.time_scale = 1.0
	get_viewport().physics_object_picking = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	balance = starting_balance
	_create_shop()
	_update_balance()
	start_button.pressed.connect(_on_raid_button_pressed)
	result_button.pressed.connect(_on_result_button_pressed)
	catapult.raid_finished.connect(_on_catapult_raid_finished)
	result_overlay.hide()
	status_label.text = "보유한 진주를 탑 위에 배치한 뒤 시작하세요."
	queue_redraw()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _physics_process(_delta: float) -> void:
	if not raid_started or raid_finished:
		return
	var pearls := _get_level_pearls()
	if pearls.is_empty():
		catapult.stop_raid()
		_finish_raid(true)
		return
	for pearl in pearls:
		if pearl.global_position.y >= pearl_game_over_y:
			catapult.stop_raid()
			_finish_raid(true)
			return


func _draw() -> void:
	draw_rect(Rect2(0, 0, WORLD_WIDTH, 720), Color("#151c28"), true)
	var grid_color := Color(0.24, 0.29, 0.37, 0.22)
	for x in range(0, int(WORLD_WIDTH) + 1, 64):
		draw_line(Vector2(x, 0), Vector2(x, GROUND_TOP), grid_color, 1.0)
	for y in range(0, int(GROUND_TOP) + 1, 64):
		draw_line(Vector2(0, y), Vector2(WORLD_WIDTH, y), grid_color, 1.0)
	draw_rect(Rect2(0, 0, BUILD_MIN_X, GROUND_TOP), Color(0.36, 0.12, 0.12, 0.13), true)
	draw_line(Vector2(BUILD_MIN_X, 0), Vector2(BUILD_MIN_X, GROUND_TOP), Color(0.72, 0.3, 0.3, 0.45), 2.0)
	draw_rect(Rect2(0, GROUND_TOP, WORLD_WIDTH, 100), Color("#3f4857"), true)
	draw_line(Vector2(0, GROUND_TOP), Vector2(WORLD_WIDTH, GROUND_TOP), Color("#aab1bd"), 2.0)
	var platform_rect := _get_platform_world_rect()
	draw_rect(platform_rect, Color("#737c89"), true)
	draw_rect(platform_rect, Color("#c5cad1"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(BUILD_MIN_X - 215, 40), "배치 금지 구역", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.55, 0.55, 0.72))


func _input(event: InputEvent) -> void:
	if not get_viewport().gui_is_dragging():
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var data: Variant = get_viewport().gui_get_drag_data()
	if not data is Dictionary or data.get("kind", "") != "level_placeable":
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


func pan_camera(horizontal_delta: float) -> void:
	var half_view := VIEWPORT_WIDTH * 0.5
	camera.position.x = clampf(camera.position.x + horizontal_delta, half_view, WORLD_WIDTH - half_view)
	camera.force_update_scroll()


func can_place_from_screen(screen_position: Vector2, data: Variant) -> bool:
	if raid_started or not data is Dictionary:
		return false
	if data.get("kind", "") != "level_placeable" or screen_position.y >= UI_TOP:
		return false
	var item_id_string := str(data.get("item_id", ""))
	if int(inventory.get(item_id_string, 0)) <= 0:
		return false
	var world_position := _screen_to_world(screen_position)
	var half_extents := _get_rotated_half_extents(data)
	var platform_top := _get_platform_world_rect().position.y
	return (
		world_position.x - half_extents.x >= BUILD_MIN_X
		and world_position.x + half_extents.x <= WORLD_WIDTH
		and world_position.y - half_extents.y >= 0.0
		and world_position.y + half_extents.y <= platform_top + 3.0
	)


func place_from_screen(screen_position: Vector2, data: Variant) -> void:
	if not can_place_from_screen(screen_position, data):
		return
	var packed_scene := load(str(data["scene_path"])) as PackedScene
	if packed_scene == null:
		return
	var placed_object := packed_scene.instantiate() as CollisionObject2D
	if placed_object == null:
		return
	world.add_child(placed_object)
	placed_object.global_position = _screen_to_world(screen_position)
	placed_object.rotation = float(data.get("rotation_steps", 0)) * ROTATION_STEP_RADIANS
	if placed_object is PhysicsBlock:
		placed_object.flipped_horizontally = bool(data.get("flipped", false))
	placed_object.reset_physics_interpolation()
	placed_object.set_meta("inventory_item_id", str(data["item_id"]))
	placed_object.input_pickable = true
	placed_object.input_event.connect(_on_placed_object_input.bind(placed_object))
	placed_objects.append(placed_object)
	placed_object.tree_exiting.connect(_on_placed_object_removed.bind(placed_object))
	_change_inventory(str(data["item_id"]), -1)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _get_platform_world_rect() -> Rect2:
	if tower_platform == null:
		return Rect2(1722, 520, 256, 24)
	var collision := tower_platform.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return Rect2(tower_platform.global_position - Vector2(128, 12), Vector2(256, 24))
	var rectangle := collision.shape as RectangleShape2D
	var half := rectangle.size * 0.5
	var corners := [
		collision.global_transform * Vector2(-half.x, -half.y),
		collision.global_transform * Vector2(half.x, -half.y),
		collision.global_transform * Vector2(half.x, half.y),
		collision.global_transform * Vector2(-half.x, half.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _get_rotated_half_extents(data: Dictionary) -> Vector2:
	var half := Vector2(32, 32)
	if data.get("item_kind", "block") == "pearl":
		half = Vector2(20, 20)
	else:
		var dimensions := _get_shape_dimensions(int(data.get("shape_index", 0))) * 32.0
		half = dimensions
	var angle := float(data.get("rotation_steps", 0)) * ROTATION_STEP_RADIANS
	var cosine := absf(cos(angle))
	var sine := absf(sin(angle))
	return Vector2(cosine * half.x + sine * half.y, sine * half.x + cosine * half.y)


func _get_shape_dimensions(shape_index: int) -> Vector2:
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


func _create_shop() -> void:
	_add_shop_item("res://objects/pearl.tscn", 0, 0, "진주", "pearl", 0, 1, false)
	for material_index in MATERIAL_FILES.size():
		for shape_index in SHAPE_FILES.size():
			var scene_path := "res://blocks/%s_%s.tscn" % [
				MATERIAL_FILES[material_index], SHAPE_FILES[shape_index]
			]
			var display_name := "%s · %s" % [MATERIAL_NAMES[material_index], SHAPE_NAMES[shape_index]]
			var area := _get_shape_area(shape_index)
			var item_price := ceili(area * MATERIAL_PRICE_PER_AREA[material_index])
			_add_shop_item(scene_path, shape_index, material_index, display_name, "block", item_price)


func _add_shop_item(
	scene_path: String,
	shape_index: int,
	material_index: int,
	display_name: String,
	item_kind: String,
	item_price: int,
	initial_count := 0,
	purchasable := true
) -> void:
	var item := BlockPaletteItem.new()
	item.configure(scene_path, shape_index, material_index, display_name, item_kind)
	item.configure_shop(scene_path, item_price, initial_count, purchasable)
	item.purchase_requested.connect(_on_purchase_requested)
	palette.add_child(item)
	inventory[scene_path] = initial_count
	shop_items[scene_path] = item


func _get_shape_area(shape_index: int) -> float:
	var dimensions := _get_shape_dimensions(shape_index)
	var area := dimensions.x * dimensions.y
	if shape_index == PhysicsBlock.BlockShape.SLOPE:
		area *= 0.5
	return area


func _on_purchase_requested(item_id_string: String) -> void:
	if raid_started:
		status_label.text = "레이드 중에는 구매할 수 없습니다."
		return
	var item := shop_items.get(item_id_string) as BlockPaletteItem
	if item == null or not item.purchasable:
		return
	if balance < item.price:
		status_label.text = "잔액이 부족합니다."
		return
	balance -= item.price
	_change_inventory(item_id_string, 1)
	_update_balance()
	status_label.text = "%s 구매 완료" % item.display_name


func _change_inventory(item_id_string: String, amount: int) -> void:
	inventory[item_id_string] = maxi(0, int(inventory.get(item_id_string, 0)) + amount)
	var item := shop_items.get(item_id_string) as BlockPaletteItem
	if item != null:
		item.set_inventory_count(int(inventory[item_id_string]))


func _update_balance() -> void:
	balance_label.text = "잔액: %d" % balance


func _on_placed_object_input(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int,
	placed_object: CollisionObject2D
) -> void:
	if raid_started or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if not is_instance_valid(placed_object):
		return
	var item_id_string := str(placed_object.get_meta("inventory_item_id", ""))
	if not item_id_string.is_empty():
		_change_inventory(item_id_string, 1)
	placed_objects.erase(placed_object)
	placed_object.queue_free()
	get_viewport().set_input_as_handled()


func _on_placed_object_removed(placed_object: CollisionObject2D) -> void:
	placed_objects.erase(placed_object)


func _on_raid_button_pressed() -> void:
	if raid_finished:
		return
	if raid_started:
		raid_paused = not raid_paused
		Engine.time_scale = 0.0 if raid_paused else 1.0
		camera.position_smoothing_enabled = not raid_paused
		camera.reset_smoothing()
		camera.force_update_scroll()
		start_button.text = "계속" if raid_paused else "일시정지"
		status_label.text = "레이드 일시정지" if raid_paused else "레이드 진행 중"
		return
	var pearls := _get_level_pearls()
	if pearls.is_empty():
		status_label.text = "진주를 먼저 배치해야 합니다."
		return
	raid_started = true
	start_button.text = "일시정지"
	status_label.text = "레이드 진행 중"
	catapult.start_raid()


func _get_level_pearls() -> Array[Pearl]:
	var pearls: Array[Pearl] = []
	for candidate in get_tree().get_nodes_in_group("pearls"):
		if candidate is Pearl and is_instance_valid(candidate) and world.is_ancestor_of(candidate):
			pearls.append(candidate)
	return pearls


func _on_catapult_raid_finished() -> void:
	status_label.text = "마지막 충격을 확인하는 중..."
	await get_tree().create_timer(5.0).timeout
	_finish_raid()


func _finish_raid(force_failure := false) -> void:
	if raid_finished:
		return
	raid_finished = true
	raid_paused = false
	Engine.time_scale = 1.0
	camera.position_smoothing_enabled = true
	start_button.disabled = true
	var pearls := _get_level_pearls()
	var success := not force_failure and not pearls.is_empty()
	var success_max_y := _get_platform_world_rect().position.y + SUCCESS_HEIGHT_MARGIN
	for pearl in pearls:
		if pearl.global_position.y >= success_max_y:
			success = false
			break
	result_overlay.show()
	if success:
		result_text.text = "레벨 %d 성공!" % level_number
		result_button.text = "다음 레벨" if level_number < 3 else "메인 화면"
		result_button.set_meta("success", true)
	else:
		result_text.text = "진주 보호 실패"
		result_button.text = "다시 시도"
		result_button.set_meta("success", false)


func _on_result_button_pressed() -> void:
	Engine.time_scale = 1.0
	var success := bool(result_button.get_meta("success", false))
	if not success:
		get_tree().reload_current_scene()
	elif level_number < 3:
		get_tree().change_scene_to_file("res://scenes/level_%d.tscn" % (level_number + 1))
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
