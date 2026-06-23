extends Node

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_sfx_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	add_child(_sfx_player)
	_apply_volume()


func _apply_volume() -> void:
	var v: float = clampf(GameSettings.master_volume, 0.0, 1.0)
	var db: float = -80.0 if v <= 0.0 else linear_to_db(v)
	_bgm_player.volume_db = db
	_sfx_player.volume_db = db


func play_bgm(stream: AudioStream) -> void:
	if stream == null:
		return
	_apply_volume()
	_bgm_player.stream = stream
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()


func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	_apply_volume()
	_sfx_player.stream = stream
	_sfx_player.play()


func on_settings_changed() -> void:
	_apply_volume()
