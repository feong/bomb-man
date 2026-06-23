extends RefCounted


static func run(failures: PackedStringArray) -> void:
	var root := Node.new()
	root.name = "TestRoot"

	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	var bombs_root := Node2D.new()
	root.add_child(gm)
	gm.add_child(bombs_root)
	gm._bombs_root = bombs_root
	gm.map_data = MapData.new()

	var bomber := Bomber.new()
	root.add_child(bomber)
	var start_cell := Vector2i(5, 5)
	bomber.setup(gm, start_cell, true, Color.RED)

	bomber.try_move(Vector2i.RIGHT)
	if not bomber._is_moving:
		failures.append("setup: bomber should be moving after try_move")
		root.free()
		return

	bomber.try_place_bomb()

	if not gm.bombs.has(start_cell):
		failures.append(
			"place_bomb_while_moving: bomb should be placed at departure cell %s while moving"
			% start_cell
		)
	var destination_cell := start_cell + Vector2i.RIGHT
	if gm.bombs.has(destination_cell):
		failures.append(
			"place_bomb_while_moving: bomb should not be placed at destination cell %s while moving"
			% destination_cell
		)
	if bomber.active_bombs != 1:
		failures.append(
			"place_bomb_while_moving: bomber active_bombs should be 1, got %d"
			% bomber.active_bombs
		)

	root.free()
