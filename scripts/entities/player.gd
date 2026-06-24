class_name Player
extends Bomber

var _bomb_pressed: bool = false
var _last_dir: Vector2i = Vector2i.ZERO
var _buffered_dir: Vector2i = Vector2i.ZERO

const _DIR_BINDINGS: Array[Dictionary] = [
	{"action": "move_up", "dir": Vector2i.UP},
	{"action": "move_down", "dir": Vector2i.DOWN},
	{"action": "move_left", "dir": Vector2i.LEFT},
	{"action": "move_right", "dir": Vector2i.RIGHT},
]


func _process(delta: float) -> void:
	if can_act():
		_handle_movement_input()
		_handle_bomb_input()
	super._process(delta)


func _handle_movement_input() -> void:
	var dir := _read_input_direction()

	if dir != Vector2i.ZERO:
		set_facing(dir)
	elif not _is_moving:
		_play_idle()

	if dir == Vector2i.ZERO:
		_buffered_dir = Vector2i.ZERO
	elif _is_moving:
		_buffered_dir = dir
	else:
		try_move(dir)


func _finish_move() -> void:
	super._finish_move()
	_continue_after_move(_read_input_direction())


func _continue_after_move(held_dir: Vector2i) -> void:
	if held_dir != Vector2i.ZERO:
		try_move(held_dir)
		return
	if _buffered_dir != Vector2i.ZERO:
		var buffered := _buffered_dir
		_buffered_dir = Vector2i.ZERO
		try_move(buffered)


func _read_input_direction() -> Vector2i:
	for binding in _DIR_BINDINGS:
		if Input.is_action_just_pressed(binding.action):
			_last_dir = binding.dir

	if _last_dir != Vector2i.ZERO and _is_dir_pressed(_last_dir):
		return _last_dir

	for binding in _DIR_BINDINGS:
		if Input.is_action_pressed(binding.action):
			_last_dir = binding.dir
			return binding.dir

	_last_dir = Vector2i.ZERO
	return Vector2i.ZERO


func _is_dir_pressed(dir: Vector2i) -> bool:
	for binding in _DIR_BINDINGS:
		if binding.dir == dir:
			return Input.is_action_pressed(binding.action)
	return false


func _handle_bomb_input() -> void:
	if Input.is_action_pressed("place_bomb"):
		if not _bomb_pressed:
			_bomb_pressed = true
			try_place_bomb()
	else:
		_bomb_pressed = false
