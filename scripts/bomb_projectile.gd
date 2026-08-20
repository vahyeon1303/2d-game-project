class_name BombProjectile
extends RigidBody2D

const RADIUS := 12.0
const EXPLOSION_RADIUS := 160.0
const LIFETIME_SECONDS := 12.0
const SOURCE_CLEAR_DISTANCE := 80.0
const TEXTURE := preload("res://Asset/Ammo.png")
const TEXTURE_REGION := Rect2(49.0, 49.0, 254.0, 254.0)
const EXPLOSION_SOUND := preload("res://Asset/boom.mp3")
const BLOCK_SIZE := 44.8
const EXPLOSION_PARTICLE_COUNT := 5
const EXPLOSION_FIRE_VISUAL_SCALE := 10.0
const EXPLOSION_FIRE_FRAMES_PER_SECOND := 45.0
const SMOKE_VISUAL_SCALE := 5.0
const EXPLOSION_VFX_SCRIPT := preload("res://scripts/explosion_vfx_particle.gd")
const SEQUENCE_PLAYER_SCRIPT := preload("res://scripts/vfx_sequence_player.gd")
const EXPLOSION_FIRE_TEXTURE := preload("res://Asset/VFX/Generated/explosion_fire_sheet.png")
const SMOKE_TEXTURES: Array[Texture2D] = [
	preload("res://Asset/VFX/Generated/smoke_1_sheet.png"),
	preload("res://Asset/VFX/Generated/smoke_2_sheet.png"),
	preload("res://Asset/VFX/Generated/smoke_3_sheet.png"),
]
const SMOKE_COLUMNS := [8, 16, 16]
const SMOKE_FRAME_COUNTS := [63, 145, 197]

var explosion_force := 2500.0
var _exploded := false
var _source_body: PhysicsBody2D
var _impact_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("catapult_stones")
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(LIFETIME_SECONDS).timeout.connect(queue_free)


func _draw() -> void:
	var diameter := RADIUS * 2.0
	var destination := Rect2(Vector2.ONE * -RADIUS, Vector2.ONE * diameter)
	draw_texture_rect_region(TEXTURE, destination, TEXTURE_REGION)


func ignore_source_until_clear(source_body: PhysicsBody2D) -> void:
	if source_body == null:
		return
	_source_body = source_body
	add_collision_exception_with(_source_body)


func _physics_process(_delta: float) -> void:
	if _source_body == null:
		return
	if not is_instance_valid(_source_body):
		_source_body = null
		return
	if global_position.distance_to(_source_body.global_position) <= SOURCE_CLEAR_DISTANCE:
		return
	remove_collision_exception_with(_source_body)
	_source_body = null


func _on_body_entered(_body: Node) -> void:
	if _exploded:
		return
	_exploded = true
	_impact_position = global_position
	visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("freeze", true)
	call_deferred("_explode")


func _explode() -> void:
	if not is_inside_tree():
		return
	_play_explosion_sound()
	_spawn_explosion_fire()
	_spawn_explosion_particles()
	_spawn_world_smoke()
	var circle := CircleShape2D.new()
	circle.radius = EXPLOSION_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 64)
	for hit in hits:
		var body := hit.get("collider") as RigidBody2D
		if body == null or not is_instance_valid(body):
			continue
		var offset := body.global_position - global_position
		var distance := offset.length()
		if distance > EXPLOSION_RADIUS:
			continue
		var direction := offset.normalized() if distance > 0.001 else Vector2.UP
		var falloff := clampf(1.0 - distance / EXPLOSION_RADIUS, 0.2, 1.0)
		body.apply_central_impulse(direction * maxf(explosion_force, 0.0) * falloff)
	queue_free()


func _play_explosion_sound() -> void:
	var world_parent := get_parent()
	if world_parent == null or EXPLOSION_SOUND == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.name = "BombExplosionAudio"
	player.stream = EXPLOSION_SOUND
	player.volume_db = -2.0
	player.max_distance = 2400.0
	player.attenuation = 0.6
	world_parent.add_child(player)
	player.global_position = _impact_position
	player.finished.connect(player.queue_free)
	player.play()


func _spawn_explosion_fire() -> void:
	var world_parent := get_parent() as Node2D
	if world_parent == null:
		return
	var fire_effect := SEQUENCE_PLAYER_SCRIPT.new() as Node2D
	fire_effect.name = "ExplosionFireVFX"
	fire_effect.z_index = 14
	world_parent.add_child(fire_effect)
	fire_effect.add_to_group("explosion_fire_vfx")
	fire_effect.global_position = _impact_position
	fire_effect.global_rotation = 0.0
	fire_effect.configure(
		EXPLOSION_FIRE_TEXTURE,
		Vector2i(128, 128),
		8,
		63,
		EXPLOSION_FIRE_FRAMES_PER_SECOND,
		Vector2.ONE * BLOCK_SIZE * EXPLOSION_FIRE_VISUAL_SCALE
	)
	fire_effect.connect("animation_finished", fire_effect.queue_free)


func _spawn_explosion_particles() -> void:
	var world_parent := get_parent()
	if world_parent == null:
		return
	for index in EXPLOSION_PARTICLE_COUNT:
		var angle := TAU * float(index) / float(EXPLOSION_PARTICLE_COUNT) + randf_range(-0.28, 0.28)
		var direction := Vector2.from_angle(angle)
		var particle := EXPLOSION_VFX_SCRIPT.new() as RigidBody2D
		world_parent.add_child(particle)
		particle.global_position = _impact_position + direction * randf_range(36.0, 64.0)
		particle.linear_velocity = linear_velocity * 0.12 + direction * randf_range(110.0, 220.0)
		particle.reset_physics_interpolation()


func _spawn_world_smoke() -> void:
	var smoke_parent := get_parent() as Node2D
	if smoke_parent == null:
		return
	var smoke_count := randi_range(1, 3)
	for _index in smoke_count:
		var smoke_kind := randi_range(0, SMOKE_TEXTURES.size() - 1)
		var smoke := SEQUENCE_PLAYER_SCRIPT.new() as Node2D
		smoke.z_index = 11
		smoke_parent.add_child(smoke)
		var direction := Vector2.from_angle(randf_range(0.0, TAU))
		smoke.global_position = _impact_position + direction * randf_range(18.0, 72.0)
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
