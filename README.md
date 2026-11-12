# 峡谷冲线 (Canyon Rally)

Godot 4.7.2 开发的 3D 低多边形峡谷越野计时赛车游戏。

## 运行

用 Godot 4.7.2 打开本工程目录，运行主场景 `scenes/main_menu.tscn`（已设为默认主场景）。

## 操作

| 按键 | 功能 |
| --- | --- |
| W / ↑ | 加速 |
| S / ↓ | 刹车 / 倒车 |
| A D / ← → | 转向 |
| Shift | 手刹（漂移甩尾） |
| 空格 | 氮气（持续约 6 秒过热，过热锁定 4 秒） |
| R | 复位到最近检查点（+5 秒罚时） |
| Esc / P | 暂停 |
| 鼠标 | 菜单操作 |

## 玩法

- 限时 150 秒，按顺序通过 8 个检查点后正向冲过终点即完成比赛。
- 赛道约 2000 米，含直路、连续弯道、上下坡；沥青与砂石两种路面（砂石抓地力更低、制动更长）。
- 跳过检查点或反向穿过终点不能完成比赛。
- 本地保存最佳有效成绩（`user://canyon_rally_save.cfg`），失败不覆盖纪录。

## 结构

- `scripts/track_data.gd` — 赛道控制点、样条采样、路面分段常量
- `scripts/track_builder.gd` — 程序化生成赛道/峡谷/护栏/检查点/标识/光照
- `scripts/car.gd` — 街机车辆物理（漂移、氮气热量、路面抓地差异）
- `scripts/game.gd` — 比赛状态机（倒计时/比赛/暂停/结算）
- `scripts/hud.gd` — HUD 与菜单面板
- `scripts/game_camera.gd` — 平滑跟随镜头
- `scripts/save_manager.gd` — 自动加载：成绩存档与输入映射
- `tests/` — 无头测试：自动驾驶全程 (`test_drive`)、系统 (`test_systems`)、规则 (`test_logic`)、截图 (`test_screenshot`)
