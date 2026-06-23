extends Node

const TestBomberPlaceBombWhileMoving := preload("res://tests/test_bomber_place_bomb_while_moving.gd")


func _ready() -> void:
	var failures: PackedStringArray = []
	TestBomberPlaceBombWhileMoving.run(failures)

	if failures.is_empty():
		print("PASS: all tests")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("FAIL: %s" % failure)
		get_tree().quit(1)
