extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

@onready var volume_slider: HSlider = $ColorRect/VBoxContainer/HBoxContainer/HSlider
@onready var full_screen_toggle: CheckButton = $ColorRect/VBoxContainer/FullScreenControl


func _ready() -> void:
	DisplaySettings.configure_window(get_window())

	var master_bus = AudioServer.get_bus_index("Master")
	var master_db = AudioServer.get_bus_volume_db(master_bus)
	volume_slider.value = snapped(_db_to_percent(master_db), 1.0)

	full_screen_toggle.set_pressed_no_signal(DisplaySettings.is_fullscreen_enabled())


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")


func _on_atras_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")


func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_volume_db(master_bus, -80.0)
		return

	AudioServer.set_bus_volume_db(master_bus, linear_to_db(value / 100.0))


func _db_to_percent(db: float) -> float:
	if db <= -79.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)
