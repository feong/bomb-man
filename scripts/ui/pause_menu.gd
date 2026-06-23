extends Control

signal resume_pressed
signal restart_pressed
signal menu_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBox/ResumeButton.pressed.connect(func(): resume_pressed.emit())
	$Panel/VBox/RestartButton.pressed.connect(func(): restart_pressed.emit())
	$Panel/VBox/MenuButton.pressed.connect(func(): menu_pressed.emit())
