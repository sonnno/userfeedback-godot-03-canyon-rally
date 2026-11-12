extends Node
## 截图验证：截取主菜单与比赛画面（需窗口模式运行，非 headless）。

var _dir := "user://screenshots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	get_tree().paused = false

	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("menu.png")
	menu.queue_free()

	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(5.5).timeout  # 倒计时结束 + 起步
	await _shot("game1.png")
	Input.action_press("accelerate")
	await get_tree().create_timer(4.0).timeout
	Input.action_press("nitro")
	await get_tree().create_timer(1.5).timeout
	await _shot("game2.png")
	Input.action_release("nitro")
	Input.action_release("accelerate")
	print("截图完成: ", ProjectSettings.globalize_path(_dir))
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_dir + "/" + name)
	print("saved ", name)
