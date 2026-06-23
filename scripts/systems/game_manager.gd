extends Node2D
class_name GameManager

enum MatchState { COUNTDOWN, PLAYING, ENDED }

const BOMB_SCENE := preload("res://scenes/bomb.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const POWERUP_SCENE := preload("res://scenes/powerup.tscn")
const BOMBER_SCENE := preload("res://scenes/bomber.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var map_data: MapData
var state: MatchState = MatchState.COUNTDOWN
var player: Bomber
var bombers: Array[Bomber] = []
var bombs: Dictionary = {}
var powerups: Dictionary = {}

var _countdown_left: float = 0.0
var _countdown_label: Label
var _enemy_label: Label
var _pause_menu: Control
var _map_view: MapView
var _entities: Node2D
var _bombs_root: Node2D
var _powerups_root: Node2D
var _effects_root: Node2D
var _map_offset: Vector2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_map_offset = GameConstants.map_offset()
	_setup_scene_refs()
	_start_match()
	if has_node("/root/AudioManager"):
		# 占位：无音频文件时静默
		pass


func _setup_scene_refs() -> void:
	_map_view = $World/MapView
	_entities = $World/Entities
	_bombs_root = $World/Bombs
	_powerups_root = $World/Powerups
	_effects_root = $World/Effects
	_countdown_label = $UI/CountdownLabel
	_enemy_label = $UI/EnemyLabel
	_pause_menu = $UI/PauseMenu
	$World.position = _map_offset
	_pause_menu.hide()
	_pause_menu.resume_pressed.connect(_on_resume)
	_pause_menu.restart_pressed.connect(_on_restart)
	_pause_menu.menu_pressed.connect(_on_menu)


func _start_match() -> void:
	_clear_world()
	var generator := MapGenerator.new()
	map_data = generator.generate()
	_map_view.render(map_data)
	_spawn_bombers()
	state = MatchState.COUNTDOWN
	_countdown_left = float(GameConstants.COUNTDOWN_SEC)
	_update_enemy_label()
	_show_countdown(str(ceili(_countdown_left)))


func _clear_world() -> void:
	for n in _entities.get_children():
		n.queue_free()
	for n in _bombs_root.get_children():
		n.queue_free()
	for n in _powerups_root.get_children():
		n.queue_free()
	for n in _effects_root.get_children():
		n.queue_free()
	bombers.clear()
	bombs.clear()
	powerups.clear()
	player = null


func _spawn_bombers() -> void:
	var player_node: Bomber = PLAYER_SCENE.instantiate()
	_entities.add_child(player_node)
	player_node.setup(self, GameConstants.SPAWN_CELLS[0], true, GameConstants.PLAYER_COLOR)
	player = player_node
	bombers.append(player_node)
	for i in GameSettings.ai_count:
		var ai: Bomber = BOMBER_SCENE.instantiate()
		_entities.add_child(ai)
		var color: Color = GameConstants.AI_COLORS[i % GameConstants.AI_COLORS.size()]
		ai.setup(self, GameConstants.SPAWN_CELLS[i + 1], false, color)
		var ctrl := AIController.new()
		ctrl.setup(ai)
		ai.add_child(ctrl)
		bombers.append(ai)
	for b in bombers:
		b.died.connect(_on_bomber_died)


func can_bombers_act() -> bool:
	return state == MatchState.PLAYING


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and state != MatchState.ENDED:
		_pause_menu.visible = not _pause_menu.visible
		get_tree().paused = _pause_menu.visible
	if state == MatchState.COUNTDOWN:
		_countdown_left -= delta
		if _countdown_left > 0.0:
			_show_countdown(str(ceili(_countdown_left)))
		elif _countdown_left > -0.6:
			_show_countdown("开始!")
		else:
			_countdown_label.visible = false
			state = MatchState.PLAYING


func _show_countdown(text: String) -> void:
	_countdown_label.visible = true
	_countdown_label.text = text


func can_move_to(bomber: Bomber, target: Vector2i) -> bool:
	if not map_data.in_bounds(target):
		return false
	if map_data.is_blocking(target):
		return false
	if bombs.has(target):
		return false
	return true


func get_bombers_at(cell: Vector2i) -> Array[Bomber]:
	var result: Array[Bomber] = []
	for b in bombers:
		if b.is_alive and b.grid_pos == cell:
			result.append(b)
	return result


func on_bomber_exited_cell(bomber: Bomber, cell: Vector2i) -> void:
	if bombs.has(cell):
		var bomb: Bomb = bombs[cell]
		bomb.on_bomber_left(bomber)


func resolve_occupancy_after_move(_bomber: Bomber) -> void:
	var occupants := get_bombers_at(_bomber.grid_pos)
	var found_player: Bomber = null
	var has_ai := false
	for b in occupants:
		if b.is_player:
			found_player = b
		else:
			has_ai = true
	if found_player != null and has_ai:
		found_player.die("contact")
		_check_match_end()


func place_bomb(bomber: Bomber) -> void:
	if not bomber.is_alive:
		return
	if bomber.active_bombs >= bomber.bomb_capacity:
		return
	var cell: Vector2i = bomber.get_bomb_placement_cell()
	if bombs.has(cell):
		return
	var bomb: Bomb = BOMB_SCENE.instantiate()
	_bombs_root.add_child(bomb)
	var overlappers: Array[Bomber] = get_bombers_at(cell)
	if not overlappers.has(bomber):
		overlappers.append(bomber)
	bomb.setup(self, cell, bomber, overlappers)
	bombs[cell] = bomb
	bomber.active_bombs += 1


func on_bomb_removed(cell: Vector2i, owner: Bomber) -> void:
	bombs.erase(cell)
	if owner != null and owner.is_alive:
		owner.active_bombs = maxi(0, owner.active_bombs - 1)


func detonate_bomb(bomb: Bomb) -> void:
	if not bombs.has(bomb.grid_pos):
		return
	var owner: Bomber = bomb.owner_bomber
	var cell: Vector2i = bomb.grid_pos
	on_bomb_removed(cell, owner)
	bomb.queue_free()
	_trigger_explosion(cell, owner.fire_range if owner else 1)


func _trigger_explosion(origin: Vector2i, range: int) -> void:
	var affected: Array[Vector2i] = [origin]
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for i in range(1, range + 1):
			var cell: Vector2i = origin + d * i
			if not map_data.in_bounds(cell):
				break
			if map_data.get_cell(cell) == MapData.CellType.HARD_WALL:
				break
			affected.append(cell)
			if map_data.is_soft_wall(cell):
				break
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	_effects_root.add_child(explosion)
	explosion.setup(self, affected)
	var chain_bombs: Array[Bomb] = []
	var map_dirty: bool = false
	for cell in affected:
		if bombs.has(cell):
			chain_bombs.append(bombs[cell])
		if powerups.has(cell):
			var p: Powerup = powerups[cell]
			p.queue_free()
			powerups.erase(cell)
		for b in bombers:
			if b.is_alive and b.grid_pos == cell:
				b.die("explosion")
		if map_data.is_soft_wall(cell):
			map_data.destroy_soft_wall(cell)
			map_dirty = true
			_try_spawn_powerup(cell)
	if map_dirty:
		_map_view.render(map_data)
	for chained in chain_bombs:
		detonate_bomb(chained)
	_check_match_end()


func _try_spawn_powerup(cell: Vector2i) -> void:
	if randf() > GameConstants.POWERUP_DROP_CHANCE:
		return
	var p: Powerup = POWERUP_SCENE.instantiate()
	_powerups_root.add_child(p)
	p.setup(self, cell, Powerup.random_kind())
	powerups[cell] = p


func check_pickup(bomber: Bomber) -> void:
	if powerups.has(bomber.grid_pos):
		var p: Powerup = powerups[bomber.grid_pos]
		bomber.apply_powerup(p.kind)
		powerups.erase(bomber.grid_pos)
		p.queue_free()


func is_cell_dangerous(cell: Vector2i, params: Dictionary) -> bool:
	for bomb in bombs.values():
		var b: Bomb = bomb
		if b.grid_pos == cell:
			return true
		var owner: Bomber = b.owner_bomber
		var r: int = owner.fire_range if owner else 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			for i in range(r + 1):
				var c: Vector2i = b.grid_pos + d * i
				if c == cell:
					return true
				if map_data.is_blocking(c):
					break
	return false


func find_safe_cell(bomber: Bomber, params: Dictionary) -> Vector2i:
	var queue: Array[Vector2i] = [bomber.grid_pos]
	var visited: Dictionary = {bomber.grid_pos: true}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if not is_cell_dangerous(c, params):
			return c
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if visited.has(n) or not can_move_to(bomber, n):
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


func find_path(bomber: Bomber, goal: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = bomber.grid_pos
	if start == goal:
		return [start]
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if came_from.has(n):
				continue
			if n != goal and not can_move_to(bomber, n):
				continue
			if n == goal and bombs.has(n):
				continue
			came_from[n] = c
			queue.append(n)
	if not came_from.has(goal):
		return [start]
	var path: Array[Vector2i] = []
	var cur: Vector2i = goal
	while true:
		path.push_front(cur)
		if cur == start:
			break
		cur = came_from[cur]
	return path


func nearest_soft_wall_cell(from: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 99999
	for y in GameConstants.GRID_HEIGHT:
		for x in GameConstants.GRID_WIDTH:
			var c := Vector2i(x, y)
			if not map_data.is_soft_wall(c):
				continue
			var dist: int = absi(c.x - from.x) + absi(c.y - from.y)
			if dist < best_dist:
				best_dist = dist
				best = c
	return best


func nearest_powerup_cell(from: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 99999
	for cell in powerups.keys():
		var c: Vector2i = cell
		var dist: int = absi(c.x - from.x) + absi(c.y - from.y)
		if dist < best_dist:
			best_dist = dist
			best = c
	return best


func _update_enemy_label() -> void:
	var count: int = 0
	for b in bombers:
		if not b.is_player and b.is_alive:
			count += 1
	_enemy_label.text = "剩余敌人: %d" % count


func _on_bomber_died(bomber: Bomber) -> void:
	_update_enemy_label()
	_check_match_end()


func _check_match_end() -> void:
	if state == MatchState.ENDED:
		return
	if player != null and not player.is_alive:
		_end_match(false)
		return
	var ai_alive: int = 0
	for b in bombers:
		if not b.is_player and b.is_alive:
			ai_alive += 1
	if ai_alive == 0:
		_end_match(true)


func _end_match(won: bool) -> void:
	state = MatchState.ENDED
	get_tree().paused = false
	_pause_menu.hide()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(load("res://scenes/game_over.tscn") as PackedScene)
	GameSettings.last_match_won = won


func _on_resume() -> void:
	_pause_menu.hide()
	get_tree().paused = false


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
