# AI 躲避他人炸弹实现计划

> **面向 Agent 执行：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实施。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 统一 AI 逃离爆炸区逻辑，修复「他人炸弹引信期间 AI 已在射线上却原地不动」的问题。

**架构：** 在 `GameManager` 新增 `find_escape_from_danger(bomber)`，复用 `_escape_bfs` + `_pick_best_escape_cell`；`find_escape_cell_after_bomb` 委托至同一实现。`AIController` 危险分支统一调用此 API，寻路使用 `allow_danger = true`。删除 `_move_away`。

**技术栈：** Godot 4.x、GDScript、现有手写测试框架（`tests/run_tests.tscn`）

**参考文档：** `docs/superpowers/specs/2026-06-24-ai-dodge-external-bomb-design.md`

**测试命令：**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

---

## 文件职责总览

| 文件 | 职责 |
|------|------|
| `scripts/systems/game_manager.gd` | 新增 `find_escape_from_danger`；`find_escape_cell_after_bomb` 改为委托 |
| `scripts/entities/ai_controller.gd` | 危险分支统一；删除 `_move_away` |
| `tests/test_ai_bomb_safety.gd` | 新增他人炸弹逃离用例 |

---

### 任务 1：他人炸弹逃离 — 失败测试

**文件：**
- 修改：`tests/test_ai_bomb_safety.gd`

- [ ] **步骤 1：在 `run()` 中注册三个新用例**

在 `tests/test_ai_bomb_safety.gd` 的 `run()` 末尾追加：

```gdscript
	_test_external_bomb_escape_through_danger(failures)
	_test_external_bomb_still_in_blast(failures)
	_test_external_bomb_path_through_danger(failures)
```

- [ ] **步骤 2：添加辅助函数 `_place_external_bomb`**

在同一文件 `_set_soft` 之后添加：

```gdscript
static func _place_external_bomb(gm: GameManager, root: Node, bomb_cell: Vector2i) -> Bomber:
	var owner := _make_bomber(gm, root, bomb_cell)
	owner.fire_range = 1
	gm.place_bomb(owner)
	return owner
```

- [ ] **步骤 3：添加 `_test_external_bomb_escape_through_danger`**

```gdscript
static func _test_external_bomb_escape_through_danger(failures: PackedStringArray) -> void:
	# 玩家炸弹在 (3,1)，AI 在 (2,1)；须穿过 (2,0) 到达 (1,0)
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_place_external_bomb(gm, setup[0], Vector2i(3, 1))
	var ai := _make_bomber(gm, setup[0], Vector2i(2, 1))

	if ai.active_bombs != 0:
		failures.append("external_escape: AI should have no active bombs")

	var escape: Vector2i = gm.find_escape_from_danger(ai)
	if escape != Vector2i(1, 0):
		failures.append(
			"external_escape: expected (1,0), got %s" % escape
		)

	setup[0].free()
```

- [ ] **步骤 4：添加 `_test_external_bomb_still_in_blast`**

```gdscript
static func _test_external_bomb_still_in_blast(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_build_user_pocket_map(gm)
	_place_external_bomb(gm, setup[0], Vector2i(3, 1))
	var ai := _make_bomber(gm, setup[0], Vector2i(4, 1))

	if not gm.is_cell_in_blast(ai.grid_pos):
		failures.append("external_still_in_blast: (4,1) should be in blast")

	var escape: Vector2i = gm.find_escape_from_danger(ai)
	if escape == Vector2i(-1, -1) or gm.is_cell_in_blast(escape):
		failures.append(
			"external_still_in_blast: expected escape outside blast, got %s"
			% escape
		)

	setup[0].free()
```

- [ ] **步骤 5：添加 `_test_external_bomb_path_through_danger`**

```gdscript
static func _test_external_bomb_path_through_danger(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_place_external_bomb(gm, setup[0], Vector2i(3, 1))
	var ai := _make_bomber(gm, setup[0], Vector2i(2, 1))
	var escape: Vector2i = gm.find_escape_from_danger(ai)

	if escape == Vector2i(-1, -1):
		failures.append("external_path: expected escape cell")
		setup[0].free()
		return

	var path: Array[Vector2i] = gm.find_path(ai, escape, false)
	if path.size() < 2:
		failures.append(
			"external_path: expected path length >= 2, got %s" % path
		)
	elif not gm.get_danger_cells().has(path[1]):
		failures.append(
			"external_path: first step %s should cross fuse-danger cell" % path[1]
		)

	setup[0].free()
```

- [ ] **步骤 6：运行测试确认失败**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：FAIL，报错含 `find_escape_from_danger` 不存在或 `external_escape` 断言失败。

- [ ] **步骤 7：提交**

```bash
git add tests/test_ai_bomb_safety.gd
git commit -m "$(cat <<'EOF'
test: 添加他人炸弹逃离失败用例

覆盖穿过引信危险区、射线上逃离与寻路语义。
EOF
)"
```

---

### 任务 2：`find_escape_from_danger` 实现

**文件：**
- 修改：`scripts/systems/game_manager.gd`

- [ ] **步骤 1：在 `find_escape_cell_after_bomb` 之前插入新函数**

在 `scripts/systems/game_manager.gd` 约第 345 行（`find_escape_cell_after_bomb` 定义处）替换为：

```gdscript
func find_escape_from_danger(bomber: Bomber) -> Vector2i:
	if bomber == null or not bomber.is_alive or map_data == null:
		return Vector2i(-1, -1)
	var bomb_cell: Vector2i = Vector2i(-1, -1)
	if bomber.active_bombs > 0:
		for cell in bombs.keys():
			var b: Bomb = bombs[cell]
			if b.owner_bomber == bomber:
				bomb_cell = cell
				break
	var danger := get_danger_cells()
	var distances := _escape_bfs(bomber, danger, bomb_cell)
	var max_steps: int = int(floor(GameConstants.BOMB_FUSE_SEC / bomber.get_move_duration()))
	return _pick_best_escape_cell(bomber, distances, danger, bomb_cell, max_steps)


func find_escape_cell_after_bomb(bomber: Bomber) -> Vector2i:
	return find_escape_from_danger(bomber)
```

（删除原 `find_escape_cell_after_bomb` 函数体中查找 `bomb_cell`、无炸弹时返回 `(-1,-1)` 等重复逻辑。）

- [ ] **步骤 2：运行测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：全部 PASS（含新增 3 个用例与原有 `test_ai_bomb_safety` 回归）。

- [ ] **步骤 3：提交**

```bash
git add scripts/systems/game_manager.gd
git commit -m "$(cat <<'EOF'
feat: 统一 find_escape_from_danger 逃离爆炸区 API

自己与他人炸弹共用 BFS 逃生逻辑，find_escape_cell_after_bomb 委托调用。
EOF
)"
```

---

### 任务 3：`AIController` 危险分支统一

**文件：**
- 修改：`scripts/entities/ai_controller.gd`

- [ ] **步骤 1：替换 `_tick` 危险分支**

将 `_tick` 中第 29–39 行：

```gdscript
	if gm.is_cell_in_blast(bomber.grid_pos) or gm.is_cell_dangerous(bomber.grid_pos, params):
		if bomber.active_bombs > 0:
			var escape := gm.find_escape_cell_after_bomb(bomber)
			if escape != Vector2i(-1, -1) and not bomber._is_moving:
				_step_toward(escape, true)
				_sync_idle()
				return
		if not bomber._is_moving:
			_move_away(params)
		_sync_idle()
		return
```

替换为：

```gdscript
	if gm.is_cell_in_blast(bomber.grid_pos) or gm.is_cell_dangerous(bomber.grid_pos, params):
		if not bomber._is_moving:
			var escape := gm.find_escape_from_danger(bomber)
			if escape != Vector2i(-1, -1):
				_step_toward(escape, true)
		_sync_idle()
		return
```

- [ ] **步骤 2：删除 `_move_away` 函数**

删除 `ai_controller.gd` 第 99–102 行：

```gdscript
func _move_away(params: Dictionary) -> void:
	var target := bomber.game_manager.find_safe_cell(bomber, params)
	if target != Vector2i(-1, -1):
		_step_toward(target)
```

- [ ] **步骤 3：运行全部测试**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_tests.tscn
```

预期：全部 PASS。

- [ ] **步骤 4：提交**

```bash
git add scripts/entities/ai_controller.gd
git commit -m "$(cat <<'EOF'
fix: AI 遇他人炸弹时统一使用 allow_danger 逃离寻路

删除 find_safe_cell 逃离路径，修复射线上原地不动问题。
EOF
)"
```

---

### 任务 4：规格状态更新与手动验证

**文件：**
- 修改：`docs/superpowers/specs/2026-06-24-ai-dodge-external-bomb-design.md`

- [ ] **步骤 1：将规格状态改为「已批准」**

将第 4 行 `**状态：** 待审阅` 改为 `**状态：** 已批准`。

- [ ] **步骤 2：手动验证（Godot 编辑器运行游戏）**

1. 开局追击 AI，当面放弹（AI 在爆炸射线上）→ AI 应在引信内走开。
2. 窄道对角逃生场景 → AI 沿 `(2,1)→(2,0)→(1,0)` 类路径撤离。
3. 三面墙死局放弹 → AI 仍站着（正确行为）。

- [ ] **步骤 3：提交**

```bash
git add docs/superpowers/specs/2026-06-24-ai-dodge-external-bomb-design.md
git commit -m "$(cat <<'EOF'
docs: 标记 AI 躲避他人炸弹规格为已批准
EOF
)"
```

---

## 规格覆盖自检

| 规格要求 | 对应任务 |
|----------|----------|
| `find_escape_from_danger` 新 API | 任务 2 |
| `find_escape_cell_after_bomb` 委托 | 任务 2 |
| AI 危险分支统一 + `allow_danger=true` | 任务 3 |
| 删除 `_move_away` | 任务 3 |
| 他人炸弹三则用例 | 任务 1 |
| 回归用例无破坏 | 任务 2、3 测试步骤 |
| `find_safe_cell` 保留不变 | 无改动（符合规格） |
| 不在范围项（主动避险、_is_moving 门控） | 无任务 |
