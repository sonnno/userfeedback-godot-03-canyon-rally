class_name Car
extends CharacterBody3D
## 街机风格赛车：加速/刹车/倒车/惯性/侧滑/漂移/氮气热量。

signal collided(strength: float)

const GRAVITY := 20.0
const ENGINE_ACCEL := 15.0
const NITRO_ACCEL := 13.0
const BRAKE_DECEL := 28.0
const GRAVEL_BRAKE_MUL := 0.62
const REVERSE_ACCEL := 10.0
const MAX_SPEED := 36.0
const NITRO_MAX_SPEED := 48.0
const OVERHEAT_MAX_SPEED := 20.0
const MAX_REVERSE := 9.0
const ROLLING_DRAG := 1.0
const AERO_DRAG := 0.012
const GRIP_ASPHALT := 9.0
const GRIP_GRAVEL := 4.2
const HANDBRAKE_GRIP_MUL := 0.20
const HANDBRAKE_DECEL := 10.0
const STEER_LOW := 2.3
const STEER_HIGH := 0.85
const HEAT_RATE := 1.0 / 6.0      ## 连续使用约 6 秒过热
const COOL_RATE := 1.0 / 3.0
const OVERHEAT_LOCK := 4.0        ## 过热后 4 秒禁用

var yaw := 0.0
var heat := 0.0
var overheat_timer := 0.0
var nitro_active := false
var surface := "asphalt"
var is_drifting := false
var handbraking := false
var speed_kmh := 0.0
var forward_speed := 0.0
var lateral_speed := 0.0
var controls_enabled := false
var floor_normal := Vector3.UP

var _body: Node3D
var _flame: MeshInstance3D
var _wheels: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _wheel_spin := 0.0
var _smooth_normal := Vector3.UP
var _steer_visual := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	_build_collision()
	_build_visual()


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.0, 4.0)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)


func _make_mat(color: Color, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.5
	return m


func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)

	var chassis := MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(1.8, 0.55, 4.2)
	chassis.mesh = chassis_mesh
	chassis.material_override = _make_mat(Color(0.85, 0.15, 0.12))
	chassis.position = Vector3(0, 0.62, 0)
	_body.add_child(chassis)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.5, 0.5, 1.9)
	cabin.mesh = cabin_mesh
	cabin.material_override = _make_mat(Color(0.12, 0.14, 0.18))
	cabin.position = Vector3(0, 1.12, 0.25)
	_body.add_child(cabin)

	var spoiler := MeshInstance3D.new()
	var spoiler_mesh := BoxMesh.new()
	spoiler_mesh.size = Vector3(1.7, 0.08, 0.45)
	spoiler.mesh = spoiler_mesh
	spoiler.material_override = _make_mat(Color(0.15, 0.15, 0.17))
	spoiler.position = Vector3(0, 1.25, 1.95)
	_body.add_child(spoiler)

	var wheel_mat := _make_mat(Color(0.08, 0.08, 0.09))
	var wheel_positions := [
		Vector3(-0.88, 0.35, -1.35), Vector3(0.88, 0.35, -1.35),
		Vector3(-0.88, 0.35, 1.35), Vector3(0.88, 0.35, 1.35)]
	for k in range(4):
		var pivot := Node3D.new()
		pivot.position = wheel_positions[k]
		_body.add_child(pivot)
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.35
		wm.bottom_radius = 0.35
		wm.height = 0.3
		wm.radial_segments = 10
		wheel.mesh = wm
		wheel.material_override = wheel_mat
		wheel.rotation.z = PI * 0.5
		pivot.add_child(wheel)
		_wheels.append(wheel)
		if k < 2:
			_front_wheels.append(pivot)

	# 氮气尾焰
	_flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 0.20
	cone.height = 0.9
	cone.radial_segments = 8
	_flame.mesh = cone
	_flame.material_override = _make_mat(Color(0.3, 0.85, 1.0), true)
	_flame.rotation.x = PI * 0.5
	_flame.position = Vector3(0, 0.55, 2.45)
	_flame.visible = false
	_body.add_child(_flame)


func set_start_transform(t: Transform3D) -> void:
	global_transform = t
	yaw = t.basis.get_euler().y
	rotation.y = yaw


func reset_to(t: Transform3D) -> void:
	set_start_transform(t)
	velocity = Vector3.ZERO
	forward_speed = 0.0
	lateral_speed = 0.0
	_smooth_normal = Vector3.UP


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return

	_update_surface()

	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	handbraking = Input.is_action_pressed("handbrake")

	# ---- 氮气与热量 ----
	var want_nitro := Input.is_action_pressed("nitro") and overheat_timer <= 0.0 and heat < 1.0
	nitro_active = want_nitro
	if nitro_active:
		heat = minf(heat + HEAT_RATE * delta, 1.0)
		if heat >= 1.0:
			overheat_timer = OVERHEAT_LOCK
			nitro_active = false
	else:
		heat = maxf(heat - COOL_RATE * delta, 0.0)
	overheat_timer = maxf(overheat_timer - delta, 0.0)

	# ---- 方向分解 ----
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := fwd.cross(Vector3.UP).normalized()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var f := horizontal.dot(fwd)
	var lat := horizontal.dot(right)

	# ---- 转向 ----
	var speed_fac := clampf(absf(f) / MAX_SPEED, 0.0, 1.0)
	var steer_rate := lerpf(STEER_LOW, STEER_HIGH, speed_fac)
	if handbraking:
		steer_rate *= 1.35
	var move_fac := clampf(absf(f) / 3.0, 0.0, 1.0)
	var dir_sign := 1.0 if f >= 0.0 else -1.0
	yaw -= steer * steer_rate * move_fac * dir_sign * delta
	rotation.y = yaw

	# ---- 抓地力（横向滑动衰减）----
	var grip := GRIP_GRAVEL if surface == "gravel" else GRIP_ASPHALT
	if handbraking:
		grip *= HANDBRAKE_GRIP_MUL
	lat *= exp(-grip * delta)

	# ---- 纵向动力 ----
	var max_spd := NITRO_MAX_SPEED if nitro_active else MAX_SPEED
	if overheat_timer > 0.0:
		max_spd = OVERHEAT_MAX_SPEED
	if throttle > 0.0:
		var a := ENGINE_ACCEL + (NITRO_ACCEL if nitro_active else 0.0)
		if overheat_timer > 0.0:
			a *= 0.35
		a *= clampf(1.0 - f / max_spd, 0.0, 1.0) + 0.08
		f += a * throttle * delta
	if brake > 0.0:
		if f > 0.5:
			var decel := BRAKE_DECEL * (GRAVEL_BRAKE_MUL if surface == "gravel" else 1.0)
			f = move_toward(f, 0.0, decel * brake * delta)
		else:
			f = move_toward(f, -MAX_REVERSE, REVERSE_ACCEL * brake * delta)
	if handbraking and f > 0.0:
		f = move_toward(f, 0.0, HANDBRAKE_DECEL * delta)
	if throttle == 0.0 and brake == 0.0:
		f = move_toward(f, 0.0, ROLLING_DRAG * delta)
	# 空气阻力
	f -= signf(f) * f * f * AERO_DRAG * delta
	f = clampf(f, -MAX_REVERSE, max_spd + 6.0)

	# ---- 坡面重力分量 ----
	if is_on_floor():
		var g_along := Vector3(0, -GRAVITY, 0).slide(get_floor_normal())
		f += g_along.dot(fwd) * delta
		lat += g_along.dot(right) * delta

	# ---- 合成速度 ----
	var vy := velocity.y
	if is_on_floor():
		vy = -1.0
	else:
		vy -= GRAVITY * delta
	velocity = fwd * f + right * lat
	velocity.y = vy

	var pre_move := velocity
	move_and_slide()

	# ---- 碰撞反馈 ----
	for k in range(get_slide_collision_count()):
		var col := get_slide_collision(k)
		var collider := col.get_collider()
		if collider is StaticBody3D and collider.is_in_group("rail"):
			var impact := absf(pre_move.dot(col.get_normal()))
			if impact > 4.0:
				collided.emit(minf(impact / 20.0, 1.0))
				f *= 0.72
				lat *= 0.55
				velocity.x *= 0.8
				velocity.z *= 0.8

	forward_speed = f
	lateral_speed = lat
	speed_kmh = Vector3(velocity.x, 0, velocity.z).length() * 3.6
	is_drifting = absf(lat) > 4.0 and absf(f) > 8.0

	_update_visual(delta, steer, lat)


func _update_surface() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP, global_position - Vector3.UP * 3.0, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider.is_in_group("surface_gravel"):
			surface = "gravel"
		elif collider.is_in_group("surface_asphalt"):
			surface = "asphalt"
		floor_normal = hit["normal"]
	elif is_on_floor():
		floor_normal = get_floor_normal()


func _update_visual(delta: float, steer: float, lat: float) -> void:
	# 车身姿态：贴合坡面 + 过弯侧倾
	_smooth_normal = _smooth_normal.lerp(floor_normal, 1.0 - exp(-10.0 * delta)).normalized()
	var f_dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var f_slope := (f_dir - _smooth_normal * f_dir.dot(_smooth_normal)).normalized()
	var target := Basis.looking_at(f_slope, _smooth_normal)
	var roll := clampf(lat * 0.018 + steer * 0.045 * clampf(absf(forward_speed) / MAX_SPEED, 0.0, 1.0), -0.16, 0.16)
	target = target * Basis(Vector3(0, 0, 1), roll)
	_body.global_transform.basis = _body.global_transform.basis.slerp(target, 1.0 - exp(-9.0 * delta))

	# 车轮
	_wheel_spin += forward_speed * delta / 0.35
	for w in _wheels:
		w.rotation.x = _wheel_spin
	_steer_visual = lerpf(_steer_visual, steer * 0.42, 1.0 - exp(-10.0 * delta))
	for p in _front_wheels:
		p.rotation.y = _steer_visual

	# 氮气尾焰
	_flame.visible = nitro_active
	if nitro_active:
		var flicker := 0.85 + 0.3 * sin(Time.get_ticks_msec() * 0.05)
		_flame.scale = Vector3(flicker, flicker, 1.0 + 0.4 * flicker)
