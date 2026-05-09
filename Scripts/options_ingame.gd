extends CanvasLayer

const MENU_SCENE = "res://Scenes/ui/menu.tscn"
const VOLUME_SLIDER_PATH = NodePath("Root/ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/SettingsRows/VolumeRow/VolumeSlider")
const FULL_SCREEN_TOGGLE_PATH = NodePath("Root/ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/SettingsRows/FullScreenRow/FullScreenToggle")
const SETTINGS_PANEL_PATH = NodePath("Root/ContentCenter/Layout/SettingsPanel")
const INFO_PANEL_PATH = NodePath("Root/ContentCenter/Layout/InfoPanel")
const BACK_BUTTON_PATH = NodePath("Root/ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/ButtonsArea/BackButton")
const SAVE_BUTTON_PATH = NodePath("Root/ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/ButtonsArea/SaveButton")
const SAVE_STATUS_LABEL_PATH = NodePath("Root/ContentCenter/Layout/SettingsPanel/MarginContainer/VBoxContainer/ButtonsArea/SaveStatusLabel")
const SAVE_SLOT_ID = 1
const DisplaySettings = preload("res://Scripts/display_settings.gd")

@onready var volume_slider: HSlider = get_node_or_null(VOLUME_SLIDER_PATH) as HSlider
@onready var full_screen_toggle: CheckButton = get_node_or_null(FULL_SCREEN_TOGGLE_PATH) as CheckButton
@onready var settings_panel: PanelContainer = get_node_or_null(SETTINGS_PANEL_PATH) as PanelContainer
@onready var info_panel: PanelContainer = get_node_or_null(INFO_PANEL_PATH) as PanelContainer
@onready var back_button: TextureButton = get_node_or_null(BACK_BUTTON_PATH) as TextureButton
@onready var save_button: TextureButton = get_node_or_null(SAVE_BUTTON_PATH) as TextureButton
@onready var save_status_label: Label = get_node_or_null(SAVE_STATUS_LABEL_PATH) as Label


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
	if back_button != null:
		back_button.grab_focus()
	_play_intro()


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


func _on_save_pressed() -> void:
	if save_button != null:
		save_button.disabled = true
	_set_save_status("Saving...")

	var saved = _stage_current_game_for_save()
	var database_manager = _get_database_manager()
	if saved and database_manager != null and database_manager.has_method("commit_manual_save"):
		saved = bool(database_manager.call("commit_manual_save", SAVE_SLOT_ID))

	if saved:
		_refresh_player_after_save()
		_set_save_status("Saved")
	else:
		_set_save_status("Save failed")

	if save_button != null:
		save_button.disabled = false


func _db_to_percent(db: float) -> float:
	if db <= -79.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _close_options_overlay() -> void:
	_set_tree_paused(false)
	queue_free()


func _set_tree_paused(is_paused: bool) -> void:
	if not is_inside_tree():
		return

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


func _play_intro() -> void:
	for node in [settings_panel, info_panel]:
		if node != null:
			node.modulate.a = 0.0

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	if settings_panel != null:
		tween.tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	if info_panel != null:
		tween.parallel().tween_property(info_panel, "modulate:a", 1.0, 0.2).set_delay(0.06)


func _stage_current_game_for_save() -> bool:
	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("save_basic_game_state"):
		return false

	var game_state = {}
	if database_manager.has_method("get_game_state"):
		game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		game_state = {}

	var important_flags = _parse_flags(game_state.get("important_flags", {}))
	var current_location = str(game_state.get("current_location", "aldea_principal"))

	var tree = get_tree()
	if tree != null and tree.current_scene != null:
		var scene_path = tree.current_scene.scene_file_path
		if not scene_path.is_empty():
			current_location = scene_path.get_file().get_basename()
			important_flags["current_scene_path"] = scene_path

	var player = _find_player_node()
	if player != null:
		if player.has_method("save_inventory_layout"):
			player.call("save_inventory_layout")
		important_flags["player_position"] = {
			"x": player.global_position.x,
			"y": player.global_position.y
		}

	return bool(database_manager.call("save_basic_game_state", SAVE_SLOT_ID, {
		"save_name": str(game_state.get("save_name", "Partida %d" % SAVE_SLOT_ID)),
		"current_location": current_location,
		"gold": int(game_state.get("gold", 0)),
		"main_progress": int(game_state.get("main_progress", 0)),
		"important_flags": important_flags,
		"playtime_seconds": int(game_state.get("playtime_seconds", 0))
	}))


func _refresh_player_after_save() -> void:
	var player = _find_player_node()
	if player != null and player.has_method("sync_inventory_from_database"):
		player.call("sync_inventory_from_database")


func _find_player_node() -> Node2D:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return null

	var direct_player = tree.current_scene.get_node_or_null("player")
	if direct_player is Node2D:
		return direct_player as Node2D

	var found_players = tree.current_scene.find_children("player", "Node2D", true, false)
	if found_players.is_empty():
		return null
	return found_players[0] as Node2D


func _parse_flags(raw_flags: Variant) -> Dictionary:
	if raw_flags is Dictionary:
		return raw_flags.duplicate(true)
	if raw_flags is String:
		var parsed = JSON.parse_string(raw_flags)
		if parsed is Dictionary:
			return parsed.duplicate(true)
	return {}


func _set_save_status(text: String) -> void:
	if save_status_label != null:
		save_status_label.text = text


func _get_database_manager() -> Node:
	return get_node_or_null("/root/GameDatabase")
