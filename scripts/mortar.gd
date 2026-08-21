class_name Mortar
extends Catapult

const MORTAR_TEXTURE := preload("res://Asset/Mortar.png")
const MORTAR_TEXTURE_REGION := Rect2(99.0, 33.0, 301.0, 467.0)
const MORTAR_VISUAL_SIZE := Vector2(82.5, 128.0)
const MORTAR_VISUAL_RECT := Rect2(-41.25, -96.0, 82.5, 128.0)
const MUZZLE_OFFSET := 72.0

@export_category("박격포 설정")
## 발사 지점과 진주 중 더 높은 위치를 기준으로 확보할 탄도 정점의 높이입니다.
## 값이 클수록 더 가파르고 높은 각도로 발사합니다.
@export_range(160.0, 2400.0, 10.0, "or_greater") var mortar_arc_height := 560.0
## 고각 궤적의 비행 시간이 길 때 일반 탄환이 중간에 사라지지 않도록 하는 시간입니다.
@export_range(0.1, 60.0, 0.1, "or_greater") var mortar_projectile_lifetime := 12.0


func _draw() -> void:
	draw_texture_rect_region(MORTAR_TEXTURE, MORTAR_VISUAL_RECT, MORTAR_TEXTURE_REGION)


func fire_once(use_bomb := false) -> bool:
	var target := _find_nearest_pearl()
	if target == null:
		return false

	var muzzle_direction := Vector2.UP.rotated(global_rotation)
	var muzzle_position := global_position + muzzle_direction * MUZZLE_OFFSET
	var velocity := _calculate_launch_velocity(muzzle_position, target.global_position)
	if velocity == Vector2.ZERO:
		return false

	var projectile_scene := BOMB_PROJECTILE_SCENE if use_bomb else PROJECTILE_SCENE
	var projectile := projectile_scene.instantiate() as RigidBody2D
	if projectile == null:
		return false
	if projectile is CatapultStone:
		projectile.lifetime_seconds = mortar_projectile_lifetime
	get_parent().add_child(projectile)
	if use_bomb:
		projectile.call("ignore_source_until_clear", self)
	projectile.global_position = muzzle_position
	projectile.mass = projectile_mass
	# 고각 비행은 체공 시간이 길어 프로젝트 기본 감쇠의 작은 영향도
	# 낙하 지점을 크게 당깁니다. 계산한 궤적을 그대로 유지합니다.
	projectile.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	projectile.linear_damp = 0.0
	if use_bomb:
		projectile.set("explosion_force", bomb_explosion_force)
	projectile.reset_physics_interpolation()
	projectile.linear_velocity = velocity
	_shot_audio_player.play()
	return true


func _calculate_launch_velocity(origin: Vector2, target: Vector2) -> Vector2:
	var delta := target - origin
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var maximum_launch_speed := launch_power * SPEED_PER_POWER
	if gravity <= 0.0 or maximum_launch_speed <= 0.0:
		return Vector2.ZERO

	# 목표보다 일정 높이에 정점을 먼저 정한 뒤, 상승·하강 시간을 이용해
	# 수평 속도를 계산합니다. 과도하게 수직인 고각 해를 피하면서도
	# 진주에는 반드시 하강 방향으로 도달합니다.
	var apex_y := minf(origin.y, target.y) - maxf(mortar_arc_height, 1.0)
	var rise_distance := origin.y - apex_y
	var fall_distance := target.y - apex_y
	var vertical_speed := sqrt(2.0 * gravity * rise_distance)
	var rise_time := vertical_speed / gravity
	var fall_time := sqrt(2.0 * fall_distance / gravity)
	var flight_time := rise_time + fall_time
	if flight_time <= 0.0:
		return Vector2.ZERO

	var velocity := Vector2(delta.x / flight_time, -vertical_speed)
	if velocity.length() > maximum_launch_speed:
		return Vector2.ZERO
	return velocity
