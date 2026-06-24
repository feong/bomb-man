# 爆炸伤害与实火判定设计规格

**日期：** 2026-06-24  
**状态：** 已批准  
**关联规格：**
- `docs/superpowers/specs/2025-06-23-bomberman-design.md`
- `docs/superpowers/specs/2026-06-23-ai-bomb-safety-design.md`

---

## 1. 概述

### 问题

早期实现仅在 `_trigger_explosion` **引爆瞬间**对 `affected` 格上的炸弹人执行一次 `die()`。爆炸视觉动画会持续约 0.35s 起（远端火焰还有分段延迟），动画播放期间走入火焰格不会再次判定伤害。

### 目标

1. **持续伤害**：动画播放期间，站在「当前有火焰」的格子上应致死。
2. **与视觉同步**：致死格集合与火焰缩放动画使用同一套进度公式。
3. **AI 对齐**：AI 躲避逻辑区分「引信危险格」与「实火格」，后者不可穿行。

### 成功标准

- 动画未结束时走入实火格 → 阵亡。
- 火焰已消失（`t = 1`）但 `Explosion` 节点尚未销毁 → 该格安全。
- 远端格在火焰出现前（`t = 0`）若未在引爆瞬间被击杀，理论上可短暂通过（与持续伤害窗口一致）。
- AI 不走入 `get_active_explosion_cells()` 返回的格；引信阶段仍可按原规则穿过 `get_danger_cells()`。

### 不在范围内

- 修改十字爆炸范围计算（仍由 `get_explosion_cells` 负责）。
- 修改引信步数逃生算法的时间尺度（仍用 `BOMB_FUSE_SEC`，不引入动画时长）。
- 软墙摧毁、道具摧毁、连锁引爆的时机（仍在引爆瞬间处理）。

---

## 2. 两阶段伤害模型

| 阶段 | 触发时机 | 致死格集合 | 实现 |
|------|----------|------------|------|
| **瞬间伤害** | 引爆帧（`_trigger_explosion`） | `get_explosion_cells(origin, range)` 的全部 `affected` 格 | `GameManager._trigger_explosion` 内循环 `b.die("explosion")` |
| **持续伤害** | `Explosion` 每帧 `_process` | 当前 **active cells**（见 §3） | `Explosion` → `GameManager.apply_explosion_damage` |

**设计取舍：** 瞬间伤害仍覆盖完整 `affected`，保留经典炸弹人「逻辑爆炸」语义——远端格在火焰动画到达前即可被击杀。持续伤害补上「引爆后才走入火焰」的缺口。

**地图与连锁（仅瞬间阶段）：** 软墙摧毁、道具清除、连锁引爆炸弹均在 `_trigger_explosion` 的 `affected` 循环中立即处理，不受动画进度影响。

---

## 3. 动画时间与 Active Cell 算法

### 3.1 常量与总时长

- 基础动画单位：`Explosion.DURATION = 0.35`（秒）。
- 每段进度跨度：归一化进度下占 `0.75`。
- 距离延迟系数：每格 `distance` 延迟 `distance × 0.12`（归一化进度）。
- 总动画时长：

```text
_total_duration = DURATION × (0.75 + max_distance × 0.12)
```

`max_distance` 为本次爆炸各臂上的最大曼哈顿距离（中心为 0）。

### 3.2 分段进度

```text
global_progress = elapsed / DURATION
elapsed = _total_duration - _timer

t = clamp((global_progress - distance × 0.12) / 0.75, 0, 1)
```

- `distance`：该火焰段距爆炸中心的曼哈顿距离（中心段为 0）。
- 视觉缩放：`eased = sin(t × π)`，`sprite.scale = base × eased`。

### 3.3 Active Cell 判定

某格在 `global_progress` 下致死 ⟺ 该格存在对应 segment 且 **`0 < t < 1`**。

汇总规则：对 `_segments` 中每个 segment 计算 `t`；同一格多 segment 时去重；`t <= 0` 或 `t >= 1` 的格不属于 active cells。

**语义：**

| `t` 范围 | 火焰状态 | 是否致死 |
|----------|----------|----------|
| `t <= 0` | 尚未出现 | 否（持续伤害）；引爆瞬间可能已被瞬间伤害击杀 |
| `0 < t < 1` | 出现中 / 消退中 | **是** |
| `t >= 1` | 已消失 | 否 |

---

## 4. 组件与 API

### 4.1 `Explosion`（`scripts/entities/explosion.gd`）

| 方法 | 说明 |
|------|------|
| `setup(manager, origin, fire_range, affected)` | 构建视觉段、计算 `_total_duration` |
| `get_animation_progress() -> float` | 返回 `(_total_duration - _timer) / DURATION` |
| `get_active_cells_now() -> Array[Vector2i]` | 当前帧 active cells，供伤害与 AI 查询 |
| `_get_active_cells(progress) -> Array[Vector2i]` | 内部实现，按 §3.3 汇总 |

**每帧流程：**

```text
_process → 更新缩放 → apply_explosion_damage(active_cells) → _timer 归零后 queue_free
```

### 4.2 `GameManager`（`scripts/systems/game_manager.gd`）

| 方法 | 说明 |
|------|------|
| `apply_explosion_damage(cells)` | 对 `cells` 上存活炸弹人 `die("explosion")`；有击杀时 `_check_match_end()` |
| `get_active_explosion_cells() -> Dictionary` | 遍历 `_effects_root` 下所有 `Explosion`，合并各 `get_active_cells_now()` |
| `is_cell_in_blast(cell) -> bool` | `get_danger_cells().has(cell)` **或** `get_active_explosion_cells().has(cell)` |
| `get_explosion_cells(origin, range)` | 不变；十字范围几何计算 |
| `get_danger_cells(extra_bomb?)` | 不变；仅含**未引爆**炸弹的假想/实际危险格 |

### 4.3 `_trigger_explosion` 流程（摘要）

```text
affected = get_explosion_cells(origin, range)
实例化 Explosion → setup
对每个 affected 格：连锁炸弹、道具、瞬间击杀、软墙
连锁引爆 → _check_match_end
```

---

## 5. AI 与寻路语义（交叉引用）

引信阶段与引爆后实火使用**不同**危险语义，详见 `2026-06-23-ai-bomb-safety-design.md` §3.4。

| 概念 | 数据源 | 逃生 BFS 可穿过？ | `find_path` 可穿过？ |
|------|--------|-------------------|----------------------|
| 引信危险格 | `get_danger_cells()` | **是**（仅终点须在射线外） | 仅当 `avoid_blast = false` |
| 实火格 | `get_active_explosion_cells()` | **否** | **始终否** |

`can_safely_place_bomb` / `find_escape_cell_after_bomb` 的 `max_steps` 仍基于 `BOMB_FUSE_SEC`，**不**引入 `_total_duration`。

---

## 6. 测试要点

| 场景 | 预期 |
|------|------|
| 站在实火格（`0 < t < 1`） | 每帧持续伤害，阵亡 |
| 动画中走入实火格 | 阵亡 |
| 火焰消失后（`t >= 1`）走入该格 | 存活 |
| 引爆瞬间站在 `affected` 远端格 | 瞬间伤害击杀（即使 `t = 0`） |
| AI 在他人爆炸动画中 | 避开 active cells；不走入实火 |
| 连锁引爆 | 各 `Explosion` 独立计时；`get_active_explosion_cells` 合并所有实例 |

**建议补充单元测试（可选）：** 对 `_segment_progress` / `_get_active_cells` 给定 `progress` 与 `distance` 的边界值断言（`t = 0`、`t = 0.5`、`t = 1`）。

---

## 7. 文件变更

| 文件 | 变更 |
|------|------|
| `scripts/entities/explosion.gd` | active cells 查询、`apply_explosion_damage` 每帧调用 |
| `scripts/systems/game_manager.gd` | `apply_explosion_damage`、`get_active_explosion_cells`、`is_cell_in_blast` 扩展；寻路/逃生 BFS 避开实火 |
| `docs/superpowers/specs/2025-06-23-bomberman-design.md` | 炸弹伤害规则、Explosion 职责 |
| `docs/superpowers/specs/2026-06-23-ai-bomb-safety-design.md` | §3.4 实火 vs 引信危险 |
