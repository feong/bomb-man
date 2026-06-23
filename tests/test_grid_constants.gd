extends RefCounted


static func run(failures: PackedStringArray) -> void:
	if GameConstants.GRID_WIDTH != 21:
		failures.append(
			"grid_constants: GRID_WIDTH should be 21, got %d"
			% GameConstants.GRID_WIDTH
		)
	if GameConstants.GRID_HEIGHT != 17:
		failures.append(
			"grid_constants: GRID_HEIGHT should be 17, got %d"
			% GameConstants.GRID_HEIGHT
		)
	if GameConstants.MAP_PIXEL_SIZE != Vector2i(672, 544):
		failures.append(
			"grid_constants: MAP_PIXEL_SIZE should be (672, 544), got %s"
			% GameConstants.MAP_PIXEL_SIZE
		)

	var expected_spawns: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(19, 1),
		Vector2i(1, 15),
		Vector2i(19, 15),
	]
	for i in expected_spawns.size():
		if GameConstants.SPAWN_CELLS[i] != expected_spawns[i]:
			failures.append(
				"grid_constants: SPAWN_CELLS[%d] should be %s, got %s"
				% [i, expected_spawns[i], GameConstants.SPAWN_CELLS[i]]
			)

	var offset := GameConstants.map_offset()
	if offset != Vector2(144.0, 108.0):
		failures.append(
			"grid_constants: map_offset() should be (144, 108), got %s"
			% offset
		)
