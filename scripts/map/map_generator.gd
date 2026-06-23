class_name MapGenerator
extends RefCounted


func generate() -> MapData:
	var density: float = GameConstants.SOFT_WALL_DENSITY
	for _attempt in 10:
		var map := _build_base()
		_scatter_soft_walls(map, density)
		if _is_connected(map):
			return map
		density *= 0.9
	return _build_base()


func get_active_spawns() -> Array[Vector2i]:
	var spawns: Array[Vector2i] = [GameConstants.SPAWN_CELLS[0]]
	for i in GameSettings.ai_count:
		if i + 1 < GameConstants.SPAWN_CELLS.size():
			spawns.append(GameConstants.SPAWN_CELLS[i + 1])
	return spawns


func _build_base() -> MapData:
	var map := MapData.new()
	for y in GameConstants.GRID_HEIGHT:
		for x in GameConstants.GRID_WIDTH:
			var cell := Vector2i(x, y)
			if (
				x == 0
				or y == 0
				or x == GameConstants.GRID_WIDTH - 1
				or y == GameConstants.GRID_HEIGHT - 1
			):
				map.set_cell(cell, MapData.CellType.HARD_WALL)
			elif x % 2 == 0 and y % 2 == 0:
				map.set_cell(cell, MapData.CellType.HARD_WALL)
	return map


func _is_safe_zone(cell: Vector2i) -> bool:
	for spawn in get_active_spawns():
		if absi(cell.x - spawn.x) + absi(cell.y - spawn.y) <= 2:
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
	var starts := get_active_spawns()
	var origin: Vector2i = starts[0]
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [origin]
	visited[origin] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not map.in_bounds(n) or visited.has(n) or map.is_blocking(n):
				continue
			visited[n] = true
			queue.append(n)
	for s in starts:
		if not visited.has(s):
			return false
	return true
