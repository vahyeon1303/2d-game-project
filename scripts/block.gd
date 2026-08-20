@tool
class_name PhysicsBlock
extends RigidBody2D

## Reusable construction block whose mass and durability are calculated from
## the selected material density and 2D volume (area with unit depth).

enum BlockShape {
	SQUARE,
	HALF_SQUARE,
	RECTANGLE,
	LARGE,
	PLATFORM,
	ROD,
	SLOPE,
}

enum BlockMaterial {
	WOOD,
	STONE,
	METAL,
}

const MATERIAL_COLORS := {
	BlockMaterial.WOOD: Color("#d4d4d4"),
	BlockMaterial.STONE: Color("#8a8a8a"),
	BlockMaterial.METAL: Color("#343434"),
}

const MATERIAL_TEXTURES := {
	BlockMaterial.WOOD: preload("res://Asset/WoodBlock.png"),
	BlockMaterial.STONE: preload("res://Asset/StoneBlock.png"),
	BlockMaterial.METAL: preload("res://Asset/MetalBlock.png"),
}

const BROKEN_TEXTURE := preload("res://Asset/Broken.png")
const BLOCK_DEBRIS_SCRIPT := preload("res://scripts/block_debris.gd")

const MATERIAL_HIT_SOUNDS := {
	BlockMaterial.WOOD: [
		preload("res://Asset/Wood_Hit_1.mp3"),
		preload("res://Asset/Wood_Hit_2.mp3"),
	],
	BlockMaterial.STONE: [
		preload("res://Asset/Stone_Hit_1.mp3"),
		preload("res://Asset/Stone_Hit_2.mp3"),
	],
	BlockMaterial.METAL: [
		preload("res://Asset/Metal_Hit_1.mp3"),
		preload("res://Asset/Metal_Hit_2.mp3"),
	],
}

const MATERIAL_COLLISION_SOUNDS := {
	BlockMaterial.WOOD: preload("res://Asset/Wood_Collision.mp3"),
	BlockMaterial.STONE: preload("res://Asset/Stone_Collision.mp3"),
	BlockMaterial.METAL: preload("res://Asset/Metal_Collision.mp3"),
}

const GLOBAL_SOUND_GAP_MSEC := 75

static var _last_global_sound_msec := -1000000

const MATERIAL_DENSITIES := {
	BlockMaterial.WOOD: 2,
	BlockMaterial.STONE: 3.5,
	BlockMaterial.METAL: 5,
}

const MATERIAL_FRICTION := {
	BlockMaterial.WOOD: 0.82,
	BlockMaterial.STONE: 1.0,
	BlockMaterial.METAL: 0.28,
}

const MATERIAL_BOUNCE := {
	BlockMaterial.WOOD: 0.03,
	BlockMaterial.STONE: 0.01,
	BlockMaterial.METAL: 0.1,
}

const MATERIAL_LINEAR_DAMP := {
	BlockMaterial.WOOD: 1.2,
	BlockMaterial.STONE: 0.6,
	BlockMaterial.METAL: 0.05,
}

const MATERIAL_ANGULAR_DAMP := {
	BlockMaterial.WOOD: 1.5,
	BlockMaterial.STONE: 0.8,
	BlockMaterial.METAL: 0.05,
}

@export var block_shape: BlockShape = BlockShape.SQUARE:
	set(value):
		block_shape = value
		if is_inside_tree():
			_refresh_block()

@export var block_material: BlockMaterial = BlockMaterial.WOOD:
	set(value):
		block_material = value
		if is_inside_tree():
			_refresh_block()

## Pixel size of one design unit. The planned sizes are expressed in these units.
@export_range(16.0, 128.0, 0.1) var unit_size := 44.8:
	set(value):
		unit_size = value
		if is_inside_tree():
			_refresh_block()

@export var flipped_horizontally := false:
	set(value):
		flipped_horizontally = value
		if is_inside_tree():
			_refresh_block()

@export_category("내구도")
## 부피와 재질 밀도로 계산한 질량 1당 최대 내구도입니다.
@export_range(1.0, 10000.0, 10.0, "or_greater") var durability_per_mass := 1200.0
## 포탄의 상대속도와 무게를 실제 피해량으로 변환하는 배율입니다.
@export_range(0.001, 10.0, 0.01, "or_greater") var projectile_damage_scale := 0.1
## 정사각형 블록 한 칸이 파괴될 때 생성되는 기본 파편 수입니다.
@export_range(1, 40, 1) var destruction_particle_count := 10
@export_range(1.0, 16.0, 0.5) var destruction_particle_min_size := 4.5
@export_range(1.0, 20.0, 0.5) var destruction_particle_max_size := 8.0

@export_category("충돌 효과음")
## 이 속도보다 느린 일반 충돌은 재생하지 않습니다. 단위는 픽셀/초입니다.
@export_range(0.0, 1000.0, 5.0, "or_greater") var minimum_collision_speed := 110.0
## 이 속도보다 느린 포탄 충돌은 재생하지 않습니다. 단위는 픽셀/초입니다.
@export_range(0.0, 1000.0, 5.0, "or_greater") var minimum_projectile_hit_speed := 160.0
## 같은 블록에서 충돌음이 연속으로 재생되는 것을 막는 시간입니다.
@export_range(0.0, 2.0, 0.01, "or_greater") var collision_sound_cooldown := 0.18
@export_range(-40.0, 0.0, 0.5) var collision_sound_volume_db := -4.0

var _audio_player: AudioStreamPlayer2D
var _last_sound_msec := -1000000
var _previous_linear_velocity := Vector2.ZERO
var _previous_angular_velocity := 0.0
var max_durability := 1.0
var current_durability := 1.0
var _durability_initialized := false
var _destroyed := false


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_refresh_block()
	_previous_linear_velocity = linear_velocity
	_previous_angular_velocity = angular_velocity
	body_entered.connect(_on_body_entered)
	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.name = "CollisionAudio"
	_audio_player.max_distance = 1600.0
	_audio_player.attenuation = 0.7
	add_child(_audio_player)


func _physics_process(_delta: float) -> void:
	_previous_linear_velocity = linear_velocity
	_previous_angular_velocity = angular_velocity


func _draw() -> void:
	var points := _get_polygon()
	if points.size() < 3:
		return
	var texture: Texture2D = MATERIAL_TEXTURES[block_material]
	draw_colored_polygon(points, Color.WHITE, _get_texture_uvs(), texture)
	var damage_alpha := get_damage_ratio()
	if damage_alpha > 0.0:
		draw_colored_polygon(
			points,
			Color(1.0, 1.0, 1.0, damage_alpha),
			_get_broken_texture_uvs(),
			BROKEN_TEXTURE
		)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color("#b8b8b8"), 2.0, true)


func _refresh_block() -> void:
	queue_redraw()
	var durability_ratio := 1.0
	if _durability_initialized and max_durability > 0.0:
		durability_ratio = clampf(current_durability / max_durability, 0.0, 1.0)
	mass = _get_area_units() * float(MATERIAL_DENSITIES[block_material])
	max_durability = mass * durability_per_mass
	current_durability = max_durability * durability_ratio
	_durability_initialized = true
	var material := PhysicsMaterial.new()
	material.friction = float(MATERIAL_FRICTION[block_material])
	material.bounce = float(MATERIAL_BOUNCE[block_material])
	physics_material_override = material
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = float(MATERIAL_LINEAR_DAMP[block_material])
	angular_damp = float(MATERIAL_ANGULAR_DAMP[block_material])
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var polygon_shape := ConvexPolygonShape2D.new()
	polygon_shape.points = _get_polygon()
	collision.shape = polygon_shape


func _on_body_entered(body: Node) -> void:
	if _destroyed or not is_instance_valid(body):
		return
	var is_projectile := body is CatapultStone
	var impact_speed := _get_impact_speed(body)
	if is_projectile and _apply_projectile_damage(body as CatapultStone, impact_speed):
		return
	if _audio_player == null:
		return
	var minimum_speed := (
		minimum_projectile_hit_speed if is_projectile else minimum_collision_speed
	)
	if impact_speed < minimum_speed:
		return
	if body is PhysicsBlock and not _should_handle_block_collision(body):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_sound_msec < int(collision_sound_cooldown * 1000.0):
		return
	if now_msec - _last_global_sound_msec < GLOBAL_SOUND_GAP_MSEC:
		return
	var stream: AudioStream
	if is_projectile:
		var hit_sounds: Array = MATERIAL_HIT_SOUNDS[block_material]
		stream = hit_sounds.pick_random() as AudioStream
	else:
		stream = MATERIAL_COLLISION_SOUNDS[block_material] as AudioStream
	if stream == null:
		return
	_last_sound_msec = now_msec
	_last_global_sound_msec = now_msec
	var strength := clampf((impact_speed - minimum_speed) / maxf(minimum_speed * 3.0, 1.0), 0.0, 1.0)
	_audio_player.stream = stream
	_audio_player.volume_db = collision_sound_volume_db + lerpf(-5.0, 0.0, strength)
	_audio_player.pitch_scale = randf_range(0.96, 1.04)
	_audio_player.play()


func get_damage_ratio() -> float:
	if max_durability <= 0.0:
		return 0.0
	return 1.0 - clampf(current_durability / max_durability, 0.0, 1.0)


func _apply_projectile_damage(projectile: CatapultStone, impact_speed: float) -> bool:
	if _destroyed or projectile == null:
		return _destroyed
	var damage := maxf(impact_speed, 0.0) * projectile.mass * projectile_damage_scale
	if damage <= 0.0:
		return false
	current_durability = maxf(0.0, current_durability - damage)
	queue_redraw()
	if current_durability > 0.0:
		return false
	_destroyed = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_deferred("freeze", true)
	call_deferred("_destroy_block")
	return true


func _destroy_block() -> void:
	if not is_inside_tree():
		return
	_spawn_destruction_particles()
	_play_destruction_sound()
	queue_free()


func _spawn_destruction_particles() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var polygon := _get_polygon()
	var particle_count := maxi(
		1,
		int(round(float(destruction_particle_count) * sqrt(_get_area_units())))
	)
	var texture: Texture2D = MATERIAL_TEXTURES[block_material]
	var density := float(MATERIAL_DENSITIES[block_material])
	var minimum_size := minf(destruction_particle_min_size, destruction_particle_max_size)
	var maximum_size := maxf(destruction_particle_min_size, destruction_particle_max_size)
	for index in particle_count:
		var local_point := _get_random_point_in_polygon(polygon)
		var debris = BLOCK_DEBRIS_SCRIPT.new()
		debris.configure(texture, density, randf_range(minimum_size, maximum_size))
		parent.add_child(debris)
		debris.global_position = to_global(local_point)
		debris.global_rotation = global_rotation + randf_range(-PI, PI)
		var radial_direction: Vector2 = (
			Vector2(debris.global_position) - global_position
		).normalized()
		if radial_direction == Vector2.ZERO:
			radial_direction = Vector2.from_angle(randf_range(-PI, 0.0))
		var upward_direction := Vector2.from_angle(randf_range(-PI, 0.0))
		var burst_direction: Vector2 = (
			radial_direction + upward_direction * 0.8
		).normalized()
		debris.linear_velocity = linear_velocity + burst_direction * randf_range(140.0, 300.0)
		debris.angular_velocity = angular_velocity + randf_range(-14.0, 14.0)
		debris.reset_physics_interpolation()


func _get_random_point_in_polygon(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	for attempt in 12:
		var candidate := Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			return candidate
	return Vector2.ZERO


func _play_destruction_sound() -> void:
	var parent := get_parent()
	var stream := MATERIAL_COLLISION_SOUNDS[block_material] as AudioStream
	if parent == null or stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.name = "BlockDestructionAudio"
	player.stream = stream
	player.volume_db = collision_sound_volume_db
	player.pitch_scale = randf_range(0.96, 1.04)
	player.max_distance = 1600.0
	player.attenuation = 0.7
	parent.add_child(player)
	player.global_position = global_position
	player.finished.connect(player.queue_free)
	player.play()


func _get_impact_speed(body: Node) -> float:
	var other_velocity := Vector2.ZERO
	var other_previous_velocity := Vector2.ZERO
	var other_angular_surface_speed := 0.0
	if body is PhysicsBlock:
		other_velocity = body.linear_velocity
		other_previous_velocity = body._previous_linear_velocity
		other_angular_surface_speed = body._get_angular_surface_speed()
	elif body is CatapultStone:
		other_velocity = body.linear_velocity
		other_previous_velocity = body.previous_linear_velocity
	elif body is RigidBody2D:
		other_velocity = body.linear_velocity
		other_previous_velocity = other_velocity
	var current_relative_speed := (linear_velocity - other_velocity).length()
	var previous_relative_speed := (
		_previous_linear_velocity - other_previous_velocity
	).length()
	return maxf(
		maxf(current_relative_speed, previous_relative_speed),
		maxf(_get_angular_surface_speed(), other_angular_surface_speed)
	)


func _get_angular_surface_speed() -> float:
	var dimensions := _get_dimensions_units() * unit_size
	var radius := dimensions.length() * 0.5
	return maxf(absf(angular_velocity), absf(_previous_angular_velocity)) * radius


func _get_recent_motion_speed() -> float:
	return maxf(
		maxf(linear_velocity.length(), _previous_linear_velocity.length()),
		_get_angular_surface_speed()
	)


func _should_handle_block_collision(other: PhysicsBlock) -> bool:
	var own_speed := _get_recent_motion_speed()
	var other_speed := other._get_recent_motion_speed()
	if not is_equal_approx(own_speed, other_speed):
		return own_speed > other_speed
	return get_instance_id() < other.get_instance_id()


func _get_polygon() -> PackedVector2Array:
	var dimensions := _get_dimensions_units() * unit_size
	var half := dimensions * 0.5
	var points: PackedVector2Array
	if block_shape == BlockShape.SLOPE:
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
	if flipped_horizontally:
		for index in points.size():
			var point := points[index]
			point.x *= -1.0
			points[index] = point
	return points


func _get_dimensions_units() -> Vector2:
	match block_shape:
		BlockShape.SQUARE:
			return Vector2(1.0, 1.0)
		BlockShape.HALF_SQUARE:
			return Vector2(1.0, 0.5)
		BlockShape.RECTANGLE:
			return Vector2(2.0, 1.0)
		BlockShape.LARGE:
			return Vector2(2.0, 2.0)
		BlockShape.PLATFORM:
			return Vector2(0.5, 3.0)
		BlockShape.ROD:
			return Vector2(0.25, 3.0)
		BlockShape.SLOPE:
			return Vector2(3.0, 2.0)
	return Vector2.ONE


func _get_texture_uvs() -> PackedVector2Array:
	var dimensions := _get_dimensions_units()
	if block_shape == BlockShape.SLOPE:
		return PackedVector2Array([
			Vector2(0.0, dimensions.y),
			dimensions,
			Vector2(dimensions.x, 0.0),
		])
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(dimensions.x, 0.0),
		dimensions,
		Vector2(0.0, dimensions.y),
	])


func _get_broken_texture_uvs() -> PackedVector2Array:
	if block_shape == BlockShape.SLOPE:
		return PackedVector2Array([
			Vector2(0.0, 1.0),
			Vector2.ONE,
			Vector2(1.0, 0.0),
		])
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(1.0, 0.0),
		Vector2.ONE,
		Vector2(0.0, 1.0),
	])


func _get_area_units() -> float:
	var dimensions := _get_dimensions_units()
	var area := dimensions.x * dimensions.y
	if block_shape == BlockShape.SLOPE:
		area *= 0.5
	return area
