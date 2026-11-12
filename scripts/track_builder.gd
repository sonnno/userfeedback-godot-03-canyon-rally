class_name TrackBuilder
extends Node3D
## 程序化生成峡谷赛道：路面（沥青/砂石）、路肩、护栏、峡谷岩壁、
## 远景山脉、检查点、终点门、方向标识。

signal checkpoint_entered(index: int, body: Node3D)
signal finish_entered(body: Node3D)

const WALL_OFFSETS := [7.6, 15.0, 25.0, 40.0, 70.0, 110.0]
const WALL_HEIGHTS := [-0.05, 5.0, 13.0, 24.0, 34.0, 0.0]
const WALL_GROUND_Y := -12.0  ## 最外环岩壁延伸到地面（绝对高度）

var samples: Array = []            ## [{pos, tangent, right, s}]
var total_length := 0.0
var checkpoints: Array = []        ## [{pos, forward, spawn, area, label, plane}]
var start_transform := Transform3D.IDENTITY
var finish_position := Vector3.ZERO
var finish_forward := Vector3.FORWARD

var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 20261112
	_sample_centerline()
	_build_road()
	_build_rails()
	_build_walls()
	_build_scenery()
	_build_checkpoints()
	_build_finish()
	_build_signs()
	_build_environment()
	print("赛道总长: %.0f m" % total_length)


func _sample_centerline() -> void:
	var data := TrackData.sample_track()
	var points: PackedVector3Array = data["points"]
	var tangents: PackedVector3Array = data["tangents"]
	var dists: PackedFloat32Array = data["dists"]
	total_length = data["total_length"]
	for i in range(points.size()):
		var tan := tangents[i]
		var flat := Vector3(tan.x, 0.0, tan.z).normalized()
		var right := flat.cross(Vector3.UP).normalized()
		samples.append({
			"pos": points[i],
			"tangent": tan,
			"right": right,
			"s": dists[i],
		})
	var start_sample: Dictionary = samples[2]
	start_transform = Transform3D(
		Basis(Vector3.UP, TrackData.yaw_from_tangent(start_sample["tangent"])),
		start_sample["pos"] + Vector3.UP * 0.15)


func _sample_at_s(s: float) -> Dictionary:
	s = clampf(s, 0.0, total_length)
	for i in range(samples.size() - 1):
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		if s <= b["s"]:
			var span: float = maxf(b["s"] - a["s"], 0.001)
			var t: float = (s - float(a["s"])) / span
			return {
				"pos": (a["pos"] as Vector3).lerp(b["pos"], t),
				"tangent": (a["tangent"] as Vector3).lerp(b["tangent"], t).normalized(),
				"right": (a["right"] as Vector3).lerp(b["right"], t).normalized(),
				"s": s,
			}
	return samples[samples.size() - 1]


# ---------- 路面 ----------

func _build_road() -> void:
	# 横断面偏移与颜色（沥青 / 砂石 两套配色）
	var offsets := [-7.5, -5.6, -5.3, 5.3, 5.6, 7.5]
	var asphalt_colors := [
		Color(0.36, 0.31, 0.27), Color(0.82, 0.82, 0.78), Color(0.22, 0.22, 0.24),
		Color(0.82, 0.82, 0.78), Color(0.36, 0.31, 0.27)]
	var gravel_colors := [
		Color(0.45, 0.38, 0.28), Color(0.50, 0.42, 0.30), Color(0.60, 0.50, 0.36),
		Color(0.50, 0.42, 0.30), Color(0.45, 0.38, 0.28)]

	var st_asphalt := SurfaceTool.new()
	var st_gravel := SurfaceTool.new()
	st_asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_gravel.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(samples.size() - 1):
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		var mid_s: float = (a["s"] + b["s"]) * 0.5
		var gravel := TrackData.is_gravel(mid_s, total_length)
		var st := st_gravel if gravel else st_asphalt
		var colors := gravel_colors if gravel else asphalt_colors
		for band in range(5):
			var o0: float = offsets[band]
			var o1: float = offsets[band + 1]
			var c: Color = colors[band]
			var v00: Vector3 = a["pos"] + a["right"] * o0
			var v01: Vector3 = a["pos"] + a["right"] * o1
			var v10: Vector3 = b["pos"] + b["right"] * o0
			var v11: Vector3 = b["pos"] + b["right"] * o1
			_quad(st, v00, v01, v11, v10, c)

	var asphalt_mesh := _commit_road(st_asphalt)
	var gravel_mesh := _commit_road(st_gravel)
	_add_road_body(asphalt_mesh, "surface_asphalt")
	_add_road_body(gravel_mesh, "surface_gravel")


func _commit_road(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


func _add_road_body(mesh: ArrayMesh, group: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _vertex_color_material()
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(group)
	var shape := CollisionShape3D.new()
	var concave := mesh.create_trimesh_shape()
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	add_child(body)


func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	return mat


# ---------- 护栏 ----------

func _build_rails() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_body := StaticBody3D.new()
	rail_body.collision_layer = 1
	rail_body.collision_mask = 0
	rail_body.add_to_group("rail")

	var col_orange := Color(0.95, 0.45, 0.10)
	var col_white := Color(0.90, 0.90, 0.85)

	var i := 0
	while i < samples.size() - 2:
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[mini(i + 2, samples.size() - 1)]
		var c: Color = col_orange if (i / 8) % 2 == 0 else col_white
		for side_sign in [-1.0, 1.0]:
			var off: float = TrackData.RAIL_OFFSET * side_sign
			var face: Vector3 = -a["right"] * side_sign
			# 竖直面
			var a0: Vector3 = a["pos"] + a["right"] * off + Vector3.UP * 0.30
			var a1: Vector3 = a0 + Vector3.UP * 0.50
			var b0: Vector3 = b["pos"] + b["right"] * off + Vector3.UP * 0.30
			var b1: Vector3 = b0 + Vector3.UP * 0.50
			_quad_facing(st, a0, a1, b1, b0, c, face)
			# 顶面
			var t0 := a1
			var t1: Vector3 = a1 - a["right"] * side_sign * 0.25
			var t2: Vector3 = b1 - b["right"] * side_sign * 0.25
			_quad_facing(st, t0, t1, t2, b1, c * 0.9, Vector3.UP)
			# 碰撞盒
			var mid: Vector3 = (a["pos"] + b["pos"]) * 0.5 + a["right"] * off
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			var seg_len: float = (b["pos"] as Vector3).distance_to(a["pos"])
			box.size = Vector3(0.5, 1.2, seg_len + 0.4)
			shape.shape = box
			shape.position = mid + Vector3.UP * 0.55
			shape.rotation.y = TrackData.yaw_from_tangent(a["tangent"])
			rail_body.add_child(shape)
		i += 2

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vertex_color_material()
	add_child(mi)
	add_child(rail_body)


# ---------- 峡谷岩壁 ----------

func _build_walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Color(0.55, 0.38, 0.27)
	var strata := [1.0, 0.92, 1.05, 0.85, 0.95, 0.8]

	# 每个采样点/岩层的高度抖动需确定，否则相邻四边形顶点不一致
	var ring_count := WALL_OFFSETS.size()
	var jitters: Array = []
	for i in range(samples.size()):
		var row: Array = []
		for j in range(ring_count):
			row.append(_rng.randf_range(-1.2, 2.2))
		jitters.append(row)

	for side_sign in [-1.0, 1.0]:
		var i := 0
		while i < samples.size() - 2:
			var i2 := mini(i + 2, samples.size() - 1)
			var a: Dictionary = samples[i]
			var b: Dictionary = samples[i2]
			var face: Vector3 = -a["right"] * side_sign
			for ring in range(ring_count - 1):
				var p00 := _wall_point(a, side_sign, ring, jitters[i][ring])
				var p01 := _wall_point(a, side_sign, ring + 1, jitters[i][ring + 1])
				var p11 := _wall_point(b, side_sign, ring + 1, jitters[i2][ring + 1])
				var p10 := _wall_point(b, side_sign, ring, jitters[i2][ring])
				var jitter := 1.0 + _rng.randf_range(-0.09, 0.09)
				var c: Color = base * strata[ring] * jitter
				c.a = 1.0
				_quad_facing(st, p00, p01, p11, p10, c, face)
			i += 2

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vertex_color_material()
	add_child(mi)


func _wall_point(sample: Dictionary, side_sign: float, ring: int, jitter: float) -> Vector3:
	var base: Vector3 = sample["pos"] + sample["right"] * (WALL_OFFSETS[ring] * side_sign)
	if ring == WALL_OFFSETS.size() - 1:
		base.y = WALL_GROUND_Y
		return base
	var h: float = WALL_HEIGHTS[ring]
	if ring > 0:
		h += jitter
	return base + Vector3.UP * h


# ---------- 远景与地面 ----------

func _build_scenery() -> void:
	# 大地面
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.72, 0.58, 0.42)
	gmat.roughness = 1.0
	ground.material_override = gmat
	ground.position = Vector3(0, -8.0, -450)
	add_child(ground)

	# 远景山脉
	var rock_palette := [
		Color(0.58, 0.42, 0.32), Color(0.50, 0.36, 0.28),
		Color(0.64, 0.48, 0.36), Color(0.45, 0.34, 0.28)]
	for k in range(14):
		var angle := TAU * float(k) / 14.0 + _rng.randf_range(-0.15, 0.15)
		var dist := _rng.randf_range(750.0, 1400.0)
		var height := _rng.randf_range(160.0, 380.0)
		var radius := _rng.randf_range(140.0, 320.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = radius
		cone.height = height
		cone.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = rock_palette[k % rock_palette.size()]
		mat.roughness = 1.0
		mi.material_override = mat
		mi.position = Vector3(cos(angle) * dist, -12.0 + height * 0.5, -450.0 + sin(angle) * dist)
		mi.rotation.y = _rng.randf() * TAU
		add_child(mi)

	# 路边散布岩石
	var rock_mats: Array[StandardMaterial3D] = []
	for c in [Color(0.48, 0.36, 0.28), Color(0.55, 0.42, 0.32), Color(0.40, 0.31, 0.26)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		rock_mats.append(m)
	for k in range(110):
		var s := _rng.randf_range(30.0, total_length - 30.0)
		var sm := _sample_at_s(s)
		var side_sign := 1.0 if _rng.randf() > 0.5 else -1.0
		var off := _rng.randf_range(9.5, 18.0)
		var scale_r := _rng.randf_range(0.5, 2.0)
		var sph := SphereMesh.new()
		sph.radius = 1.0
		sph.height = 2.0
		sph.radial_segments = 5
		sph.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = sph
		mi.material_override = rock_mats[k % rock_mats.size()]
		var wall_h := _wall_height_at(off)
		mi.position = sm["pos"] + sm["right"] * (off * side_sign) \
			+ Vector3.UP * (wall_h - scale_r * 0.6)
		mi.scale = Vector3.ONE * scale_r
		mi.rotation.y = _rng.randf() * TAU
		add_child(mi)


func _wall_height_at(off: float) -> float:
	for j in range(WALL_OFFSETS.size() - 1):
		if off <= WALL_OFFSETS[j + 1]:
			var t: float = (off - WALL_OFFSETS[j]) / (WALL_OFFSETS[j + 1] - WALL_OFFSETS[j])
			return lerpf(WALL_HEIGHTS[j], WALL_HEIGHTS[j + 1], t)
	return WALL_HEIGHTS[WALL_HEIGHTS.size() - 1]


# ---------- 检查点与终点 ----------

func _build_checkpoints() -> void:
	for idx in range(TrackData.CHECKPOINT_COUNT):
		var s := total_length * float(idx + 1) / float(TrackData.CHECKPOINT_COUNT + 1)
		var sm := _sample_at_s(s)
		var gate := Node3D.new()
		gate.position = sm["pos"]
		gate.rotation.y = TrackData.yaw_from_tangent(sm["tangent"])
		add_child(gate)

		var pillar_mat := StandardMaterial3D.new()
		pillar_mat.albedo_color = Color(0.95, 0.55, 0.10)
		pillar_mat.roughness = 0.7
		for side_sign in [-1.0, 1.0]:
			var pillar := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.28
			cyl.bottom_radius = 0.34
			cyl.height = 5.0
			cyl.radial_segments = 8
			pillar.mesh = cyl
			pillar.material_override = pillar_mat
			pillar.position = Vector3(6.8 * side_sign, 2.5, 0)
			gate.add_child(pillar)

		var label := Label3D.new()
		label.text = str(idx + 1)
		label.font = UIHelper.get_font()
		label.font_size = 160
		label.pixel_size = 0.016
		label.modulate = Color(0.4, 0.95, 1.0)
		label.outline_size = 12
		label.outline_modulate = Color(0, 0, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 6.0, 0)
		gate.add_child(label)

		var plane_mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(13.4, 4.0)
		pm.orientation = PlaneMesh.FACE_Z
		plane_mi.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pmat.albedo_color = Color(0.3, 0.9, 1.0, 0.16)
		pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane_mi.material_override = pmat
		plane_mi.position = Vector3(0, 2.4, 0)
		gate.add_child(plane_mi)

		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(14.0, 6.0, 3.0)
		shape.shape = box
		shape.position = Vector3(0, 3.0, 0)
		area.add_child(shape)
		gate.add_child(area)
		area.body_entered.connect(_on_checkpoint_body.bind(idx))

		var spawn_s: float = maxf(s - 12.0, 4.0)
		var spawn_sm := _sample_at_s(spawn_s)
		var spawn := Transform3D(
			Basis(Vector3.UP, TrackData.yaw_from_tangent(spawn_sm["tangent"])),
			spawn_sm["pos"] + Vector3.UP * 0.15)
		checkpoints.append({
			"pos": sm["pos"],
			"forward": sm["tangent"],
			"spawn": spawn,
			"label": label,
			"plane": plane_mi,
			"pillar_mat": pillar_mat,
		})


func _on_checkpoint_body(body: Node3D, idx: int) -> void:
	checkpoint_entered.emit(idx, body)


func mark_checkpoint_passed(idx: int) -> void:
	if idx < 0 or idx >= checkpoints.size():
		return
	var cp: Dictionary = checkpoints[idx]
	cp["plane"].visible = false
	cp["label"].modulate = Color(0.3, 1.0, 0.4)
	cp["pillar_mat"].albedo_color = Color(0.3, 0.9, 0.35)


func get_spawn(idx: int) -> Transform3D:
	if idx < 0:
		return start_transform
	return checkpoints[idx]["spawn"]


func _build_finish() -> void:
	var s := total_length - 6.0
	var sm := _sample_at_s(s)
	finish_position = sm["pos"]
	finish_forward = sm["tangent"]
	var gate := Node3D.new()
	gate.position = sm["pos"]
	gate.rotation.y = TrackData.yaw_from_tangent(sm["tangent"])
	add_child(gate)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.85, 0.15, 0.15)
	for side_sign in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.42
		cyl.height = 6.4
		cyl.radial_segments = 8
		pillar.mesh = cyl
		pillar.material_override = pillar_mat
		pillar.position = Vector3(7.0 * side_sign, 3.2, 0)
		gate.add_child(pillar)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(14.6, 1.1, 0.7)
	beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.12, 0.12, 0.14)
	beam.material_override = beam_mat
	beam.position = Vector3(0, 6.2, 0)
	gate.add_child(beam)

	var label := Label3D.new()
	label.text = "终 点"
	label.font = UIHelper.get_font()
	label.font_size = 128
	label.pixel_size = 0.02
	label.modulate = Color(1.0, 0.9, 0.3)
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0)
	label.double_sided = true
	label.position = Vector3(0, 6.2, 0)
	gate.add_child(label)

	# 终点白线
	var line := MeshInstance3D.new()
	var lm := PlaneMesh.new()
	lm.size = Vector2(13.0, 1.4)
	line.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.92, 0.92, 0.90)
	line.material_override = lmat
	line.position = Vector3(0, 0.04, 0)
	gate.add_child(line)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14.5, 6.5, 3.0)
	shape.shape = box
	shape.position = Vector3(0, 3.0, 0)
	area.add_child(shape)
	gate.add_child(area)
	area.body_entered.connect(_on_finish_body)

	# 起点标识
	var start_label := Label3D.new()
	start_label.text = "起 点"
	start_label.font = UIHelper.get_font()
	start_label.font_size = 120
	start_label.pixel_size = 0.018
	start_label.modulate = Color(0.5, 1.0, 0.6)
	start_label.outline_size = 12
	start_label.outline_modulate = Color(0, 0, 0)
	start_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var start_sm: Dictionary = samples[2]
	start_label.position = start_sm["pos"] + Vector3.UP * 6.0
	add_child(start_label)


func _on_finish_body(body: Node3D) -> void:
	finish_entered.emit(body)


# ---------- 方向标识 ----------

func _build_signs() -> void:
	var last_sign_s := -100.0
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.10, 0.10, 0.12)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.3, 0.3, 0.32)
	var i := 6
	while i < samples.size() - 6:
		var t_a: Vector3 = samples[i - 5]["tangent"]
		var t_b: Vector3 = samples[i + 5]["tangent"]
		var angle := t_a.angle_to(t_b)
		var s: float = samples[i]["s"]
		if angle > 0.26 and s - last_sign_s > 70.0:
			last_sign_s = s
			var cross_y := t_a.cross(t_b).y
			var side_sign := 1.0 if cross_y > 0.0 else -1.0
			var text := "<<<" if cross_y > 0.0 else ">>>"
			_make_sign(samples[i], side_sign, text, board_mat, post_mat)
		i += 4


func _make_sign(sample: Dictionary, side_sign: float, text: String,
		board_mat: Material, post_mat: Material) -> void:
	var sign_node := Node3D.new()
	sign_node.position = sample["pos"] + sample["right"] * (8.4 * side_sign) + Vector3.UP * 1.9
	sign_node.rotation.y = TrackData.yaw_from_tangent(sample["tangent"]) + PI
	add_child(sign_node)

	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.8, 1.3, 0.12)
	board.mesh = bm
	board.material_override = board_mat
	sign_node.add_child(board)

	var chev := Label3D.new()
	chev.text = text
	chev.font_size = 110
	chev.pixel_size = 0.011
	chev.modulate = Color(1.0, 0.62, 0.1)
	chev.outline_size = 8
	chev.outline_modulate = Color(0, 0, 0)
	chev.position = Vector3(0, 0, 0.09)
	sign_node.add_child(chev)

	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = 1.6
	post.mesh = cyl
	post.material_override = post_mat
	post.position = Vector3(0, -1.3, 0)
	sign_node.add_child(post)


# ---------- 光照与环境 ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.75)
	sky_mat.sky_horizon_color = Color(0.85, 0.70, 0.55)
	sky_mat.ground_bottom_color = Color(0.45, 0.35, 0.28)
	sky_mat.ground_horizon_color = Color(0.85, 0.70, 0.55)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.72, 0.58)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	add_child(sun)


# ---------- 网格工具 ----------

## 添加一个四边形（两个三角形），顶点顺序固定为 v00,v01,v11,v10。
## Godot 正面为顺时针绕序，法线方向为 (v10-v00)×(v11-v00)。
func _quad(st: SurfaceTool, v00: Vector3, v01: Vector3, v11: Vector3, v10: Vector3, c: Color) -> void:
	st.set_color(c)
	st.add_vertex(v00)
	st.set_color(c)
	st.add_vertex(v10)
	st.set_color(c)
	st.add_vertex(v11)
	st.set_color(c)
	st.add_vertex(v00)
	st.set_color(c)
	st.add_vertex(v11)
	st.set_color(c)
	st.add_vertex(v01)


## 同 _quad，但保证正面朝向 face_dir。
func _quad_facing(st: SurfaceTool, v00: Vector3, v01: Vector3, v11: Vector3, v10: Vector3,
		c: Color, face_dir: Vector3) -> void:
	var n := (v10 - v00).cross(v11 - v00)
	if n.dot(face_dir) < 0.0:
		_quad(st, v00, v10, v11, v01, c)
	else:
		_quad(st, v00, v01, v11, v10, c)
