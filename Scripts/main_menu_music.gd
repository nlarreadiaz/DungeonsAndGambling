extends Node

const MAIN_MENU_STREAM: AudioStream = preload("res://assets/Music/MainMenu.mp3")
const VILLAGE_STREAM: AudioStream = preload("res://assets/Music/Mediaval-Village.mp3")
const SCENE_MUSIC_STREAMS = {
	"res://Scenes/ui/menu.tscn": MAIN_MENU_STREAM,
	"res://Scenes/ui/options.tscn": MAIN_MENU_STREAM,
	"res://Scenes/ui/Inicio.tscn": MAIN_MENU_STREAM,
	"res://Scenes/ui/role_selection.tscn": VILLAGE_STREAM,
	"res://Scenes/world/aldea_principal.tscn": VILLAGE_STREAM,
}

var _player: AudioStreamPlayer
var _last_scene_path := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MainMenuAudioPlayer"
	_player.stream = MAIN_MENU_STREAM
	add_child(_player)
	set_process(true)


func _process(_delta: float) -> void:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	var current_scene_path := ""
	current_scene_path = current_scene.scene_file_path

	if current_scene_path == _last_scene_path:
		return

	_last_scene_path = current_scene_path
	if SCENE_MUSIC_STREAMS.has(current_scene_path):
		_play_music_stream(SCENE_MUSIC_STREAMS[current_scene_path])
	else:
		_pause_or_stop_music()


func _play_music_stream(music_stream: AudioStream) -> void:
	if _player == null or music_stream == null:
		return

	if _player.stream != music_stream:
		_player.stream_paused = false
		_player.stream = music_stream
		_player.play()
		return

	if _player.stream_paused:
		_player.stream_paused = false

	if not _player.playing:
		_player.play()


func _pause_or_stop_music() -> void:
	if _player == null:
		return

	if _player.stream == VILLAGE_STREAM and _player.playing:
		_player.stream_paused = true
		return

	if _player.playing:
		_player.stop()
