# 扩大地图网格实现计划

> **面向 Agent 执行：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实施。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 将默认对战地图从 13×11 扩大到 21×17，通过修改 `GameConstants` 常量实现，并补充自动化测试验证地图尺寸与生成逻辑。

**架构：** 仅改 `scripts/constants.gd` 中 `GRID_WIDTH` / `GRID_HEIGHT`；出生点、`MAP_PIXEL_SIZE`、`map_offset()` 均由常量推导。`MapGenerator`、`MapData`、`MapView` 等已通过 `GameConstants` 引用尺寸，无需改动。

**技术栈：** Godot 4.x、GDScript、现有手写测试框架（`tests/run_tests.tscn`）

**参考文档：** `docs/superpowers/specs/2026-06-23-larger-grid-design.md`

---

## 文件职责总览

| 文件 | 职责 |
|------|------|
| `scripts/constants.gd` | 修改 `GRID_WIDTH` / `GRID_HEIGHT` 为 21 / 17 |
| `tests/test_grid_constants.gd` | 验证常量、出生点、`map_offset()` |
| `tests/test_map_generator_grid.gd` | 验证 `MapData` 尺寸与 `MapGenerator` 生成规则 |
| `tests/run_tests_node.gd` | 注册并运行新测试 |

以下文件**无需修改**：`map_data.gd`、`map_generator.gd`、`map_view.gd`、`game_manager.gd`、所有 `.tscn` 场景。

---

### 任务 1：网格常量自动化测试

**文件：**
- 创建：`tests/test_grid_constants.gd`
- 修改：`tests/run_tests_node.gd`

- [ ] **步骤 1：编写失败测试**

创建 `tests/test_grid_constants.gd`：

```gdscript
extends RefCounted


static func run(failures: PackedStringArray) -> void:
	if GameConstants.GRID_WIDTH != 21:
		failures.append(
			"grid_constants: GRID_WIDTH should be 21, got %d"
			% GameConstants.GRID_WIDTH
		)
	if GameConstants.GRID_HEIGHT != 17:
		failures.append(
			"grid_constants: GRID_HEIGHT should be 17, got %d"
			% GameConstants.GRID_HEIGHT
		)
	if GameConstants.MAP_PIXEL_SIZE != Vector2i(672, 544):
		failures.append(
			"grid_constants: MAP_PIXEL_SIZE should be (672, 544), got %s"
			% GameConstants.MAP_PIXEL_SIZE
		)

	var expected_spawns: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(19, 1),
		Vector2i(1, 15),
		Vector2i(19, 15),
	]
	for i in expected_spawns.size():
		if GameConstants.SPAWN_CELLS[i] != expected_spawns[i]:
			failures.append(
				"grid_constants: SPAWN_CELLS[%d] should be %s, got %s"
				% [i, expected_spawns[i], GameConstants.SPAWN_CELLS[i]]
			)

	var offset := GameConstants.map_offset()
	if offset != Vector2(144.0, 108.0):
		failures.append(
			"grid_constants: map_offset() should be (144, 108), got %s"
			% offset
		)
```

- [ ] **步骤 2：注册测试并运行，确认失败**

修改 `tests/run_tests_node.gd`，在文件顶部添加 preload，在 `_ready()` 中调用：

```gdscript
const TestGridConstants := preload("res://tests/test_grid_constants.gd")
```

```gdscript
TestGridConstants.run(failures)
```

运行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：FAIL，`GRID_WIDTH should be 21, got 13` 等错误。

- [ ] **步骤 3：提交测试（红灯）**

```bash
git add tests/test_grid_constants.gd tests/run_tests_node.gd
git commit -m "test: 添加 21×17 网格常量失败测试"
```

---

### 任务 2：修改网格常量

**文件：**
- 修改：`scripts/constants.gd`

- [ ] **步骤 1：更新常量**

将 `scripts/constants.gd` 第 4–5 行改为：

```gdscript
const GRID_WIDTH := 21
const GRID_HEIGHT := 17
```

- [ ] **步骤 2：运行测试，确认任务 1 测试通过**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`PASS: all tests`（此时仅含 grid_constants 与既有 bomber 测试）。

- [ ] **步骤 3：提交**

```bash
git add scripts/constants.gd
git commit -m "feat: 将默认地图网格扩大至 21×17"
```

---

### 任务 3：地图生成自动化测试

**文件：**
- 创建：`tests/test_map_generator_grid.gd`
- 修改：`tests/run_tests_node.gd`

- [ ] **步骤 1：编写测试**

创建 `tests/test_map_generator_grid.gd`：

```gdscript
extends RefCounted


static func run(failures: PackedStringArray) -> void:
	_test_map_data_dimensions(failures)
	_test_generator_layout(failures)
	_test_generator_connectivity(failures)
	_test_spawn_safe_zones(failures)


static func _test_map_data_dimensions(failures: PackedStringArray) -> void:
	var map := MapData.new()
	if map.cells.size() != 17:
		failures.append(
			"map_data: cells should have 17 rows, got %d" % map.cells.size()
		)
	if map.cells.size() > 0 and map.cells[0].size() != 21:
		failures.append(
			"map_data: cells should have 21 columns, got %d" % map.cells[0].size()
		)


static func _test_generator_layout(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	var map := gen._build_base()

	# 外圈硬墙
	for x in GameConstants.GRID_WIDTH:
		if map.get_cell(Vector2i(x, 0)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: top border missing hard wall at x=%d" % x)
		if map.get_cell(Vector2i(x, GameConstants.GRID_HEIGHT - 1)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: bottom border missing hard wall at x=%d" % x)
	for y in GameConstants.GRID_HEIGHT:
		if map.get_cell(Vector2i(0, y)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: left border missing hard wall at y=%d" % y)
		if map.get_cell(Vector2i(GameConstants.GRID_WIDTH - 1, y)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: right border missing hard wall at y=%d" % y)

	# 棋盘格硬墙柱（内圈偶数坐标）
	for y in range(2, GameConstants.GRID_HEIGHT - 1, 2):
		for x in range(2, GameConstants.GRID_WIDTH - 1, 2):
			if map.get_cell(Vector2i(x, y)) != MapData.CellType.HARD_WALL:
				failures.append(
					"generator_layout: checker pillar missing at (%d, %d)" % [x, y]
				)


static func _test_generator_connectivity(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	var map := gen.generate()
	if not gen._is_connected(map):
		failures.append("generator_connectivity: generated map is not connected")


static func _test_spawn_safe_zones(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	# 固定随机种子，使软墙散布可重复
	seed(42)
	var map := gen.generate()
	for spawn in gen.get_active_spawns():
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if absi(dx) + absi(dy) > 2:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if not map.in_bounds(cell):
					continue
				if map.get_cell(cell) == MapData.CellType.SOFT_WALL:
					failures.append(
						"spawn_safe_zone: soft wall at %s within safe zone of spawn %s"
						% [cell, spawn]
					)
```

- [ ] **步骤 2：注册测试**

在 `tests/run_tests_node.gd` 添加：

```gdscript
const TestMapGeneratorGrid := preload("res://tests/test_map_generator_grid.gd")
```

```gdscript
TestMapGeneratorGrid.run(failures)
```

- [ ] **步骤 3：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`PASS: all tests`

- [ ] **步骤 4：提交**

```bash
git add tests/test_map_generator_grid.gd tests/run_tests_node.gd
git commit -m "test: 添加 21×17 地图生成与布局测试"
```

---

### 任务 4：手动验证

**文件：** 无代码改动

- [ ] **步骤 1：启动游戏**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/main_menu.tscn
```

- [ ] **步骤 2：按规格手动测试清单逐项确认**

- [ ] 地图正确渲染 21×17，外圈硬墙与棋盘格柱布局正常
- [ ] 地图在 960×720 窗口内居中，顶栏 HUD 不遮挡
- [ ] 玩家与 AI 在四角正确出生，安全区内无软墙
- [ ] 软墙密度体感合理，各出生点之间可通行
- [ ] 移动、放弹、爆炸、连锁、道具拾取正常
- [ ] AI 寻路与决策在大地图上无异常卡顿
- [ ] 身体接触、穿弹规则仍正常
- [ ] 胜负判定与重开流程正常

---

## 规格覆盖自检

| 规格要求 | 对应任务 |
|----------|----------|
| GRID_WIDTH=21, GRID_HEIGHT=17 | 任务 2 |
| MAP_PIXEL_SIZE=672×544 | 任务 1 测试 |
| 出生点四角坐标正确 | 任务 1 测试 |
| map_offset 居中 | 任务 1 测试 |
| 外圈硬墙 + 棋盘格柱 | 任务 3 测试 |
| 软墙密度 55%、安全区、连通性 | 任务 3 测试 |
| 玩法无回归 | 任务 4 手动验证 + 既有 bomber 测试 |
| 主设计文档已更新 |  brainstorming 阶段已完成 |
