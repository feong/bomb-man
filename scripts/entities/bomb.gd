class_name Bomb
extends Node2D

var game_manager: GameManager
var grid_pos: Vector2i
var owner_bomber: Bomber
var allowed_overlappers: Array[Bomber] = []
var _fuse: float = 0.0
var _fuse_duration: float = 0.0
var _pulse_time: float = 0.0
var _sprite: ColorRect
var _animated_sprite: AnimatedSprite2D
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _animated_sprite:
		_apply_sprite_scale()
	else:
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
	_fuse_duration = GameConstants.BOMB_FUSE_SEC
	_pulse_time = 0.0
	if _animated_sprite:
		_sync_animation_to_fuse()
		_update_fuse_visuals()


func can_overlap(bomber: Bomber) -> bool:
	return allowed_overlappers.has(bomber)


func on_bomber_left(bomber: Bomber) -> void:
	allowed_overlappers.erase(bomber)


func detonate() -> void:
	if game_manager:
		game_manager.detonate_bomb(self)


func _process(delta: float) -> void:
	_pulse_time += delta
	_fuse -= delta
	_update_fuse_visuals()
	if _fuse <= 0.0:
		set_process(false)
		detonate()


func _apply_sprite_scale() -> void:
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
	var s := GameConstants.BOMB_SPRITE_SIZE / float(frame_height)
	_base_scale = Vector2(s, s)
	_animated_sprite.scale = _base_scale
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animated_sprite.centered = true


func _sync_animation_to_fuse() -> void:
	var frames := _animated_sprite.sprite_frames
	if frames == null:
		return
	const ANIM := "default"
	if not frames.has_animation(ANIM):
		return
	frames.set_animation_loop(ANIM, false)
	var total_duration := 0.0
	for i in frames.get_frame_count(ANIM):
		total_duration += frames.get_frame_duration(ANIM, i)
	var anim_speed := frames.get_animation_speed(ANIM)
	if anim_speed <= 0.0:
		anim_speed = 1.0
	var native_length := total_duration / anim_speed
	if _fuse_duration > 0.0 and native_length > 0.0:
		_animated_sprite.speed_scale = native_length / _fuse_duration
	else:
		_animated_sprite.speed_scale = 1.0
	_animated_sprite.play(ANIM)


func _update_fuse_visuals() -> void:
	if not _animated_sprite or _fuse_duration <= 0.0:
		return
	var progress := 1.0 - clampf(_fuse / _fuse_duration, 0.0, 1.0)
	var freq := lerpf(0.8, 3.0, progress)
	var amp := lerpf(0.03, 0.08, progress)
	var pulse := 1.0 + sin(_pulse_time * freq * TAU) * amp
	_animated_sprite.scale = _base_scale * pulse
