extends RefCounted


static func _make_manager() -> Array:
	var root := Node.new()
	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	var bombs_root := Node2D.new()
	root.add_child(gm)
	gm.add_child(bombs_root)
	gm._bombs_root = bombs_root
	gm.map_data = MapData.new()
	return [root, gm]


static func _make_bomber(gm: GameManager, root: Node, cell: Vector2i) -> Bomber:
	var bomber := Bomber.new()
	root.add_child(bomber)
	bomber.setup(gm, cell, false, Color.BLUE)
	return bomber


static func _set_hard(map_data: MapData, cell: Vector2i) -> void:
	map_data.set_cell(cell, MapData.CellType.HARD_WALL)


static func _set_soft(map_data: MapData, cell: Vector2i) -> void:
	map_data.set_cell(cell, MapData.CellType.SOFT_WALL)


static func run(failures: PackedStringArray) -> void:
	_test_explosion_cells(failures)
	_test_dead_end_no_bomb(failures)
	_test_escape_through_danger(failures)
	_test_fuse_step_limit(failures)
	_test_find_escape_after_bomb(failures)
	_test_pocket_dead_end(failures)
	_test_moving_bomb_into_pocket(failures)
	_test_pocket_escape_not_viable(failures)
	_test_flee_away_from_bomb_behind(failures)
	_test_avoid_returning_to_blast(failures)
	_test_still_in_blast_must_flee(failures)


static func _test_still_in_blast_must_flee(failures: PackedStringArray) -> void:
	# (4,1) 仍在炸弹 (3,1) 的射程内，必须能规划到射线外
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_build_user_pocket_map(gm)
	var bomber := _make_bomber(gm, setup[0], Vector2i(3, 1))
	gm.place_bomb(bomber)
	bomber.grid_pos = Vector2i(4, 1)

	if not gm.is_cell_in_blast(bomber.grid_pos):
		failures.append("still_in_blast: (4,1) should be inside blast radius")

	var escape: Vector2i = gm.find_escape_cell_after_bomb(bomber)
	if escape == Vector2i(-1, -1) or gm.is_cell_in_blast(escape):
		failures.append(
			"still_in_blast: expected escape outside blast, got %s"
			% escape
		)

	setup[0].free()


static func _test_avoid_returning_to_blast(failures: PackedStringArray) -> void:
	# AI 已逃到 (5,1)，炸弹在 (3,1)；(4,1) 仍在射程内
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_build_user_pocket_map(gm)
	var bomber := _make_bomber(gm, setup[0], Vector2i(3, 1))
	gm.place_bomb(bomber)
	bomber.grid_pos = Vector2i(5, 1)

	if not gm.is_cell_in_blast(Vector2i(3, 1)):
		failures.append("avoid_returning_to_blast: setup bomb cell (3,1) should be in blast")
	if gm.is_cell_in_blast(Vector2i(5, 1)):
		failures.append("avoid_returning_to_blast: setup safe cell (5,1) should not be in blast")

	var next: Vector2i = gm.get_next_step_toward(bomber, Vector2i(1, 1), true)
	if gm.is_cell_in_blast(next):
		failures.append(
			"avoid_returning_to_blast: next step %s should not enter blast toward soft wall"
			% next
		)

	setup[0].free()


static func _test_flee_away_from_bomb_behind(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_build_user_pocket_map(gm)
	var bomber := _make_bomber(gm, setup[0], Vector2i(3, 1))
	gm.place_bomb(bomber)
	bomber.grid_pos = Vector2i(2, 1)
	var escape := gm.find_escape_cell_after_bomb(bomber)
	if escape == Vector2i(-1, -1):
		failures.append("flee_from_bomb_behind: expected escape route")
	elif escape == Vector2i(1, 1):
		failures.append("flee_from_bomb_behind: should not flee into pocket (1,1)")
	setup[0].free()


static func _build_user_pocket_map(gm: GameManager) -> void:
	#  . # . .
	#  # . . .
	#  . # . .
	_set_hard(gm.map_data, Vector2i(1, 0))
	_set_hard(gm.map_data, Vector2i(0, 1))
	_set_hard(gm.map_data, Vector2i(1, 2))
	_set_soft(gm.map_data, Vector2i(1, 1))


static func _test_moving_bomb_into_pocket(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_build_user_pocket_map(gm)
	var bomber := _make_bomber(gm, setup[0], Vector2i(3, 1))
	bomber.try_move(Vector2i.LEFT)

	if not bomber._is_moving:
		failures.append("moving_bomb_pocket: bomber should be moving left from (3,1)")
	elif gm.can_safely_place_bomb(bomber):
		failures.append(
			"moving_bomb_pocket: should not place bomb while moving into pocket"
		)

	setup[0].free()


static func _test_pocket_escape_not_viable(failures: PackedStringArray) -> void:
	# 炸弹在 (3,1)，AI 在 (2,1)：(1,1) 虽不在射线上但是死胡同，不算有效逃生
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_build_user_pocket_map(gm)
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))
	var danger := gm.get_danger_cells({"cell": Vector2i(3, 1), "range": 1})

	if gm._is_viable_escape_cell(bomber, Vector2i(1, 1), danger, Vector2i(3, 1)):
		failures.append("pocket_escape: (1,1) should not be a viable escape endpoint")

	setup[0].free()


static func _test_pocket_dead_end(failures: PackedStringArray) -> void:
	# 用户场景（封闭口袋）：AI 在 (2,1)，左侧空地 (1,1)，三面硬墙
	#  010
	#  10A
	#  010
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 0))
	_set_hard(gm.map_data, Vector2i(0, 1))
	_set_hard(gm.map_data, Vector2i(1, 2))
	_set_hard(gm.map_data, Vector2i(2, 0))
	_set_hard(gm.map_data, Vector2i(2, 2))
	_set_hard(gm.map_data, Vector2i(3, 0))
	_set_hard(gm.map_data, Vector2i(3, 1))
	_set_hard(gm.map_data, Vector2i(3, 2))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))

	if gm.can_safely_place_bomb(bomber):
		failures.append(
			"pocket_dead_end: bomber at (2,1) should not place bomb in walled pocket"
		)

	setup[0].free()


static func _test_explosion_cells(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))

	var cells := gm.get_explosion_cells(Vector2i(2, 1), 1)
	var expected: Array[Vector2i] = [
		Vector2i(2, 1),
		Vector2i(2, 0),
		Vector2i(2, 2),
		Vector2i(3, 1),
	]
	for c in expected:
		if not cells.has(c):
			failures.append(
				"explosion_cells: expected %s in blast from (2,1), got %s"
				% [c, cells]
			)
	if cells.has(Vector2i(1, 1)):
		failures.append("explosion_cells: hard wall (1,1) should not be in blast")
	setup[0].free()


static func _test_dead_end_no_bomb(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))
	_set_hard(gm.map_data, Vector2i(2, 0))
	_set_hard(gm.map_data, Vector2i(2, 2))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))

	if gm.can_safely_place_bomb(bomber):
		failures.append("dead_end: bomber should not safely place bomb in sealed corner")

	setup[0].free()


static func _test_escape_through_danger(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))

	if not gm.can_safely_place_bomb(bomber):
		failures.append(
			"escape_through_danger: bomber should escape via (2,0)->(1,0)"
		)

	setup[0].free()


static func _test_fuse_step_limit(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	var bomber := _make_bomber(gm, setup[0], Vector2i(1, 1))
	bomber.fire_range = 12
	for x in range(0, 16):
		_set_hard(gm.map_data, Vector2i(x, 0))
		_set_hard(gm.map_data, Vector2i(x, 2))
	_set_hard(gm.map_data, Vector2i(0, 1))
	_set_hard(gm.map_data, Vector2i(15, 1))
	for x in range(1, 15):
		gm.map_data.set_cell(Vector2i(x, 1), MapData.CellType.EMPTY)

	if gm.can_safely_place_bomb(bomber):
		failures.append(
			"fuse_step_limit: path too long for fuse should not allow bomb"
		)

	setup[0].free()


static func _test_find_escape_after_bomb(failures: PackedStringArray) -> void:
	var setup := _make_manager()
	var gm: GameManager = setup[1]
	_set_hard(gm.map_data, Vector2i(1, 1))
	_set_soft(gm.map_data, Vector2i(3, 1))
	var bomber := _make_bomber(gm, setup[0], Vector2i(2, 1))
	gm.place_bomb(bomber)
	var escape := gm.find_escape_cell_after_bomb(bomber)
	if escape == Vector2i(-1, -1):
		failures.append("find_escape_after_bomb: expected reachable safe cell")
	elif escape != Vector2i(1, 0):
		failures.append(
			"find_escape_after_bomb: expected (1,0), got %s"
			% escape
		)
	setup[0].free()
