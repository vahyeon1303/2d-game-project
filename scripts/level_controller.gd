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
const WORLD_WIDTH := 4800.0
const WORLD_HEIGHT := 1440.0
const VIEWPORT_WIDTH := 2560.0
const GROUND_TOP := 1240.0
const FALLEN_BLOCK_REMOVAL_Y := GROUND_TOP - 2.0
const BUILD_MIN_X := 1520.0
const UI_TOP := 1209.0
const STRUCTURE_FACE_THRESHOLDS := [0.8, 0.7, 0.6, 0.5, 0.4]
const STRUCTURE_SCORE_LABELS := ["매우 훌륭함", "훌륭함", "보통", "못함", "매우 못함"]
const CLEAR_SOUND := preload("res://Asset/Clear.mp3")
const FAILED_SOUND := preload("res://Asset/Failed.mp3")
const SUCCESS_RESULT_DELAY := 3.0
const CLEAR_TO_RESULT_DELAY := 0.5
const STRUCTURE_FACE_TEXTURES: Array[Texture2D] = [
	preload("res://Asset/Face/Verry Good.png"),
	preload("res://Asset/Face/Good.png"),
	preload("res://Asset/Face/Not Bad.png"),
	preload("res://Asset/Face/Bad.png"),
	preload("res://Asset/Face/Very Bad.png"),
]

@export_range(1, 3, 1) var level_number := 1
@export var starting_balance := 500
@export_category("승패 설정")
## 진주의 전체 원이 이 월드 Y 경계 아래로 벗어나면 제거하고 즉시 실패합니다.
@export var pearl_game_over_y: float = WORLD_HEIGHT

@onready var world: Node2D = %World
@onready var camera: Camera2D = %Camera2D
@onready var catapult: Catapult = %Catapult
@onready var tower_platform: StaticBody2D = %TowerPlatform
@onready var palette: HBoxContainer = %Palette
@onready var balance_label: Label = %BalanceLabel
@onready var start_button: Button = %RaidButton
@onready var structure_face_panel: PanelContainer = %StructureFacePanel
@onready var structure_face_texture: TextureRect = %StructureFaceTexture
@onready var ammunition_panel: PanelContainer = %AmmunitionPanel
@onready var normal_ammo_label: Label = %NormalAmmoLabel
@onready var bomb_ammo_label: Label = %BombAmmoLabel
@onready var save_layout_button: Button = %SaveLayoutButton
@onready var load_layout_button: Button = %LoadLayoutButton
@onready var layout_status_label: Label = %LayoutStatusLabel
@onready var result_overlay: Control = %ResultOverlay
@onready var result_text: Label = %ResultText
@onready var result_score_label: Label = %ResultScoreLabel
@onready var result_button: Button = %ResultButton

var balance := 0
var inventory: Dictionary = {}
var shop_items: Dictionary = {}
var placed_objects: Array[CollisionObject2D] = []
var raid_started := false
var raid_finished := false
var catapults: Array[Catapult] = []
var _remaining_catapult_shots: Array[int] = []
var _remaining_bomb_shots: Array[int] = []
var _next_catapult_index := 0
var _attack_timer: Timer
var layout_save_path := ""
var initial_placed_block_count := 0
var _current_structure_face_index := -1
var _clear_audio_player: AudioStreamPlayer
var _failed_audio_player: AudioStreamPlayer


func _ready() -> void:
	get_viewport().physics_object_picking = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	layout_save_path = "user://level_%d_layout.json" % level_number
	balance = starting_balance
	_setup_attack_sequence()
	_create_shop()
	_update_balance()
	start_button.pressed.connect(_on_raid_button_pressed)
	save_layout_button.pressed.connect(_save_block_layout)
	load_layout_button.pressed.connect(_load_block_layout)
	result_button.pressed.connect(_on_result_button_pressed)
	_clear_audio_player = AudioStreamPlayer.new()
	_clear_audio_player.name = "ClearAudio"
	_clear_audio_player.stream = CLEAR_SOUND
	_clear_audio_player.volume_db = -2.0
	add_child(_clear_audio_player)
	_failed_audio_player = AudioStreamPlayer.new()
	_failed_audio_player.name = "FailedAudio"
	_failed_audio_player.stream = FAILED_SOUND
	_failed_audio_player.volume_db = -2.0
	add_child(_failed_audio_player)
	result_overlay.hide()
	result_score_label.hide()
	structure_face_panel.hide()
	ammunition_panel.hide()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if raid_started:
		_remove_fallen_blocks()
		_update_structure_face()
	if not raid_started or raid_finished:
		return
	var pearls := _get_level_pearls()
	if pearls.is_empty():
		_stop_attack_sequence()
		_finish_raid(true)
		return
	for pearl in pearls:
		if _is_pearl_outside_play_area(pearl):
			pearl.queue_free()
			_stop_attack_sequence()
			_finish_raid(true)
			return


func _draw() -> void:
	draw_rect(Rect2(0, 0, BUILD_MIN_X, GROUND_TOP), Color(1, 1, 1, 0.035), true)
	draw_line(Vector2(BUILD_MIN_X, 0), Vector2(BUILD_MIN_X, GROUND_TOP), Color(0.72, 0.72, 0.72, 0.55), 2.0)
	draw_rect(Rect2(0, GROUND_TOP, WORLD_WIDTH, WORLD_HEIGHT - GROUND_TOP), Color("#282828"), true)
	draw_line(Vector2(0, GROUND_TOP), Vector2(WORLD_WIDTH, GROUND_TOP), Color("#d0d0d0"), 2.0)
	for collision in _get_platform_collision_shapes():
		var points := _get_platform_polygon(collision)
		if points.size() < 3:
			continue
		draw_colored_polygon(points, Color("#666666"))
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, Color("#e0e0e0"), 2.0, true)


func _input(event: InputEvent) -> void:
	if _is_escape_pressed(event):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
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


func _is_escape_pressed(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	)


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
	return (
		world_position.x - half_extents.x >= BUILD_MIN_X
		and world_position.x + half_extents.x <= WORLD_WIDTH
		and world_position.y - half_extents.y >= 0.0
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
	_play_ui_pop_sound()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _get_platform_world_rect() -> Rect2:
	var has_point := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for collision in _get_platform_collision_shapes():
		for point in _get_platform_polygon(collision):
			if not has_point:
				minimum = point
				maximum = point
				has_point = true
			else:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	if has_point:
		return Rect2(minimum, maximum - minimum)
	if tower_platform != null:
		return Rect2(tower_platform.position, Vector2.ZERO)
	return Rect2()


func _get_platform_collision_shapes() -> Array[CollisionShape2D]:
	var collisions: Array[CollisionShape2D] = []
	if tower_platform == null:
		return collisions
	for child in tower_platform.get_children():
		if (
			child is CollisionShape2D
			and not child.disabled
			and child.shape is RectangleShape2D
		):
			collisions.append(child)
	return collisions


func _get_platform_polygon(collision: CollisionShape2D) -> PackedVector2Array:
	if collision == null or not collision.shape is RectangleShape2D:
		return PackedVector2Array()
	var rectangle := collision.shape as RectangleShape2D
	var half := rectangle.size * 0.5
	var world_to_level := global_transform.affine_inverse()
	return PackedVector2Array([
		world_to_level * (collision.global_transform * Vector2(-half.x, -half.y)),
		world_to_level * (collision.global_transform * Vector2(half.x, -half.y)),
		world_to_level * (collision.global_transform * Vector2(half.x, half.y)),
		world_to_level * (collision.global_transform * Vector2(-half.x, half.y)),
	])


func _get_rotated_half_extents(data: Dictionary) -> Vector2:
	var half := Vector2(22.4, 22.4)
	if data.get("item_kind", "block") == "pearl":
		half = Vector2(20, 20)
	else:
		var dimensions := _get_shape_dimensions(int(data.get("shape_index", 0))) * 22.4
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
	if item_kind == "block":
		item.tooltip_text += "\n%s" % _get_material_trait(material_index)
	item.purchase_requested.connect(_on_purchase_requested)
	palette.add_child(item)
	inventory[scene_path] = initial_count
	shop_items[scene_path] = item


func _get_material_trait(material_index: int) -> String:
	match material_index:
		PhysicsBlock.BlockMaterial.WOOD:
			return "가벼움 · 충격 감쇠가 빠름"
		PhysicsBlock.BlockMaterial.STONE:
			return "마찰력이 높아 기초에 안정적"
		PhysicsBlock.BlockMaterial.METAL:
			return "매우 무거움 · 미끄러지며 주변에 큰 충격"
	return ""


func _get_shape_area(shape_index: int) -> float:
	var dimensions := _get_shape_dimensions(shape_index)
	var area := dimensions.x * dimensions.y
	if shape_index == PhysicsBlock.BlockShape.SLOPE:
		area *= 0.5
	return area


func _on_purchase_requested(item_id_string: String) -> void:
	if raid_started:
		return
	var item := shop_items.get(item_id_string) as BlockPaletteItem
	if item == null or not item.purchasable:
		return
	if balance < item.price:
		return
	balance -= item.price
	_change_inventory(item_id_string, 1)
	_update_balance()
	_play_ui_pop_sound()


func _change_inventory(item_id_string: String, amount: int) -> void:
	inventory[item_id_string] = maxi(0, int(inventory.get(item_id_string, 0)) + amount)
	var item := shop_items.get(item_id_string) as BlockPaletteItem
	if item != null:
		item.set_inventory_count(int(inventory[item_id_string]))


func _update_balance() -> void:
	balance_label.text = "잔액: %d" % balance


func _save_block_layout() -> void:
	if raid_started:
		layout_status_label.text = "진행 중에는 저장할 수 없습니다"
		return
	var saved_blocks: Array[Dictionary] = []
	for placed_object in placed_objects:
		if not placed_object is PhysicsBlock or not is_instance_valid(placed_object):
			continue
		saved_blocks.append({
			"material": int(placed_object.block_material),
			"shape": int(placed_object.block_shape),
			"position": [placed_object.global_position.x, placed_object.global_position.y],
			"rotation": placed_object.global_rotation,
			"flipped": placed_object.flipped_horizontally,
		})
	var file := FileAccess.open(layout_save_path, FileAccess.WRITE)
	if file == null:
		layout_status_label.text = "저장 실패"
		return
	file.store_string(JSON.stringify({"version": 1, "level": level_number, "blocks": saved_blocks}))
	file.close()
	layout_status_label.text = "블록 %d개 저장 완료" % saved_blocks.size()


func _load_block_layout() -> void:
	if raid_started:
		layout_status_label.text = "진행 중에는 불러올 수 없습니다"
		return
	var saved_blocks: Variant = _read_saved_blocks()
	if saved_blocks == null:
		return
	var required_counts: Variant = _count_required_blocks(saved_blocks)
	if required_counts == null:
		layout_status_label.text = "저장 파일이 올바르지 않습니다"
		return
	var available_counts := _get_available_block_counts_after_reclaim()
	var missing_counts: Dictionary = {}
	var required_cost := 0
	for scene_path in required_counts:
		var missing_count := maxi(
			int(required_counts[scene_path]) - int(available_counts.get(scene_path, 0)),
			0
		)
		if missing_count <= 0:
			continue
		var item := shop_items.get(scene_path) as BlockPaletteItem
		if item == null or not item.purchasable:
			layout_status_label.text = "저장 파일이 올바르지 않습니다"
			return
		missing_counts[scene_path] = missing_count
		required_cost += item.price * missing_count
	if required_cost > balance:
		layout_status_label.text = "잔액 부족 · 필요 금액: %d" % required_cost
		return

	_reclaim_and_remove_all_placed_objects()
	for scene_path in missing_counts:
		_change_inventory(str(scene_path), int(missing_counts[scene_path]))
	balance -= required_cost
	var loaded_count := 0
	for saved_block in saved_blocks:
		if _restore_saved_block(saved_block):
			loaded_count += 1
	_update_balance()
	layout_status_label.text = "블록 %d개 불러오기 완료 · 사용 금액: %d" % [
		loaded_count, required_cost
	]


func _read_saved_blocks() -> Variant:
	if not FileAccess.file_exists(layout_save_path):
		layout_status_label.text = "저장된 배치가 없습니다"
		return null
	var file := FileAccess.open(layout_save_path, FileAccess.READ)
	if file == null:
		layout_status_label.text = "불러오기 실패"
		return null
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not json.data is Dictionary:
		layout_status_label.text = "저장 파일이 올바르지 않습니다"
		return null
	var saved_blocks: Variant = json.data.get("blocks", [])
	if not saved_blocks is Array:
		layout_status_label.text = "저장 파일이 올바르지 않습니다"
		return null
	return saved_blocks


func _count_required_blocks(saved_blocks: Array) -> Variant:
	var required_counts: Dictionary = {}
	for saved_block in saved_blocks:
		var scene_path := _get_saved_block_scene_path(saved_block)
		if scene_path.is_empty():
			return null
		required_counts[scene_path] = int(required_counts.get(scene_path, 0)) + 1
	return required_counts


func _get_available_block_counts_after_reclaim() -> Dictionary:
	var available_counts: Dictionary = {}
	for scene_path in shop_items:
		var item := shop_items[scene_path] as BlockPaletteItem
		if item != null and item.purchasable:
			available_counts[scene_path] = int(inventory.get(scene_path, 0))
	for placed_object in placed_objects:
		if not placed_object is PhysicsBlock or not is_instance_valid(placed_object):
			continue
		var scene_path := str(placed_object.get_meta("inventory_item_id", ""))
		if not scene_path.is_empty():
			available_counts[scene_path] = int(available_counts.get(scene_path, 0)) + 1
	return available_counts


func _get_saved_block_scene_path(saved_block: Variant) -> String:
	if not saved_block is Dictionary:
		return ""
	var material_index := int(saved_block.get("material", -1))
	var shape_index := int(saved_block.get("shape", -1))
	if material_index < 0 or material_index >= MATERIAL_FILES.size():
		return ""
	if shape_index < 0 or shape_index >= SHAPE_FILES.size():
		return ""
	return "res://blocks/%s_%s.tscn" % [
		MATERIAL_FILES[material_index], SHAPE_FILES[shape_index]
	]


func _restore_saved_block(saved_block: Variant) -> bool:
	var scene_path := _get_saved_block_scene_path(saved_block)
	if scene_path.is_empty():
		return false
	var position_data: Variant = saved_block.get("position", [])
	if not position_data is Array or position_data.size() < 2:
		return false
	if int(inventory.get(scene_path, 0)) <= 0:
		return false
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return false
	var block := packed_scene.instantiate() as PhysicsBlock
	if block == null:
		return false
	block.flipped_horizontally = bool(saved_block.get("flipped", false))
	world.add_child(block)
	block.global_position = Vector2(float(position_data[0]), float(position_data[1]))
	block.global_rotation = float(saved_block.get("rotation", 0.0))
	block.reset_physics_interpolation()
	block.set_meta("inventory_item_id", scene_path)
	block.input_pickable = true
	block.input_event.connect(_on_placed_object_input.bind(block))
	placed_objects.append(block)
	block.tree_exiting.connect(_on_placed_object_removed.bind(block))
	_change_inventory(scene_path, -1)
	return true


func _reclaim_and_remove_all_placed_objects() -> void:
	var objects_to_remove := placed_objects.duplicate()
	placed_objects.clear()
	for placed_object in objects_to_remove:
		if not is_instance_valid(placed_object):
			continue
		var item_id_string := str(placed_object.get_meta("inventory_item_id", ""))
		if not item_id_string.is_empty():
			_change_inventory(item_id_string, 1)
		if placed_object.get_parent() != null:
			placed_object.get_parent().remove_child(placed_object)
		placed_object.queue_free()


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
	_play_ui_pop_sound()
	get_viewport().set_input_as_handled()


func _on_placed_object_removed(placed_object: CollisionObject2D) -> void:
	placed_objects.erase(placed_object)


func _play_ui_pop_sound() -> void:
	var button_sfx := get_node_or_null("/root/ButtonSfx")
	if button_sfx != null:
		button_sfx.call("play_click_sound")


func _on_raid_button_pressed() -> void:
	if raid_finished or raid_started:
		return
	var pearls := _get_level_pearls()
	if pearls.is_empty():
		return
	initial_placed_block_count = _count_current_placed_blocks()
	_current_structure_face_index = -1
	structure_face_panel.show()
	_update_structure_face()
	raid_started = true
	start_button.text = "진행 중"
	start_button.disabled = true
	save_layout_button.disabled = true
	load_layout_button.disabled = true
	ammunition_panel.show()
	_start_attack_sequence()


func _count_current_placed_blocks() -> int:
	var block_count := 0
	for placed_object in placed_objects:
		if (
			placed_object is PhysicsBlock
			and is_instance_valid(placed_object)
			and not placed_object.is_queued_for_deletion()
		):
			block_count += 1
	return block_count


func _remove_fallen_blocks() -> void:
	for placed_object in placed_objects:
		if (
			not placed_object is PhysicsBlock
			or not is_instance_valid(placed_object)
			or placed_object.is_queued_for_deletion()
		):
			continue
		var block := placed_object as PhysicsBlock
		if _get_block_lowest_world_y(block) < FALLEN_BLOCK_REMOVAL_Y:
			continue
		block.queue_free()


func _get_block_lowest_world_y(block: PhysicsBlock) -> float:
	if block == null or not is_instance_valid(block):
		return -INF
	var collision := block.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return block.global_position.y
	var polygon := collision.shape as ConvexPolygonShape2D
	if polygon == null or polygon.points.is_empty():
		return block.global_position.y
	var lowest_y := -INF
	for point in polygon.points:
		lowest_y = maxf(lowest_y, (collision.global_transform * point).y)
	return lowest_y


func _update_structure_face() -> void:
	if not structure_face_panel.visible:
		return
	var current_block_count := _count_current_placed_blocks()
	var remaining_ratio := _get_remaining_block_ratio(current_block_count)
	var face_index := _get_structure_score_index(remaining_ratio)
	if face_index != _current_structure_face_index:
		_current_structure_face_index = face_index
		structure_face_texture.texture = STRUCTURE_FACE_TEXTURES[face_index]
	structure_face_panel.tooltip_text = "남은 블록: %d / %d (%d%%)" % [
		current_block_count,
		initial_placed_block_count,
		roundi(remaining_ratio * 100.0),
	]


func _get_remaining_block_ratio(current_block_count := -1) -> float:
	var resolved_count := (
		_count_current_placed_blocks() if current_block_count < 0 else current_block_count
	)
	if initial_placed_block_count <= 0:
		return 0.0
	return clampf(float(resolved_count) / float(initial_placed_block_count), 0.0, 1.0)


func _get_structure_score_index(remaining_ratio: float) -> int:
	for index in STRUCTURE_FACE_THRESHOLDS.size():
		if remaining_ratio >= STRUCTURE_FACE_THRESHOLDS[index]:
			return index
	return STRUCTURE_SCORE_LABELS.size() - 1


func _get_level_pearls() -> Array[Pearl]:
	var pearls: Array[Pearl] = []
	for candidate in get_tree().get_nodes_in_group("pearls"):
		if (
			candidate is Pearl
			and is_instance_valid(candidate)
			and not candidate.is_queued_for_deletion()
			and world.is_ancestor_of(candidate)
		):
			pearls.append(candidate)
	return pearls


func _is_pearl_outside_play_area(pearl: Pearl) -> bool:
	if pearl == null or not is_instance_valid(pearl) or pearl.is_queued_for_deletion():
		return true
	var pearl_position := world.global_transform.affine_inverse() * pearl.global_position
	return (
		pearl_position.x + Pearl.RADIUS < 0.0
		or pearl_position.x - Pearl.RADIUS > WORLD_WIDTH
		or pearl_position.y + Pearl.RADIUS < 0.0
		or pearl_position.y - Pearl.RADIUS > pearl_game_over_y
	)


func _on_catapult_raid_finished() -> void:
	if raid_finished:
		return
	var pre_clear_delay := maxf(SUCCESS_RESULT_DELAY - CLEAR_TO_RESULT_DELAY, 0.0)
	if pre_clear_delay > 0.0:
		await get_tree().create_timer(pre_clear_delay).timeout
	if raid_finished:
		return
	if not _is_level_success_state():
		_finish_raid(true)
		return
	_clear_audio_player.play()
	await get_tree().create_timer(CLEAR_TO_RESULT_DELAY).timeout
	if raid_finished:
		return
	if not _is_level_success_state():
		_finish_raid(true)
		return
	_finish_raid()


func _is_level_success_state() -> bool:
	var pearls := _get_level_pearls()
	if pearls.is_empty():
		return false
	for pearl in pearls:
		if _is_pearl_outside_play_area(pearl):
			return false
	return true


func _finish_raid(force_failure := false) -> void:
	if raid_finished:
		return
	raid_finished = true
	_stop_attack_sequence()
	start_button.disabled = true
	var success := not force_failure and _is_level_success_state()
	if success:
		var score_index := _get_structure_score_index(_get_remaining_block_ratio())
		result_text.text = "레벨 %d 성공!" % level_number
		result_score_label.text = STRUCTURE_SCORE_LABELS[score_index]
		result_score_label.show()
		result_button.text = "다음 레벨" if level_number < 3 else "메인 화면"
		result_button.set_meta("success", true)
	else:
		result_text.text = "실패"
		result_score_label.hide()
		result_button.text = "다시 시도"
		result_button.set_meta("success", false)
		_failed_audio_player.play()
	result_overlay.show()

func _on_result_button_pressed() -> void:
	var success := bool(result_button.get_meta("success", false))
	if not success:
		get_tree().reload_current_scene()
	elif level_number < 3:
		get_tree().change_scene_to_file("res://scenes/level_%d.tscn" % (level_number + 1))
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _setup_attack_sequence() -> void:
	catapults.clear()
	for candidate in get_tree().get_nodes_in_group("catapults"):
		if candidate is Catapult and world.is_ancestor_of(candidate):
			candidate.stop_raid()
			candidate.auto_start = false
			catapults.append(candidate)
	catapults.sort_custom(_sort_catapults_bottom_to_top)
	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_fire_next_catapult)
	add_child(_attack_timer)


func _sort_catapults_bottom_to_top(first: Catapult, second: Catapult) -> bool:
	return first.global_position.y > second.global_position.y


func _start_attack_sequence() -> void:
	_remaining_catapult_shots.clear()
	_remaining_bomb_shots.clear()
	_next_catapult_index = 0
	for current_catapult in catapults:
		_remaining_catapult_shots.append(maxi(0, current_catapult.projectile_count))
		_remaining_bomb_shots.append(maxi(0, current_catapult.bomb_projectile_count))
	_update_ammunition_display()
	if not _has_remaining_catapult_shots():
		_on_catapult_raid_finished()
		return
	_attack_timer.start(maxf(0.1, catapults[0].fire_interval))


func _fire_next_catapult() -> void:
	if raid_finished or catapults.is_empty():
		return
	var chosen_index := -1
	for offset in catapults.size():
		var candidate_index := (_next_catapult_index + offset) % catapults.size()
		if (
			_remaining_bomb_shots[candidate_index] > 0
			or _remaining_catapult_shots[candidate_index] > 0
		):
			chosen_index = candidate_index
			break
	if chosen_index < 0:
		_on_catapult_raid_finished()
		return
	var firing_catapult := catapults[chosen_index]
	var use_bomb := _remaining_bomb_shots[chosen_index] > 0
	firing_catapult.fire_once(use_bomb)
	if use_bomb:
		_remaining_bomb_shots[chosen_index] -= 1
	else:
		_remaining_catapult_shots[chosen_index] -= 1
	_update_ammunition_display()
	_next_catapult_index = (chosen_index + 1) % catapults.size()
	if not _has_remaining_catapult_shots():
		_on_catapult_raid_finished()
		return
	_attack_timer.start(maxf(0.1, firing_catapult.fire_interval))


func _update_ammunition_display() -> void:
	var normal_ammo := 0
	var bomb_ammo := 0
	for remaining in _remaining_catapult_shots:
		normal_ammo += maxi(remaining, 0)
	for remaining in _remaining_bomb_shots:
		bomb_ammo += maxi(remaining, 0)
	normal_ammo_label.text = "일반 탄환: %d" % normal_ammo
	bomb_ammo_label.text = "폭탄 탄환: %d" % bomb_ammo
	# 컨테이너가 두 텍스트와 내부 여백만큼만 차지하도록 다시 맞춥니다.
	ammunition_panel.reset_size()
	ammunition_panel.call_deferred("reset_size")


func _has_remaining_catapult_shots() -> bool:
	for index in _remaining_catapult_shots.size():
		if _remaining_bomb_shots[index] > 0 or _remaining_catapult_shots[index] > 0:
			return true
	return false


func _stop_attack_sequence() -> void:
	if _attack_timer != null:
		_attack_timer.stop()
	for current_catapult in catapults:
		current_catapult.stop_raid()
