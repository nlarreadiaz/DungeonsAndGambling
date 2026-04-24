extends Node

const BATTLE_SCENE_PATH = "res://Scenes/battle/battle_scene.tscn"

var _active_encounter: Dictionary = {}
var _pending_return_data: Dictionary = {}


func start_battle(encounter_data: Dictionary) -> bool:
	if encounter_data.is_empty():
		push_warning("BattleManager recibio un encounter vacio.")
		return false
	if has_active_encounter():
		return false

	var tree = get_tree()
	if tree == null:
		return false

	var prepared_encounter = encounter_data.duplicate(true)
	prepared_encounter["world_scene_path"] = str(prepared_encounter.get("world_scene_path", ""))
	prepared_encounter["battle_scene_path"] = BATTLE_SCENE_PATH
	_active_encounter = prepared_encounter

	var changed = tree.change_scene_to_file(BATTLE_SCENE_PATH) == OK
	if not changed:
		_active_encounter.clear()
	return changed


func finish_battle(result: Dictionary) -> bool:
	if _active_encounter.is_empty():
		return false

	var world_scene_path = str(_active_encounter.get("world_scene_path", ""))
	if world_scene_path.is_empty():
		return false

	var return_position = result.get("return_player_position", _active_encounter.get("return_player_position", null))
	_pending_return_data = {
		"scene_path": world_scene_path,
		"player_position": return_position,
		"encounter_id": _active_encounter.get("encounter_id", ""),
		"battle_result": result.duplicate(true)
	}

	_active_encounter.clear()
	var tree = get_tree()
	if tree == null:
		return false

	return tree.change_scene_to_file(world_scene_path) == OK


func has_active_encounter() -> bool:
	return not _active_encounter.is_empty()


func get_active_encounter() -> Dictionary:
	return _active_encounter.duplicate(true)


func consume_return_data(scene_path: String) -> Dictionary:
	if _pending_return_data.is_empty():
		return {}
	if str(_pending_return_data.get("scene_path", "")) != scene_path:
		return {}

	var return_data = _pending_return_data.duplicate(true)
	_pending_return_data.clear()
	return return_data
