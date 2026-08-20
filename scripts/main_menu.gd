extends Control


func _ready() -> void:
	Engine.time_scale = 1.0
	%StartGameButton.pressed.connect(_start_game)
	%SandboxButton.pressed.connect(_open_sandbox)
	%QuitButton.pressed.connect(_quit_game)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/level_1.tscn")


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/build_sandbox.tscn")


func _quit_game() -> void:
	get_tree().quit()
