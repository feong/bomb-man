extends Bomber

var _bomb_pressed: bool = false


func _physics_process(_delta: float) -> void:
	if not can_act():
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		try_move(dir)
	if Input.is_action_pressed("place_bomb"):
		if not _bomb_pressed:
			_bomb_pressed = true
			try_place_bomb()
	else:
		_bomb_pressed = false
