extends Node2D

const PLAYER_NODE_PATH = NodePath("player")
const ALDEA_SCENE = "res://Scenes/aldea_principal.tscn"
const INTERACT_ACTION = "interact"

var _player_can_exit = false


func _input(event: InputEvent) -> void:
	if _is_interact_event(event) and _player_can_exit:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_try_exit_herreria()


func _on_exit_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit = true


func _on_exit_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit = false


func _try_exit_herreria() -> bool:
	if not _player_can_exit:
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		return false

	var tree = get_tree()
	if tree == null:
		return false

	return tree.change_scene_to_file(ALDEA_SCENE) == OK


func _is_player_body(body: Node2D) -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	return body != null and player != null and body == player


func _is_interact_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if InputMap.has_action(INTERACT_ACTION) and event.is_action_pressed(INTERACT_ACTION):
			return true
		return key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E

	if InputMap.has_action(INTERACT_ACTION) and event.is_action_pressed(INTERACT_ACTION):
		return true

	return false
