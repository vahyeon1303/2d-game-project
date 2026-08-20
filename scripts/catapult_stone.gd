class_name CatapultStone
extends RigidBody2D

const RADIUS := 12.0
const LIFETIME_SECONDS := 5.0
const SMOKE_COOLDOWN_MSEC := 300
const TEXTURE := preload("res://Asset/Ammo.png")
const TEXTURE_REGION := Rect2(49.0, 49.0, 254.0, 254.0)
const BLOCK_SIZE := 44.8
const SMOKE_VISUAL_SCALE := 2.5
const SEQUENCE_PLAYER_SCRIPT := preload("res://scripts/vfx_sequence_player.gd")
const SMOKE_TEXTURES: Array[Texture2D] = [
	preload("res://Asset/VFX/Generated/smoke_1_sheet.png"),
	preload("res://Asset/VFX/Generated/smoke_2_sheet.png"),
	preload("res://Asset/VFX/Generated/smoke_3_sheet.png"),
]
const SMOKE_COLUMNS := [8, 16, 16]
const SMOKE_FRAME_COUNTS := [63, 145, 197]

var previous_linear_velocity := Vector2.ZERO
var _last_smoke_msec := -SMOKE_COOLDOWN_MSEC


func _ready() -> void:
	add_to_group("catapult_stones")
	body_entered.connect(_on_body_entered)
	previous_linear_velocity = linear_velocity
	queue_redraw()
	get_tree().create_timer(LIFETIME_SECONDS).timeout.connect(queue_free)


func _physics_process(_delta: float) -> void:
	previous_linear_velocity = linear_velocity


func _draw() -> void:
	var diameter := RADIUS * 2.0
	var destination := Rect2(Vector2.ONE * -RADIUS, Vector2.ONE * diameter)
	draw_texture_rect_region(TEXTURE, destination, TEXTURE_REGION)


func _on_body_entered(_body: Node) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_smoke_msec < SMOKE_COOLDOWN_MSEC:
		return
	_last_smoke_msec = now_msec
	_spawn_world_smoke()


func _spawn_world_smoke() -> void:
	var smoke_parent := get_parent() as Node2D
	if smoke_parent == null:
		return
	var impact_position := global_position
	var smoke_count := randi_range(1, 3)
	for _index in smoke_count:
		var smoke_kind := randi_range(0, SMOKE_TEXTURES.size() - 1)
		var smoke := SEQUENCE_PLAYER_SCRIPT.new() as Node2D
		smoke.z_index = 11
		smoke_parent.add_child(smoke)
		var direction := Vector2.from_angle(randf_range(0.0, TAU))
		smoke.global_position = impact_position + direction * randf_range(9.0, 36.0)
		smoke.global_rotation = randf_range(-0.25, 0.25)
		smoke.configure(
			SMOKE_TEXTURES[smoke_kind],
			Vector2i(96, 96),
			SMOKE_COLUMNS[smoke_kind],
			SMOKE_FRAME_COUNTS[smoke_kind],
			30.0,
			Vector2.ONE * BLOCK_SIZE * 2.0 * SMOKE_VISUAL_SCALE
		)
		smoke.connect("animation_finished", smoke.queue_free)
