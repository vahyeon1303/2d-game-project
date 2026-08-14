extends Control


func _ready() -> void:
	Engine.time_scale = 1.0
	%StartGameButton.pressed.connect(_start_game)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/level_1.tscn")
