extends Node3D
## 比赛主场景：状态机、计时、检查点顺序校验、复位、暂停与结算。

enum State { COUNTDOWN, RACING, FINISHED, FAILED }

var state: State = State.COUNTDOWN
var race_time := 0.0
var penalty := 0.0
var next_checkpoint := 0
var countdown := 3.0

var _builder: TrackBuilder
var _car: Car
var _cam: GameCamera
var _hud: HUD
var _finish_warn_cd := 0.0


func _ready() -> void:
	_builder = TrackBuilder.new()
	add_child(_builder)
	_builder.build()
	_builder.checkpoint_entered.connect(_on_checkpoint_entered)
	_builder.finish_entered.connect(_on_finish_entered)

	_car = Car.new()
	add_child(_car)
	_car.set_start_transform(_builder.start_transform)
	_car.collided.connect(_on_car_collided)

	_cam = GameCamera.new()
	add_child(_cam)
	_cam.target = _car
	_cam.snap_to_target()

	_hud = HUD.new()
	add_child(_hud)
	_hud.pause_requested.connect(_pause)
	_hud.resume_requested.connect(_resume)
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(_to_menu)
	_hud.show_hint(true)
	_hud.update_hud(_car, 0.0, 0.0, 0)


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown -= delta
			if countdown <= 0.0:
				state = State.RACING
				_car.controls_enabled = true
				_hud.show_go()
				_hud.show_hint(false)
			else:
				_hud.show_countdown(maxi(ceili(countdown), 1))
		State.RACING:
			race_time += delta
			if race_time + penalty >= TrackData.TIME_LIMIT:
				_fail()

	if state == State.COUNTDOWN or state == State.RACING:
		_hud.update_hud(_car, race_time + penalty, penalty, next_checkpoint)

	if state == State.RACING:
		if Input.is_action_just_pressed("reset_car"):
			_do_reset()
		# 掉出赛道兜底
		if _car.global_position.y < -4.0:
			_do_reset()

	_finish_warn_cd = maxf(_finish_warn_cd - delta, 0.0)


# ---------- 检查点与终点 ----------

func _car_move_dir() -> Vector3:
	var dir := Vector3(_car.velocity.x, 0, _car.velocity.z)
	if dir.length() < 2.0:
		dir = -_car.global_transform.basis.z
		dir.y = 0
	return dir.normalized()


func _on_checkpoint_entered(idx: int, body: Node3D) -> void:
	if body != _car or state != State.RACING:
		return
	if idx != next_checkpoint:
		return  # 跳过检查点不计入
	var gate_fwd: Vector3 = _builder.checkpoints[idx]["forward"]
	gate_fwd.y = 0
	if _car_move_dir().dot(gate_fwd.normalized()) <= 0.0:
		_hud.show_toast("通过方向错误！", Color(1, 0.4, 0.3))
		return
	_builder.mark_checkpoint_passed(idx)
	next_checkpoint += 1
	_hud.show_toast("检查点 %d / %d" % [next_checkpoint, TrackData.CHECKPOINT_COUNT])


func _on_finish_entered(body: Node3D) -> void:
	if body != _car or state != State.RACING:
		return
	var fwd := _builder.finish_forward
	fwd.y = 0
	if _car_move_dir().dot(fwd.normalized()) <= 0.0:
		return  # 反向穿过终点无效
	if next_checkpoint < TrackData.CHECKPOINT_COUNT:
		if _finish_warn_cd <= 0.0:
			_hud.show_toast("请先按顺序通过所有检查点！", Color(1, 0.4, 0.3))
			_finish_warn_cd = 2.0
		return
	_win()


# ---------- 比赛流程 ----------

func _win() -> void:
	state = State.FINISHED
	_car.controls_enabled = false
	var final := race_time + penalty
	var is_record := SaveManager.try_save_best(final)
	_hud.show_result(true, final, SaveManager.best_time, is_record)


func _fail() -> void:
	state = State.FAILED
	_car.controls_enabled = false
	_hud.show_result(false, race_time + penalty, SaveManager.best_time, false)


func _do_reset() -> void:
	var idx := next_checkpoint - 1
	_car.reset_to(_builder.get_spawn(idx))
	penalty += TrackData.RESET_PENALTY
	_cam.snap_to_target()
	_hud.show_toast("复位：+5 秒罚时", Color(1.0, 0.7, 0.3))


func _on_car_collided(strength: float) -> void:
	_cam.add_shake(strength)
	_hud.flash_collision(strength)


# ---------- 暂停 / 重试 / 菜单 ----------

func _pause() -> void:
	if state != State.RACING and state != State.COUNTDOWN:
		return
	get_tree().paused = true
	_hud.show_pause(true)


func _resume() -> void:
	get_tree().paused = false
	_hud.show_pause(false)


func _retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
