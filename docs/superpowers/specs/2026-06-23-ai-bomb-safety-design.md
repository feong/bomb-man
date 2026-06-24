# AI 放弹安全设计规格

**日期：** 2026-06-23  
**状态：** 已批准  
**关联规格：**
- `docs/superpowers/specs/2025-06-23-bomberman-design.md`
- `docs/superpowers/specs/2026-06-24-explosion-damage-design.md`

---

## 1. 概述

### 问题

当前 AI 在邻接软墙或玩家时，仅通过 `_has_escape_route()` 判断「四邻是否有一格能走」即放弹。该检查未模拟放弹后的爆炸范围，导致 AI 常在「炸弹 + 墙」窄道中放弹后无法逃到安全区而自杀。

### 目标

消除 AI 因放弹位置不当导致的愚蠢自杀；宁可少放弹，也不在无法逃生时放弹。

### 成功标准

- AI 在真正的死角（引信结束前到不了爆炸范围外）不再放弹。
- 开阔区域或「需穿过爆炸区才能到达安全格」的局面，AI 仍能正常放弹并撤离。
- 放弹通过后，同一决策 tick 内向最近逃生目标格移动一步。
- 简单 / 普通 / 困难三档共用同一套严格逃生判定。
- 新增单元测试覆盖核心场景，现有测试无回归。

### 不在范围内

- 调整 AI 追击概率、寻道具概率、决策间隔等难度参数
- 实现原设计中的「困难档堵路」等进攻增强
- 启用或改造 `danger_margin` 参数（当前未使用，本方案以精确爆炸范围判定）
- 模拟放弹后软墙被摧毁
- 模拟连锁引爆（偏保守，宁可少放弹）

---

## 2. 方案选择

采用**方案 A：模拟放弹 + BFS 逃生验证**。

在 `GameManager` 中新增假想炸弹爆炸范围计算与 `can_safely_place_bomb()`；`AIController` 放弹前调用该 API，通过后放弹并同 tick 撤离。

未采用邻格启发式规则（漏判复杂地形）或仅加强 `_has_escape_route()`（未考虑放弹后爆炸范围）的方案。

---

## 3. 爆炸与逃生语义

### 3.1 爆炸形状是十字，不是方块

`fire_range = 1` 时，炸弹在 `(x, y)` 的危险格为原点加四向射线上的格（遇墙即止），**不包含对角格**：

```text
      (x,y-1)  ← 射线上，危险
         |
(x-1,y)—(x,y)—(x+1,y)
         |
      (x,y+1)  ← 射线上，危险

(x-1,y-1) 等对角格 ← 不在射线上，安全
```

因此「放弹后上下左右都在射线上」并不等于必死——AI 可在引信期间**穿过**危险格，到达射线外的安全格（常为对角方向，如 `(x,y) → (x,y-1) → (x-1,y-1)`）。

### 3.2 逃生判定的正确含义

| 概念 | 定义 |
|------|------|
| 危险格 | 引爆瞬间站立其上会受伤；**寻路时可通行**（模拟引信期间穿行） |
| 安全格 | 不在任何相关炸弹的爆炸射线上 |
| 可安全放弹 | 存在一条路径：从 `bomber.grid_pos` 到某个安全格，**路径长度 ≤ 引信允许的最大步数** |

引信允许的最大步数：

```text
max_steps = floor(GameConstants.BOMB_FUSE_SEC / bomber.get_move_duration())
```

使用 `bomber.get_move_duration()` 以反映该 AI 当前速度档位。

### 3.3 与旧 `_has_escape_route()` 的差异

旧逻辑：四邻有一格能走 → 放弹。  
新逻辑：四邻能走 ≠ 安全；必须能到达**射线外**的安全格，且在引信结束前走得完。

### 3.4 引爆后实火 vs 引信危险

引信阶段与爆炸动画阶段的危险语义**不同**。完整算法见 `docs/superpowers/specs/2026-06-24-explosion-damage-design.md`。

| 概念 | 数据源 | 含义 | 逃生 BFS | `find_path` |
|------|--------|------|----------|-------------|
| **引信危险格** | `get_danger_cells()` | 未引爆炸弹的十字范围；引爆后站立会受伤 | **可穿过**（终点须在射线外） | 仅 `avoid_blast = false` 时可穿过 |
| **实火格** | `get_active_explosion_cells()` | 已引爆、动画播放中且 `0 < t < 1` 的格 | **不可穿过** | **始终不可穿过** |

`is_cell_in_blast(cell)` 现为上述两者之并集，供 AI 逃离、随机移动等即时危险判断。

**不变：** `can_safely_place_bomb` / `find_escape_cell_after_bomb` 的 `max_steps` 仍基于 `BOMB_FUSE_SEC`，**不**引入爆炸动画时长 `_total_duration`。

---

## 4. 核心算法（GameManager）

### 4.1 `get_explosion_cells(origin: Vector2i, fire_range: int) -> Array[Vector2i]`

从现有 `_trigger_explosion` 提取爆炸范围计算，规则保持一致：

- 包含原点
- 四向延伸最多 `fire_range` 格
- 遇硬墙停止（不包含硬墙）
- 遇软墙包含该格后停止
- 不穿透软墙或硬墙

### 4.2 `get_danger_cells(extra_bomb: Dictionary = {}) -> Dictionary`

合并场上所有现有炸弹与可选假想炸弹的危险格，返回 `Dictionary`（`Vector2i` → `true`）便于 O(1) 查询。

假想炸弹格式：`{ "cell": Vector2i, "range": int }`。

对每个炸弹（含假想）调用 `get_explosion_cells` 并合并结果。

### 4.3 `_escape_bfs(bomber: Bomber, danger: Dictionary, bomb_cell: Vector2i) -> Dictionary`

BFS 共用实现，返回 `visited` 字典：`Vector2i → 从起点到该格的最短步数`。供放弹判定与撤离目标查询复用。

**起点：** `bomber.grid_pos`

**邻格可通行条件：**

- 在边界内
- 非硬墙/软墙（`map_data.is_blocking`）
- 非场上已有炸弹格（`bombs.has(n)`）
- **非实火格**（`get_active_explosion_cells().has(n)` 为真则不可扩展）
- **例外**：`bomb_cell` 对正在放弹的 `bomber` 视为可通行（穿弹规则）

**重要：引信危险格不阻挡 BFS 扩展。** `danger.has(n)` 的格照常入队；实火格始终阻挡。候选安全格须 `not danger.has(cell)` 且 `not get_active_explosion_cells().has(cell)`（见 §3.4）。

### 4.4 `can_safely_place_bomb(bomber: Bomber) -> bool`

**前置检查：**

- `bomber` 存活且 `game_manager` 有效
- `bomber.active_bombs < bomber.bomb_capacity`
- `bomb_cell = bomber.get_bomb_placement_cell()` 上无已有炸弹

**危险区：**

```text
danger = get_danger_cells({ "cell": bomb_cell, "range": bomber.fire_range })
```

**判定：**

```text
distances = _escape_bfs(bomber, danger, bomb_cell)
max_steps = floor(GameConstants.BOMB_FUSE_SEC / bomber.get_move_duration())
```

若存在某格 `cell` 满足 `not danger.has(cell)` 且 `distances[cell] <= max_steps` → `true`，否则 `false`。

### 4.5 `find_escape_cell_after_bomb(bomber: Bomber) -> Vector2i`

与 `can_safely_place_bomb` 使用相同的 `danger`、`_escape_bfs` 与 `max_steps` 规则，在可达安全格中返回**步数最少**的一格；若无则返回 `Vector2i(-1, -1)`。

放弹后撤离须调用此函数，**不可**复用 `find_safe_cell()`——后者把危险格视为不可通行，与引信期间可穿过爆炸区的语义矛盾。

**保守假设：**

- 不模拟放弹后软墙被摧毁
- 不模拟连锁引爆

---

## 5. AIController 行为变更

### 5.1 新增 `_try_bomb_and_flee() -> void`

```text
if not game_manager.can_safely_place_bomb(bomber):
    return
bomber.try_place_bomb()
var escape := game_manager.find_escape_cell_after_bomb(bomber)
if escape != Vector2i(-1, -1):
    _step_toward(escape)
```

### 5.2 替换放弹调用点

追击玩家与炸软墙两处，将：

```gdscript
if _adjacent_to(target) and _has_escape_route():
    bomber.try_place_bomb()
```

替换为：

```gdscript
if _adjacent_to(target):
    _try_bomb_and_flee()
```

### 5.3 删除

移除 `_has_escape_route()` 函数。

### 5.4 不变行为

- 危险区逃离（`_move_away` + `find_safe_cell`）——针对**已存在**的炸弹引信危险，仍不穿过 `get_danger_cells()`；同时避开实火格
- `is_cell_in_blast` 含引信危险与实火格，用于站立格即时危险判断
- 寻道具、追击、随机移动逻辑
- 决策间隔与各难度概率参数

---

## 6. 文件变更

| 文件 | 变更 |
|------|------|
| `scripts/systems/game_manager.gd` | 新增 `get_explosion_cells`、`get_danger_cells`、`_escape_bfs`、`can_safely_place_bomb`、`find_escape_cell_after_bomb`；`_trigger_explosion` 改为调用 `get_explosion_cells`；后续增补 `apply_explosion_damage`、`get_active_explosion_cells`（见 `2026-06-24-explosion-damage-design.md`） |
| `scripts/entities/ai_controller.gd` | 新增 `_try_bomb_and_flee`；替换放弹逻辑；删除 `_has_escape_route` |
| `tests/test_ai_bomb_safety.gd` | 新增单元测试 |
| `tests/run_tests_node.gd` | 注册新测试 |

---

## 7. 测试计划

**文件：** `tests/test_ai_bomb_safety.gd`  
**风格：** 与 `test_bomber_place_bomb_while_moving.gd` 一致，静态 `run(failures)` + 手工构造 `MapData` / `GameManager`。

### 用例

| 用例 | 地图布局 | 预期 |
|------|----------|------|
| 死角夹杀 | AI 在 `(2,1)`，左 `(1,1)` 硬墙、右 `(3,1)` 软墙、下 `(2,2)` 硬墙、上 `(2,0)` 硬墙，`fire_range=1`；爆炸射线外无任何可达格 | `can_safely_place_bomb` 为 `false` |
| 穿过危险区逃生 | AI 在 `(2,1)`，左硬墙、右软墙，`(2,0)` 空地且在射线上，`(1,0)` 空地且安全；`fire_range=1` | `can_safely_place_bomb` 为 `true`（路径 `(2,1)→(2,0)→(1,0)`，2 步） |
| 开阔可放 | AI 在空地中央，邻接软墙，多条短路径可达射线外安全格 | `can_safely_place_bomb` 为 `true` |
| 爆炸范围提取 | 已知原点与 `fire_range`，软墙/硬墙阻挡 | `get_explosion_cells` 结果与 `_trigger_explosion` 行为一致 |
| 引信步数不足 | 安全格存在但最短路径步数 > `max_steps`（可临时缩短 `BOMB_FUSE_SEC` 或增大 `get_move_duration` 构造） | `can_safely_place_bomb` 为 `false` |
| 已有炸弹叠加 | 场上另有炸弹，其爆炸范围使所有安全格在步数限制内不可达 | `can_safely_place_bomb` 为 `false` |
| 穿弹格通行 | AI 站在即将放弹的格上，经 `bomb_cell` 穿出后有安全格 | BFS 允许经过 `bomb_cell`，返回 `true` |

### 死角夹杀示意图

```text
       (2,0) 硬墙
         |
(1,1)硬— AI —软(3,1)
         |
       (2,2) 硬墙
```

四向封死，爆炸射线覆盖 `(2,1)` 与 `(3,1)`，不存在射线外可达格 → 不可放弹。

### 穿过危险区逃生示意图

```text
(1,0) 安全
  |
(1,1)硬— AI —软(3,1)
```

路径：`(2,1) → (2,0)`（穿过危险区）`→ (1,0)`（安全）→ 可放弹。

### 手动验证

- 开局观察 AI 是否仍频繁在墙角/窄道自杀
- AI 贴软墙炸墙后能否穿过爆炸区走开
- 三档难度放弹安全标准一致（仅决策快慢不同）

---

## 8. 数据流

```text
AIController._tick
  → 邻接目标？
    → can_safely_place_bomb (GameManager)
      → get_danger_cells (现有炸弹 + 假想炸弹)
      → _escape_bfs（危险格可穿过，找射线外安全格，校验步数 ≤ max_steps）
    → try_place_bomb
    → find_escape_cell_after_bomb → _step_toward
```

---

## 9. 风险与缓解

| 风险 | 缓解 |
|------|------|
| AI 放弹频率下降，显得消极 | 符合设计取向（宁可少放弹）；后续可单独调进攻参数 |
| `is_cell_dangerous` 与 `get_explosion_cells` 逻辑不一致 | 放弹判定用新 API；`_trigger_explosion` 复用 `get_explosion_cells` |
| `find_safe_cell` 与放弹后撤离语义不同 | 放弹后专用 `find_escape_cell_after_bomb`，不复用 `find_safe_cell` |
| 不模拟连锁导致极端情况下仍受伤 | 偏保守；连锁场景少见，后续可迭代 |
