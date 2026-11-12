class_name GameCamera
extends Camera3D
## 平滑跟随镜头：转弯与上下坡时保持车辆与前方路面可见。

var target: Car = null
var _look_point := Vector3.ZERO
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _base_fov := 70.0


func _ready() -> void:
	current = true
	fov = _base_fov


func snap_to_target() -> void:
	if target == null:
		return
	var basis_h := Basis(Vector3.UP, target.yaw)
	global_position = target.global_position + basis_h * Vector3(0, 4.2, 8.5)
	_look_point = target.global_position + basis_h * Vector3(0, 1.4, -6.0)
	look_at(_look_point)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var basis_h := Basis(Vector3.UP, target.yaw)

	# 目标机位：车后上方，速度越快略微拉远
	var speed_fac: float = clampf(absf(target.forward_speed) / 36.0, 0.0, 1.0)
	var back := 8.5 + 2.0 * speed_fac
	var anchor := target.global_position + basis_h * Vector3(0, 4.2, back)

	# 防止镜头穿墙：从车头向机位做射线检测
	var space := get_world_3d().direct_space_state
	var from := target.global_position + Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(from, anchor, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		anchor = hit["position"] - (anchor - from).normalized() * 0.6 + Vector3.UP * 0.4

	# 不低于车辆过多，避免钻入路面
	anchor.y = maxf(anchor.y, target.global_position.y + 1.6)

	var t := 1.0 - exp(-5.5 * delta)
	global_position = global_position.lerp(anchor, t)

	# 注视点：车辆前方路面
	var look_target := target.global_position + basis_h * Vector3(0, 1.3, -6.5)
	_look_point = _look_point.lerp(look_target, 1.0 - exp(-7.0 * delta))

	var up := Vector3.UP
	if _shake > 0.001:
		_shake = maxf(_shake - delta * 1.8, 0.0)
		var s := _shake * 0.5
		global_position += Vector3(
			_rng.randf_range(-s, s), _rng.randf_range(-s, s), _rng.randf_range(-s, s))
	look_at(_look_point, up)

	# 氮气/高速时视野外扩
	var target_fov := _base_fov + 10.0 * speed_fac + (6.0 if target.nitro_active else 0.0)
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))
