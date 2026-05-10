extends Control

const ACTOR_CARD_SCENE: PackedScene = preload("res://Scenes/battle/battle_actor.tscn")
const DATA_PROVIDER_SCRIPT = preload("res://Scripts/battle/battle_data_provider.gd")
const CONTEXT_SCRIPT = preload("res://Scripts/battle/battle_context.gd")
const TURN_QUEUE_SCRIPT = preload("res://Scripts/battle/turn_queue.gd")
const ACTION_RESOLVER_SCRIPT = preload("res://Scripts/battle/battle_action_resolver.gd")
const RESULT_SCRIPT = preload("res://Scripts/battle/battle_result.gd")
const DisplaySettings = preload("res://Scripts/display_settings.gd")
const ENEMY_THINK_DELAY = 0.55
const ACTION_READ_DELAY = 1.45

@onready var battle_ui = $BattleUI

var _data_provider: BattleDataProvider = DATA_PROVIDER_SCRIPT.new()
var _context: BattleContext = CONTEXT_SCRIPT.new()
var _turn_queue: BattleTurnQueue = TURN_QUEUE_SCRIPT.new()
var _action_resolver: BattleActionResolver = ACTION_RESOLVER_SCRIPT.new()
var _result_builder: BattleResult = RESULT_SCRIPT.new()

var _encounter_data: Dictionary = {}
var _state = "boot"
var _current_action: Dictionary = {}
var _pending_result: Dictionary = {}
var _turn_queue_preview: Array = []


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	_connect_ui_signals()
	_encounter_data = _get_encounter_data()
	var snapshot = _data_provider.build_snapshot(_encounter_data)
	_context.setup(_encounter_data, snapshot)
	battle_ui.call("hide_outcome_banner")
	if battle_ui.has_method("set_background_texture_path"):
		battle_ui.call("set_background_texture_path", str(_encounter_data.get("battle_background_path", "")))
	battle_ui.call("set_titles", _context.battle_title, _context.battle_subtitle)
	battle_ui.call("set_hint", "Elige comando y objetivo para resolver el turno.")
	_refresh_battlefield()
	await _begin_battle()


func _unhandled_input(event: InputEvent) -> void:
	if _state != "ended":
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_battle()


func _connect_ui_signals() -> void:
	battle_ui.connect("command_requested", Callable(self, "_on_command_requested"))
	battle_ui.connect("selection_confirmed", Callable(self, "_on_selection_confirmed"))
	battle_ui.connect("selection_back_requested", Callable(self, "_on_selection_back_requested"))


func _begin_battle() -> void:
	_context.add_log("El combate comienza.")
	_context.add_log("La iniciativa se resuelve por velocidad en cada ronda.")
	_refresh_battlefield()
	await _start_next_turn()


func _start_next_turn() -> void:
	if _check_battle_end():
		return

	while true:
		if not _turn_queue.has_next():
			if _context.turn_number > 1:
				_context.round_number += 1
			_turn_queue_preview = _turn_queue.build_queue(_context)
			if _context.round_number > 1:
				_context.add_log("Comienza la ronda %d." % _context.round_number)

		var actor_id = _turn_queue.pop_next()
		if actor_id == -1:
			return
		if not _context.is_actor_alive(actor_id):
			continue

		_context.prepare_actor_turn(actor_id)
		_turn_queue_preview = _turn_queue.peek_queue()
		var actor = _context.get_actor(actor_id)
		_refresh_battlefield()

		if str(actor.get("side", "party")) == "party":
			_begin_player_turn(actor)
		else:
			await _begin_enemy_turn(actor)
		return


func _begin_player_turn(actor: Dictionary) -> void:
	_state = "await_command"
	_current_action.clear()
	var has_skills = not _context.get_available_skills(int(actor.get("battle_id", -1))).is_empty()
	var has_items = not _context.get_usable_items(int(actor.get("battle_id", -1))).is_empty()
	battle_ui.call("set_commands_enabled", true)
	battle_ui.call("set_commands_for_actor", actor, has_skills, has_items, true)
	battle_ui.call("hide_selection")
	_update_turn_info(actor)


func _begin_enemy_turn(actor: Dictionary) -> void:
	_state = "enemy_turn"
	battle_ui.call("set_commands_enabled", false)
	battle_ui.call("hide_selection")
	battle_ui.call("set_status", "Turno de %s..." % str(actor.get("name", "Enemigo")))
	_update_turn_info(actor)
	await get_tree().create_timer(ENEMY_THINK_DELAY).timeout

	var action = _build_enemy_action(actor)
	await _execute_action(action)


func _on_command_requested(command_name: String) -> void:
	if _state != "await_command":
		return

	var actor = _context.get_actor(_context.current_actor_id)
	if actor.is_empty():
		return

	match command_name:
		"attack":
			_current_action = {
				"type": "attack",
				"attacker_id": _context.current_actor_id
			}
			_open_target_selection("Selecciona objetivo", _context.get_living_actors("enemy"))
		"skill":
			_open_skill_selection(actor)
		"item":
			_open_item_selection(actor)
		"defend":
			await _execute_action({
				"type": "defend",
				"attacker_id": _context.current_actor_id
			})
		"flee":
			await _execute_action({
				"type": "flee",
				"attacker_id": _context.current_actor_id
			})


func _on_selection_confirmed(selected_payload: Dictionary) -> void:
	match _state:
		"choose_skill":
			_current_action = {
				"type": "skill",
				"attacker_id": _context.current_actor_id,
				"skill": selected_payload.get("payload", {})
			}
			await _open_targets_for_skill(_current_action["skill"])
		"choose_item":
			_current_action = {
				"type": "item",
				"attacker_id": _context.current_actor_id,
				"item": selected_payload.get("payload", {})
			}
			_open_targets_for_item(_current_action["item"])
		"choose_target":
			_current_action["target_id"] = int(selected_payload.get("battle_id", -1))
			_current_action["target_ids"] = [int(selected_payload.get("battle_id", -1))]
			await _execute_action(_current_action)


func _on_selection_back_requested() -> void:
	match _state:
		"choose_skill", "choose_item", "choose_target":
			_state = "await_command"
			_current_action.clear()
			battle_ui.call("hide_selection")
			var actor = _context.get_actor(_context.current_actor_id)
			if not actor.is_empty():
				_begin_player_turn(actor)


func _open_skill_selection(actor: Dictionary) -> void:
	var available_skills = _context.get_available_skills(int(actor.get("battle_id", -1)))
	if available_skills.is_empty():
		battle_ui.call("set_status", "%s no tiene habilidades disponibles." % str(actor.get("name", "Actor")))
		return

	var entries: Array = []
	for skill in available_skills:
		entries.append({
			"label": str(skill.get("name", "Habilidad")),
			"detail": _format_skill_detail(skill),
			"payload": skill
		})

	_state = "choose_skill"
	battle_ui.call("set_commands_enabled", false)
	battle_ui.call("show_selection", "Habilidades", entries)
	battle_ui.call("set_status", "Selecciona una habilidad.")


func _open_item_selection(actor: Dictionary) -> void:
	var usable_items = _context.get_usable_items(int(actor.get("battle_id", -1)))
	if usable_items.is_empty():
		battle_ui.call("set_status", "%s no tiene objetos usables." % str(actor.get("name", "Actor")))
		return

	var entries: Array = []
	for item in usable_items:
		entries.append({
			"label": "%s x%d" % [str(item.get("item_name", "Objeto")), int(item.get("quantity", 0))],
			"detail": _format_item_detail(item),
			"payload": item
		})

	_state = "choose_item"
	battle_ui.call("set_commands_enabled", false)
	battle_ui.call("show_selection", "Objetos", entries)
	battle_ui.call("set_status", "Selecciona un objeto.")


func _open_targets_for_skill(skill: Dictionary) -> void:
	var target_type = str(skill.get("target_type", "single_enemy"))
	if target_type == "self":
		_current_action["target_id"] = _context.current_actor_id
		_current_action["target_ids"] = [_context.current_actor_id]
		await _execute_action(_current_action)
		return

	var targets = _context.get_living_actors("enemy")
	var title = "Selecciona enemigo"
	if target_type == "single_ally":
		targets = _context.get_living_actors("party")
		title = "Selecciona aliado"
	elif target_type == "all_enemies":
		_current_action["target_ids"] = _extract_actor_ids(_context.get_living_actors("enemy"))
		await _execute_action(_current_action)
		return
	elif target_type == "all_allies":
		_current_action["target_ids"] = _extract_actor_ids(_context.get_living_actors("party"))
		await _execute_action(_current_action)
		return

	_open_target_selection(title, targets)


func _open_targets_for_item(item: Dictionary) -> void:
	var effect_data = item.get("effect_data", {})
	if effect_data is String:
		effect_data = JSON.parse_string(effect_data)
	if effect_data == null or effect_data is not Dictionary:
		effect_data = {}

	var targets = _context.get_living_actors("party")
	var title = "Selecciona objetivo"
	if effect_data.has("heal_hp") or effect_data.has("heal_mp") or effect_data.has("cure_status"):
		title = "Selecciona aliado"
	else:
		targets = [_context.get_actor(_context.current_actor_id)]
		title = "Selecciona usuario"

	_open_target_selection(title, targets)


func _open_target_selection(title: String, raw_targets: Array) -> void:
	var entries: Array = []
	for target in raw_targets:
		if target is not Dictionary:
			continue
		entries.append({
			"label": str(target.get("name", "Objetivo")),
			"detail": "HP %d/%d | MP %d/%d | DEF %d" % [
				int(target.get("current_hp", 0)),
				int(target.get("max_hp", 0)),
				int(target.get("current_mana", 0)),
				int(target.get("max_mana", 0)),
				int(target.get("defense", 0))
			],
			"battle_id": int(target.get("battle_id", -1))
		})

	if entries.is_empty():
		battle_ui.call("set_status", "No hay objetivos validos.")
		var actor = _context.get_actor(_context.current_actor_id)
		if not actor.is_empty():
			_begin_player_turn(actor)
		return

	_state = "choose_target"
	battle_ui.call("set_commands_enabled", false)
	battle_ui.call("show_selection", title, entries)
	battle_ui.call("set_status", title)


func _build_enemy_action(actor: Dictionary) -> Dictionary:
	var available_skills = _context.get_available_skills(int(actor.get("battle_id", -1)))
	if not available_skills.is_empty() and (bool(actor.get("always_use_first_skill", false)) or randf() <= 0.55):
		var chosen_skill: Dictionary = available_skills[0]
		var skill_targets = _resolve_targets_for_target_type(str(chosen_skill.get("target_type", "single_enemy")), str(actor.get("side", "enemy")))
		if not skill_targets.is_empty():
			return {
				"type": "skill",
				"attacker_id": int(actor.get("battle_id", -1)),
				"skill": chosen_skill,
				"target_id": int(skill_targets[0]),
				"target_ids": skill_targets
			}

	var living_party = _context.get_living_actors("party")
	var target = _pick_lowest_hp_target(living_party)
	if target.is_empty():
		return {
			"type": "defend",
			"attacker_id": int(actor.get("battle_id", -1))
		}

	return {
		"type": "attack",
		"attacker_id": int(actor.get("battle_id", -1)),
		"target_id": int(target.get("battle_id", -1)),
		"target_ids": [int(target.get("battle_id", -1))]
	}


func _resolve_targets_for_target_type(target_type: String, side: String) -> Array:
	match target_type:
		"self":
			return [_context.current_actor_id]
		"single_ally":
			return _extract_actor_ids([_pick_lowest_hp_target(_context.get_living_actors(side))])
		"all_allies":
			return _extract_actor_ids(_context.get_living_actors(side))
		"all_enemies":
			var opposite_side = "party"
			if side == "party":
				opposite_side = "enemy"
			return _extract_actor_ids(_context.get_living_actors(opposite_side))
		_:
			var target_side = "party"
			if side == "party":
				target_side = "enemy"
			return _extract_actor_ids([_pick_lowest_hp_target(_context.get_living_actors(target_side))])


func _pick_lowest_hp_target(targets: Array) -> Dictionary:
	var best_target: Dictionary = {}
	var best_ratio = INF
	for target in targets:
		if target is not Dictionary:
			continue
		var max_hp = max(int(target.get("max_hp", 1)), 1)
		var ratio = float(target.get("current_hp", 0)) / float(max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best_target = target
	return best_target


func _execute_action(action: Dictionary) -> void:
	_state = "resolving"
	battle_ui.call("set_commands_enabled", false)
	battle_ui.call("hide_selection")

	await _play_actor_action_animation(
		int(action.get("attacker_id", -1)),
		str(action.get("type", "attack"))
	)

	var result = _action_resolver.resolve_action(_context, action)
	for line in result.get("log_lines", []):
		_context.add_log(str(line))

	_persist_action(result)
	_refresh_battlefield()
	await get_tree().create_timer(ACTION_READ_DELAY).timeout

	if _check_battle_end():
		return

	_context.turn_number += 1
	await _start_next_turn()


func _check_battle_end() -> bool:
	if _context.escaped:
		_finish_battle("escaped")
		return true
	if _context.is_side_defeated("enemy"):
		_finish_battle("victory")
		return true
	if _context.is_side_defeated("party"):
		_finish_battle("defeat")
		return true
	return false


func _finish_battle(outcome: String) -> void:
	if _state == "ended":
		return

	_state = "ended"
	_context.outcome = outcome
	_pending_result = _result_builder.build_result(_context, outcome)
	_apply_battle_persistence(_pending_result)
	var summary = str(_pending_result.get("summary", "El combate ha terminado."))
	var log_lines = _context.get_log_lines()
	if log_lines.is_empty() or str(log_lines[log_lines.size() - 1]) != summary:
		_context.add_log(summary)
	_refresh_battlefield()
	battle_ui.call("set_commands_enabled", false)
	battle_ui.call("hide_selection")
	battle_ui.call("set_status", summary)
	if outcome == "escaped":
		battle_ui.call("hide_outcome_banner")
		battle_ui.call("set_hint", "Volviendo al mapa...")
		_return_to_previous_scene_after_escape()
	elif outcome == "defeat":
		battle_ui.call("show_outcome_banner", "DERROTA", "Regresando al inicio del mapa...")
		battle_ui.call("set_hint", "Regresando al inicio del mapa...")
		_return_to_map_after_defeat()
	else:
		battle_ui.call("show_outcome_banner", "VICTORIA", "Combate completado.")
		battle_ui.call("set_hint", "Volviendo a la aldea...")
		_return_to_map_after_victory()


func _return_to_previous_scene_after_escape() -> void:
	await get_tree().create_timer(0.9).timeout
	if _state != "ended" or _context.outcome != "escaped":
		return
	_leave_battle()


func _return_to_map_after_defeat() -> void:
	await get_tree().create_timer(2.0).timeout
	if _state != "ended" or _context.outcome != "defeat":
		return
	_leave_battle()


func _return_to_map_after_victory() -> void:
	await get_tree().create_timer(1.6).timeout
	if _state != "ended" or _context.outcome != "victory":
		return
	_leave_battle()


func _leave_battle() -> void:
	var battle_manager = get_node_or_null("/root/BattleManager")
	if battle_manager == null:
		return
	battle_manager.call("finish_battle", _pending_result)


func _apply_battle_persistence(result: Dictionary) -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null:
		return

	var save_slot_id = _context.save_slot_id
	for actor in _context.party:
		if actor is not Dictionary:
			continue
		var database_id = actor.get("database_id", null)
		if database_id == null:
			continue
		if database_manager.has_method("update_character_battle_state"):
			database_manager.call(
				"update_character_battle_state",
				_to_int(database_id),
				_to_int(actor.get("current_hp", 0)),
				_to_int(actor.get("current_mana", 0)),
				str(actor.get("state", "normal")),
				save_slot_id
			)

	var game_state = {}
	if database_manager.has_method("get_game_state"):
		game_state = database_manager.call("get_game_state", save_slot_id)
	if game_state == null or game_state is not Dictionary:
		game_state = {}

	var current_gold = _to_int(game_state.get("gold", 0))
	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags == null or important_flags is not Dictionary:
		important_flags = {}

	if str(result.get("outcome", "")) == "victory":
		var rewards: Dictionary = result.get("rewards", {})
		var experience_reward = _to_int(rewards.get("experience", 0))
		var gold_reward = _to_int(rewards.get("gold", 0))
		current_gold += gold_reward
		if database_manager.has_method("add_gold"):
			database_manager.call("add_gold", save_slot_id, gold_reward)

		for actor in _context.party:
			if actor is not Dictionary:
				continue
			var database_id = actor.get("database_id", null)
			if database_id == null:
				continue
			if database_manager.has_method("add_character_experience"):
				database_manager.call("add_character_experience", _to_int(database_id), experience_reward, save_slot_id)

		var loot_entries = rewards.get("loot", [])
		var party_leader = _context.get_party_leader()
		var leader_database_id = party_leader.get("database_id", null)
		if leader_database_id != null:
			for loot_entry in loot_entries:
				if loot_entry is not Dictionary:
					continue
				if database_manager.has_method("add_item_to_inventory"):
					database_manager.call(
						"add_item_to_inventory",
						_to_int(leader_database_id),
						_to_int(loot_entry.get("item_id", 0)),
						_to_int(loot_entry.get("quantity", 1)),
						save_slot_id
					)

		var encounter_id = str(_context.encounter_id)
		if not encounter_id.is_empty():
			var defeated_encounters = important_flags.get("defeated_encounters", {})
			if defeated_encounters is String:
				defeated_encounters = JSON.parse_string(defeated_encounters)
			if defeated_encounters == null or defeated_encounters is not Dictionary:
				defeated_encounters = {}
			defeated_encounters[encounter_id] = true
			important_flags["defeated_encounters"] = defeated_encounters

	if str(result.get("outcome", "")) == "defeat":
		result["return_player_position"] = null

	important_flags["last_battle_outcome"] = str(result.get("outcome", ""))
	important_flags["last_battle_encounter"] = str(_context.encounter_id)
	var world_scene_path = str(_encounter_data.get("world_scene_path", ""))
	var location_name = "aldea_principal"
	if not world_scene_path.is_empty():
		location_name = world_scene_path.get_file().get_basename()

	if database_manager.has_method("save_basic_game_state"):
		database_manager.call("save_basic_game_state", save_slot_id, {
			"save_name": str(game_state.get("save_name", "Partida %d" % save_slot_id)),
			"current_location": location_name,
			"gold": current_gold,
			"main_progress": _to_int(game_state.get("main_progress", 0)),
			"important_flags": important_flags,
			"playtime_seconds": _to_int(game_state.get("playtime_seconds", 0))
		})

	if str(result.get("outcome", "")) == "victory" and database_manager.has_method("commit_manual_save"):
		if not bool(database_manager.call("commit_manual_save", save_slot_id)):
			push_warning("No se pudo autoguardar la victoria del combate.")


func _persist_action(result: Dictionary) -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null:
		return

	if result.get("item_consumed", false):
		var inventory_id = result.get("consumed_inventory_id", null)
		if inventory_id != null and database_manager.has_method("set_inventory_quantity"):
			database_manager.call("set_inventory_quantity", _to_int(inventory_id), _to_int(result.get("remaining_quantity", 0)))

	if database_manager.has_method("log_battle_action"):
		var action_log = " | ".join(result.get("log_lines", []))
		database_manager.call(
			"log_battle_action",
			_context.save_slot_id,
			_context.turn_number,
			result.get("attacker_database_id", null),
			result.get("target_database_id", null),
			result.get("skill_id", null),
			_to_int(result.get("damage_done", 0)),
			action_log
		)


func _to_int(value: Variant, default_value: int = 0) -> int:
	if value == null:
		return default_value
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is bool:
		return 1 if value else 0
	if value is String:
		var text = value.strip_edges()
		if text.is_empty():
			return default_value
		if text.is_valid_int():
			return text.to_int()
		if text.is_valid_float():
			return int(text.to_float())
	return default_value


func _refresh_battlefield() -> void:
	battle_ui.call("set_party_header", "Aliados")
	battle_ui.call("set_enemy_header", "Enemigos")
	battle_ui.call("clear_actor_lists")

	var party_container = battle_ui.call("get_party_container") as Control
	var enemy_container = battle_ui.call("get_enemy_container") as Control
	var party_index = 0
	var enemy_index = 0
	for actor in _context.party:
		_add_actor_card(party_container, actor, party_index)
		party_index += 1
	for actor in _context.enemies:
		_add_actor_card(enemy_container, actor, enemy_index)
		enemy_index += 1

	var current_actor = _context.get_actor(_context.current_actor_id)
	_update_turn_info(current_actor)
	battle_ui.call("set_log_lines", _context.get_log_lines())


func _add_actor_card(container: Control, actor_data: Dictionary, slot_index: int) -> void:
	if container == null:
		return

	var actor_card = ACTOR_CARD_SCENE.instantiate()
	if actor_card == null:
		return

	var actor_copy = actor_data.duplicate(true)
	actor_card.set_meta("battle_id", int(actor_copy.get("battle_id", -1)))
	actor_copy["is_current_turn"] = int(actor_copy.get("battle_id", -1)) == _context.current_actor_id
	actor_copy["battle_slot_index"] = slot_index
	if battle_ui.has_method("get_actor_slot_position"):
		actor_copy["battle_stage_position"] = battle_ui.call(
			"get_actor_slot_position",
			str(actor_copy.get("side", "party")),
			slot_index
		)
	container.add_child(actor_card)
	if actor_card.has_method("apply_actor_data"):
		actor_card.call("apply_actor_data", actor_copy)


func _play_actor_action_animation(attacker_id: int, action_type: String) -> void:
	if action_type == "defend" or action_type == "flee":
		return

	var attacker = _context.get_actor(attacker_id)
	if attacker.is_empty():
		return

	var actor_card = _find_actor_card(attacker_id)
	if actor_card == null or not actor_card.has_method("play_action_animation"):
		return

	await actor_card.call("play_action_animation", action_type)


func _find_actor_card(actor_id: int) -> Node:
	for container in [
		battle_ui.call("get_party_container") as Control,
		battle_ui.call("get_enemy_container") as Control
	]:
		if container == null:
			continue
		for child in container.get_children():
			if int(child.get_meta("battle_id", -1)) == actor_id:
				return child
	return null


func _update_turn_info(actor: Dictionary) -> void:
	var actor_name = "Resolviendo..."
	if not actor.is_empty():
		actor_name = str(actor.get("name", actor_name))
	var queue_text = "Siguientes: %s" % _format_turn_queue(_turn_queue_preview)
	battle_ui.call("set_turn_info", actor_name, _context.round_number, queue_text)


func _format_turn_queue(queue_ids: Array) -> String:
	if queue_ids.is_empty():
		return "-"

	var names: Array = []
	for actor_id in queue_ids:
		var actor = _context.get_actor(int(actor_id))
		if actor.is_empty():
			continue
		names.append(str(actor.get("name", "Actor")))
		if names.size() >= 3:
			break

	if names.is_empty():
		return "-"
	var queue_text = " -> ".join(names)
	if queue_ids.size() > names.size():
		queue_text += " -> ..."
	return queue_text


func _format_skill_detail(skill: Dictionary) -> String:
	var damage = int(skill.get("damage", 0))
	var effect_text = "Dano %d" % damage
	if damage < 0:
		effect_text = "Cura %d" % abs(damage)

	return "%s | MP %d | CD %d | %s" % [
		effect_text,
		int(skill.get("mana_cost", 0)),
		int(skill.get("cooldown_turns", 0)),
		str(skill.get("damage_type", "physical")).capitalize()
	]


func _format_item_detail(item: Dictionary) -> String:
	var effect_data = item.get("effect_data", {})
	if effect_data is String:
		effect_data = JSON.parse_string(effect_data)
	if effect_data == null or effect_data is not Dictionary:
		effect_data = {}

	var details: Array = []
	if effect_data.has("heal_hp"):
		details.append("Cura HP %d" % int(effect_data.get("heal_hp", 0)))
	if effect_data.has("heal_mp"):
		details.append("Restaura MP %d" % int(effect_data.get("heal_mp", 0)))
	if effect_data.has("cure_status"):
		details.append("Cura estado")
	if details.is_empty():
		details.append(str(item.get("description", "Sin efecto de combate")))
	return " | ".join(details)


func _extract_actor_ids(actors: Array) -> Array:
	var ids: Array = []
	for actor in actors:
		if actor is not Dictionary or actor.is_empty():
			continue
		ids.append(int(actor.get("battle_id", -1)))
	return ids


func _get_encounter_data() -> Dictionary:
	var battle_manager = get_node_or_null("/root/BattleManager")
	if battle_manager == null:
		return {}
	if not bool(battle_manager.call("has_active_encounter")):
		return {}
	return battle_manager.call("get_active_encounter")
