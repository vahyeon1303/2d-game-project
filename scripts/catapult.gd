class_name Catapult
extends StaticBody2D

signal raid_finished

const PROJECTILE_SCENE := preload("res://objects/catapult_stone.tscn")
const SIZE := 64.0
const MUZZLE_DISTANCE := 47.0

@export_category("발사 설정")
@export_range(100.0, 1600.0, 10.0) var launch_speed := 850.0
@export_range(0.5, 10.0, 0.1) var fire_interval := 3.0
## 0이면 샌드박스처럼 제한 없이 계속 발사합니다.
@export_range(0, 100, 1) var projectile_count := 0
@export var auto_start := true

var arm_angle_local := -PI * 0.25
var _shots_attempted := 0
var _raid_active := false
var _fire_timer: Timer


func _ready() -> void:
	add_to_group("catapults")
	_fire_timer = Timer.new()
	_fire_timer.wait_time = fire_interval
	_fire_timer.timeout.connect(_on_fire_timeout)
	add_child(_fire_timer)
	if auto_start:
		start_raid()
	queue_redraw()


func start_raid() -> void:
	_shots_attempted = 0
	_raid_active = true
	_fire_timer.wait_time = fire_interval
	_fire_timer.start()


func stop_raid() -> void:
	_raid_active = false
	if _fire_timer != null:
		_fire_timer.stop()


func _draw() -> void:
	draw_rect(Rect2(-32, 11, 64, 18), Color("#71451f"), true)
	draw_rect(Rect2(-31, 10, 62, 19), Color("#a36a32"), false, 2.0)
	draw_circle(Vector2(-21, 25), 7.0, Color("#343941"))
	draw_circle(Vector2(21, 25), 7.0, Color("#343941"))
	draw_circle(Vector2(-21, 25), 3.5, Color("#7b828c"))
	draw_circle(Vector2(21, 25), 3.5, Color("#7b828c"))
	draw_line(Vector2(0, 14), Vector2.from_angle(arm_angle_local) * 24.0, Color("#bd7d3e"), 7.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color("#4a5059"))
	var cup_position := Vector2.from_angle(arm_angle_local) * 26.0
	draw_circle(cup_position, 6.0, Color("#59606a"))


func _on_fire_timeout() -> void:
	if not _raid_active:
		return
	_try_fire()
	if projectile_count <= 0:
		return
	_shots_attempted += 1
	if _shots_attempted >= projectile_count:
		stop_raid()
		raid_finished.emit()


func _try_fire() -> bool:
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
	var stone := PROJECTILE_SCENE.instantiate() as CatapultStone
	get_parent().add_child(stone)
	stone.global_position = muzzle_position
	stone.linear_velocity = velocity
	return true


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
	if gravity <= 0.0:
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
