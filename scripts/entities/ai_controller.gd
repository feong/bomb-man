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
	if gm.is_cell_in_blast(bomber.grid_pos) or gm.is_cell_dangerous(bomber.grid_pos, params):
		if bomber.active_bombs > 0:
			var escape := gm.find_escape_cell_after_bomb(bomber)
			if escape != Vector2i(-1, -1) and not bomber._is_moving:
				_step_toward(escape, true)
				_sync_idle()
				return
		if not bomber._is_moving:
			_move_away(params)
		_sync_idle()
		return
	if randf() < float(params.powerup) and gm.nearest_powerup_cell(bomber.grid_pos) != Vector2i(-1, -1):
		_move_toward(gm.nearest_powerup_cell(bomber.grid_pos))
		_sync_idle()
		return
	if player != null and player.is_alive and randf() < float(params.chase):
		if _adjacent_to(player.grid_pos):
			_try_bomb_and_flee()
		else:
			_move_toward(player.grid_pos)
		_sync_idle()
		return
	var soft := gm.nearest_soft_wall_cell(bomber.grid_pos)
	if soft != Vector2i(-1, -1):
		if bomber._is_moving:
			return
		if _adjacent_to(soft):
			if not _try_bomb_and_flee():
				_move_away_from_cell(soft)
		else:
			_move_toward(soft)
		_sync_idle()
		return
	_move_random_safe()
	_sync_idle()


func _sync_idle() -> void:
	if bomber != null and not bomber._is_moving:
		bomber._play_idle()


func _adjacent_to(cell: Vector2i) -> bool:
	var d: Vector2i = bomber.grid_pos - cell
	return absi(d.x) + absi(d.y) == 1


func _try_bomb_and_flee() -> bool:
	if not bomber.game_manager.can_safely_place_bomb(bomber):
		return false
	bomber.try_place_bomb()
	var escape := bomber.game_manager.find_escape_cell_after_bomb(bomber)
	if escape != Vector2i(-1, -1):
		_step_toward(escape, true)
	return true


func _move_away_from_cell(cell: Vector2i) -> void:
	var away: Vector2i = bomber.grid_pos - cell
	if away != Vector2i.ZERO:
		var target: Vector2i = bomber.grid_pos + away
		if (
			bomber.game_manager.can_move_to(bomber, target)
			and not bomber.game_manager.is_cell_in_blast(target)
		):
			bomber.try_move(away)
			return
	_move_random_safe()


func _move_away(params: Dictionary) -> void:
	var target := bomber.game_manager.find_safe_cell(bomber, params)
	if target != Vector2i(-1, -1):
		_step_toward(target)


func _move_toward(cell: Vector2i) -> void:
	_step_toward(cell)


func _step_toward(cell: Vector2i, allow_danger: bool = false) -> void:
	var path: Array[Vector2i] = bomber.game_manager.find_path(bomber, cell, not allow_danger)
	if path.size() >= 2:
		var next: Vector2i = path[1]
		var dir: Vector2i = next - bomber.grid_pos
		bomber.try_move(dir)


func _move_random_safe() -> void:
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	dirs.shuffle()
	for d in dirs:
		var target: Vector2i = bomber.grid_pos + d
		if not bomber.game_manager.can_move_to(bomber, target):
			continue
		if bomber.game_manager.is_cell_in_blast(target):
			continue
		bomber.try_move(d)
		return
