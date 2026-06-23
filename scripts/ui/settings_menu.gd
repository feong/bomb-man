extends Control

func _ready() -> void:
	var count_btn: OptionButton = $VBox/AICountOption
	count_btn.add_item("1", 1)
	count_btn.add_item("2", 2)
	count_btn.add_item("3", 3)
	count_btn.select(GameSettings.ai_count - 1)
	var diff_btn: OptionButton = $VBox/DifficultyOption
	diff_btn.add_item("简单", GameSettings.Difficulty.EASY)
	diff_btn.add_item("普通", GameSettings.Difficulty.NORMAL)
	diff_btn.add_item("困难", GameSettings.Difficulty.HARD)
	diff_btn.select(GameSettings.difficulty)
	$VBox/VolumeSlider.value = GameSettings.master_volume * 100.0
	$VBox/BackButton.pressed.connect(_on_back)


func _on_back() -> void:
	var count_btn: OptionButton = $VBox/AICountOption
	var diff_btn: OptionButton = $VBox/DifficultyOption
	GameSettings.ai_count = count_btn.get_selected_id()
	GameSettings.difficulty = diff_btn.get_selected_id() as GameSettings.Difficulty
	GameSettings.master_volume = $VBox/VolumeSlider.value / 100.0
	GameSettings.save_settings()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
