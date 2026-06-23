extends RefCounted


static func run(failures: PackedStringArray) -> void:
	_test_generate_includes_soft_walls(failures)
	_test_generate_soft_walls_across_seeds(failures)
	_test_density_produces_expected_soft_wall_count(failures)
	_test_higher_density_produces_more_soft_walls(failures)


static func _count_soft_walls(map: MapData) -> int:
	var count := 0
	for y in GameConstants.GRID_HEIGHT:
		for x in GameConstants.GRID_WIDTH:
			if map.get_cell(Vector2i(x, y)) == MapData.CellType.SOFT_WALL:
				count += 1
	return count


static func _test_generate_includes_soft_walls(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	seed(42)
	var map := gen.generate()
	var soft_count := _count_soft_walls(map)
	if soft_count == 0:
		failures.append(
			"generate_soft_walls: expected soft walls on generated map, got 0"
		)


static func _test_generate_soft_walls_across_seeds(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	for seed_value in 20:
		seed(seed_value)
		var map := gen.generate()
		if _count_soft_walls(map) == 0:
			failures.append(
				"generate_soft_walls: seed %d produced map with no soft walls"
				% seed_value
			)


static func _count_eligible_cells(gen: MapGenerator) -> int:
	var map := gen._build_base()
	var count := 0
	for y in range(1, GameConstants.GRID_HEIGHT - 1):
		for x in range(1, GameConstants.GRID_WIDTH - 1):
			var cell := Vector2i(x, y)
			if not map.is_blocking(cell) and not gen._is_safe_zone(cell):
				count += 1
	return count


static func _test_density_produces_expected_soft_wall_count(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	var eligible := _count_eligible_cells(gen)
	var min_soft := int(eligible * GameConstants.SOFT_WALL_DENSITY * 0.40)
	seed(42)
	var map := gen.generate()
	var soft_count := _count_soft_walls(map)
	if soft_count < min_soft:
		failures.append(
			"soft_wall_density: expected at least %d soft walls (40%% of target), got %d (eligible=%d density=%.2f)"
			% [min_soft, soft_count, eligible, GameConstants.SOFT_WALL_DENSITY]
		)


static func _test_higher_density_produces_more_soft_walls(failures: PackedStringArray) -> void:
	var gen := MapGenerator.new()
	var total_low := 0
	var total_high := 0
	for seed_value in 20:
		seed(seed_value)
		var map_low := gen._build_base()
		gen._scatter_soft_walls(map_low, 0.55)
		total_low += _count_soft_walls(map_low)
		seed(seed_value)
		var map_high := gen._build_base()
		gen._scatter_soft_walls(map_high, 0.90)
		total_high += _count_soft_walls(map_high)
	if total_high <= total_low:
		failures.append(
			"soft_wall_density: density 0.90 should produce more soft walls than 0.55 over 20 seeds (got %d vs %d)"
			% [total_high, total_low]
		)
