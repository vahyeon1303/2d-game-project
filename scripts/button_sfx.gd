extends Node

const HOVER_SOUND := preload("res://Asset/Tick.mp3")
const CLICK_SOUND := preload("res://Asset/Pop.mp3")
const CONNECTED_META := &"button_sfx_connected"

var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover_player = _create_audio_player("TickAudio", HOVER_SOUND, -7.0)
	_click_player = _create_audio_player("PopAudio", CLICK_SOUND, -4.0)
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_in_branch(get_tree().root)


func _create_audio_player(
	player_name: String,
	stream: AudioStream,
	volume_db: float
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	player.max_polyphony = 8
	add_child(player)
	return player


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)


func _connect_buttons_in_branch(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	for child in node.get_children():
		_connect_buttons_in_branch(child)


func _connect_button(button: BaseButton) -> void:
	if button.has_meta(CONNECTED_META):
		return
	button.set_meta(CONNECTED_META, true)
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_mouse_entered(button: BaseButton) -> void:
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	play_hover_sound()


func _on_button_pressed(button: BaseButton) -> void:
	if button == null or button.disabled:
		return
	play_click_sound()


func play_hover_sound() -> void:
	if _hover_player != null:
		_hover_player.play()


func play_click_sound() -> void:
	if _click_player != null:
		_click_player.play()
