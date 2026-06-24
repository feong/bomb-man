extends RefCounted


static func run(failures: PackedStringArray) -> void:
	_test_finish_uses_buffered_dir(failures)
	_test_finish_idle_when_no_input(failures)


static func _make_player() -> Array:
	var root := Node.new()
	var gm := GameManager.new()
	gm.state = GameManager.MatchState.PLAYING
	root.add_child(gm)
	gm.map_data = MapData.new()
	var player = preload("res://scripts/entities/player.gd").new()
	root.add_child(player)
	player.setup(gm, Vector2i(5, 5), true, Color.RED)
	return [root, player]


static func _test_finish_uses_buffered_dir(failures: PackedStringArray) -> void:
	var setup := _make_player()
	var root: Node = setup[0]
	var player = setup[1]
	var start: Vector2i = player.grid_pos

	player._buffered_dir = Vector2i.RIGHT
	player._continue_after_move(Vector2i.ZERO)

	if player.grid_pos != start + Vector2i.RIGHT:
		failures.append(
			"move_finish_buffered: expected %s, got %s"
			% [start + Vector2i.RIGHT, player.grid_pos]
		)
	if player._buffered_dir != Vector2i.ZERO:
		failures.append("move_finish_buffered: buffer should be cleared after consume")

	root.free()


static func _test_finish_idle_when_no_input(failures: PackedStringArray) -> void:
	var setup := _make_player()
	var root: Node = setup[0]
	var player = setup[1]
	var start: Vector2i = player.grid_pos

	player._continue_after_move(Vector2i.ZERO)

	if player.grid_pos != start:
		failures.append(
			"move_finish_idle: grid_pos should stay %s, got %s" % [start, player.grid_pos]
		)
	if player._is_moving:
		failures.append("move_finish_idle: should not start moving")

	root.free()
