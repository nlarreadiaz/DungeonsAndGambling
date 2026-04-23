extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

const VOLUME_SLIDER_PATH = NodePath("ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/SettingsRows/VolumeRow/VolumeSlider")
const FULL_SCREEN_TOGGLE_PATH = NodePath("ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/SettingsRows/FullScreenRow/FullScreenControl")
const SETTINGS_PANEL_PATH = NodePath("ContentCenter/Layout/SettingsPanel")
const INFO_PANEL_PATH = NodePath("ContentCenter/Layout/InfoPanel")
const BACK_BUTTON_PATH = NodePath("ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/BackArea/Atras")

@onready var volume_slider: HSlider = get_node_or_null(VOLUME_SLIDER_PATH) as HSlider
@onready var full_screen_toggle: CheckButton = get_node_or_null(FULL_SCREEN_TOGGLE_PATH) as CheckButton
@onready var settings_panel: PanelContainer = get_node_or_null(SETTINGS_PANEL_PATH) as PanelContainer
@onready var info_panel: PanelContainer = get_node_or_null(INFO_PANEL_PATH) as PanelContainer
@onready var back_button: TextureButton = get_node_or_null(BACK_BUTTON_PATH) as TextureButton


func _ready() -> void:
	DisplaySettings.configure_window(get_window())

	if volume_slider == null or full_screen_toggle == null:
		push_warning("No se encontraron los controles del menu de opciones.")
		return

	var master_bus = AudioServer.get_bus_index("Master")
	var master_db = AudioServer.get_bus_volume_db(master_bus)
	volume_slider.value = snapped(_db_to_percent(master_db), 1.0)

	full_screen_toggle.set_pressed_no_signal(DisplaySettings.is_fullscreen_enabled())
	if back_button != null:
		back_button.grab_focus()
	_play_intro()


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


func _play_intro() -> void:
	for node in [settings_panel, info_panel]:
		if node != null:
			node.modulate.a = 0.0

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	if settings_panel != null:
		tween.tween_property(settings_panel, "modulate:a", 1.0, 0.24)
	if info_panel != null:
		tween.parallel().tween_property(info_panel, "modulate:a", 1.0, 0.24).set_delay(0.08)
