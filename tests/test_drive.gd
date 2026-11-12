extends Node
## 自动驾驶测试：验证车辆物理、检查点顺序、终点判定与比赛用时。
## 运行: godot --headless --path . scenes/../tests/test_drive.tscn --quit-after 6500

var _game: Node
var _car: Car
var _builder: TrackBuilder
var _frames := 0
var _nearest := 0


func _ready() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	add_child(_game)
	_builder = _game._builder
	_car = _game._car
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		print("!! exiting: frames=%d state=%s t=%.1f" % [_frames, _game.state, _game.race_time])


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _game.state != _game.State.RACING:
		return

	# 找最近采样点
	var pos := _car.global_position
	var best_dist := INF
	for i in range(maxi(_nearest - 5, 0), mini(_nearest + 40, _builder.samples.size())):
		var d: float = pos.distance_squared_to(_builder.samples[i]["pos"])
		if d < best_dist:
			best_dist = d
			_nearest = i

	# 朝向前方采样点转向
	var target_i := mini(_nearest + 4, _builder.samples.size() - 1)
	var target: Vector3 = _builder.samples[target_i]["pos"]
	var dir := (target - pos)
	dir.y = 0
	dir = dir.normalized()
	var fwd := -_car.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var cross_y := fwd.cross(dir).y
	var angle := fwd.angle_to(dir)

	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_release("accelerate")
	Input.action_release("nitro")
	if angle > 0.55 and _car.forward_speed > 14.0:
		pass  # 急弯松油门
	else:
		Input.action_press("accelerate")
	if cross_y < -0.03:
		Input.action_press("steer_right")
	elif cross_y > 0.03:
		Input.action_press("steer_left")
	if angle < 0.12 and _car.heat < 0.6:
		Input.action_press("nitro")

	if _frames % 120 == 0:
		print("t=%.1fs pos=(%.0f,%.0f,%.0f) v=%.0fkm/h cp=%d heat=%.2f surf=%s" % [
			_game.race_time, pos.x, pos.y, pos.z, _car.speed_kmh,
			_game.next_checkpoint, _car.heat, _car.surface])
		print("   debug: f=%.2f lat=%.2f vel=%s floor=%s throttle=%.2f yaw=%.2f y=%.3f" % [
			_car.forward_speed, _car.lateral_speed, _car.velocity,
			_car.is_on_floor(), Input.get_action_strength("accelerate"), _car.yaw,
			_car.global_position.y])
		print("   collisions=%d" % _car.get_slide_collision_count())
		for k in range(_car.get_slide_collision_count()):
			var col := _car.get_slide_collision(k)
			var c: Object = col.get_collider()
			print("     hit %s groups=%s normal=%s" % [c, c.get_groups(), col.get_normal()])
	if _game.state == _game.State.FINISHED:
		print("胜利！最终成绩: %.1f 秒 (含罚时 %.0f)" % [_game.race_time + _game.penalty, _game.penalty])
		get_tree().quit()
	if _game.state == _game.State.FAILED:
		print("超时失败！cp=%d" % _game.next_checkpoint)
		get_tree().quit()
