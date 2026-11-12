extends Node
## 规则测试：检查点顺序、方向校验、终点有效性。

var _game: Node
var _car: Car
var _frames := 0
var _done := false


func _ready() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	add_child(_game)
	_car = _game._car


func _check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _done or _game.state != _game.State.RACING:
		return
	_done = true

	# 1. 跳过检查点：直接触发 3 号门，不计入
	_game._on_checkpoint_entered(3, _car)
	_check("跳过检查点不计入", _game.next_checkpoint == 0)

	# 2. 反向穿过检查点：车朝向反转，触发 1 号门（当前应为 0 号）
	_car.yaw += PI
	_car.rotation.y = _car.yaw
	_game._on_checkpoint_entered(0, _car)
	_check("反向穿过检查点不计入", _game.next_checkpoint == 0)
	_car.yaw -= PI
	_car.rotation.y = _car.yaw

	# 3. 未完成所有检查点时冲终点无效
	_game._on_finish_entered(_car)
	_check("缺少检查点冲终点无效", _game.state != _game.State.FINISHED)

	# 4. 反向冲终点无效（以逆终点方向的速度穿过）
	_game.next_checkpoint = 8
	_car.velocity = -_game._builder.finish_forward.normalized() * 10.0
	_game._on_finish_entered(_car)
	_check("反向冲终点无效", _game.state != _game.State.FINISHED)
	_car.velocity = Vector3.ZERO

	# 5. 正向且检查点齐全，冲线成功
	_car.velocity = _game._builder.finish_forward.normalized() * 10.0
	_game._on_finish_entered(_car)
	_check("正常冲线完成比赛", _game.state == _game.State.FINISHED)

	print("规则测试完成")
	get_tree().quit()
