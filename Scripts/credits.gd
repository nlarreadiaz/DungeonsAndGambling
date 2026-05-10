extends Control

const MAIN_MENU_SCENE = "res://Scenes/ui/menu.tscn"


func _ready() -> void:
	var return_button = get_node_or_null("Content/ReturnButton") as Button
	if return_button != null:
		return_button.pressed.connect(_return_to_menu)
		return_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()


func _return_to_menu() -> void:
	var tree = get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(MAIN_MENU_SCENE)
