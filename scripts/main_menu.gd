extends Control
## 主菜单：标题、最佳成绩、开始 / 操作说明 / 退出。

var _controls_panel: PanelContainer


func _ready() -> void:
	theme = UIHelper.make_theme(22)

	# 背景渐变
	var grad := Gradient.new()
	grad.set_color(0, Color(0.07, 0.09, 0.15))
	grad.set_color(1, Color(0.48, 0.28, 0.17))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = gtex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "峡谷冲线"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 14)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CANYON RALLY · 峡谷越野计时赛"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	vbox.add_child(subtitle)

	var best := Label.new()
	if SaveManager.has_best():
		best.text = "最佳成绩  " + SaveManager.format_time(SaveManager.best_time)
	else:
		best.text = "暂无成绩记录"
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.add_theme_font_size_override("font_size", 22)
	best.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	vbox.add_child(best)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var btn_start := _make_button(vbox, "开始比赛")
	btn_start.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/game.tscn"))
	var btn_help := _make_button(vbox, "操作说明")
	btn_help.pressed.connect(_toggle_controls)
	var btn_quit := _make_button(vbox, "退出游戏")
	btn_quit.pressed.connect(func(): get_tree().quit())

	# 操作说明面板
	_controls_panel = PanelContainer.new()
	_controls_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_controls_panel.position = Vector2(-380, -150)
	_controls_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_controls_panel.add_theme_stylebox_override("panel", sb)
	var help_text := Label.new()
	help_text.text = "操 作 说 明\n\nW / ↑          加速\nS / ↓          刹车 / 倒车\nA D / ← →   转向\nShift          手刹（漂移甩尾）\n空格           氮气（注意热量，过热锁定 4 秒）\nR               复位到检查点（+5 秒罚时）\nEsc / P       暂停\n\n限时 150 秒，按顺序通过 8 个检查点\n后正向冲过终点即完成比赛。"
	help_text.add_theme_font_size_override("font_size", 20)
	help_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	_controls_panel.add_child(help_text)
	add_child(_controls_panel)


func _toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _make_button(parent: Control, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 56)
	btn.add_theme_font_size_override("font_size", 26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.18, 0.26, 0.9)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.30, 0.36, 0.50, 0.95)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	parent.add_child(btn)
	return btn
