class_name MapData
extends RefCounted

enum CellType { EMPTY, HARD_WALL, SOFT_WALL }

var cells: Array = []


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


func in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < GameConstants.GRID_WIDTH
		and cell.y < GameConstants.GRID_HEIGHT
	)


func is_blocking(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	var t: int = get_cell(cell)
	return t == CellType.HARD_WALL or t == CellType.SOFT_WALL


func is_soft_wall(cell: Vector2i) -> bool:
	return in_bounds(cell) and get_cell(cell) == CellType.SOFT_WALL


func destroy_soft_wall(cell: Vector2i) -> void:
	if is_soft_wall(cell):
		set_cell(cell, CellType.EMPTY)
