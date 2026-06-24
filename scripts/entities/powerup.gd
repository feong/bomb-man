class_name Powerup
extends Area2D

enum Kind { BOMB, FIRE, SPEED }

const TEXTURES := {
	Kind.BOMB: preload("res://assets/textures/powerups/powerup_bomb.png"),
	Kind.FIRE: preload("res://assets/textures/powerups/powerup_fire.png"),
	Kind.SPEED: preload("res://assets/textures/powerups/powerup_speed.png"),
}

var game_manager: GameManager
var grid_pos: Vector2i
var kind: Kind
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	var scale_factor := GameConstants.POWERUP_SPRITE_SIZE / float(GameConstants.POWERUP_TEXTURE_SIZE)
	_sprite.scale = Vector2(scale_factor, scale_factor)
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
	_sprite.texture = TEXTURES[kind]


static func random_kind() -> Kind:
	var roll := randi() % 3
	return roll as Kind
