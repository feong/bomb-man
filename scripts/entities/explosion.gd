class_name Explosion
extends Node2D

var game_manager: GameManager
var cells: Array[Vector2i] = []
var _timer: float = 0.35


func setup(manager: GameManager, affected: Array[Vector2i]) -> void:
	game_manager = manager
	cells = affected
	for cell in affected:
		var rect := ColorRect.new()
		rect.size = Vector2(GameConstants.TILE_SIZE - 4, GameConstants.TILE_SIZE - 4)
		rect.position = Vector2(cell) * GameConstants.TILE_SIZE + Vector2(2, 2)
		rect.color = Color(1.0, 0.55, 0.1, 0.85)
		add_child(rect)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		queue_free()
