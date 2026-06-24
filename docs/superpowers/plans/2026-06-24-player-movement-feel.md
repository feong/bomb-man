# 玩家移动手感优化实现计划

> **面向 Agent 执行：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实施。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 让玩家方向输入即时反映到朝向/动画，同时用单槽缓冲与格心结算改善离散网格移动的跟手感，且不改变炸弹格对齐与 AI 行为。

**架构：** 在 `Bomber` 新增 `set_facing()` 分离表现与位移；`Player` 重写输入读取（最后按下优先）、单槽 `_buffered_dir`、以及 `_finish_move()` 覆盖实现格心续行。`Player` 从 `_physics_process` 改为 `_process`，与 `Bomber` 的 lerp 帧同步。

**技术栈：** Godot 4.x、GDScript、手写测试（`tests/run_tests.tscn`）

**参考文档：** `docs/superpowers/specs/2026-06-24-player-movement-feel-design.md`

**测试命令：**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

---

## 文件职责总览

| 文件 | 职责 |
|------|------|
| `scripts/entities/bomber.gd` | 新增 `set_facing(dir)` |
| `scripts/entities/player.gd` | 最后按下优先、缓冲、格心续行、`_process` 输入循环 |
| `tests/test_bomber_set_facing.gd` | `set_facing` 不改 `grid_pos` |
| `tests/test_player_move_finish.gd` | 格心结算消费缓冲/按住方向 |
| `tests/run_tests_node.gd` | 注册新测试 |

---

### 任务 1：`set_facing` — 失败测试

**文件：**
- 创建：`tests/test_bomber_set_facing.gd`
- 修改：`tests/run_tests_node.gd`

- [ ] **步骤 1：创建 `tests/test_bomber_set_facing.gd`**

```gdscript
extends RefCounted


static func run(failures: PackedStringArray) -> void:
	var root := Node.new()
	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	root.add_child(gm)
	gm.map_data = MapData.new()

	var bomber := Bomber.new()
	root.add_child(bomber)
	var start_cell := Vector2i(3, 3)
	bomber.setup(gm, start_cell, true, Color.RED)

	bomber.set_facing(Vector2i.LEFT)

	if bomber.grid_pos != start_cell:
		failures.append(
			"set_facing: grid_pos should stay %s, got %s" % [start_cell, bomber.grid_pos]
		)
	if bomber._facing != Vector2i.LEFT:
		failures.append(
			"set_facing: _facing should be LEFT, got %s" % bomber._facing
		)
	if bomber._is_moving:
		failures.append("set_facing: should not start movement")

	root.free()
```

- [ ] **步骤 2：在 `tests/run_tests_node.gd` 注册测试**

在文件顶部 `const` 区添加：

```gdscript
const TestBomberSetFacing := preload("res://tests/test_bomber_set_facing.gd")
```

在 `_ready()` 中 `TestBomberPlaceBombWhileMoving.run(failures)` 之后添加：

```gdscript
	TestBomberSetFacing.run(failures)
```

- [ ] **步骤 3：运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`FAIL: set_facing` 相关错误（`set_facing` 方法不存在）

- [ ] **步骤 4：提交**

```bash
git add tests/test_bomber_set_facing.gd tests/run_tests_node.gd
git commit -m "test: 添加 Bomber.set_facing 失败用例"
```

---

### 任务 2：实现 `Bomber.set_facing`

**文件：**
- 修改：`scripts/entities/bomber.gd`（在 `can_act()` 之后、`try_move()` 之前）

- [ ] **步骤 1：添加 `set_facing`**

在 `scripts/entities/bomber.gd` 的 `can_act()` 与 `try_move()` 之间插入：

```gdscript
func set_facing(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	_facing = dir
	_play_walk(dir)
```

- [ ] **步骤 2：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`PASS: all tests`

- [ ] **步骤 3：提交**

```bash
git add scripts/entities/bomber.gd
git commit -m "feat: Bomber 新增 set_facing 仅更新朝向动画"
```

---

### 任务 3：格心续行 — 失败测试

**文件：**
- 创建：`tests/test_player_move_finish.gd`
- 修改：`tests/run_tests_node.gd`

- [ ] **步骤 1：创建 `tests/test_player_move_finish.gd`**

```gdscript
extends RefCounted


static func run(failures: PackedStringArray) -> void:
	_test_finish_uses_buffered_dir(failures)
	_test_finish_idle_when_no_input(failures)


static func _make_player() -> Array:
	var root := Node.new()
	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	root.add_child(gm)
	gm.map_data = MapData.new()
	var player: Player = preload("res://scripts/entities/player.gd").new()
	root.add_child(player)
	player.setup(gm, Vector2i(5, 5), true, Color.RED)
	return [root, player]


static func _test_finish_uses_buffered_dir(failures: PackedStringArray) -> void:
	var setup := _make_player()
	var root: Node = setup[0]
	var player: Player = setup[1]
	var start := player.grid_pos

	player._buffered_dir = Vector2i.RIGHT
	player._continue_after_move(Vector2i.ZERO)

	if player.grid_pos != start + Vector2i.RIGHT:
		failures.append(
			"move_finish_buffered: expected %s, got %s"
			% [start + Vector2i.RIGHT, player.grid_pos]
		)
	if player._buffered_dir != Vector2i.ZERO:
		failures.append("move_finish_buffered: buffer should be cleared after consume")

	root.free()


static func _test_finish_idle_when_no_input(failures: PackedStringArray) -> void:
	var setup := _make_player()
	var root: Node = setup[0]
	var player: Player = setup[1]
	var start := player.grid_pos

	player._continue_after_move(Vector2i.ZERO)

	if player.grid_pos != start:
		failures.append(
			"move_finish_idle: grid_pos should stay %s, got %s" % [start, player.grid_pos]
		)
	if player._is_moving:
		failures.append("move_finish_idle: should not start moving")

	root.free()
```

- [ ] **步骤 2：在 `tests/run_tests_node.gd` 注册**

```gdscript
const TestPlayerMoveFinish := preload("res://tests/test_player_move_finish.gd")
```

```gdscript
	TestPlayerMoveFinish.run(failures)
```

- [ ] **步骤 3：运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`FAIL: move_finish_buffered`（`_continue_after_move` 不存在）

- [ ] **步骤 4：提交**

```bash
git add tests/test_player_move_finish.gd tests/run_tests_node.gd
git commit -m "test: 添加玩家格心续行失败用例"
```

---

### 任务 4：重写 `Player` 输入与缓冲

**文件：**
- 修改：`scripts/entities/player.gd`（整文件替换）

- [ ] **步骤 1：用以下完整内容替换 `scripts/entities/player.gd`**

```gdscript
extends Bomber

var _bomb_pressed: bool = false
var _last_dir: Vector2i = Vector2i.ZERO
var _buffered_dir: Vector2i = Vector2i.ZERO

const _DIR_BINDINGS: Array[Dictionary] = [
	{"action": "move_up", "dir": Vector2i.UP},
	{"action": "move_down", "dir": Vector2i.DOWN},
	{"action": "move_left", "dir": Vector2i.LEFT},
	{"action": "move_right", "dir": Vector2i.RIGHT},
]


func _process(delta: float) -> void:
	if can_act():
		_handle_movement_input()
		_handle_bomb_input()
	super._process(delta)


func _handle_movement_input() -> void:
	var dir := _read_input_direction()

	if dir != Vector2i.ZERO:
		set_facing(dir)
	elif not _is_moving:
		_play_idle()

	if dir == Vector2i.ZERO:
		_buffered_dir = Vector2i.ZERO
	elif _is_moving:
		_buffered_dir = dir
	else:
		try_move(dir)


func _finish_move() -> void:
	super._finish_move()
	_continue_after_move(_read_input_direction())


func _continue_after_move(held_dir: Vector2i) -> void:
	if held_dir != Vector2i.ZERO:
		try_move(held_dir)
		return
	if _buffered_dir != Vector2i.ZERO:
		var buffered := _buffered_dir
		_buffered_dir = Vector2i.ZERO
		try_move(buffered)


func _read_input_direction() -> Vector2i:
	for binding in _DIR_BINDINGS:
		if Input.is_action_just_pressed(binding.action):
			_last_dir = binding.dir

	if _last_dir != Vector2i.ZERO and _is_dir_pressed(_last_dir):
		return _last_dir

	for binding in _DIR_BINDINGS:
		if Input.is_action_pressed(binding.action):
			_last_dir = binding.dir
			return binding.dir

	_last_dir = Vector2i.ZERO
	return Vector2i.ZERO


func _is_dir_pressed(dir: Vector2i) -> bool:
	for binding in _DIR_BINDINGS:
		if binding.dir == dir:
			return Input.is_action_pressed(binding.action)
	return false


func _handle_bomb_input() -> void:
	if Input.is_action_pressed("place_bomb"):
		if not _bomb_pressed:
			_bomb_pressed = true
			try_place_bomb()
	else:
		_bomb_pressed = false
```

**实现说明（供执行者核对）：**

- `_process` 末尾调用 `super._process(delta)`，保留 `Bomber` 的 lerp 移动。
- 静止时：`try_move(dir)` 直接发起移动；失败时 `set_facing` 已在上方执行，朝向仍跟手。
- 移动中：只写 `_buffered_dir`，不调用 `try_move`。
- `_finish_move` 覆盖：`super` 完成占格/拾取后，按 spec 先 `held_dir` 后缓冲续行。
- `_continue_after_move` 公开给测试调用；生产路径仅 `_finish_move` 使用。

- [ ] **步骤 2：运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：`PASS: all tests`（含 `test_bomber_place_bomb_while_moving` 回归）

- [ ] **步骤 3：提交**

```bash
git add scripts/entities/player.gd
git commit -m "feat: 玩家单槽输入缓冲与即时朝向"
```

---

### 任务 5：手动验证

**文件：** 无代码变更

- [ ] **步骤 1：启动游戏手动测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

按 spec 第 12 节逐项验证：

1. 原地快速左右：朝向跟手，`grid_pos` 不变
2. 右移中 tap 左后松手：走完当前格停，不折返
3. 右移中按住左：格心折返
4. 路口提前按垂直方向：格心拐弯
5. 顶墙：朝向更新，位置不变
6. 移动中放弹：炸弹在离开的格
7. 观察 AI：行为与改前一致

- [ ] **步骤 2：若有手感问题，仅调整 `player.gd`，不改 `Bomber.try_move` 语义**

---

## 规格覆盖自检

| 规格章节 | 对应任务 |
|---------|---------|
| 5.1 `set_facing` | 任务 2 |
| 5.2–5.4 即时朝向 / 原地连按 / 移动中换向 | 任务 4 |
| 6 单槽缓冲 | 任务 4 |
| 7 每帧处理顺序 | 任务 4 `_process` |
| 8 最后按下优先 | 任务 4 `_read_input_direction` |
| 9 格心结算 | 任务 4 `_finish_move` + 任务 3 测试 |
| 10 不变项（AI、放弹格） | 任务 4 不改 `try_move`；任务 5 回归 |
| 12 测试计划 | 任务 3、5 |

---

## 执行交接

计划已保存至 `docs/superpowers/plans/2026-06-24-player-movement-feel.md`。

**两种执行方式：**

1. **Subagent-Driven（推荐）** — 每个任务派生子 Agent，任务间做代码审查，迭代快
2. **Inline Execution** — 本会话用 executing-plans 按检查点批量执行

请选择一种方式开始实现。
