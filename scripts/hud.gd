class_name HUD
extends CanvasLayer
## 比赛 HUD：速度、时间、检查点、路面、氮气热量、提示与各类面板。

signal pause_requested
signal resume_requested
signal retry_requested
signal menu_requested

var _time_label: Label
var _penalty_label: Label
var _best_label: Label
var _cp_label: Label
var _surface_label: Label
var _speed_label: Label
var _heat_bar: ProgressBar
var _heat_fill: StyleBoxFlat
var _heat_label: Label
var _overheat_label: Label
var _drift_label: Label
var _nitro_label: Label
var _toast_label: Label
var _countdown_label: Label
var _hint_panel: PanelContainer
var _flash_rect: ColorRect
var _pause_overlay: Control
var _result_overlay: Control
var _result_title: Label
var _result_time: Label
var _result_best: Label
var _result_record: Label

var _toast_t := 0.0
var _flash_a := 0.0
var _go_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIHelper.make_theme(22)
	add_child(root)

	_time_label = _make_label(root, 34, Color.WHITE, Vector2(0.5, 0.0), Vector2(0, 14))
	_penalty_label = _make_label(root, 20, Color(1, 0.45, 0.35), Vector2(0.5, 0.0), Vector2(0, 58))
	_best_label = _make_label(root, 18, Color(0.85, 0.85, 0.9), Vector2(0.5, 0.0), Vector2(0, 86))
	_cp_label = _make_label(root, 26, Color.WHITE, Vector2(0.0, 0.0), Vector2(24, 16), HORIZONTAL_ALIGNMENT_LEFT)
	_surface_label = _make_label(root, 22, Color(0.8, 0.85, 1.0), Vector2(0.0, 0.0), Vector2(24, 52), HORIZONTAL_ALIGNMENT_LEFT)
	_speed_label = _make_label(root, 46, Color.WHITE, Vector2(1.0, 1.0), Vector2(-30, -70), HORIZONTAL_ALIGNMENT_RIGHT)

	# 氮气热量条
	_heat_label = _make_label(root, 18, Color(0.6, 0.9, 1.0), Vector2(0.5, 1.0), Vector2(0, -108))
	_heat_label.text = "氮气热量"
	_heat_bar = ProgressBar.new()
	_heat_bar.min_value = 0.0
	_heat_bar.max_value = 100.0
	_heat_bar.value = 0.0
	_heat_bar.show_percentage = false
	_heat_bar.custom_minimum_size = Vector2(320, 18)
	_heat_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_heat_bar.position = Vector2(-160, -84)
	_heat_bar.size = Vector2(320, 18)
	_heat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	bg_sb.set_corner_radius_all(4)
	_heat_bar.add_theme_stylebox_override("background", bg_sb)
	_heat_fill = StyleBoxFlat.new()
	_heat_fill.bg_color = Color(0.2, 0.8, 0.4)
	_heat_fill.set_corner_radius_all(4)
	_heat_bar.add_theme_stylebox_override("fill", _heat_fill)
	root.add_child(_heat_bar)

	_overheat_label = _make_label(root, 26, Color(1, 0.3, 0.2), Vector2(0.5, 1.0), Vector2(0, -140))
	_overheat_label.text = "过热！冷却中…"
	_overheat_label.visible = false
	_drift_label = _make_label(root, 30, Color(1.0, 0.65, 0.15), Vector2(0.5, 1.0), Vector2(0, -180))
	_drift_label.text = "漂移！"
	_drift_label.visible = false
	_nitro_label = _make_label(root, 26, Color(0.35, 0.9, 1.0), Vector2(0.5, 1.0), Vector2(0, -180))
	_nitro_label.text = "氮气加速！"
	_nitro_label.visible = false

	_toast_label = _make_label(root, 30, Color(0.5, 1.0, 0.6), Vector2(0.5, 0.28), Vector2.ZERO)
	_toast_label.visible = false
	_countdown_label = _make_label(root, 130, Color(1.0, 0.9, 0.3), Vector2(0.5, 0.38), Vector2.ZERO)
	_countdown_label.visible = false

	# 操作提示（倒计时期间显示）
	_hint_panel = PanelContainer.new()
	_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_panel.position = Vector2(20, -210)
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0, 0, 0, 0.55)
	hint_sb.set_corner_radius_all(8)
	hint_sb.content_margin_left = 16
	hint_sb.content_margin_right = 16
	hint_sb.content_margin_top = 12
	hint_sb.content_margin_bottom = 12
	_hint_panel.add_theme_stylebox_override("panel", hint_sb)
	var hint_label := Label.new()
	hint_label.text = "W/↑ 加速    S/↓ 刹车/倒车\nA D/← → 转向    Shift 手刹漂移\n空格 氮气    R 复位(+5秒)    Esc 暂停"
	hint_label.add_theme_font_size_override("font_size", 20)
	_hint_panel.add_child(hint_label)
	root.add_child(_hint_panel)

	# 碰撞红闪
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 0.1, 0.05, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash_rect)

	_build_pause_overlay(root)
	_build_result_overlay(root)

	if SaveManager.has_best():
		_best_label.text = "最佳成绩 " + SaveManager.format_time(SaveManager.best_time)
	else:
		_best_label.text = "暂无最佳成绩"


func _make_label(parent: Control, size: int, color: Color, anchor: Vector2,
		offset: Vector2, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.position = offset
	label.horizontal_alignment = align
	match align:
		HORIZONTAL_ALIGNMENT_LEFT:
			label.grow_horizontal = Control.GROW_DIRECTION_END
		HORIZONTAL_ALIGNMENT_RIGHT:
			label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_:
			label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(parent: Control, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 52)
	btn.add_theme_font_size_override("font_size", 24)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.18, 0.24)
	normal.set_corner_radius_all(8)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.34, 0.46)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.10, 0.12, 0.16)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	parent.add_child(btn)
	return btn


func _make_overlay(root: Control) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	overlay.add_child(dim)
	return overlay


func _build_pause_overlay(root: Control) -> void:
	_pause_overlay = _make_overlay(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "WASD/方向键 驾驶 · Shift 手刹 · 空格 氮气 · R 复位"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	vbox.add_child(hint)
	var btn_resume := _make_button(vbox, "继续比赛")
	btn_resume.pressed.connect(func(): resume_requested.emit())
	var btn_retry := _make_button(vbox, "重新开始")
	btn_retry.pressed.connect(func(): retry_requested.emit())
	var btn_menu := _make_button(vbox, "返回主菜单")
	btn_menu.pressed.connect(func(): menu_requested.emit())


func _build_result_overlay(root: Control) -> void:
	_result_overlay = _make_overlay(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 46)
	vbox.add_child(_result_title)
	_result_time = _make_panel_label(vbox, 28)
	_result_best = _make_panel_label(vbox, 24)
	_result_record = _make_panel_label(vbox, 26)
	_result_record.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	var btn_retry := _make_button(vbox, "重试")
	btn_retry.pressed.connect(func(): retry_requested.emit())
	var btn_menu := _make_button(vbox, "返回主菜单")
	btn_menu.pressed.connect(func(): menu_requested.emit())


func _make_panel_label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause_game"):
		if get_tree().paused:
			resume_requested.emit()
		else:
			pause_requested.emit()

	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.8:
			_toast_label.modulate.a = clampf(_toast_t / 0.8, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast_label.visible = false
	if _flash_a > 0.0:
		_flash_a = maxf(_flash_a - delta * 2.2, 0.0)
		_flash_rect.color.a = _flash_a * 0.35
	if _go_t > 0.0:
		_go_t -= delta
		if _go_t <= 0.0:
			_countdown_label.visible = false
	if _overheat_label.visible:
		_overheat_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)


# ---------- 对外接口 ----------

func update_hud(car: Car, elapsed: float, penalty: float, next_cp: int) -> void:
	_time_label.text = "%s / %s" % [
		SaveManager.format_time(elapsed), SaveManager.format_time(TrackData.TIME_LIMIT)]
	if elapsed > TrackData.TIME_LIMIT - 15.0:
		_time_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	else:
		_time_label.add_theme_color_override("font_color", Color.WHITE)
	_penalty_label.text = ("罚时 +%.0f 秒" % penalty) if penalty > 0.0 else ""
	_cp_label.text = "检查点 %d / %d" % [next_cp, TrackData.CHECKPOINT_COUNT]
	if car.surface == "gravel":
		_surface_label.text = "路面：砂石"
		_surface_label.add_theme_color_override("font_color", Color(0.85, 0.70, 0.45))
	else:
		_surface_label.text = "路面：沥青"
		_surface_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_speed_label.text = "%3d km/h" % int(car.speed_kmh)

	_heat_bar.value = car.heat * 100.0
	if car.overheat_timer > 0.0:
		_heat_fill.bg_color = Color(0.9, 0.15, 0.1)
	else:
		var h := car.heat
		_heat_fill.bg_color = Color(0.2 + h * 0.8, 0.8 - h * 0.55, 0.35 - h * 0.2)
	_overheat_label.visible = car.overheat_timer > 0.0
	_drift_label.visible = car.is_drifting
	_nitro_label.visible = car.nitro_active and not car.is_drifting


func show_countdown(n: int) -> void:
	_countdown_label.visible = true
	_countdown_label.text = str(n)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))


func show_go() -> void:
	_countdown_label.visible = true
	_countdown_label.text = "GO!"
	_countdown_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_go_t = 0.8


func show_toast(text: String, color := Color(0.5, 1.0, 0.6)) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	_toast_t = 2.0


func flash_collision(strength: float) -> void:
	_flash_a = clampf(_flash_a + strength, 0.0, 1.0)


func show_hint(visible: bool) -> void:
	_hint_panel.visible = visible


func show_pause(visible: bool) -> void:
	_pause_overlay.visible = visible


func show_result(win: bool, final_time: float, best: float, is_record: bool) -> void:
	if win:
		_result_title.text = "冲线成功！"
		_result_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		_result_time.text = "成绩  " + SaveManager.format_time(final_time)
	else:
		_result_title.text = "超时失败"
		_result_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		_result_time.text = "未能在 %s 内完成比赛" % SaveManager.format_time(TrackData.TIME_LIMIT)
	_result_best.text = "最佳成绩  " + (SaveManager.format_time(best) if best > 0.0 else "--:--.-")
	_result_record.text = "★ 新纪录！★" if is_record else ""
	_result_overlay.visible = true
