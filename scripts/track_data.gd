class_name TrackData
## 赛道数据：控制点、样条采样、路面分段。

const ROAD_HALF_WIDTH := 5.5        ## 路面半宽（米）
const SHOULDER_WIDTH := 2.0         ## 路肩宽度（米）
const RAIL_OFFSET := 6.3            ## 护栏距中线距离（米）
const SAMPLE_STEP := 4.0            ## 样条采样间距（米）
const CHECKPOINT_COUNT := 8
const TIME_LIMIT := 150.0           ## 比赛限时（秒）
const RESET_PENALTY := 5.0          ## 复位罚时（秒）


## 赛道控制点（水平缩放后约 2000 米：直路、连续弯道、上坡、下坡）。
static func control_points() -> Array[Vector3]:
	const H_SCALE := 0.72
	var raw := [
		Vector3(0, 0, 0),
		Vector3(0, 0, -140),        # 发车直道
		Vector3(20, 1, -260),
		Vector3(90, 3, -340),       # 右弯
		Vector3(100, 8, -450),
		Vector3(40, 14, -530),      # 左弯上坡
		Vector3(-60, 20, -540),
		Vector3(-140, 26, -480),    # 连续弯
		Vector3(-160, 32, -380),
		Vector3(-110, 38, -290),
		Vector3(-10, 44, -260),
		Vector3(90, 50, -300),      # 上坡右弯
		Vector3(150, 55, -400),
		Vector3(140, 58, -510),     # 山顶
		Vector3(60, 54, -580),      # 开始下坡
		Vector3(-40, 48, -560),
		Vector3(-120, 42, -620),
		Vector3(-150, 36, -730),
		Vector3(-90, 30, -830),     # 下坡左弯
		Vector3(20, 24, -860),
		Vector3(120, 18, -820),
		Vector3(170, 12, -720),
		Vector3(160, 8, -600),
		Vector3(100, 4, -500),
		Vector3(60, 1, -390),       # 终点直道
		Vector3(50, 0, -260),
	]
	var points: Array[Vector3] = []
	for p in raw:
		points.append(Vector3(p.x * H_SCALE, p.y, p.z * H_SCALE))
	return points


## Catmull-Rom 样条插值。
static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## 采样整条赛道，返回 {points, tangents, dists, total_length}。
static func sample_track() -> Dictionary:
	var cps := control_points()
	var raw := PackedVector3Array()
	var n := cps.size()
	for i in range(n - 1):
		var p0: Vector3 = cps[maxi(i - 1, 0)]
		var p1: Vector3 = cps[i]
		var p2: Vector3 = cps[i + 1]
		var p3: Vector3 = cps[mini(i + 2, n - 1)]
		var seg_len := p1.distance_to(p2)
		var steps := maxi(int(seg_len / SAMPLE_STEP), 2)
		for j in range(steps):
			raw.append(_catmull(p0, p1, p2, p3, float(j) / float(steps)))
	raw.append(cps[n - 1])

	var tangents := PackedVector3Array()
	var dists := PackedFloat32Array()
	var total := 0.0
	for i in range(raw.size()):
		var prev: Vector3 = raw[maxi(i - 1, 0)]
		var next: Vector3 = raw[mini(i + 1, raw.size() - 1)]
		var tan := (next - prev)
		tan.y = tan.y  # 保留坡度
		tangents.append(tan.normalized())
		if i > 0:
			total += raw[i].distance_to(raw[i - 1])
		dists.append(total)
	return {
		"points": raw,
		"tangents": tangents,
		"dists": dists,
		"total_length": total,
	}


## 判断某里程处是否为砂石路段（25%~40% 与 60%~75%）。
static func is_gravel(s: float, total: float) -> bool:
	var f := s / total
	return (f >= 0.25 and f <= 0.40) or (f >= 0.60 and f <= 0.75)


## 由切线求水平朝向角（车头 -Z 朝向前方）。
static func yaw_from_tangent(tan: Vector3) -> float:
	return atan2(-tan.x, -tan.z)
