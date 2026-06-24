class_name Explosion
extends Node2D

const TEX_CENTER := preload("res://assets/textures/entities/bomb_center.png")
# 注意：若实际文件名是 bomb_horizon.png，请自行去掉下方的 'i'
const TEX_HORIZON := preload("res://assets/textures/entities/bomb_horiziton.png")
const TEX_RIGHT := preload("res://assets/textures/entities/bomb_right.png")
const DURATION := 0.35

enum SegmentKind { CENTER, HORIZON, TIP }

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var game_manager: GameManager
var cells: Array[Vector2i] = []
var _segments: Array[Dictionary] = []
var _timer: float = 0.0
var _total_duration: float = DURATION


func setup(
	manager: GameManager,
	origin: Vector2i,
	fire_range: int,
	affected: Array[Vector2i]
) -> void:
	game_manager = manager
	cells = affected
	var affected_set: Dictionary = {}
	for cell in affected:
		affected_set[cell] = true
	_build_visuals(origin, fire_range, affected_set)
	
	# 【优化】动态计算最大的爆炸距离
	var max_distance := 0
	for seg in _segments:
		max_distance = max(max_distance, seg["distance"])
	
	# 【修复生命周期】每个段需要 0.75 的进度跨度，最远的段延迟为 max_distance * 0.12
	# 动态延长总动画时间，保证最远端火焰也能完美缩放回 0
	_total_duration = DURATION * (0.75 + float(max_distance) * 0.12)
	_timer = _total_duration


func _process(delta: float) -> void:
	_timer -= delta
	var elapsed := _total_duration - _timer
	var progress := elapsed / DURATION # 这里的 progress 会超过 1.0，这正是延迟段所需要的
	_update_segment_scales(progress)
	if _timer <= 0.0:
		queue_free()


func _build_visuals(origin: Vector2i, fire_range: int, affected: Dictionary) -> void:
	_add_segment(origin, Vector2i.ZERO, SegmentKind.CENTER, TEX_CENTER, 0)

	for dir in DIRECTIONS:
		var arm: Array[Vector2i] = []
		var cell := origin + dir
		while affected.has(cell):
			arm.append(cell)
			cell += dir
		for i in arm.size():
			var dist := i + 1
			var arm_cell: Vector2i = arm[i]
			var is_tip := i == arm.size() - 1
			if is_tip:
				_add_segment(arm_cell, dir, SegmentKind.TIP, TEX_RIGHT, dist)
			else:
				# 【修复断层 Bug】移除了 "elif fire_range > 2"
				# 只要不是末梢，就必定是过渡段
				_add_segment(arm_cell, dir, SegmentKind.HORIZON, TEX_HORIZON, dist)


func _add_segment(
	cell: Vector2i,
	dir: Vector2i,
	kind: int,
	texture: Texture2D,
	distance: int
) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind != SegmentKind.CENTER:
		sprite.rotation = _direction_rotation(dir)
	var original_pos = Vector2(cell) * GameConstants.TILE_SIZE + Vector2(
		GameConstants.TILE_SIZE,
		GameConstants.TILE_SIZE
	) * 0.5
	sprite.position = original_pos
	sprite.scale = Vector2.ZERO
	add_child(sprite)
	_segments.append({
		"sprite": sprite,
		"kind": kind,
		"dir": dir,
		"base": _fit_tile_scale(texture),
		"texture_size": texture.get_size(), # 【新增】存储纹理原始尺寸
		"distance": distance,
		"original_pos": original_pos, # 【新增】存储 sprite 原始中心位置
	})


func _fit_tile_scale(texture: Texture2D) -> float:
	return GameConstants.TILE_SIZE / float(texture.get_size().y)


func _direction_rotation(dir: Vector2i) -> float:
	if dir == Vector2i.RIGHT:
		return 0.0
	if dir == Vector2i.DOWN:
		return PI * 0.5
	if dir == Vector2i.LEFT:
		return PI
	if dir == Vector2i.UP:
		return -PI * 0.5
	return 0.0


func _segment_progress(global_progress: float, distance: int) -> float:
	var delayed := global_progress - float(distance) * 0.12
	return clampf(delayed / 0.75, 0.0, 1.0)


func _update_segment_scales(progress: float) -> void:
	for seg in _segments:
		var sprite: Sprite2D = seg["sprite"]
		var base: float = seg["base"]
		var distance: int = seg["distance"]
		var kind: int = seg["kind"]
		var dir: Vector2i = seg["dir"]
		var texture_size: Vector2 = seg["texture_size"]
		var original_pos: Vector2 = seg["original_pos"]

		var t := _segment_progress(progress, distance)
		var eased := sin(t * PI) # Scale from 0 to 1 and back to 0

		# 总是设置缩放
		sprite.scale = Vector2(base, base) * eased
		
		# 重置位置到原始中心点，为后续计算做准备
		sprite.position = original_pos

		# 【修复 TIP 动画中心】只对 TIP 类型的火焰段应用位置调整，使其从内侧边缘向外伸展
		if kind == SegmentKind.TIP:
			# 计算在完全缩放状态下，纹理在游戏单位中的半尺寸
			var half_texture_full_scaled_size = texture_size * base * 0.5
			
			# 计算所需的额外位置偏移量。
			# 目标是：当 eased=0 时， Sprite 的“内侧”边缘位于原始中心点 - 半尺寸的距离（即内侧边缘的实际坐标）。
			# 当 eased=1 时， Sprite 的中心位于原始中心点，不需要偏移。
			# 偏移量与 (1.0 - eased) 成正比。
			
			var offset_vector := Vector2.ZERO
			if dir.x != 0: # 水平方向的尖端 (RIGHT 或 LEFT)
				# 偏移量沿 X 轴计算。例如，如果 dir 是 RIGHT，则 sprite 需要向 LEFT 移动。
				# dir.x 是 1 或 -1，用于控制偏移方向。
				offset_vector.x = dir.x * half_texture_full_scaled_size.x * (1.0 - eased)
			elif dir.y != 0: # 垂直方向的尖端 (UP 或 DOWN)
				# 偏移量沿 Y 轴计算。例如，如果 dir 是 DOWN，则 sprite 需要向 UP 移动。
				# dir.y 是 1 或 -1，用于控制偏移方向。
				offset_vector.y = dir.y * half_texture_full_scaled_size.y * (1.0 - eased)
			
			# 将计算出的偏移量应用到 Sprite 的位置。
			# 注意这里是 `-=`，因为 `dir` 指向外侧，而我们需要将 Sprite 的中心向内侧移动。
			sprite.position -= offset_vector