class_name Bomb
extends Node2D

var game_manager: GameManager
var grid_pos: Vector2i
var owner_bomber: Bomber
var allowed_overlappers: Array[Bomber] = []
var _fuse: float = 0.0
var _sprite: ColorRect


func _ready() -> void:
	_sprite = ColorRect.new()
	_sprite.size = Vector2(20, 20)
	_sprite.position = Vector2(-10, -10)
	_sprite.color = Color(0.1, 0.1, 0.1)
	add_child(_sprite)


func setup(
	manager: GameManager,
	cell: Vector2i,
	owner: Bomber,
	overlappers: Array[Bomber]
) -> void:
	game_manager = manager
	grid_pos = cell
	owner_bomber = owner
	allowed_overlappers = overlappers.duplicate()
	position = GameConstants.grid_to_world(cell)
	_fuse = GameConstants.BOMB_FUSE_SEC


func can_overlap(bomber: Bomber) -> bool:
	return allowed_overlappers.has(bomber)


func on_bomber_left(bomber: Bomber) -> void:
	allowed_overlappers.erase(bomber)


func detonate() -> void:
	if game_manager:
		game_manager.detonate_bomb(self)


func _process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		set_process(false)
		detonate()
