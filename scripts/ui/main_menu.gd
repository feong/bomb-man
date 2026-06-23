extends Control

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


func _on_quit() -> void:
	get_tree().quit()
