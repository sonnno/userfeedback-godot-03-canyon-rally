extends Node
## 系统测试：氮气过热锁定、复位罚时、暂停冻结。

var _game: Node
var _car: Car
var _frames := 0
var _phase := 0
var _phase_frame := 0
var _results: Array[String] = []


func _ready() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	add_child(_game)
	_car = _game._car


func _check(name: String, ok: bool) -> void:
	_results.append(("PASS " if ok else "FAIL ") + name)
	print(_results[_results.size() - 1])


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _game.state != _game.State.RACING:
		return
	_phase_frame += 1

	match _phase:
		0:  # 持续氮气直至过热
			Input.action_press("accelerate")
			Input.action_press("nitro")
			if _car.overheat_timer > 0.0:
				_check("氮气约6秒过热并锁定", _car.heat >= 0.99 and _car.overheat_timer > 3.0)
				Input.action_release("nitro")
				_phase = 1
				_phase_frame = 0
		1:  # 过热期间尝试氮气无效
			Input.action_press("nitro")
			if _phase_frame == 60:
				_check("过热锁定期间氮气无效", not _car.nitro_active)
				_phase = 2
				_phase_frame = 0
		2:  # 等待锁定结束
			if _phase_frame == 190:
				_check("4秒后氮气恢复可用", _car.overheat_timer <= 0.0)
				Input.action_release("nitro")
				Input.action_release("accelerate")
				_phase = 3
				_phase_frame = 0
		3:  # 复位罚时
			var old_penalty: float = _game.penalty
			_game._do_reset()
			_check("复位罚时+5秒", absf(_game.penalty - old_penalty - 5.0) < 0.01)
			_check("复位后速度清零", _car.velocity.length() < 0.1)
			_phase = 4
		4:  # 暂停冻结
			_game._pause()
			_check("暂停生效", get_tree().paused)
			var t0: float = _game.race_time
			await get_tree().create_timer(0.5).timeout
			_check("暂停时计时冻结", absf(_game.race_time - t0) < 0.001)
			_game._resume()
			_check("恢复比赛", not get_tree().paused)
			_phase = 5
		5:
			for r in _results:
				print(r)
			print("系统测试完成")
			get_tree().quit()
