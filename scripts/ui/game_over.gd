extends Control

func _ready() -> void:
	var won: bool = GameSettings.last_match_won
	if won:
		$VBox/TitleLabel.text = "胜利!"
	else:
		$VBox/TitleLabel.text = "失败!"
	$VBox/RestartButton.pressed.connect(_on_restart)
	$VBox/MenuButton.pressed.connect(_on_menu)


func _on_restart() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
