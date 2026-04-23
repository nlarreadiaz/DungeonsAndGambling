extends Control

const MENU_SCENE := "res://Scenes/menu.tscn"

@onready var volume_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeSlider
@onready var full_screen_toggle: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullScreenToggle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var master_bus := AudioServer.get_bus_index("Master")
	var master_db := AudioServer.get_bus_volume_db(master_bus)
	volume_slider.value = snapped(_db_to_percent(master_db), 1.0)

	full_screen_toggle.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func _input(event: InputEvent) -> void:
	if not _is_pause_event(event):
		return

	get_viewport().set_input_as_handled()
	_on_back_pressed()


func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_volume_db(master_bus, -80.0)
		return

	AudioServer.set_bus_volume_db(master_bus, linear_to_db(value / 100.0))


func _on_full_screen_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_back_pressed() -> void:
	_close_options_overlay()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _db_to_percent(db: float) -> float:
	if db <= -79.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _close_options_overlay() -> void:
	get_tree().paused = false
	queue_free()


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		)

	return false
