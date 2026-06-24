extends Node

const TestBomberPlaceBombWhileMoving := preload("res://tests/test_bomber_place_bomb_while_moving.gd")
const TestBomberSetFacing := preload("res://tests/test_bomber_set_facing.gd")
const TestPlayerMoveFinish := preload("res://tests/test_player_move_finish.gd")
const TestGridConstants := preload("res://tests/test_grid_constants.gd")
const TestMapGeneratorGrid := preload("res://tests/test_map_generator_grid.gd")
const TestMapGeneratorSoftWalls := preload("res://tests/test_map_generator_soft_walls.gd")
const TestAiBombSafety := preload("res://tests/test_ai_bomb_safety.gd")


func _ready() -> void:
	var failures: PackedStringArray = []
	TestBomberPlaceBombWhileMoving.run(failures)
	TestBomberSetFacing.run(failures)
	TestPlayerMoveFinish.run(failures)
	TestGridConstants.run(failures)
	TestMapGeneratorGrid.run(failures)
	TestMapGeneratorSoftWalls.run(failures)
	TestAiBombSafety.run(failures)

	if failures.is_empty():
		print("PASS: all tests")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("FAIL: %s" % failure)
		get_tree().quit(1)
