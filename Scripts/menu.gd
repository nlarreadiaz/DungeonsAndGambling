extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

@onready var menu_panel: PanelContainer = $ContentCenter/Layout/MenuPanel
@onready var feature_panel: PanelContainer = $ContentCenter/Layout/FeaturePanel
@onready var play_button: TextureButton = $ContentCenter/Layout/MenuPanel/MarginContainer/VBoxContainer/ButtonsArea/PlayButton
@onready var options_button: TextureButton = $ContentCenter/Layout/MenuPanel/MarginContainer/VBoxContainer/ButtonsArea/OptionsButton
@onready var exit_button: TextureButton = $ContentCenter/Layout/MenuPanel/MarginContainer/VBoxContainer/ButtonsArea/ExitButton
@onready var footer_hint: Label = $FooterHint


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	_prepare_intro_state()
	play_button.grab_focus()
	_play_intro()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/aldea_principal.tscn")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/options.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _prepare_intro_state() -> void:
	for node in [menu_panel, feature_panel, play_button, options_button, exit_button, footer_hint]:
		node.modulate.a = 0.0


func _play_intro() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.28)
	tween.parallel().tween_property(feature_panel, "modulate:a", 1.0, 0.28).set_delay(0.08)
	tween.parallel().tween_property(play_button, "modulate:a", 1.0, 0.22).set_delay(0.12)
	tween.parallel().tween_property(options_button, "modulate:a", 1.0, 0.22).set_delay(0.18)
	tween.parallel().tween_property(exit_button, "modulate:a", 1.0, 0.22).set_delay(0.24)
	tween.parallel().tween_property(footer_hint, "modulate:a", 1.0, 0.28).set_delay(0.28)
