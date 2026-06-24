extends RefCounted


static func run(failures: PackedStringArray) -> void:
	var root := Node.new()
	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	root.add_child(gm)
	gm.map_data = MapData.new()

	var bomber := Bomber.new()
	root.add_child(bomber)
	var start_cell := Vector2i(3, 3)
	bomber.setup(gm, start_cell, true, Color.RED)

	bomber.set_facing(Vector2i.LEFT)

	if bomber.grid_pos != start_cell:
		failures.append(
			"set_facing: grid_pos should stay %s, got %s" % [start_cell, bomber.grid_pos]
		)
	if bomber._facing != Vector2i.LEFT:
		failures.append(
			"set_facing: _facing should be LEFT, got %s" % bomber._facing
		)
	if bomber._is_moving:
		failures.append("set_facing: should not start movement")

	root.free()
