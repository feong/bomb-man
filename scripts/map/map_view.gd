class_name MapView
extends Node2D

const TILE_TEXTURE_SIZE := 100.0
const TILE_SCALE := GameConstants.TILE_SIZE / TILE_TEXTURE_SIZE

const TILE_TEXTURES := {
	MapData.CellType.EMPTY: preload("res://assets/textures/tiles/tile_floor.png"),
	MapData.CellType.HARD_WALL: preload("res://assets/textures/tiles/tile_hard_wall.png"),
	MapData.CellType.SOFT_WALL: preload("res://assets/textures/tiles/tile_soft_wall.png"),
}


func render(map: MapData) -> void:
	for child in get_children():
		child.queue_free()
	for y in GameConstants.GRID_HEIGHT:
		for x in GameConstants.GRID_WIDTH:
			var cell := Vector2i(x, y)
			var cell_type: int = map.get_cell(cell)
			var sprite := Sprite2D.new()
			sprite.texture = TILE_TEXTURES[cell_type]
			sprite.position = Vector2(x, y) * GameConstants.TILE_SIZE + Vector2(
				GameConstants.TILE_SIZE,
				GameConstants.TILE_SIZE
			) * 0.5
			sprite.scale = Vector2(TILE_SCALE, TILE_SCALE)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = true
			add_child(sprite)
