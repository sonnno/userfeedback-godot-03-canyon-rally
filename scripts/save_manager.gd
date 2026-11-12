extends Node
## 全局存档与输入映射。作为 Autoload 加载。

const SAVE_PATH := "user://canyon_rally_save.cfg"

var best_time: float = -1.0  ## 本地最佳有效成绩（秒），-1 表示暂无


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input_actions()
	_load_best()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_time = cfg.get_value("records", "best_time", -1.0)


## 仅当成绩有效且更好时保存，失败不覆盖纪录。
func try_save_best(t: float) -> bool:
	if t <= 0.0:
		return false
	if best_time > 0.0 and t >= best_time:
		return false
	best_time = t
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_time", t)
	cfg.save(SAVE_PATH)
	return true


func has_best() -> bool:
	return best_time > 0.0


static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.-"
	var total := maxf(t, 0.0)
	var minutes := int(total) / 60
	var seconds := int(total) % 60
	var tenths := int(fmod(total, 1.0) * 10.0)
	return "%02d:%02d.%d" % [minutes, seconds, tenths]


func _register_input_actions() -> void:
	_add_key_action("accelerate", [KEY_W, KEY_UP])
	_add_key_action("brake", [KEY_S, KEY_DOWN])
	_add_key_action("steer_left", [KEY_A, KEY_LEFT])
	_add_key_action("steer_right", [KEY_D, KEY_RIGHT])
	_add_key_action("handbrake", [KEY_SHIFT])
	_add_key_action("nitro", [KEY_SPACE])
	_add_key_action("reset_car", [KEY_R])
	_add_key_action("pause_game", [KEY_ESCAPE, KEY_P])


func _add_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var exists := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.physical_keycode == k:
				exists = true
				break
		if not exists:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
