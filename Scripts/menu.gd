extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

@onready var menu_panel: PanelContainer = $ContentCenter/Layout/MenuPanel
@onready var feature_panel: PanelContainer = $ContentCenter/Layout/FeaturePanel
@onready var buttons_area: Control = $ContentCenter/Layout/MenuPanel/MarginContainer/VBoxContainer/ButtonsArea
@onready var play_button: TextureButton = _get_menu_button("PlayButton")
@onready var options_button: TextureButton = _get_menu_button("OptionsButton")
@onready var exit_button: TextureButton = _get_menu_button("ExitButton")
@onready var footer_hint: Label = get_node_or_null("FooterHint") as Label


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
	get_tree().change_scene_to_file("res://Scenes/ui/role_selection.tscn")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/options.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


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
