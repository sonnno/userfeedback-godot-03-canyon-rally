extends Node
## 诊断：固定高空视角俯瞰赛道起点区域。

var _dir := "user://screenshots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var car: Node3D = game._car
	var cam: Node3D = game._cam
	print("car pos=", car.global_position, " cam pos=", cam.global_position)

	# 高空俯瞰相机
	var cam2 := Camera3D.new()
	add_child(cam2)
	cam2.current = true
	cam2.global_position = Vector3(0, 120, 60)
	cam2.look_at(Vector3(0, 0, -60))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_dir + "/debug_top.png")
	print("saved debug_top.png")

	# 贴近路面的视角
	cam2.global_position = Vector3(0, 6, 14)
	cam2.look_at(Vector3(0, 0, -20))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	img = get_viewport().get_texture().get_image()
	img.save_png(_dir + "/debug_road.png")
	print("saved debug_road.png")

	# 高空全景
	cam2.global_position = Vector3(0, 600, 100)
	cam2.look_at(Vector3(0, 0, -320))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	img = get_viewport().get_texture().get_image()
	img.save_png(_dir + "/debug_orbit.png")
	print("saved debug_orbit.png")
	get_tree().quit()
