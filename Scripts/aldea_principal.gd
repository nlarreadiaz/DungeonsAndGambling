extends Node2D

const OPTIONS_INGAME_SCENE := preload("res://Scenes/options_ingame.tscn")

var options_ingame: Control
var pause_ui_layer: CanvasLayer


func _ready() -> void:
	pause_ui_layer = CanvasLayer.new()
	add_child(pause_ui_layer)

	options_ingame = OPTIONS_INGAME_SCENE.instantiate()
	options_ingame.visible = false
	pause_ui_layer.add_child(options_ingame)

	if options_ingame.has_signal("resume_requested"):
		options_ingame.resume_requested.connect(_on_resume_requested)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _open_pause_menu() -> void:
	options_ingame.visible = true
	get_tree().paused = true


func _on_resume_requested() -> void:
	get_tree().paused = false
	options_ingame.visible = false
