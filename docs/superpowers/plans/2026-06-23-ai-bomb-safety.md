# AI 放弹安全实现计划

> **面向 Agent 执行：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实施。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 为 AI 放弹增加「模拟爆炸 + BFS 逃生 + 引信步数」判定，消除死角自杀；放弹后同 tick 向逃生格移动一步。

**架构：** 在 `GameManager` 提取 `get_explosion_cells` 并新增 `get_danger_cells`、`_escape_bfs`、`can_safely_place_bomb`、`find_escape_cell_after_bomb`；`AIController` 用 `_try_bomb_and_flee` 替换 `_has_escape_route` 放弹逻辑。危险格在 BFS 中可穿过，终点须在爆炸射线外且步数 ≤ `floor(BOMB_FUSE_SEC / get_move_duration())`。

**技术栈：** Godot 4.x、GDScript、现有手写测试框架（`tests/run_tests.tscn`）

**参考文档：** `docs/superpowers/specs/2026-06-23-ai-bomb-safety-design.md`

**测试命令：**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

---

## 文件职责总览

| 文件 | 职责 |
|------|------|
| `scripts/systems/game_manager.gd` | 爆炸范围提取、危险区合并、逃生 BFS、放弹安全 API |
| `scripts/entities/ai_controller.gd` | `_try_bomb_and_flee`，删除 `_has_escape_route` |
| `tests/test_ai_bomb_safety.gd` | 死角、穿危险区、爆炸范围、步数限制等用例 |
| `tests/run_tests_node.gd` | 注册新测试 |

---

### 任务 1：`get_explosion_cells` 测试与实现

**文件：**
- 创建：`tests/test_ai_bomb_safety.gd`
- 修改：`scripts/systems/game_manager.gd`
- 修改：`tests/run_tests_node.gd`

- [ ] **步骤 1：创建测试文件（爆炸范围用例）**

创建 `tests/test_ai_bomb_safety.gd`：

```gdscript
extends RefCounted


static func _make_manager() -> Array:
	var root := Node.new()
	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	var bombs_root := Node2D.new()
	root.add_child(gm)
	gm.add_child(bombs_root)
	gm._bombs_root = bombs_root
	gm.map_data = MapData.new()
	return [root, gm]


static func _make_bomber(gm: GameManager, root: Node, cell: Vector2i) -> Bomber:
	var bomber := Bomber.new()
	root.add_child(bomber)
	bomber.setup(gm, cell, false, Color.BLUE)
	return bomber


static func _set_hard(map_data: MapData, cell: Vector2i) -> void:
	map_data.set_cell(cell, MapData.CellType.HARD_WALL)


static func _set_soft(map_data: MapData, cell: Vector2i) -> void:
	map_data.set_cell(cell, MapData.CellType.SOFT_WALL)


static func run(failures: PackedStringArray) -> void:
	_test_explosion_cells(failures)
	_test_dead_end_no_bomb(failures)
	_test_escape_through_danger(failures)
	_test_fuse_step_limit(failures)


static func _test_explosion_cells(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))

	var cells := gm.get_explosion_cells(Vector2i(2, 1), 1)
	var expected: Array[Vector2i] = [
		Vector2i(2, 1),
		Vector2i(2, 0),
		Vector2i(2, 2),
		Vector2i(3, 1),
	]
	for c in expected:
		if not cells.has(c):
			failures.append(
				"explosion_cells: expected %s in blast from (2,1), got %s"
				% [c, cells]
			)
	if cells.has(Vector2i(1, 1)):
		failures.append("explosion_cells: hard wall (1,1) should not be in blast")
	setup[0].free()


static func _test_dead_end_no_bomb(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))
	_set_hard(gm.map_data, Vector2i(2, 0))
	_set_hard(gm.map_data, Vector2i(2, 2))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))

	if gm.can_safely_place_bomb(bomber):
		failures.append("dead_end: bomber should not safely place bomb in sealed corner")

	setup[0].free()


static func _test_escape_through_danger(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))

	if not gm.can_safely_place_bomb(bomber):
		failures.append(
			"escape_through_danger: bomber should escape via (2,0)->(1,0)"
		)

	setup[0].free()


static func _test_fuse_step_limit(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	var bomber := _make_bomber(gm, setup[0], Vector2i(1, 1))
	# 构造 13 格长的水平走廊，安全格在 (14,1)；max_steps=12（2.5/0.2）
	for x in range(2, 14):
		gm.map_data.set_cell(Vector2i(x, 1), MapData.CellType.EMPTY)
	_set_hard(gm.map_data, Vector2i(0, 1))
	_set_hard(gm.map_data, Vector2i(15, 1))
	_set_hard(gm.map_data, Vector2i(14, 0))
	_set_hard(gm.map_data, Vector2i(14, 2))

	if gm.can_safely_place_bomb(bomber):
		failures.append(
			"fuse_step_limit: path too long for fuse should not allow bomb"
		)

	setup[0].free()
```

- [ ] **步骤 2：注册测试**

修改 `tests/run_tests_node.gd`：

```gdscript
const TestAiBombSafety := preload("res://tests/test_ai_bomb_safety.gd")
```

在 `_ready()` 中、`TestMapGeneratorSoftWalls.run(failures)` 之后添加：

```gdscript
TestAiBombSafety.run(failures)
```

- [ ] **步骤 3：运行测试，确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：FAIL，`get_explosion_cells` / `can_safely_place_bomb` 未定义或行为错误。

- [ ] **步骤 4：实现 `get_explosion_cells` 并重构 `_trigger_explosion`**

在 `scripts/systems/game_manager.gd` 中，于 `is_cell_dangerous` 之前添加：

```gdscript
func get_explosion_cells(origin: Vector2i, fire_range: int) -> Array[Vector2i]:
	var affected: Array[Vector2i] = [origin]
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for i in range(1, fire_range + 1):
			var cell: Vector2i = origin + d * i
			if not map_data.in_bounds(cell):
				break
			if map_data.get_cell(cell) == MapData.CellType.HARD_WALL:
				break
			affected.append(cell)
			if map_data.is_soft_wall(cell):
				break
	return affected
```

将 `_trigger_explosion` 开头替换为：

```gdscript
func _trigger_explosion(origin: Vector2i, range: int) -> void:
	var affected: Array[Vector2i] = get_explosion_cells(origin, range)
```

删除原 `_trigger_explosion` 内手动构建 `affected` 的 for 循环（第 200–210 行左右）。

- [ ] **步骤 5：运行测试**

预期：`_test_explosion_cells` 通过；其余仍 FAIL。

- [ ] **步骤 6：提交**

```bash
git add tests/test_ai_bomb_safety.gd tests/run_tests_node.gd scripts/systems/game_manager.gd
git commit -m "test: 添加 AI 放弹安全失败测试并实现 get_explosion_cells"
```

---

### 任务 2：危险区合并与逃生 BFS

**文件：**
- 修改：`scripts/systems/game_manager.gd`

- [ ] **步骤 1：实现 `get_danger_cells`**

紧接 `get_explosion_cells` 之后添加：

```gdscript
func get_danger_cells(extra_bomb: Dictionary = {}) -> Dictionary:
	var danger: Dictionary = {}
	for bomb in bombs.values():
		var b: Bomb = bomb
		var owner: Bomber = b.owner_bomber
		var r: int = owner.fire_range if owner else 1
		for cell in get_explosion_cells(b.grid_pos, r):
			danger[cell] = true
	if extra_bomb.has("cell") and extra_bomb.has("range"):
		for cell in get_explosion_cells(extra_bomb["cell"], int(extra_bomb["range"])):
			danger[cell] = true
	return danger
```

- [ ] **步骤 2：实现 `_escape_bfs`**

```gdscript
func _escape_bfs(bomber: Bomber, danger: Dictionary, bomb_cell: Vector2i) -> Dictionary:
	var start: Vector2i = bomber.grid_pos
	var distances: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var steps: int = int(distances[c])
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if distances.has(n):
				continue
			if not map_data.in_bounds(n):
				continue
			if map_data.is_blocking(n):
				continue
			if bombs.has(n) and n != bomb_cell:
				continue
			distances[n] = steps + 1
			queue.append(n)
	return distances
```

- [ ] **步骤 3：实现 `can_safely_place_bomb`**

```gdscript
func can_safely_place_bomb(bomber: Bomber) -> bool:
	if bomber == null or not bomber.is_alive or map_data == null:
		return false
	if bomber.active_bombs >= bomber.bomb_capacity:
		return false
	var bomb_cell: Vector2i = bomber.get_bomb_placement_cell()
	if bombs.has(bomb_cell):
		return false
	var danger := get_danger_cells({"cell": bomb_cell, "range": bomber.fire_range})
	var distances := _escape_bfs(bomber, danger, bomb_cell)
	var max_steps: int = int(floor(GameConstants.BOMB_FUSE_SEC / bomber.get_move_duration()))
	for cell in distances.keys():
		if danger.has(cell):
			continue
		if int(distances[cell]) <= max_steps:
			return true
	return false
```

- [ ] **步骤 4：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`dead_end`、`escape_through_danger`、`fuse_step_limit` 全部 PASS。

- [ ] **步骤 5：提交**

```bash
git add scripts/systems/game_manager.gd
git commit -m "feat: 实现 AI 放弹安全 BFS 判定"
```

---

### 任务 3：`find_escape_cell_after_bomb` 与 AIController

**文件：**
- 修改：`scripts/systems/game_manager.gd`
- 修改：`scripts/entities/ai_controller.gd`
- 修改：`tests/test_ai_bomb_safety.gd`

- [ ] **步骤 1：实现 `find_escape_cell_after_bomb`**

在 `can_safely_place_bomb` 之后添加：

```gdscript
func find_escape_cell_after_bomb(bomber: Bomber) -> Vector2i:
	if bomber == null or not bomber.is_alive:
		return Vector2i(-1, -1)
	var bomb_cell: Vector2i = Vector2i(-1, -1)
	for cell in bombs.keys():
		var b: Bomb = bombs[cell]
		if b.owner_bomber == bomber:
			bomb_cell = cell
			break
	if bomb_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var danger := get_danger_cells()
	var distances := _escape_bfs(bomber, danger, bomb_cell)
	var max_steps: int = int(floor(GameConstants.BOMB_FUSE_SEC / bomber.get_move_duration()))
	var best: Vector2i = Vector2i(-1, -1)
	var best_steps: int = 99999
	for cell in distances.keys():
		if danger.has(cell):
			continue
		var steps: int = int(distances[cell])
		if steps > max_steps:
			continue
		if steps < best_steps:
			best_steps = steps
			best = cell
	return best
```

- [ ] **步骤 2：在测试中补充放弹后逃生目标用例**

在 `test_ai_bomb_safety.gd` 的 `run()` 中调用 `_test_find_escape_after_bomb(failures)`，并添加：

```gdscript
static func _test_find_escape_after_bomb(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))
	gm.place_bomb(bomber)
	var escape := gm.find_escape_cell_after_bomb(bomber)
	if escape == Vector2i(-1, -1):
		failures.append("find_escape_after_bomb: expected reachable safe cell")
	elif escape != Vector2i(1, 0):
		failures.append(
			"find_escape_after_bomb: expected (1,0), got %s"
			% escape
		)
	setup[0].free()
```

- [ ] **步骤 3：修改 `AIController`**

将 `scripts/entities/ai_controller.gd` 中两处放弹逻辑：

```gdscript
		if _adjacent_to(player.grid_pos) and _has_escape_route():
			bomber.try_place_bomb()
```

```gdscript
		if _adjacent_to(soft) and _has_escape_route():
			bomber.try_place_bomb()
```

均改为：

```gdscript
		if _adjacent_to(player.grid_pos):
			_try_bomb_and_flee()
```

```gdscript
		if _adjacent_to(soft):
			_try_bomb_and_flee()
```

删除 `_has_escape_route()` 整个函数，在 `_adjacent_to` 之后添加：

```gdscript
func _try_bomb_and_flee() -> void:
	if not bomber.game_manager.can_safely_place_bomb(bomber):
		return
	bomber.try_place_bomb()
	var escape := bomber.game_manager.find_escape_cell_after_bomb(bomber)
	if escape != Vector2i(-1, -1):
		_step_toward(escape)
```

- [ ] **步骤 4：运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`PASS: all tests`

- [ ] **步骤 5：提交**

```bash
git add scripts/systems/game_manager.gd scripts/entities/ai_controller.gd tests/test_ai_bomb_safety.gd
git commit -m "feat: AI 放弹后逃生与 find_escape_cell_after_bomb"
```

---

### 任务 4：手动验证

- [ ] **步骤 1：启动游戏**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

- [ ] **步骤 2：验证清单**

1. 开局观察 AI 是否仍贴墙/死角自杀
2. AI 邻接软墙时能否放弹并走开（含穿过爆炸区）
3. 切换简单/普通/困难，放弹安全行为一致（仅决策快慢不同）

- [ ] **步骤 3：提交（若手动验证中有小修复）**

```bash
git add -A
git commit -m "fix: 手动验证后的 AI 放弹安全调整"
```

（无改动则跳过此提交。）

---

## 规格覆盖自检

| 规格要求 | 对应任务 |
|----------|----------|
| `get_explosion_cells` 与 `_trigger_explosion` 一致 | 任务 1 |
| 危险格可穿过、终点在射线外 | 任务 2 `_escape_bfs` |
| 引信步数上限 | 任务 2 `can_safely_place_bomb` |
| `find_escape_cell_after_bomb` 不复用 `find_safe_cell` | 任务 3 |
| `_try_bomb_and_flee` 同 tick 撤离 | 任务 3 |
| 死角 / 穿危险区 / 步数不足测试 | 任务 1–2 |
| 不模拟软墙摧毁、不模拟连锁 | 设计约束，实现中不添加 |
