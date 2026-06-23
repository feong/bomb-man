class_name Powerup
extends Area2D

enum Kind { BOMB, FIRE, SPEED }

const COLORS := {
	Kind.BOMB: Color(0.95, 0.95, 0.95),
	Kind.FIRE: Color(0.95, 0.2, 0.2),
	Kind.SPEED: Color(0.2, 0.85, 0.9),
}

var game_manager: GameManager
var grid_pos: Vector2i
var kind: Kind
var _sprite: ColorRect


func _ready() -> void:
	_sprite = ColorRect.new()
	_sprite.size = Vector2(18, 18)
	_sprite.position = Vector2(-9, -9)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape.shape = rect
	add_child(shape)


func setup(manager: GameManager, cell: Vector2i, power_kind: Kind) -> void:
	game_manager = manager
	grid_pos = cell
	kind = power_kind
	position = GameConstants.grid_to_world(cell)
	_sprite.color = COLORS[kind]


static func random_kind() -> Kind:
	var roll := randi() % 3
	return roll as Kind
