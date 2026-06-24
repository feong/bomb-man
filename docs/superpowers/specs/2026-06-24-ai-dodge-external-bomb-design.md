# AI 躲避他人炸弹设计规格

**日期：** 2026-06-24  
**状态：** 已批准  
**关联规格：**
- `docs/superpowers/specs/2025-06-23-bomberman-design.md`
- `docs/superpowers/specs/2026-06-23-ai-bomb-safety-design.md`
- `docs/superpowers/specs/2026-06-24-explosion-damage-design.md`

---

## 1. 概述

### 问题

玩家在 AI 面前放炸弹后，AI 已站在爆炸射线上、引信倒计时中，却原地不动被炸死。

### 根因

`AIController` 危险逃离分两条路径：

| 条件 | 逃离 API | 寻路 `allow_danger` |
|------|----------|---------------------|
| `active_bombs > 0`（自己刚放弹） | `find_escape_cell_after_bomb()` | `true`（可穿过引信危险格） |
| `active_bombs == 0`（他人炸弹） | `find_safe_cell()` | `false`（禁止穿过引信危险格） |

他人炸弹场景下，`find_safe_cell()` 能找到射线外安全格，但 `find_path(avoid_blast=true)` 无法规划需穿过引信危险格的路径（例如 `(2,1) → (2,0) → (1,0)`），导致 AI 站着不动。

该问题与 `2026-06-23-ai-bomb-safety-design.md` 已解决的「自己放弹后撤离」属同一类语义缺陷，但未覆盖「躲避他人炸弹」。

### 目标

消除 AI 在他人炸弹引信期间、已处于爆炸射线上时原地不动的问题。

### 成功标准

- 玩家当面放弹、AI 已在射线上时，AI 在引信结束前向安全格移动（含需穿过引信危险格的逃生路径）。
- 自己放弹后的撤离行为无回归。
- 真死局（引信内到不了射线外，或仅有口袋死胡同）仍不移动——属正确行为。
- 三档难度共用同一套逃离逻辑。
- 新增单元测试覆盖他人炸弹场景；现有 `test_ai_bomb_safety.gd` 无回归。

### 不在范围内

- 主动避险：AI 尚未进入爆炸区时提前绕开面前的炸弹（场景 B）
- 移动中中断当前步伐立即改道（`_is_moving` 门控）
- 启用 `danger_margin` 参数
- 调整追击/寻道具/决策间隔等难度参数
- 模拟连锁引爆或放弹后软墙摧毁

---

## 2. 方案选择

采用**方案 A：统一「逃离爆炸区」API**。

在 `GameManager` 新增 `find_escape_from_danger(bomber)`，复用 `_escape_bfs`、`_pick_best_escape_cell` 与引信步数限制；`AIController` 危险分支与放弹后撤离均调用此 API，寻路统一使用 `allow_danger = true`。

未采用仅给 `_move_away` 开 `allow_danger`（`find_safe_cell` 不考虑引信步数与最优目标）或扩展 `find_path` 新模式的方案（改动面大且仍缺目标格选择逻辑）。

---

## 3. 爆炸与逃生语义（复用）

与 `2026-06-23-ai-bomb-safety-design.md` §3 一致：

| 概念 | 引信阶段 | 实火阶段 |
|------|----------|----------|
| 危险格来源 | `get_danger_cells()` | `get_active_explosion_cells()` |
| BFS 扩展 | 可穿过引信危险格 | 不可穿过实火格 |
| 安全终点 | 不在引信危险且不在实火 | 同左 |
| 步数上限 | `floor(BOMB_FUSE_SEC / bomber.get_move_duration())` | 同左 |

**穿弹例外：** 仅当 `bomber.active_bombs > 0` 时，该 AI 自己最近一枚炸弹所在格在 BFS 中视为可通行（与现 `find_escape_cell_after_bomb` 一致）。

---

## 4. 核心算法（GameManager）

### 4.1 `find_escape_from_danger(bomber: Bomber) -> Vector2i`

**前置：** `bomber` 存活且 `map_data` 有效。

**步骤：**

```text
danger = get_danger_cells()
bomb_cell = 若 bomber.active_bombs > 0，取 bomber 拥有的最近一枚炸弹格；否则 Vector2i(-1, -1)
distances = _escape_bfs(bomber, danger, bomb_cell)
max_steps = floor(BOMB_FUSE_SEC / bomber.get_move_duration())
return _pick_best_escape_cell(bomber, distances, danger, bomb_cell, max_steps)
```

**返回值：** 最优可达安全格；若无则 `Vector2i(-1, -1)`。

**与 `find_escape_cell_after_bomb` 的关系：** 后者改为单行委托 `find_escape_from_danger(bomber)`，保持对外 API 兼容。

### 4.2 `find_safe_cell` 不变

仍用于需要「全程避开引信危险格」的语义（当前仅 `_move_away` 使用，改后 `_move_away` 不再调用它）。保留函数供未来非引信穿越场景使用。

---

## 5. AIController 行为变更

### 5.1 危险分支统一

**现逻辑：**

```gdscript
if gm.is_cell_in_blast(...) or gm.is_cell_dangerous(...):
    if bomber.active_bombs > 0:
        escape = find_escape_cell_after_bomb(...)
        _step_toward(escape, true)
    if not bomber._is_moving:
        _move_away(params)  # find_safe_cell + allow_danger=false
```

**新逻辑：**

```gdscript
if gm.is_cell_in_blast(...) or gm.is_cell_dangerous(...):
    if not bomber._is_moving:
        var escape := gm.find_escape_from_danger(bomber)
        if escape != Vector2i(-1, -1):
            _step_toward(escape, true)
    _sync_idle()
    return
```

### 5.2 `_move_away` 变更

改为调用 `find_escape_from_danger` + `_step_toward(escape, true)`，或内联后删除 `_move_away`（由危险分支直接调用 API）。推荐删除 `_move_away`，危险分支直接调用，减少间接层。

### 5.3 `_try_bomb_and_flee` 不变

放弹后仍调用 `find_escape_cell_after_bomb`（委托至 `find_escape_from_danger`）。

### 5.4 不变行为

- 追击、寻道具、炸软墙、随机移动优先级与概率
- `not bomber._is_moving` 门控（本次不改动）
- 三档难度参数

---

## 6. 文件变更

| 文件 | 变更 |
|------|------|
| `scripts/systems/game_manager.gd` | 新增 `find_escape_from_danger`；`find_escape_cell_after_bomb` 委托调用 |
| `scripts/entities/ai_controller.gd` | 危险分支统一；删除或简化 `_move_away` |
| `tests/test_ai_bomb_safety.gd` | 新增他人炸弹逃离用例 |
| `tests/run_tests_node.gd` | 无需改动（已注册 `test_ai_bomb_safety`） |

---

## 7. 测试计划

**文件：** `tests/test_ai_bomb_safety.gd`

### 新增用例

| 用例 | 布局 | 预期 |
|------|------|------|
| 他人炸弹 — 穿过危险区逃生 | 硬墙 `(1,1)`、软墙 `(3,1)`；玩家炸弹在 `(3,1)`（`fire_range=1`）；AI 在 `(2,1)`，`active_bombs=0` | `find_escape_from_danger` 返回 `(1,0)`；`get_next_step_toward(..., avoid_blast=false)` 或路径第一步为 `(2,0)` |
| 他人炸弹 — 仍在射线上须逃离 | 用户口袋地图；玩家炸弹在 `(3,1)`；AI 在 `(4,1)` | `find_escape_from_danger` 返回射线外格，非 `(-1,-1)` |
| 他人炸弹 — 寻路可穿过引信格 | 同上「穿过危险区」；对逃生目标调用 `find_path(bomber, escape, false)` | 路径长度 ≥ 2，且包含需穿过的引信危险中间格 |

### 回归用例

现有 `find_escape_after_bomb`、`escape_through_danger`、`pocket_dead_end` 等全部保持通过。

### 手动验证

1. 开局追击 AI，当面放弹（AI 在射线上），观察 AI 是否在引信内走开。
2. 角落窄道放弹，确认 AI 能沿对角穿出爆炸区。
3. 真死局（三面墙）放弹，AI 仍应站着——符合预期。

---

## 8. 数据流

```text
AIController._tick
  → is_cell_in_blast / is_cell_dangerous ?
    → find_escape_from_danger (GameManager)
      → get_danger_cells()
      → _escape_bfs（引信危险可穿过，实火不可）
      → _pick_best_escape_cell（步数 ≤ max_steps，口袋死局过滤）
    → _step_toward(escape, allow_danger=true)
      → find_path(avoid_blast=false)
```

---

## 9. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 与 `find_escape_cell_after_bomb` 行为分叉 | 后者委托同一实现 |
| AI 走向口袋死胡同 | `_is_viable_escape_cell` 已过滤 |
| 多炸弹叠加步数不足 | `_pick_best_escape_cell` 校验 `max_steps`；偏保守 |
| `find_safe_cell` 成为死代码 | 保留函数，仅 `_move_away` 停用 |
