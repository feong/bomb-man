extends Node

enum Difficulty { EASY, NORMAL, HARD }

const CONFIG_PATH := "user://settings.cfg"

var ai_count: int = 3
var difficulty: Difficulty = Difficulty.NORMAL
var master_volume: float = 0.8
var last_match_won: bool = false

func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	ai_count = int(cfg.get_value("game", "ai_count", 3))
	difficulty = int(cfg.get_value("game", "difficulty", Difficulty.NORMAL)) as Difficulty
	master_volume = float(cfg.get_value("audio", "master_volume", 0.8))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "ai_count", ai_count)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(CONFIG_PATH)
	AudioManager.on_settings_changed()


func get_difficulty_name() -> String:
	match difficulty:
		Difficulty.EASY:
			return "简单"
		Difficulty.NORMAL:
			return "普通"
		Difficulty.HARD:
			return "困难"
	return "普通"


func get_ai_params() -> Dictionary:
	match difficulty:
		Difficulty.EASY:
			return {
				"interval": 0.5,
				"chase": 0.2,
				"powerup": 0.1,
				"danger_margin": 1,
			}
		Difficulty.HARD:
			return {
				"interval": 0.15,
				"chase": 0.8,
				"powerup": 0.6,
				"danger_margin": 2,
			}
	return {
		"interval": 0.3,
		"chase": 0.5,
		"powerup": 0.4,
		"danger_margin": 1,
	}
