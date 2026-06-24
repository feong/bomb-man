class_name Bomber
extends Node2D

signal died(bomber: Bomber)

var game_manager: GameManager
var grid_pos: Vector2i
var is_player: bool = false
var is_alive: bool = true

var bomb_capacity: int = 1
var active_bombs: int = 0
var fire_range: int = 1
var speed_tier: int = 0

var _move_dir: Vector2i = Vector2i.ZERO
var _is_moving: bool = false
var _move_elapsed: float = 0.0
var _move_from: Vector2 = Vector2.ZERO
var _move_to: Vector2 = Vector2.ZERO
var _previous_cell: Vector2i

var body_color: Color = Color.WHITE
var _sprite: ColorRect
var _animated_sprite: AnimatedSprite2D
var _facing: Vector2i = Vector2i.DOWN

const DIR_TO_ANIM := {
	Vector2i.DOWN: "down",
	Vector2i.UP: "up",
	Vector2i.LEFT: "left",
	Vector2i.RIGHT: "right",
}


func _ready() -> void:
	_animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _animated_sprite:
		_scale_animated_sprite()
		_play_idle()
	else:
		_sprite = ColorRect.new()
		_sprite.size = Vector2(24, 24)
		_sprite.position = Vector2(-12, -12)
		_sprite.color = body_color
		add_child(_sprite)


func setup(manager: GameManager, cell: Vector2i, player: bool, color: Color) -> void:
	game_manager = manager
	is_player = player
	body_color = color
	grid_pos = cell
	_previous_cell = cell
	if _sprite:
		_sprite.color = color
	sync_world_position()


func sync_world_position() -> void:
	position = GameConstants.grid_to_world(grid_pos)


func get_move_duration() -> float:
	return maxf(
		0.08,
		GameConstants.BASE_MOVE_DURATION - speed_tier * GameConstants.SPEED_TIER_DELTA
	)


func can_act() -> bool:
	return is_alive and game_manager != null and game_manager.can_bombers_act()


func try_move(dir: Vector2i) -> void:
	if not can_act() or _is_moving or dir == Vector2i.ZERO:
		return
	var target: Vector2i = grid_pos + dir
	if not game_manager.can_move_to(self, target):
		return
	_previous_cell = grid_pos
	grid_pos = target
	_is_moving = true
	_move_elapsed = 0.0
	_move_from = GameConstants.grid_to_world(_previous_cell)
	_move_to = GameConstants.grid_to_world(grid_pos)
	position = _move_from
	_move_dir = dir
	_play_walk(dir)


func get_bomb_placement_cell() -> Vector2i:
	if _is_moving:
		return _previous_cell
	return grid_pos


func try_place_bomb() -> void:
	if can_act():
		game_manager.place_bomb(self)


func apply_powerup(kind: Powerup.Kind) -> void:
	match kind:
		Powerup.Kind.BOMB:
			bomb_capacity = mini(bomb_capacity + 1, GameConstants.MAX_BOMB_COUNT)
		Powerup.Kind.FIRE:
			fire_range = mini(fire_range + 1, GameConstants.MAX_FIRE_RANGE)
		Powerup.Kind.SPEED:
			speed_tier = mini(speed_tier + 1, GameConstants.MAX_SPEED_TIER)


func die(_reason: String = "explosion") -> void:
	if not is_alive:
		return
	is_alive = false
	visible = false
	set_process(false)
	died.emit(self)


func _process(delta: float) -> void:
	if not _is_moving:
		return
	_move_elapsed += delta
	var duration: float = get_move_duration()
	var t: float = clampf(_move_elapsed / duration, 0.0, 1.0)
	position = _move_from.lerp(_move_to, t)
	if t >= 1.0:
		_finish_move()


func _finish_move() -> void:
	_is_moving = false
	position = _move_to
	if _previous_cell != grid_pos:
		game_manager.on_bomber_exited_cell(self, _previous_cell)
	game_manager.resolve_occupancy_after_move(self)
	game_manager.check_pickup(self)


func _play_walk(dir: Vector2i) -> void:
	if not _animated_sprite:
		return
	_facing = dir
	var anim_name: String = DIR_TO_ANIM.get(dir, "down")
	if _animated_sprite.animation != anim_name:
		_animated_sprite.play(anim_name)
	elif not _animated_sprite.is_playing():
		_animated_sprite.play(anim_name)


func _play_idle() -> void:
	if not _animated_sprite:
		return
	var anim_name: String = DIR_TO_ANIM.get(_facing, "down")
	if _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.animation = anim_name
	_animated_sprite.stop()
	_animated_sprite.frame = 0


func _scale_animated_sprite() -> void:
	var frames := _animated_sprite.sprite_frames
	if frames == null:
		return
	var anim_names := frames.get_animation_names()
	if anim_names.is_empty():
		return
	var tex: Texture2D = frames.get_frame_texture(anim_names[0], 0)
	if tex == null:
		return
	var frame_height := tex.get_height()
	if frame_height <= 0:
		return
	var s := GameConstants.CHARACTER_SPRITE_HEIGHT / float(frame_height)
	_animated_sprite.scale = Vector2(s, s)
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
