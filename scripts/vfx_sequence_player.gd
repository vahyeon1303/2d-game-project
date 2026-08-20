extends Node2D

signal animation_finished

var _texture: Texture2D
var _cell_size := Vector2i.ONE
var _columns := 1
var _frame_count := 1
var _frames_per_second := 30.0
var _display_size := Vector2.ONE
var _elapsed := 0.0
var _frame_index := 0
var _is_playing := false


func configure(
		texture: Texture2D,
		cell_size: Vector2i,
		columns: int,
		frame_count: int,
		frames_per_second: float,
		display_size: Vector2
) -> void:
	_texture = texture
	_cell_size = cell_size
	_columns = maxi(columns, 1)
	_frame_count = maxi(frame_count, 1)
	_frames_per_second = maxf(frames_per_second, 1.0)
	_display_size = display_size
	_elapsed = 0.0
	_frame_index = 0
	_is_playing = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _process(delta: float) -> void:
	if not _is_playing:
		return
	_elapsed += delta
	var next_frame := int(floor(_elapsed * _frames_per_second))
	if next_frame >= _frame_count:
		_is_playing = false
		animation_finished.emit()
		return
	if next_frame == _frame_index:
		return
	_frame_index = next_frame
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var column := _frame_index % _columns
	var row := int(_frame_index / _columns)
	var source := Rect2(
		Vector2(column * _cell_size.x, row * _cell_size.y),
		Vector2(_cell_size)
	)
	var destination := Rect2(_display_size * -0.5, _display_size)
	draw_texture_rect_region(_texture, destination, source)
