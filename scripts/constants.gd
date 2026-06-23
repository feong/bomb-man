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

const PLAYER_COLOR := Color(0.9, 0.2, 0.2)
const AI_COLORS: Array[Color] = [
	Color(0.2, 0.4, 0.9),
	Color(0.2, 0.75, 0.3),
	Color(0.9, 0.85, 0.2),
]


static func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


static func world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / TILE_SIZE), floor(pos.y / TILE_SIZE))


static func map_offset() -> Vector2:
	return Vector2(
		(WINDOW_SIZE.x - MAP_PIXEL_SIZE.x) * 0.5,
		(WINDOW_SIZE.y - MAP_PIXEL_SIZE.y) * 0.5 + 20.0
	)
