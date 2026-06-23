class_name MapView
extends Node2D

const COLORS := {
	MapData.CellType.EMPTY: Color(0.15, 0.45, 0.2),
	MapData.CellType.HARD_WALL: Color(0.25, 0.25, 0.28),
	MapData.CellType.SOFT_WALL: Color(0.65, 0.45, 0.25),
}


func render(map: MapData) -> void:
	for child in get_children():
		child.queue_free()
	for y in GameConstants.GRID_HEIGHT:
		for x in GameConstants.GRID_WIDTH:
			var cell := Vector2i(x, y)
			var rect := ColorRect.new()
			rect.size = Vector2(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE)
			rect.position = Vector2(x, y) * GameConstants.TILE_SIZE
			rect.color = COLORS[map.get_cell(cell)]
			add_child(rect)
