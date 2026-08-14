extends Control

var _panning := false


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var level := get_tree().current_scene
	return level != null and level.has_method("can_place_from_screen") and bool(
		level.call("can_place_from_screen", at_position, data)
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var level := get_tree().current_scene
	if level != null and level.has_method("place_from_screen"):
		level.call("place_from_screen", at_position, data)


func _gui_input(event: InputEvent) -> void:
	if get_viewport().gui_is_dragging():
		_panning = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_panning = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _panning:
		var level := get_tree().current_scene
		if level != null and level.has_method("pan_camera"):
			level.call("pan_camera", -event.relative.x)
		accept_event()
