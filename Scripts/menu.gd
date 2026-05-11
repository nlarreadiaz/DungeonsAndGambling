extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

const SAVE_SLOT_ID = 1
const ROLE_SELECTION_SCENE = "res://Scenes/ui/role_selection.tscn"
const ALDEA_PRINCIPAL_SCENE = "res://Scenes/world/aldea_principal.tscn"
const DUNGEON_AGUA_SCENE = "res://Scenes/dungeonAgua.tscn"

@onready var menu_panel: PanelContainer = $ContentCenter/Layout/MenuPanel
@onready var feature_panel: PanelContainer = $ContentCenter/Layout/FeaturePanel
@onready var buttons_area: Control = $ContentCenter/Layout/MenuPanel/MarginContainer/VBoxContainer/ButtonsArea
@onready var play_button: TextureButton = _get_menu_button("PlayButton")
@onready var options_button: TextureButton = _get_menu_button("OptionsButton")
@onready var exit_button: TextureButton = _get_menu_button("ExitButton")
@onready var footer_hint: Label = get_node_or_null("FooterHint") as Label

var _continue_dialog: Control = null


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	_prepare_intro_state()
	if play_button != null:
		play_button.grab_focus()
	_play_intro()


func _get_menu_button(primary_name: String, fallback_name: String = "") -> TextureButton:
	if buttons_area == null:
		return null

	var button = buttons_area.get_node_or_null(primary_name) as TextureButton
	if button != null:
		return button

	if fallback_name != "":
		return buttons_area.get_node_or_null(fallback_name) as TextureButton

	return null


func _on_play_pressed() -> void:
	if _has_started_save():
		_show_continue_dialog()
		return

	_start_role_selection()


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/options.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_continue_dialog() -> void:
	if _continue_dialog == null:
		_continue_dialog = _build_continue_dialog()
		add_child(_continue_dialog)

	_continue_dialog.visible = true
	var continue_button = _continue_dialog.get_node_or_null("Panel/Margin/Layout/Buttons/ContinueButton") as Button
	if continue_button != null:
		continue_button.grab_focus()


func _build_continue_dialog() -> Control:
	var overlay = Control.new()
	overlay.name = "ContinueDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.48)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 112)
	panel.offset_left = -150
	panel.offset_top = -56
	panel.offset_right = 150
	panel.offset_bottom = 56
	overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "Partida guardada"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	layout.add_child(title)

	var text = Label.new()
	text.text = "Continuar donde lo dejaste o empezar una partida nueva."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 8)
	layout.add_child(text)

	var buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)

	var new_button = Button.new()
	new_button.name = "NewGameButton"
	new_button.text = "Nueva"
	new_button.custom_minimum_size = Vector2(78, 24)
	new_button.pressed.connect(_on_new_game_from_dialog)
	buttons.add_child(new_button)

	var continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continuar"
	continue_button.custom_minimum_size = Vector2(92, 24)
	continue_button.pressed.connect(_on_continue_from_dialog)
	buttons.add_child(continue_button)

	return overlay


func _on_continue_from_dialog() -> void:
	if _continue_dialog != null:
		_continue_dialog.visible = false
	_continue_saved_game()


func _on_new_game_from_dialog() -> void:
	if _continue_dialog != null:
		_continue_dialog.visible = false
	_start_new_game()


func _continue_saved_game() -> void:
	var game_state = _get_saved_game_state()
	var important_flags = _get_important_flags(game_state)
	var location_name = str(important_flags.get(
		"current_scene_path",
		important_flags.get("autosave_scene_path", game_state.get("current_location", "aldea_principal"))
	))
	get_tree().change_scene_to_file(_get_scene_path_for_location(location_name))


func _start_new_game() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager != null and database_manager.has_method("reset_game"):
		database_manager.call("reset_game", SAVE_SLOT_ID)
	_start_role_selection()


func _start_role_selection() -> void:
	get_tree().change_scene_to_file(ROLE_SELECTION_SCENE)


func _has_started_save() -> bool:
	var game_state = _get_saved_game_state()
	if game_state.is_empty():
		return false

	var important_flags = _get_important_flags(game_state)
	return (
		bool(important_flags.get("game_started", false))
		or important_flags.has("player_position")
		or important_flags.has("autosave_position")
	)


func _get_saved_game_state() -> Dictionary:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_game_state"):
		return {}

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is Dictionary:
		return game_state
	return {}


func _get_important_flags(game_state: Dictionary) -> Dictionary:
	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags is Dictionary:
		return important_flags
	return {}


func _get_scene_path_for_location(location_name: String) -> String:
	if location_name.begins_with("res://"):
		return location_name

	match location_name:
		"dungeonAgua", "dungeon_agua":
			return DUNGEON_AGUA_SCENE
		_:
			return ALDEA_PRINCIPAL_SCENE


func _prepare_intro_state() -> void:
	for node in [menu_panel, feature_panel, play_button, options_button, exit_button, footer_hint]:
		if node != null:
			node.modulate.a = 0.0


func _play_intro() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	_tween_node_alpha(tween, menu_panel, 1.0, 0.28, 0.0)
	_tween_node_alpha(tween, feature_panel, 1.0, 0.28, 0.08)
	_tween_node_alpha(tween, play_button, 1.0, 0.22, 0.12)
	_tween_node_alpha(tween, options_button, 1.0, 0.22, 0.20)
	_tween_node_alpha(tween, exit_button, 1.0, 0.22, 0.28)
	_tween_node_alpha(tween, footer_hint, 1.0, 0.28, 0.32)


func _tween_node_alpha(tween: Tween, node: CanvasItem, alpha: float, duration: float, delay: float) -> void:
	if node == null:
		return

	tween.parallel().tween_property(node, "modulate:a", alpha, duration).set_delay(delay)
