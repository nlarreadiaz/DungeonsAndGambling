extends Node

const MAIN_MENU_STREAM: AudioStream = preload("res://assets/Music/MainMenu.mp3")
const MENU_SCENE_PATHS = {
	"res://Scenes/ui/menu.tscn": true,
	"res://Scenes/ui/options.tscn": true,
	"res://Scenes/ui/Inicio.tscn": true,
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
	if MENU_SCENE_PATHS.has(current_scene_path):
		_play_main_menu_music()
	else:
		_stop_main_menu_music()


func _play_main_menu_music() -> void:
	if _player == null:
		return

	if _player.stream != MAIN_MENU_STREAM:
		_player.stream = MAIN_MENU_STREAM

	if not _player.playing:
		_player.play()


func _stop_main_menu_music() -> void:
	if _player != null and _player.playing:
		_player.stop()
