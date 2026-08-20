class_name Catapult
extends StaticBody2D

signal raid_finished

const PROJECTILE_SCENE := preload("res://objects/catapult_stone.tscn")
const BOMB_PROJECTILE_SCENE := preload("res://objects/bomb_projectile.tscn")
const TEXTURE := preload("res://Asset/Cannon.png")
const SHOT_SOUND := preload("res://Asset/Shot.mp3")
const TEXTURE_REGION := Rect2(4.0, 144.0, 496.0, 212.0)
const SIZE := 64.0
const VISUAL_SIZE := Vector2(128.0, 54.70968)
const VISUAL_RECT := Rect2(-64.0, -22.70968, 128.0, 54.70968)
const MUZZLE_DISTANCE := 47.0
const SPEED_PER_POWER := 16.0

@export_category("발사 설정")
## 제한 없는 발사 파워입니다. 내부 물리 속도로 자동 환산됩니다.
@export var launch_power: float = 53.1
## 초 단위 발사 간격입니다. 1.0이면 1초마다 한 번 발사합니다.
@export_range(0.1, 60.0, 0.1, "or_greater") var fire_interval: float = 3.0
@export_range(0.1, 100.0, 0.1, "or_greater") var projectile_mass := 4.0
## 0이면 샌드박스처럼 제한 없이 계속 발사합니다.
@export_range(0, 100, 1) var projectile_count := 0
@export var auto_start := true

@export_category("폭탄 탄환")
## 0보다 크면 이 수량을 일반 탄환보다 먼저 발사합니다.
@export_range(0, 100, 1) var bomb_projectile_count := 0
## 폭발 범위 안의 물리 오브젝트에 가하는 순간적인 힘입니다.
@export var bomb_explosion_force: float = 2500.0

@export_category("효과음")
@export_range(-40.0, 6.0, 0.5) var shot_sound_volume_db := -4.0

var arm_angle_local := -PI * 0.25
var _shots_attempted := 0
var _bomb_shots_attempted := 0
var _raid_active := false
var _fire_timer: Timer
var _shot_audio_player: AudioStreamPlayer
var _sandbox_firing_mode := false
var _sandbox_stones_enabled := true
var _sandbox_bombs_enabled := false


func _ready() -> void:
	add_to_group("catapults")
	_fire_timer = Timer.new()
	_fire_timer.wait_time = fire_interval
	_fire_timer.timeout.connect(_on_fire_timeout)
	add_child(_fire_timer)
	_shot_audio_player = AudioStreamPlayer.new()
	_shot_audio_player.name = "ShotAudio"
	_shot_audio_player.stream = SHOT_SOUND
	_shot_audio_player.volume_db = shot_sound_volume_db
	_shot_audio_player.max_polyphony = 4
	add_child(_shot_audio_player)
	if auto_start:
		start_raid()
	queue_redraw()


func start_raid() -> void:
	_shots_attempted = 0
	_bomb_shots_attempted = 0
	_raid_active = true
	_fire_timer.wait_time = fire_interval
	_fire_timer.start()


func stop_raid() -> void:
	_raid_active = false
	if _fire_timer != null:
		_fire_timer.stop()


func configure_sandbox_firing(stones_enabled: bool, bombs_enabled: bool) -> void:
	_sandbox_firing_mode = true
	_sandbox_stones_enabled = stones_enabled
	_sandbox_bombs_enabled = bombs_enabled


func _draw() -> void:
	draw_texture_rect_region(TEXTURE, VISUAL_RECT, TEXTURE_REGION)


func _on_fire_timeout() -> void:
	if not _raid_active:
		return
	if _sandbox_firing_mode:
		_fire_sandbox_projectile()
		return
	var use_bomb := _bomb_shots_attempted < bomb_projectile_count
	if not fire_once(use_bomb):
		return
	if use_bomb:
		_bomb_shots_attempted += 1
	elif projectile_count > 0:
		_shots_attempted += 1
	if (
		projectile_count > 0
		and _bomb_shots_attempted >= bomb_projectile_count
		and _shots_attempted >= projectile_count
	):
		stop_raid()
		raid_finished.emit()


func _fire_sandbox_projectile() -> void:
	if not _sandbox_stones_enabled and not _sandbox_bombs_enabled:
		return
	fire_once(_sandbox_bombs_enabled)


func fire_once(use_bomb := false) -> bool:
	var target := _find_nearest_pearl()
	if target == null:
		return false

	var velocity := _calculate_launch_velocity(global_position, target.global_position)
	if velocity == Vector2.ZERO:
		return false
	var muzzle_position := global_position + velocity.normalized() * MUZZLE_DISTANCE
	velocity = _calculate_launch_velocity(muzzle_position, target.global_position)
	if velocity == Vector2.ZERO:
		return false

	arm_angle_local = velocity.angle() - global_rotation
	queue_redraw()
	var projectile_scene := BOMB_PROJECTILE_SCENE if use_bomb else PROJECTILE_SCENE
	var projectile := projectile_scene.instantiate() as RigidBody2D
	get_parent().add_child(projectile)
	if use_bomb:
		projectile.call("ignore_source_until_clear", self)
	projectile.global_position = muzzle_position
	projectile.mass = projectile_mass
	if use_bomb:
		projectile.set("explosion_force", bomb_explosion_force)
	projectile.reset_physics_interpolation()
	projectile.linear_velocity = velocity
	_shot_audio_player.play()
	return true


## 이전 테스트 및 장면과의 호환성을 위한 별칭입니다.
func _try_fire() -> bool:
	return fire_once()


func _find_nearest_pearl() -> Pearl:
	var nearest: Pearl = null
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("pearls"):
		if not candidate is Pearl or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _calculate_launch_velocity(origin: Vector2, target: Vector2) -> Vector2:
	var delta := target - origin
	var horizontal_distance := absf(delta.x)
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var launch_speed := launch_power * SPEED_PER_POWER
	if gravity <= 0.0:
		return Vector2.ZERO
	if launch_speed <= 0.0:
		return Vector2.ZERO

	if horizontal_distance < 1.0:
		var maximum_rise := launch_speed * launch_speed / (2.0 * gravity)
		if -delta.y > maximum_rise:
			return Vector2.ZERO
		return Vector2(0.0, -launch_speed)

	# 고정 발사력으로 가능한 저각 탄도를 계산합니다. 판별식이 음수이면
	# 현재 발사력으로 도달할 수 없으므로 발사하지 않습니다.
	var speed_squared := launch_speed * launch_speed
	var vertical_up := -delta.y
	var discriminant := (
		speed_squared * speed_squared
		- gravity * (gravity * horizontal_distance * horizontal_distance
		+ 2.0 * vertical_up * speed_squared)
	)
	if discriminant < 0.0:
		return Vector2.ZERO
	var tangent := (speed_squared - sqrt(discriminant)) / (gravity * horizontal_distance)
	var angle := atan(tangent)
	var horizontal_direction := signf(delta.x)
	return Vector2(
		horizontal_direction * launch_speed * cos(angle),
		-launch_speed * sin(angle)
	)
