class_name AIController
extends Node

var bomber: Bomber
var _timer: float = 0.0


func setup(target: Bomber) -> void:
	bomber = target
	_timer = 0.0


func _process(delta: float) -> void:
	if bomber == null or not bomber.is_alive or bomber.game_manager == null:
		return
	if not bomber.game_manager.can_bombers_act():
		return
	var params: Dictionary = GameSettings.get_ai_params()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = float(params.interval)
	_tick(params)


func _tick(params: Dictionary) -> void:
	var gm: GameManager = bomber.game_manager
	var player: Bomber = gm.player
	if gm.is_cell_dangerous(bomber.grid_pos, params):
		_move_away(params)
		return
	if randf() < float(params.powerup) and gm.nearest_powerup_cell(bomber.grid_pos) != Vector2i(-1, -1):
		_move_toward(gm.nearest_powerup_cell(bomber.grid_pos))
		return
	if player != null and player.is_alive and randf() < float(params.chase):
		_move_toward(player.grid_pos)
		if _adjacent_to(player.grid_pos) and _has_escape_route():
			bomber.try_place_bomb()
		return
	var soft := gm.nearest_soft_wall_cell(bomber.grid_pos)
	if soft != Vector2i(-1, -1):
		_move_toward(soft)
		if _adjacent_to(soft) and _has_escape_route():
			bomber.try_place_bomb()
		return
	_move_random_safe()


func _adjacent_to(cell: Vector2i) -> bool:
	var d: Vector2i = bomber.grid_pos - cell
	return absi(d.x) + absi(d.y) == 1


func _has_escape_route() -> bool:
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = bomber.grid_pos + d
		if bomber.game_manager.can_move_to(bomber, n):
			return true
	return false


func _move_away(params: Dictionary) -> void:
	var target := bomber.game_manager.find_safe_cell(bomber, params)
	if target != Vector2i(-1, -1):
		_step_toward(target)


func _move_toward(cell: Vector2i) -> void:
	_step_toward(cell)


func _step_toward(cell: Vector2i) -> void:
	var path: Array[Vector2i] = bomber.game_manager.find_path(bomber, cell)
	if path.size() >= 2:
		var next: Vector2i = path[1]
		var dir: Vector2i = next - bomber.grid_pos
		bomber.try_move(dir)


func _move_random_safe() -> void:
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	dirs.shuffle()
	for d in dirs:
		if bomber.game_manager.can_move_to(bomber, bomber.grid_pos + d):
			bomber.try_move(d)
			return
