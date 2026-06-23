extends RefCounted


static func run(failures: PackedStringArray) -> void:
	_test_map_data_dimensions(failures)
	_test_generator_layout(failures)
	_test_generator_connectivity(failures)
	_test_spawn_safe_zones(failures)


static func _test_map_data_dimensions(failures: PackedStringArray) -> void:
	var map := MapData.new()
	if map.cells.size() != 17:
		failures.append(
			"map_data: cells should have 17 rows, got %d" % map.cells.size()
		)
	if map.cells.size() > 0 and map.cells[0].size() != 21:
		failures.append(
			"map_data: cells should have 21 columns, got %d" % map.cells[0].size()
		)


static func _test_generator_layout(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	var map := gen._build_base()

	for x in GameConstants.GRID_WIDTH:
		if map.get_cell(Vector2i(x, 0)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: top border missing hard wall at x=%d" % x)
		if map.get_cell(Vector2i(x, GameConstants.GRID_HEIGHT - 1)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: bottom border missing hard wall at x=%d" % x)
	for y in GameConstants.GRID_HEIGHT:
		if map.get_cell(Vector2i(0, y)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: left border missing hard wall at y=%d" % y)
		if map.get_cell(Vector2i(GameConstants.GRID_WIDTH - 1, y)) != MapData.CellType.HARD_WALL:
			failures.append("generator_layout: right border missing hard wall at y=%d" % y)

	for y in range(2, GameConstants.GRID_HEIGHT - 1, 2):
		for x in range(2, GameConstants.GRID_WIDTH - 1, 2):
			if map.get_cell(Vector2i(x, y)) != MapData.CellType.HARD_WALL:
				failures.append(
					"generator_layout: checker pillar missing at (%d, %d)" % [x, y]
				)


static func _test_generator_connectivity(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	var map := gen.generate()
	if not gen._is_connected(map):
		failures.append("generator_connectivity: generated map is not connected")


static func _test_spawn_safe_zones(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	seed(42)
	var map := gen.generate()
	for spawn in gen.get_active_spawns():
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if absi(dx) + absi(dy) > 2:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if not map.in_bounds(cell):
					continue
				if map.get_cell(cell) == MapData.CellType.SOFT_WALL:
					failures.append(
						"spawn_safe_zone: soft wall at %s within safe zone of spawn %s"
						% [cell, spawn]
					)
