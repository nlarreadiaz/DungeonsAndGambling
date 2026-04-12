extends Node2D

const OPTIONS_INGAME_SCENE := "res://Scenes/options_ingame.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(OPTIONS_INGAME_SCENE)
