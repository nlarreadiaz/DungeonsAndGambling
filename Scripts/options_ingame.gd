extends CanvasLayer

const MENU_SCENE = "res://Scenes/menu.tscn"
const VOLUME_SLIDER_PATH = NodePath("Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeSlider")
const FULL_SCREEN_TOGGLE_PATH = NodePath("Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullScreenToggle")
const DisplaySettings = preload("res://Scripts/display_settings.gd")

@onready var volume_slider: HSlider = get_node_or_null(VOLUME_SLIDER_PATH) as HSlider
@onready var full_screen_toggle: CheckButton = get_node_or_null(FULL_SCREEN_TOGGLE_PATH) as CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 12
	DisplaySettings.configure_window(get_window())

	if volume_slider == null or full_screen_toggle == null:
		push_warning("No se encontraron los controles del menu de pausa.")
		return

	var master_bus = AudioServer.get_bus_index("Master")
	var master_db = AudioServer.get_bus_volume_db(master_bus)
	volume_slider.value = snapped(_db_to_percent(master_db), 1.0)

	full_screen_toggle.set_pressed_no_signal(DisplaySettings.is_fullscreen_enabled())


func _input(event: InputEvent) -> void:
	if not _is_pause_event(event):
		return

	get_viewport().set_input_as_handled()
	_on_back_pressed()


func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_volume_db(master_bus, -80.0)
		return

	AudioServer.set_bus_volume_db(master_bus, linear_to_db(value / 100.0))


func _on_full_screen_toggle_toggled(toggled_on: bool) -> void:
	DisplaySettings.set_fullscreen_enabled(get_window(), toggled_on)


func _on_back_pressed() -> void:
	_close_options_overlay()


func _on_menu_pressed() -> void:
	var tree = get_tree()
	if tree == null:
		return

	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)


func _db_to_percent(db: float) -> float:
	if db <= -79.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _close_options_overlay() -> void:
	_set_tree_paused(false)
	queue_free()


func _set_tree_paused(is_paused: bool) -> void:
	var tree = get_tree()
	if tree == null:
		return

	tree.paused = is_paused


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		)

	return false
