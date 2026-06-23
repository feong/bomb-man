# AI 美术资源设计规格（单图集）

**日期：** 2026-06-23  
**状态：** 待审阅  
**关联规格：** `docs/superpowers/specs/2025-06-23-bomberman-design.md`

---

## 1. 概述

### 目标

为炸弹人 v1 定义一套可用 AI 生成的游戏内美术资源，**全部打包在同一张 PNG 图集中**，替换当前 `ColorRect` 色块占位，并给出完整 AI 生图提示词。

### 已确认决策

| 决策项 | 选择 |
|--------|------|
| 视觉风格 | 扁平卡通 + 高清像素（Hi-bit） |
| 动画范围 | 基础动画：四向行走、爆炸、炸弹引信闪烁 |
| UI 美术 | 仅游戏内精灵；菜单保持 Godot 默认控件 |
| 角色造型 | 玩家 + 3 个 AI 各一套独立造型 |
| 资产组织 | **单张 PNG 图集**（`game_atlas.png`） |

### 成功标准

- 一张 `576×384` 透明 PNG 包含 v1 所需的全部精灵与动画帧。
- 图集中各区域坐标固定、可文档化，便于 Godot `AtlasTexture` 或后续 `SpriteFrames` 配置引用。
- AI 提示词可直接复制使用，且含主提示词、负面提示词与分区备用提示词。
- 替换占位美术后，玩法逻辑无需改动（仅表现层换皮）。

### 不在范围内

- 菜单 / HUD 自定义 UI 皮肤
- 角色死亡、拾取道具等额外动画
- 音频素材（见主规格第 6 节，另行处理）
- 多张图集或外部 TileSet 资源文件

---

## 2. 图集文件

| 属性 | 值 |
|------|-----|
| 文件名 | `assets/textures/game_atlas.png` |
| 尺寸 | **576 × 384** 像素 |
| 背景 | 透明（RGBA） |
| 色彩模式 | 索引色或 RGBA，**禁用 JPEG** |
| 缩放过滤 | Godot 导入时设为 **Nearest**（保持像素锐利） |

---

## 3. 图集布局

自上而下分区排列，区域之间留 12–16px 透明间隔，避免渗色。

```
┌──────────────────────────────────────────────────────────── 576px ────┐
│ [空地32] [硬墙32] [软墙32]                              y=0, h=32     │
│ ───────────── 间隔 16px ─────────────                                 │
│ [玩家 12帧 × 48px]                                      y=48, h=48    │
│ [AI蓝  12帧 × 48px]                                     y=96, h=48    │
│ [AI绿  12帧 × 48px]                                    y=144, h=48    │
│ [AI黄  12帧 × 48px]                                    y=192, h=48    │
│ ───────────── 间隔 16px ─────────────                                 │
│ [炸弹3帧] 每格占 32px 宽，精灵 28×28 居中               y=256, h=32   │
│ ───────────── 间隔 12px ─────────────                                 │
│ [爆炸5帧 × 32px]                                       y=300, h=32    │
│ ───────────── 间隔 16px ─────────────                                 │
│ [道具3个] 每格占 32px 宽，精灵 24×24 居中               y=348, h=32   │
└──────────────────────────────────────────────────────────── h=380 ────┘
（画布底部可留 4px 边距至 384px）
```

### 3.1 地图瓦片（32×32）

| ID | 名称 | Rect (x, y, w, h) |
|----|------|---------------------|
| `tile_floor` | 空地 | (0, 0, 32, 32) |
| `tile_hard_wall` | 硬墙 | (32, 0, 32, 32) |
| `tile_soft_wall` | 软墙 | (64, 0, 32, 32) |

### 3.2 角色行走动画（48×48，每角色 12 帧）

帧序（每行相同）：**下×3 → 上×3 → 左×3 → 右×3**

| ID | 角色 | 行 Y | 第 n 帧 X 坐标 |
|----|------|------|----------------|
| `char_player` | 玩家（红） | 48 | `x = n × 48`（n = 0..11） |
| `char_ai_blue` | AI 蓝 | 96 | 同上 |
| `char_ai_green` | AI 绿 | 144 | 同上 |
| `char_ai_yellow` | AI 黄 | 192 | 同上 |

示例：`char_player` 朝左第 2 帧（行内 index 7）→ Rect(336, 48, 48, 48)

角色造型区分：

- **玩家**：红色围巾/头盔，矮胖主角感
- **AI 蓝**：蓝色护目镜，体型偏高瘦
- **AI 绿**：绿色蘑菇帽/背包，圆润
- **AI 黄**：黄色星星发饰/护肩，活泼

### 3.3 炸弹引信闪烁（28×28，居中对齐于 32px 格）

| ID | 帧 | Rect (x, y, w, h) |
|----|-----|-------------------|
| `bomb_idle` | 常态 | (2, 258, 28, 28) |
| `bomb_blink_1` | 闪烁 1 | (34, 258, 28, 28) |
| `bomb_blink_2` | 闪烁 2 | (66, 258, 28, 28) |

### 3.4 爆炸动画（32×32）

| ID | 帧 | Rect (x, y, w, h) |
|----|-----|-------------------|
| `explosion_0` | 初起 | (0, 300, 32, 32) |
| `explosion_1` | 扩大 | (32, 300, 32, 32) |
| `explosion_2` | 峰值 | (64, 300, 32, 32) |
| `explosion_3` | 衰减 | (96, 300, 32, 32) |
| `explosion_4` | 消散 | (128, 300, 32, 32) |

### 3.5 道具（24×24，居中对齐于 32px 格）

| ID | 类型 | Rect (x, y, w, h) |
|----|------|-------------------|
| `powerup_bomb` | 炸弹+ | (4, 352, 24, 24) |
| `powerup_fire` | 火力+ | (36, 352, 24, 24) |
| `powerup_speed` | 速度+ | (68, 352, 24, 24) |

### 3.6 资产统计

| 类别 | 帧/图数量 |
|------|-----------|
| 地图瓦片 | 3 |
| 角色动画 | 48（4 角色 × 12 帧） |
| 炸弹 | 3 |
| 爆炸 | 5 |
| 道具 | 3 |
| **合计** | **62 格**（单文件） |

---

## 4. 视觉规范

### 画风

俯视（top-down）、Hi-bit 像素、扁平卡通、有限色板、1px 硬边、无抗锯齿模糊、轻松街机炸弹人氛围、统一左上光源。

### 与玩法尺寸的关系

| 元素 | 图集内尺寸 | 游戏格子 |
|------|------------|----------|
| 瓦片 / 爆炸 | 32×32 | 贴满 `TILE_SIZE` |
| 角色 | 48×48 | 在 32×32 格中心对齐，允许 8px 溢出 |
| 炸弹 | 28×28 | 格内居中 |
| 道具 | 24×24 | 格内居中 |

### 动画行为（实现时参考）

- 角色：移动时播放对应朝向 3 帧循环；静止时显示该朝向第 1 帧。
- 炸弹：3 帧循环闪烁，直至引信结束。
- 爆炸：5 帧播放一次，时长约 0.35s（与现有 `Explosion._timer` 一致）。
- 道具：静态图。

---

## 5. AI 生图提示词

以下提示词为英文，便于 Midjourney、Stable Diffusion、Flux、DALL·E 等工具识别；生成后须用 **最近邻** 缩放校正至精确 `576×384`，禁止双线性模糊。

### 5.1 全局 Style Anchor

每条正向提示词末尾追加：

```
top-down view, hi-bit pixel art, flat cartoon style, crisp 1px pixels, limited 16-color palette, no anti-aliasing, no blur, no gradient noise, cheerful arcade bomber game aesthetic, consistent top-left lighting, transparent background, game sprite atlas
```

### 5.2 全局负面提示词（Negative Prompt）

```
photorealistic, 3D render, blurry, soft edges, anti-aliased, watercolor, sketch, messy lines, inconsistent perspective, isometric, side view, text, watermark, logo, UI frame, drop shadow on background, multiple separate images, collage with gaps, white background instead of transparent
```

### 5.3 主提示词：整张图集（推荐优先生成）

将下列整段作为**一条完整提示词**使用：

```
Complete game sprite atlas PNG exactly 576x384 pixels, transparent background, single image containing ALL assets laid out in fixed rows:

ROW 1 (y=0, height 32): three 32x32 top-down tiles side by side — dark green grass floor, dark gray stone brick hard wall, light brown wooden crate soft wall.

GAP 16px empty.

ROW 2 (y=48, height 48): player bomber character sprite row, 12 frames each 48x48, horizontal — red scarf hero, walk cycle facing down 3 frames, up 3 frames, left 3 frames, right 3 frames.

ROW 3 (y=96): blue goggles tall slim AI character, same 12-frame layout, blue theme.

ROW 4 (y=144): green mushroom cap AI character, same 12-frame layout, green theme.

ROW 5 (y=192): yellow star accessory AI character, same 12-frame layout, yellow theme.

GAP 16px.

ROW 6 (y=256, height 32): three 28x28 round black bombs with fuse, centered in 32px slots, frames show fuse spark idle / blink / bright blink.

GAP 12px.

ROW 7 (y=300, height 32): five 32x32 explosion frames side by side — spark, grow, peak burst, fade, smoke.

GAP 16px.

ROW 8 (y=348, height 32): three 24x24 pickup icons centered in 32px slots — white bomb plus icon, red flame fire upgrade, cyan speed boot icon.

All characters share same pixel scale, outline thickness, top-down angle, and art style. Crisp hi-bit pixel art, flat cartoon, no blur.
```

末尾追加 **§5.1 Style Anchor**，并配合 **§5.2 Negative Prompt**。

### 5.4 备用提示词：分区生成后手工拼接

若单张图集一次生成失败，可按区生成相同尺寸的分块，在 Aseprite / Photoshop 中按 §3 坐标拼合为 `576×384`。各分块提示词如下。

#### 分块 A — 瓦片行（96×32）

```
Sprite strip 96x32 pixels, three 32x32 top-down tiles: dark green grass, dark gray stone wall, light brown wood crate, hi-bit pixel art, flat cartoon, tileable floor, crisp pixels, transparent background
```

#### 分块 B — 玩家角色行（576×48）

```
Sprite strip 576x48, 12 frames of 48x48 each, top-down red scarf bomber hero, walk animation down 3 up 3 left 3 right 3, hi-bit pixel art, flat cartoon, transparent background, consistent frame alignment
```

#### 分块 C — AI 蓝（576×48）

```
Sprite strip 576x48, 12 frames 48x48, top-down blue goggles slim bomber, walk down up left right 3 frames each, hi-bit pixel art, flat cartoon, same style as red hero reference
```

#### 分块 D — AI 绿（576×48）

```
Sprite strip 576x48, 12 frames 48x48, top-down green mushroom cap bomber, walk down up left right 3 frames each, hi-bit pixel art, flat cartoon
```

#### 分块 E — AI 黄（576×48）

```
Sprite strip 576x48, 12 frames 48x48, top-down yellow star accessory bomber, walk down up left right 3 frames each, hi-bit pixel art, flat cartoon
```

#### 分块 F — 炸弹（96×32）

```
Three 28x28 top-down cartoon bombs in a 96x32 row, centered in 32px cells, black round bomb with fuse, spark blink animation 3 frames, hi-bit pixel art, transparent background
```

#### 分块 G — 爆炸（160×32）

```
Five 32x32 explosion frames in a row, top-down orange yellow fire burst sequence spark grow peak fade smoke, hi-bit pixel art, transparent background
```

#### 分块 H — 道具（96×32）

```
Three 24x24 pickup icons in 96x32 row, white bomb plus, red flame, cyan speed boot, hi-bit pixel art, flat cartoon, transparent background
```

分块生成时，除分块 A 外，其余分块均建议以已生成的玩家角色行作为 **style reference / img2img** 输入，减少画风漂移。

### 5.5 各工具参数建议

| 工具 | 建议 |
|------|------|
| **Midjourney** | `--ar 3:2` 近似 576:384；`--style raw`；`--no blur` |
| **Stable Diffusion / Flux** | 指定宽高 576×384；采样后检查像素网格；后处理仅 nearest neighbor |
| **DALL·E** | 常需分块生成（§5.4）再拼接；单张难以精确到像素 |
| **通用** | 导出 PNG RGBA；在 Godot 导入预设中将 Filter 设为 Nearest |

### 5.6 生成与验收顺序

1. 用 §5.3 主提示词尝试一次性生成整张图集。
2. 失败则按 §5.4 分块生成 → 拼合 → 导出 `game_atlas.png`。
3. 按 §3 坐标表逐格核对：尺寸、对齐、透明底、帧序。
4. 角色脚底中心对齐各 48×48 帧的几何中心（便于 `grid_to_world` 定位）。
5. 将文件放入 `assets/textures/game_atlas.png`，提交前目视检查在 2× 缩放下无糊边。

---

## 6. Godot 接入要点（实现阶段参考）

> 本节供后续实现计划使用；本规格仅定义资源，不要求立即改代码。

- 新建 `scripts/resources/game_atlas.gd` 或在 `GameConstants` 中集中定义 `AtlasTexture` 区域 Rect，键名与 §3 表一致。
- `MapView`：由 `ColorRect` 改为 `Sprite2D` + `AtlasTexture`，按格子类型取 §3.1 区域。
- `Bomber`：`AnimatedSprite2D`，按角色 ID 绑定对应行的 `SpriteFrames`。
- `Bomb` / `Explosion` / `Powerup`：同上，帧率与循环模式见 §4。
- 图集导入：Project Settings → 纹理默认 Filter 设为 Nearest，或在 `.import` 中覆盖。

---

## 7. 不在本图集内的资源

| 资源 | 说明 |
|------|------|
| 主菜单 / 设置 / 暂停 / 结束 UI | 继续使用 Godot 默认 `Theme` + 中文 `Label` |
| 音效 ×6、BGM ×1 | 见主规格第 6 节，非本图集范围 |
| 应用图标 `icon.svg` | 保持现有矢量图标，不纳入 `game_atlas.png` |

---

## 8. 测试清单

- [ ] `game_atlas.png` 尺寸为 576×384，背景透明
- [ ] §3 坐标表中 62 个区域均可裁切出清晰精灵，无邻帧渗色
- [ ] 四套角色造型可区分，风格统一
- [ ] 角色在 32×32 格子内居中，移动时脚不漂移
- [ ] 炸弹 3 帧闪烁、爆炸 5 帧时序肉眼可辨
- [ ] Godot 中以 Nearest 过滤显示，无模糊
- [ ] 替换色块后核心玩法手动测试无回归（见主规格第 10 节）
