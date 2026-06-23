# 炸弹人 v1 实现计划

> **面向 Agent 执行：** 必须使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实施。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 在空仓库中实现可玩的 Godot 4.x 单人炸弹人游戏（1 玩家 vs 1–3 AI），符合 [设计规格](../specs/2025-06-23-bomberman-design.md)。

**架构：** 混合网格 + 场景实体。`MapGenerator` 生成网格数据，`TileMapLayer` 渲染静态地图，炸弹人/炸弹/道具为独立节点，`GameManager` 协调对局状态与规则判定。

**技术栈：** Godot 4.x、GDScript、Compatibility 渲染器、桌面 960×720。

**参考文档：** `docs/superpowers/specs/2025-06-23-bomberman-design.md`、`AGENTS.md`

---

## 文件职责总览

| 文件 | 职责 |
|------|------|
| `scripts/constants.gd` | 网格尺寸、速度、引信等常量 |
| `autoload/game_settings.gd` | 设置持久化 |
| `autoload/audio_manager.gd` | BGM/SFX |
| `scripts/map/map_data.gd` | 单元格类型枚举与网格数据 |
| `scripts/map/map_generator.gd` | 地图生成 + 连通性校验 |
| `scripts/map/map_view.gd` | TileMapLayer 渲染 |
| `scripts/entities/bomber.gd` | 炸弹人基类（移动、属性） |
| `scripts/entities/player.gd` | 玩家输入 |
| `scripts/entities/ai_controller.gd` | AI 决策 |
| `scripts/entities/bomb.gd` | 炸弹 + `allowed_overlappers` |
| `scripts/entities/explosion.gd` | 十字爆炸 |
| `scripts/entities/powerup.gd` | 道具 |
| `scripts/systems/game_manager.gd` | 对局状态机、规则、胜负 |
| `scenes/*.tscn` | UI 与实体场景 |

---

### 任务 1：Godot 项目脚手架

**文件：**
- 创建：`project.godot`
- 创建：`scripts/constants.gd`
- 创建：`.gitignore`

- [ ] **步骤 1：创建 `.gitignore`**

```
.godot/
.import/
export/
*.translation
```

- [ ] **步骤 2：创建 `scripts/constants.gd`**

```gdscript
class_name GameConstants
extends RefCounted

const GRID_WIDTH := 13
const GRID_HEIGHT := 11
const TILE_SIZE := 32
const MAP_PIXEL_SIZE := Vector2i(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
const WINDOW_SIZE := Vector2i(960, 720)

const BOMB_FUSE_SEC := 2.5
const SOFT_WALL_DENSITY := 0.55
const POWERUP_DROP_CHANCE := 0.20
const COUNTDOWN_SEC := 3

const SPAWN_CELLS: Array[Vector2i] = [
    Vector2i(1, 1),
    Vector2i(GRID_WIDTH - 2, 1),
    Vector2i(1, GRID_HEIGHT - 2),
    Vector2i(GRID_WIDTH - 2, GRID_HEIGHT - 2),
]

const MAX_BOMB_COUNT := 8
const MAX_FIRE_RANGE := 8
const MAX_SPEED_TIER := 3

const BASE_MOVE_DURATION := 0.20
const SPEED_TIER_DELTA := 0.04

static func grid_to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5

static func world_to_grid(pos: Vector2) -> Vector2i:
    return Vector2i(pos / TILE_SIZE)
```

- [ ] **步骤 3：创建 `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]
config/name="Bomberman"
config/version="0.1.0"
run/main_scene="res://scenes/main_menu.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")
config/icon="res://icon.svg"

[autoload]
GameSettings="*res://autoload/game_settings.gd"
AudioManager="*res://autoload/audio_manager.gd"

[display]
window/size/viewport_width=960
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[input]
move_up={"deadzone":0.5,"events":[{"type":"input_event_key","keycode":4194320},{"type":"input_event_key","keycode":87}]}
move_down={"deadzone":0.5,"events":[{"type":"input_event_key","keycode":4194322},{"type":"input_event_key","keycode":83}]}
move_left={"deadzone":0.5,"events":[{"type":"input_event_key","keycode":4194319},{"type":"input_event_key","keycode":65}]}
move_right={"deadzone":0.5,"events":[{"type":"input_event_key","keycode":4194321},{"type":"input_event_key","keycode":68}]}
place_bomb={"deadzone":0.5,"events":[{"type":"input_event_key","keycode":32}]}
pause={"deadzone":0.5,"events":[{"type":"input_event_key","keycode":4194305}]}

[rendering]
renderer/rendering_method="gl_compatibility"
```

- [ ] **步骤 4：创建占位 `icon.svg`（Godot 默认图标，16×16 红块即可）**

- [ ] **步骤 5：在 Godot 编辑器中打开项目，确认无报错**

运行：Godot 导入项目  
预期：项目可加载，`GameSettings` / `AudioManager` autoload 待下一步创建

- [ ] **步骤 6：提交**

```bash
git add project.godot scripts/constants.gd .gitignore icon.svg
git commit -m "feat: 初始化 Godot 项目脚手架与常量"
```

---

### 任务 2：GameSettings 单例

**文件：**
- 创建：`autoload/game_settings.gd`

- [ ] **步骤 1：实现 `autoload/game_settings.gd`**

```gdscript
extends Node

enum Difficulty { EASY, NORMAL, HARD }

const CONFIG_PATH := "user://settings.cfg"

var ai_count: int = 3
var difficulty: Difficulty = Difficulty.NORMAL
var master_volume: float = 0.8

func _ready() -> void:
    load_settings()

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(CONFIG_PATH) != OK:
        return
    ai_count = int(cfg.get_value("game", "ai_count", 3))
    difficulty = int(cfg.get_value("game", "difficulty", Difficulty.NORMAL))
    master_volume = float(cfg.get_value("audio", "master_volume", 0.8))

func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("game", "ai_count", ai_count)
    cfg.set_value("game", "difficulty", difficulty)
    cfg.set_value("audio", "master_volume", master_volume)
    cfg.save(CONFIG_PATH)

func get_difficulty_name() -> String:
    match difficulty:
        Difficulty.EASY: return "简单"
        Difficulty.NORMAL: return "普通"
        Difficulty.HARD: return "困难"
    return "普通"

func get_ai_params() -> Dictionary:
    match difficulty:
        Difficulty.EASY:
            return {"interval": 0.5, "chase": 0.2, "powerup": 0.1, "danger_margin": 1}
        Difficulty.HARD:
            return {"interval": 0.15, "chase": 0.8, "powerup": 0.6, "danger_margin": 2}
    return {"interval": 0.3, "chase": 0.5, "powerup": 0.4, "danger_margin": 1}
```

- [ ] **步骤 2：提交**

```bash
git add autoload/game_settings.gd
git commit -m "feat: 添加 GameSettings 设置持久化"
```

---

### 任务 3：AudioManager 单例

**文件：**
- 创建：`autoload/audio_manager.gd`
- 创建：`assets/audio/.gitkeep`

- [ ] **步骤 1：实现 `autoload/audio_manager.gd`**

```gdscript
extends Node

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
    _bgm_player = AudioStreamPlayer.new()
    _sfx_player = AudioStreamPlayer.new()
    add_child(_bgm_player)
    add_child(_sfx_player)
    _apply_volume()

func _apply_volume() -> void:
    var v := GameSettings.master_volume
    _bgm_player.volume_db = linear_to_db(v)
    _sfx_player.volume_db = linear_to_db(v)

func play_bgm(stream: AudioStream) -> void:
    _apply_volume()
    _bgm_player.stream = stream
    _bgm_player.play()

func stop_bgm() -> void:
    _bgm_player.stop()

func play_sfx(stream: AudioStream) -> void:
    _apply_volume()
    _sfx_player.stream = stream
    _sfx_player.play()

func on_settings_changed() -> void:
    _apply_volume()
```

- [ ] **步骤 2：提交**

```bash
git add autoload/audio_manager.gd assets/audio/.gitkeep
git commit -m "feat: 添加 AudioManager 音频管理"
```

---

### 任务 4：地图数据与生成器

**文件：**
- 创建：`scripts/map/map_data.gd`
- 创建：`scripts/map/map_generator.gd`

- [ ] **步骤 1：实现 `scripts/map/map_data.gd`**

```gdscript
class_name MapData
extends RefCounted

enum CellType { EMPTY, HARD_WALL, SOFT_WALL }

var cells: Array = []  # Array[Array[int]]

func _init() -> void:
    cells = []
    for y in GameConstants.GRID_HEIGHT:
        var row: Array = []
        row.resize(GameConstants.GRID_WIDTH)
        row.fill(CellType.EMPTY)
        cells.append(row)

func get_cell(cell: Vector2i) -> int:
    return cells[cell.y][cell.x]

func set_cell(cell: Vector2i, type: int) -> void:
    cells[cell.y][cell.x] = type

func is_blocking(cell: Vector2i) -> bool:
    var t := get_cell(cell)
    return t == CellType.HARD_WALL or t == CellType.SOFT_WALL

func is_soft_wall(cell: Vector2i) -> bool:
    return get_cell(cell) == CellType.SOFT_WALL

func destroy_soft_wall(cell: Vector2i) -> void:
    if is_soft_wall(cell):
        set_cell(cell, CellType.EMPTY)
```

- [ ] **步骤 2：实现 `scripts/map/map_generator.gd`**

```gdscript
class_name MapGenerator
extends RefCounted

func generate() -> MapData:
    var density := GameConstants.SOFT_WALL_DENSITY
    for attempt in 10:
        var map := _build_base()
        _scatter_soft_walls(map, density)
        if _is_connected(map):
            return map
        density *= 0.9
    return _build_base()

func _build_base() -> MapData:
    var map := MapData.new()
    for y in GameConstants.GRID_HEIGHT:
        for x in GameConstants.GRID_WIDTH:
            var cell := Vector2i(x, y)
            if x == 0 or y == 0 or x == GameConstants.GRID_WIDTH - 1 or y == GameConstants.GRID_HEIGHT - 1:
                map.set_cell(cell, MapData.CellType.HARD_WALL)
            elif x % 2 == 0 and y % 2 == 0:
                map.set_cell(cell, MapData.CellType.HARD_WALL)
    return map

func _is_safe_zone(cell: Vector2i) -> bool:
    for spawn in GameConstants.SPAWN_CELLS:
        if abs(cell.x - spawn.x) + abs(cell.y - spawn.y) <= 2:
            return true
    return false

func _scatter_soft_walls(map: MapData, density: float) -> void:
    for y in range(1, GameConstants.GRID_HEIGHT - 1):
        for x in range(1, GameConstants.GRID_WIDTH - 1):
            var cell := Vector2i(x, y)
            if map.is_blocking(cell) or _is_safe_zone(cell):
                continue
            if randf() < density:
                map.set_cell(cell, MapData.CellType.SOFT_WALL)

func _is_connected(map: MapData) -> bool:
    var starts: Array[Vector2i] = []
    for i in GameSettings.ai_count + 1:
        if i < GameConstants.SPAWN_CELLS.size():
            starts.append(GameConstants.SPAWN_CELLS[i])
    starts.append(GameConstants.SPAWN_CELLS[0])  # player spawn
    var origin := starts[0]
    var visited := {}
    var queue: Array[Vector2i] = [origin]
    visited[origin] = true
    while not queue.is_empty():
        var c: Vector2i = queue.pop_front()
        for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var n := c + d
            if not _in_bounds(n) or visited.has(n) or map.is_blocking(n):
                continue
            visited[n] = true
            queue.append(n)
    for s in starts:
        if not visited.has(s):
            return false
    return true

func _in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < GameConstants.GRID_WIDTH and cell.y < GameConstants.GRID_HEIGHT
```

- [ ] **步骤 3：提交**

```bash
git add scripts/map/map_data.gd scripts/map/map_generator.gd
git commit -m "feat: 添加地图数据结构与生成器"
```

---

### 任务 5：地图渲染

**文件：**
- 创建：`scripts/map/map_view.gd`
- 创建：`scenes/game.tscn`（仅含 MapView 占位，后续扩展）

- [ ] **步骤 1：实现 `scripts/map/map_view.gd`**

使用 `TileMapLayer`（Godot 4.x）或 `TileMap` + 程序化 `ColorRect` 子节点绘制占位色块。v1 可用 `Node2D` + 循环创建 `ColorRect`（32×32）按 `MapData.CellType` 上色：空地深绿、硬墙深灰、软墙浅棕。

```gdscript
class_name MapView
extends Node2D

const COLORS := {
    MapData.CellType.EMPTY: Color(0.15, 0.45, 0.2),
    MapData.CellType.HARD_WALL: Color(0.25, 0.25, 0.28),
    MapData.CellType.SOFT_WALL: Color(0.65, 0.45, 0.25),
}

func render(map: MapData) -> void:
    for child in get_children():
        child.queue_free()
    for y in GameConstants.GRID_HEIGHT:
        for x in GameConstants.GRID_WIDTH:
            var cell := Vector2i(x, y)
            var rect := ColorRect.new()
            rect.size = Vector2(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE)
            rect.position = Vector2(x, y) * GameConstants.TILE_SIZE
            rect.color = COLORS[map.get_cell(cell)]
            add_child(rect)
```

- [ ] **步骤 2：提交**

```bash
git add scripts/map/map_view.gd
git commit -m "feat: 添加地图占位渲染"
```

---

### 任务 6：炸弹人基类

**文件：**
- 创建：`scripts/entities/bomber.gd`
- 创建：`scenes/bomber.tscn`

- [ ] **步骤 1：实现 `scripts/entities/bomber.gd`**

关键字段：`grid_pos`、`is_player`、`is_alive`、`bomb_count`（默认1）、`fire_range`（默认1）、`speed_tier`、`game_manager` 引用。  
移动：`try_move(dir)` 调用 `game_manager.can_move_to`；lerp `position`；到达后 `resolve_occupancy_after_move`；离开格时 `on_bomber_exited_cell`。  
`get_move_duration()`: `BASE_MOVE_DURATION - speed_tier * SPEED_TIER_DELTA`。

- [ ] **步骤 2：创建 `scenes/bomber.tscn`**

根节点 `CharacterBody2D` 或 `Node2D` + `ColorRect`（24×24）+ 脚本 `bomber.gd`。

- [ ] **步骤 3：提交**

```bash
git add scripts/entities/bomber.gd scenes/bomber.tscn
git commit -m "feat: 添加炸弹人基类与移动插值"
```

---

### 任务 7：炸弹与爆炸

**文件：**
- 创建：`scripts/entities/bomb.gd`
- 创建：`scripts/entities/explosion.gd`
- 创建：`scenes/bomb.tscn`
- 创建：`scenes/explosion.tscn`

- [ ] **步骤 1：实现 `scripts/entities/bomb.gd`**

字段：`grid_pos`、`owner`、`allowed_overlappers: Array`、`fuse_timer`。  
`detonate()` 发信号给 `GameManager` 生成 `Explosion`，连锁引爆其他炸弹。

- [ ] **步骤 2：实现 `scripts/entities/explosion.gd`**

计算十字范围；对每格：摧毁软墙、伤害炸弹人、摧毁道具、引爆其他炸弹。短暂显示橙色十字 `ColorRect` 后 `queue_free`。

- [ ] **步骤 3：提交**

```bash
git add scripts/entities/bomb.gd scripts/entities/explosion.gd scenes/bomb.tscn scenes/explosion.tscn
git commit -m "feat: 添加炸弹、爆炸与连锁逻辑"
```

---

### 任务 8：GameManager 核心

**文件：**
- 创建：`scripts/systems/game_manager.gd`
- 修改：`scenes/game.tscn`

- [ ] **步骤 1：实现 `scripts/systems/game_manager.gd`**

职责：
- 持有 `MapData`、炸弹/道具字典、`bombers` 数组
- `can_move_to(bomber, target)` — 穿弹规则：有炸弹则 `false`；硬墙/软墙 `false`
- `resolve_occupancy_after_move` — 玩家+AI 同格 → 玩家阵亡；AI+AI 共存
- `place_bomb(bomber)` — 检查上限；设置 `allowed_overlappers`；注册炸弹
- `on_bomber_exited_cell` — 从炸弹 `allowed_overlappers` 移除
- 状态机：`COUNTDOWN` → `PLAYING` → `ENDED`
- 胜负判定、剩余敌人数
- 软墙破坏 20% 掉落道具

- [ ] **步骤 2：组装 `scenes/game.tscn`**

节点：`Game`（game_manager.gd）→ `MapView`、`Entities`、`Bombs`、`Powerups`、`HUD`、`PauseMenu`、`CountdownLabel`

- [ ] **步骤 3：提交**

```bash
git add scripts/systems/game_manager.gd scenes/game.tscn
git commit -m "feat: 添加 GameManager 对局核心与规则"
```

---

### 任务 9：玩家与道具

**文件：**
- 创建：`scripts/entities/player.gd`
- 创建：`scripts/entities/powerup.gd`
- 创建：`scenes/powerup.tscn`

- [ ] **步骤 1：实现 `scripts/entities/player.gd`**

读取 Input Map；对局冻结时不处理；`place_bomb` 按键单次触发。

- [ ] **步骤 2：实现 `scripts/entities/powerup.gd`**

枚举 `BOMB`、`FIRE`、`SPEED`；拾取时应用属性并遵守上限；爆炸时销毁。

- [ ] **步骤 3：提交**

```bash
git add scripts/entities/player.gd scripts/entities/powerup.gd scenes/powerup.tscn
git commit -m "feat: 添加玩家控制与道具系统"
```

---

### 任务 10：AI 控制器

**文件：**
- 创建：`scripts/entities/ai_controller.gd`

- [ ] **步骤 1：实现 AI 决策**

挂载为 `Bomber` 子节点或组件。按 `GameSettings.get_ai_params()` 定时 tick：危险逃离 → 道具 → 追击玩家 → 炸墙；BFS 寻路；队友格可进入；困难档提高撞玩家倾向。

- [ ] **步骤 2：提交**

```bash
git add scripts/entities/ai_controller.gd
git commit -m "feat: 添加三档难度 AI 控制器"
```

---

### 任务 11：UI 场景

**文件：**
- 创建：`scenes/main_menu.tscn`
- 创建：`scenes/settings.tscn`
- 创建：`scenes/game_over.tscn`
- 创建：`scenes/pause_menu.tscn`
- 创建：`scripts/ui/main_menu.gd`
- 创建：`scripts/ui/settings_menu.gd`
- 创建：`scripts/ui/game_over.gd`
- 创建：`scripts/ui/pause_menu.gd`

- [ ] **步骤 1：主菜单** — 开始游戏 → `game.tscn`；设置 → `settings.tscn`；退出 → `get_tree().quit()`

- [ ] **步骤 2：设置页** — OptionButton AI 数量、难度；HSlider 音量；保存并返回

- [ ] **步骤 3：暂停菜单** — 继续 / 重新开始 / 返回主菜单

- [ ] **步骤 4：结束界面** — 接收 `won: bool`；显示胜利/失败；重开 / 回主菜单

- [ ] **步骤 5：对战 HUD** — `剩余敌人: N`；倒计时 3-2-1-开始!

- [ ] **步骤 6：提交**

```bash
git add scenes/main_menu.tscn scenes/settings.tscn scenes/game_over.tscn scenes/pause_menu.tscn scripts/ui/
git commit -m "feat: 添加中文 UI 流程场景"
```

---

### 任务 12：音频资源

**文件：**
- 创建：`assets/audio/*.ogg` 或占位 `AudioStreamGenerator` 短音

- [ ] **步骤 1：添加 6 个 SFX + 1 个 BGM**（可用 Kenney 免费包或极简占位）

- [ ] **步骤 2：在 `GameManager` 关键事件调用 `AudioManager.play_sfx` / `play_bgm`**

- [ ] **步骤 3：提交**

```bash
git add assets/audio/ scripts/systems/game_manager.gd autoload/audio_manager.gd
git commit -m "feat: 接入音效与对战 BGM"
```

---

### 任务 13：集成与手动验证

- [ ] **步骤 1：地图居中** — 在 `game.tscn` 将 `MapView` 偏移至窗口中央（(960-416)/2, (720-352)/2 附近，预留 HUD）

- [ ] **步骤 2：执行设计规格第 10 节手动测试清单全部项**

运行：Godot 运行主场景  
预期：完整流程可玩，规则符合规格

- [ ] **步骤 3：修复测试中发现的问题**

- [ ] **步骤 4：提交**

```bash
git add -A
git commit -m "feat: 炸弹人 v1 可玩版本"
```

---

## 规格覆盖自检

| 规格章节 | 对应任务 |
|----------|----------|
| 架构 / Autoload | 任务 1–3 |
| 地图生成 13×11 | 任务 4–5 |
| 移动 + 穿弹规则 | 任务 6、8 |
| 身体接触 | 任务 8 |
| 炸弹 / 连锁 / 道具 | 任务 7、9 |
| AI 三档难度 | 任务 10 |
| UI 中文流程 | 任务 11 |
| 音频 | 任务 12 |
| 测试清单 | 任务 13 |

## 执行方式

计划已保存至 `docs/superpowers/plans/2025-06-23-bomberman.md`。

**两种执行方式：**

1. **Subagent 驱动（推荐）** — 每个任务派发独立 subagent，任务间做审查，迭代快
2. **本会话内联执行** — 使用 executing-plans 在本会话批量执行，设检查点

请选择执行方式，或回复「开始实现」直接按推荐方式启动。
