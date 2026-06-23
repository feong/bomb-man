# Bomberman v1 Design Spec

**Date:** 2025-06-23  
**Status:** Approved  
**Engine:** Godot 4.x (latest stable) + GDScript  
**Platform:** Desktop (Windows / macOS / Linux)

---

## 1. Overview

### Goal

Build a playable single-player Bomberman-style game in Godot 4.x: one human vs 1–3 AI opponents on a grid-based arena with bombs, destructible walls, power-ups, and elimination victory rules.

### Success Criteria

- Player can navigate main menu → settings → match → win/lose → restart or return to menu.
- Core mechanics work: grid movement, bomb placement, chain explosions, soft-wall destruction, power-up drops and pickup.
- AI difficulty tiers (Easy / Normal / Hard) produce noticeably different behavior.
- Settings (AI count, difficulty, volume) persist between sessions.
- All UI text is in Chinese.

### Out of Scope (v1)

- Online or local multiplayer between humans
- Gamepad support
- Custom key rebinding
- Multiple map templates
- Kick bomb, pierce bomb, remote bomb
- Leaderboards, tutorials, replay
- Separate BGM/SFX volume sliders

---

## 2. Architecture

### Approach: Hybrid Grid + Scene Entities (Option C)

- `MapGenerator` produces a 2D grid data structure.
- `TileMapLayer` renders static floor, hard walls, and soft walls.
- Dynamic entities (players, AI, bombs, power-ups, explosions) are independent scene nodes.
- `GameManager` coordinates match state, win/lose, and entity lifecycle.

This separates game logic from presentation, supports placeholder art with future reskinning, and keeps AI/pathfinding logic straightforward.

### Scene Flow

```
MainMenu → Settings → Game → GameOver
                ↑___________|
         (restart or menu)
```

### Autoloads

| Name | Responsibility |
|------|----------------|
| `GameSettings` | Load/save AI count (1–3), difficulty, master volume via `ConfigFile` |
| `AudioManager` | Play BGM and SFX; respect master volume |

### Core Modules (Game Scene)

| Module | Responsibility |
|--------|----------------|
| `GameManager` | Match state machine: countdown → playing → ended |
| `MapGenerator` | Generate 13×11 grid with hard walls, random soft walls, connectivity check |
| `MapView` | Render grid via `TileMapLayer` |
| `Bomber` (base) | Grid movement, bomb stats, bomb-pass rule state |
| `Player` | Keyboard input (arrows / WASD, Space) |
| `AIController` | Difficulty-parameterized AI decisions |
| `Bomb` | Fuse timer, detonation, chain trigger |
| `Explosion` | Cross-shaped blast calculation and damage |
| `Powerup` | Drop type, pickup collision, stat application |

### Coordinate System

- Grid: 13 columns × 11 rows (width × height).
- Tile size: 32×32 pixels.
- Map pixel size: 416×352.
- Window: 960×720 (centered playfield + HUD margins).
- Grid origin: top-left cell (0, 0).
- Conversion helpers: `grid_to_world(cell: Vector2i) -> Vector2`, `world_to_grid(pos: Vector2) -> Vector2i`.

---

## 3. Gameplay Rules

### Match Setup

- Default: 1 human vs 3 AI.
- AI count configurable in settings: 1, 2, or 3.
- All AI share the difficulty selected in settings (default: Normal).
- Spawn positions: four corners of the map.
- Empty player slots are not used; only active AI count spawn.

### Map Generation

- Fixed outer ring of hard walls.
- Fixed checkerboard hard-wall pillars (classic Bomberman pattern).
- Soft walls randomly placed on eligible empty cells at ~55% density.
- Safe zones: no soft walls within 2 Manhattan-distance cells of each spawn corner.
- Connectivity validation: ensure all spawn corners can reach each other via walkable paths (BFS). Regenerate up to 10 times; on failure, reduce soft-wall density slightly and retry.

### Cell Types (Runtime Grid)

| Type | Walkable | Destructible | Notes |
|------|----------|--------------|-------|
| Empty | Yes | No | Floor |
| Hard wall | No | No | Permanent |
| Soft wall | No | Yes | Destroyed by explosion |
| Bomb | No* | No | *See bomb-pass rule |
| Power-up | Yes | No | Destroyed if caught in explosion |

### Movement

- Four-directional grid logic with visual lerp interpolation between cell centers.
- Only one direction processed at a time (no diagonal).
- Speed stat increases lerp speed (base + increments per Speed+ pickup, max 3 tiers).
- Movement blocked by hard walls, soft walls, other bombers, and bombs per bomb-pass rule.

### Bombs

- Place bomb on current cell if: active bombs < bomb count stat, and cell has no existing bomb.
- One bomb per key press (no hold-to-spam).
- Fuse: 2.5 seconds.
- Explosion: cross shape, radius = fire power stat (default 1, max 8).
- Hard walls stop blast propagation.
- Soft walls in blast are destroyed; blast stops at soft wall (does not penetrate).
- Chain reaction: bomb hit by explosion detonates immediately.
- Bombs and explosions kill any bomber standing in affected cells.

### Bomb-Pass Rule (Custom)

Implementation semantics:

1. When a bomber places a bomb, they occupy the same cell as the bomb.
2. The bomber may leave that cell normally on their next move (moving to an adjacent empty cell).
3. **Once the bomber has left the cell where they placed their first bomb**, set `bombs_solid = true` on that bomber permanently for the rest of the match.
4. When `bombs_solid` is true, the bomber cannot enter any cell containing a bomb (own or others').
5. AI follows the same rule.

### Power-Ups

Dropped when a soft wall is destroyed (20% chance). Random among:

| Power-up | Effect | Max |
|----------|--------|-----|
| Bomb+ | +1 max simultaneous bombs | 8 |
| Fire+ | +1 explosion radius | 8 |
| Speed+ | +1 movement speed tier | 3 |

- Pickup on contact (player walks over; AI pathing targets power-ups).
- Uncollected power-ups are destroyed if caught in an explosion.

### Victory / Defeat

- **Win:** Player eliminates all AI opponents.
- **Lose:** Player is killed by an explosion.
- On end: show Chinese win/lose screen with restart and main-menu options.

### Match Start

- 3-2-1 countdown displayed on screen.
- All bombers and AI frozen during countdown.
- Match begins at "开始!" (or "1" completion); bombers can move and place bombs.

---

## 4. AI System

Single `AIController` with difficulty parameters from `GameSettings`:

| Parameter | Easy | Normal | Hard |
|-----------|------|--------|------|
| Decision interval (sec) | 0.5 | 0.3 | 0.15 |
| Danger zone awareness | Low (1 cell margin) | Medium (blast radius) | High (blast radius + 1) |
| Chase player probability | 0.2 | 0.5 | 0.8 |
| Power-up seek probability | 0.1 | 0.4 | 0.6 |
| Random movement weight | High | Medium | Low |

### Behavior Loop (each decision tick)

1. If current cell is or will be dangerous, flee to nearest safe cell (BFS).
2. Else if power-up visible and seek roll passes, path toward nearest power-up.
3. Else if player nearby and chase roll passes, path toward player.
4. Else move toward nearest soft wall or random safe cell.
5. Place bomb if adjacent to soft wall or player and escape route exists (Hard: also attempt traps).

Pathfinding: BFS on walkable cells respecting `bombs_solid` and current danger map. Grid is 13×11; no external pathfinding library needed.

---

## 5. UI / UX (Chinese)

### Main Menu

- 开始游戏
- 设置
- 退出 (desktop only; hidden or no-op on web if ever ported)

### Settings

- AI 数量: 1 / 2 / 3 (default 3)
- 难度: 简单 / 普通 / 困难 (default 普通)
- 主音量: slider 0–100 (default 80)
- 返回

Settings persist to `user://settings.cfg`.

### In-Game HUD

- Top bar: `剩余敌人: N`
- Center overlay during countdown: 3, 2, 1, 开始!

### Pause Menu (Esc)

- 继续
- 重新开始
- 返回主菜单

### Game Over

- 胜利! / 失败!
- 重新开始
- 返回主菜单

### Controls

| Action | Keys |
|--------|------|
| Move | Arrow keys or WASD |
| Place bomb | Space |
| Pause | Esc |

---

## 6. Audio

### Sound Effects (6)

1. Place bomb
2. Explosion
3. Pick up power-up
4. Player death
5. Victory
6. Defeat

### Music

- One looping battle BGM during match.
- Menu can be silent or reuse battle BGM at lower volume.

### Source

- Free asset packs (Kenney, OpenGameArt) or minimal placeholder tones.
- Master volume slider controls all audio.

---

## 7. Visual Style (Placeholder)

| Element | Placeholder |
|---------|-------------|
| Floor | Dark green `ColorRect` / tile |
| Hard wall | Dark gray |
| Soft wall | Light brown |
| Player | Red square/sprite |
| AI | Blue, green, yellow |
| Bomb | Black circle |
| Explosion | Orange cross animation (brief) |
| Power-ups | Colored icons: white (Bomb+), red (Fire+), cyan (Speed+) |

Node structure uses `Sprite2D` or `ColorRect` with resource paths in a config dict so art can be swapped without logic changes.

---

## 8. Project File Structure

```
godot-cursor-game/
├── project.godot
├── autoload/
│   ├── game_settings.gd
│   └── audio_manager.gd
├── scenes/
│   ├── main_menu.tscn
│   ├── settings.tscn
│   ├── game.tscn
│   ├── game_over.tscn
│   ├── pause_menu.tscn
│   ├── bomber.tscn
│   ├── bomb.tscn
│   ├── powerup.tscn
│   └── explosion.tscn
├── scripts/
│   ├── map/
│   │   ├── map_data.gd
│   │   ├── map_generator.gd
│   │   └── map_view.gd
│   ├── entities/
│   │   ├── bomber.gd
│   │   ├── player.gd
│   │   ├── ai_controller.gd
│   │   ├── bomb.gd
│   │   ├── powerup.gd
│   │   └── explosion.gd
│   └── systems/
│       └── game_manager.gd
├── assets/
│   ├── audio/
│   └── textures/
└── docs/
    └── superpowers/
        └── specs/
            └── 2025-06-23-bomberman-design.md
```

---

## 9. Error Handling & Edge Cases

| Case | Handling |
|------|----------|
| Map generation fails connectivity | Retry up to 10 times with reduced density |
| Move into blocked cell | Ignore input; no position change |
| Place bomb when at max or cell occupied | Ignore input |
| Scene change mid-match | `GameManager` frees all bombs, explosions, power-ups |
| Player dies while bombs active | Bombs remain; show game over immediately |
| Last AI dies | Trigger win immediately |

---

## 10. Testing

Manual test checklist for v1:

- [ ] Grid movement feels smooth; direction changes work
- [ ] Bomb fuse, cross explosion, and chain reactions
- [ ] Soft walls destroyed; 20% power-up drop rate feels reasonable
- [ ] Bomb-pass rule: can leave first bomb cell; cannot enter any bomb cell afterward
- [ ] Power-ups apply stats and respect caps
- [ ] Explosions destroy uncollected power-ups
- [ ] AI Easy/Normal/Hard behave differently
- [ ] 3-2-1 countdown freezes all entities
- [ ] Win and lose screens; restart and menu navigation
- [ ] Settings persist after restart

---

## 11. Technical Notes

- Renderer: Compatibility (friendly for placeholder art and broad hardware support).
- Godot version: 4.x latest stable.
- Language: GDScript with type hints.
- Input: Godot Input Map (`move_up`, `move_down`, `move_left`, `move_right`, `place_bomb`, `pause`).
