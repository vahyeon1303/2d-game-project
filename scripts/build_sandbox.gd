extends Control

const SHAPE_FILES := [
	"square", "half_square", "rectangle", "large", "platform", "rod", "slope"
]
const SHAPE_NAMES := ["정사각형", "반사각형", "직사각형", "대형", "발판", "막대", "경사"]
const MATERIAL_FILES := ["wood", "stone", "metal"]
const MATERIAL_NAMES := ["나무", "석재", "금속"]
const BUILD_AREA_BOTTOM := 1080.0
const GROUND_TOP := BUILD_AREA_BOTTOM - 16.0
const ROTATION_STEP_RADIANS := PI / 12.0
const SANDBOX_DEFAULT_CATAPULT_POWER := 200.0
const SANDBOX_DEFAULT_FIRE_INTERVAL := 3.0
const SANDBOX_DEFAULT_EXPLOSION_FORCE := 2500.0

@onready var world: Node2D = %World
@onready var palette: HBoxContainer = %Palette
@onready var block_count: Label = %BlockCount
@onready var clear_button: Button = %ClearButton
@onready var save_layout_button: Button = %SaveLayoutButton
@onready var load_layout_button: Button = %LoadLayoutButton
@onready var layout_status_label: Label = %LayoutStatusLabel
@onready var catapult_toggle_button: Button = %CatapultToggleButton
@onready var bomb_toggle_button: Button = %BombToggleButton
@onready var fire_interval_spinbox: SpinBox = %FireIntervalSpinBox
@onready var launch_power_spinbox: SpinBox = %LaunchPowerSpinBox
@onready var explosion_force_spinbox: SpinBox = %ExplosionForceSpinBox

var placed_objects: Array[Node2D] = []
var _catapult_firing_enabled := true
var _bomb_firing_enabled := false
var _sandbox_fire_interval := SANDBOX_DEFAULT_FIRE_INTERVAL
var _sandbox_launch_power := SANDBOX_DEFAULT_CATAPULT_POWER
var _sandbox_explosion_force := SANDBOX_DEFAULT_EXPLOSION_FORCE
var layout_save_path := "user://sandbox_layout.json"


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_create_palette()
	clear_button.pressed.connect(_clear_blocks)
	save_layout_button.pressed.connect(_save_block_layout)
	load_layout_button.pressed.connect(_load_block_layout)
	catapult_toggle_button.pressed.connect(_toggle_catapult_firing)
	bomb_toggle_button.pressed.connect(_toggle_bomb_firing)
	fire_interval_spinbox.value_changed.connect(_on_fire_interval_changed)
	launch_power_spinbox.value_changed.connect(_on_launch_power_changed)
	explosion_force_spinbox.value_changed.connect(_on_explosion_force_changed)
	fire_interval_spinbox.value = _sandbox_fire_interval
	launch_power_spinbox.value = _sandbox_launch_power
	explosion_force_spinbox.value = _sandbox_explosion_force
	_update_catapult_toggle_button()
	_update_bomb_toggle_button()
	_update_block_count()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, GROUND_TOP, size.x, 32), Color("#4a4a4a"))
	draw_line(Vector2(0, GROUND_TOP), Vector2(size.x, GROUND_TOP), Color("#d0d0d0"), 4.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


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


func _is_escape_pressed(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	)


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
	if placed_object is Catapult:
		placed_object.auto_start = false
	world.add_child(placed_object)
	placed_object.global_position = Vector2(
		clampf(at_position.x, 16.0, size.x - 16.0),
		clampf(at_position.y, 16.0, BUILD_AREA_BOTTOM - 16.0)
	)
	placed_object.rotation = float(data.get("rotation_steps", 0)) * ROTATION_STEP_RADIANS
	if placed_object is PhysicsBlock:
		placed_object.flipped_horizontally = bool(data.get("flipped", false))
	elif placed_object is Catapult:
		_apply_catapult_firing_state(placed_object)
	placed_object.reset_physics_interpolation()
	_register_placed_object(placed_object)
	_update_block_count()
	_play_ui_pop_sound()


func _register_placed_object(placed_object: Node2D) -> void:
	if placed_object is CollisionObject2D:
		placed_object.input_pickable = true
		placed_object.input_event.connect(_on_placed_object_input.bind(placed_object))
	placed_objects.append(placed_object)
	placed_object.tree_exiting.connect(_on_object_removed.bind(placed_object))


func _create_palette() -> void:
	var pearl_item := BlockPaletteItem.new()
	pearl_item.configure("res://objects/pearl.tscn", 0, 0, "진주", "pearl")
	palette.add_child(pearl_item)

	var catapult_item := BlockPaletteItem.new()
	catapult_item.configure("res://objects/catapult.tscn", 0, 0, "투석기", "catapult")
	palette.add_child(catapult_item)

	var mortar_item := BlockPaletteItem.new()
	mortar_item.configure("res://objects/mortar.tscn", 0, 0, "박격포", "mortar")
	palette.add_child(mortar_item)

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
			item.tooltip_text += "\n%s" % _get_material_trait(material_index)
			palette.add_child(item)


func _get_material_trait(material_index: int) -> String:
	match material_index:
		PhysicsBlock.BlockMaterial.WOOD:
			return "가벼움 · 충격 감쇠가 빠름"
		PhysicsBlock.BlockMaterial.STONE:
			return "마찰력이 높아 기초에 안정적"
		PhysicsBlock.BlockMaterial.METAL:
			return "매우 무거움 · 미끄러지며 주변에 큰 충격"
	return ""


func _toggle_catapult_firing() -> void:
	_catapult_firing_enabled = not _catapult_firing_enabled
	if _catapult_firing_enabled:
		_bomb_firing_enabled = false
	_apply_firing_state_to_all_catapults()
	_update_catapult_toggle_button()
	_update_bomb_toggle_button()


func _toggle_bomb_firing() -> void:
	_bomb_firing_enabled = not _bomb_firing_enabled
	if _bomb_firing_enabled:
		_catapult_firing_enabled = false
	_apply_firing_state_to_all_catapults()
	_update_catapult_toggle_button()
	_update_bomb_toggle_button()


func _apply_firing_state_to_all_catapults() -> void:
	for candidate in get_tree().get_nodes_in_group("catapults"):
		if not candidate is Catapult or not world.is_ancestor_of(candidate):
			continue
		_apply_catapult_firing_state(candidate)


func _apply_catapult_firing_state(catapult: Catapult) -> void:
	catapult.launch_power = _sandbox_launch_power
	catapult.fire_interval = _sandbox_fire_interval
	catapult.bomb_explosion_force = _sandbox_explosion_force
	catapult.configure_sandbox_firing(_catapult_firing_enabled, _bomb_firing_enabled)
	catapult.auto_start = _catapult_firing_enabled or _bomb_firing_enabled
	if catapult.auto_start:
		catapult.start_raid()
	else:
		catapult.stop_raid()


func _on_fire_interval_changed(value: float) -> void:
	_sandbox_fire_interval = maxf(value, 0.1)
	_apply_firing_state_to_all_catapults()


func _on_launch_power_changed(value: float) -> void:
	_sandbox_launch_power = maxf(value, 0.1)
	_apply_firing_state_to_all_catapults()


func _on_explosion_force_changed(value: float) -> void:
	_sandbox_explosion_force = maxf(value, 0.0)
	_apply_firing_state_to_all_catapults()


func _update_catapult_toggle_button() -> void:
	catapult_toggle_button.text = (
		"돌 투척: 활성" if _catapult_firing_enabled else "돌 투척: 비활성"
	)


func _update_bomb_toggle_button() -> void:
	bomb_toggle_button.text = (
		"폭탄 탄환: 활성" if _bomb_firing_enabled else "폭탄 탄환: 비활성"
	)


func _on_placed_object_input(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int,
	placed_object: Node2D
) -> void:
	if get_viewport().gui_is_dragging() or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if not is_instance_valid(placed_object):
		return
	placed_objects.erase(placed_object)
	placed_object.queue_free()
	_update_block_count()
	_play_ui_pop_sound()
	get_viewport().set_input_as_handled()


func _play_ui_pop_sound() -> void:
	var button_sfx := get_node_or_null("/root/ButtonSfx")
	if button_sfx != null:
		button_sfx.call("play_click_sound")


func _save_block_layout() -> void:
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
	file.store_string(JSON.stringify({"version": 1, "blocks": saved_blocks}))
	file.close()
	layout_status_label.text = "블록 %d개 저장 완료" % saved_blocks.size()


func _load_block_layout() -> void:
	if not FileAccess.file_exists(layout_save_path):
		layout_status_label.text = "저장된 배치가 없습니다"
		return
	var file := FileAccess.open(layout_save_path, FileAccess.READ)
	if file == null:
		layout_status_label.text = "불러오기 실패"
		return
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not json.data is Dictionary:
		layout_status_label.text = "저장 파일이 올바르지 않습니다"
		return
	var saved_blocks: Variant = json.data.get("blocks", [])
	if not saved_blocks is Array:
		layout_status_label.text = "저장 파일이 올바르지 않습니다"
		return

	_remove_all_placed_objects()
	_remove_fired_projectiles()
	var loaded_count := 0
	for saved_block in saved_blocks:
		if _restore_saved_block(saved_block):
			loaded_count += 1
	_update_block_count()
	layout_status_label.text = "블록 %d개 불러오기 완료" % loaded_count


func _restore_saved_block(saved_block: Variant) -> bool:
	if not saved_block is Dictionary:
		return false
	var material_index := int(saved_block.get("material", -1))
	var shape_index := int(saved_block.get("shape", -1))
	if material_index < 0 or material_index >= MATERIAL_FILES.size():
		return false
	if shape_index < 0 or shape_index >= SHAPE_FILES.size():
		return false
	var position_data: Variant = saved_block.get("position", [])
	if not position_data is Array or position_data.size() < 2:
		return false
	var scene_path := "res://blocks/%s_%s.tscn" % [
		MATERIAL_FILES[material_index], SHAPE_FILES[shape_index]
	]
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
	_register_placed_object(block)
	return true


func _remove_all_placed_objects() -> void:
	var objects_to_remove := placed_objects.duplicate()
	placed_objects.clear()
	for placed_object in objects_to_remove:
		if not is_instance_valid(placed_object):
			continue
		if placed_object.get_parent() != null:
			placed_object.get_parent().remove_child(placed_object)
		placed_object.queue_free()


func _remove_fired_projectiles() -> void:
	for stone in get_tree().get_nodes_in_group("catapult_stones"):
		if is_instance_valid(stone):
			stone.queue_free()


func _clear_blocks() -> void:
	_remove_all_placed_objects()
	_remove_fired_projectiles()
	_update_block_count()


func _on_object_removed(placed_object: Node2D) -> void:
	placed_objects.erase(placed_object)
	_update_block_count()


func _update_block_count() -> void:
	if block_count != null:
		block_count.text = "배치된 오브젝트: %d" % placed_objects.size()
