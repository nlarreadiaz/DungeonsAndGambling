class_name BattleContext
extends RefCounted

var encounter_data: Dictionary = {}
var party: Array = []
var enemies: Array = []
var save_slot_id = 1
var encounter_id = ""
var battle_title = ""
var battle_subtitle = ""
var status_message = ""
var current_actor_id = -1
var turn_number = 1
var round_number = 1
var escaped = false
var outcome = ""

var _next_battle_id = 1
var _log_lines: Array = []


func setup(encounter: Dictionary, snapshot: Dictionary) -> void:
	encounter_data = encounter.duplicate(true)
	save_slot_id = int(encounter.get("save_slot_id", 1))
	encounter_id = str(encounter.get("encounter_id", ""))
	battle_title = str(snapshot.get("title", "Combate"))
	battle_subtitle = str(snapshot.get("subtitle", ""))
	status_message = str(snapshot.get("status_message", ""))
	current_actor_id = -1
	turn_number = 1
	round_number = 1
	escaped = false
	outcome = ""
	_next_battle_id = 1
	party = _decorate_actors(snapshot.get("party", []), "party")
	enemies = _decorate_actors(snapshot.get("enemies", []), "enemy")
	_log_lines.clear()
	if not status_message.is_empty():
		add_log(status_message)


func _decorate_actors(raw_actors: Variant, side: String) -> Array:
	var decorated: Array = []
	if raw_actors is not Array:
		return decorated

	for raw_actor in raw_actors:
		if raw_actor is not Dictionary:
			continue

		var skills = _normalize_skills(raw_actor.get("skills", []))
		var inventory = _normalize_inventory(raw_actor.get("inventory", []))
		var actor = {
			"battle_id": _next_battle_id,
			"database_id": raw_actor.get("database_id", null),
			"enemy_template_id": raw_actor.get("enemy_template_id", null),
			"name": str(raw_actor.get("name", "Combatiente")),
			"role": str(raw_actor.get("role", "Unidad")),
			"side": side,
			"level": int(raw_actor.get("level", 1)),
			"current_hp": max(int(raw_actor.get("current_hp", raw_actor.get("max_hp", 1))), 0),
			"max_hp": max(int(raw_actor.get("max_hp", 1)), 1),
			"current_mana": max(int(raw_actor.get("current_mana", raw_actor.get("max_mana", 0))), 0),
			"max_mana": max(int(raw_actor.get("max_mana", 0)), 0),
			"attack": max(int(raw_actor.get("attack", 8)), 0),
			"defense": max(int(raw_actor.get("defense", 4)), 0),
			"speed": max(int(raw_actor.get("speed", 5)), 0),
			"state": str(raw_actor.get("state", "normal")),
			"skills": skills,
			"inventory": inventory,
			"defending": false,
			"experience_reward": max(int(raw_actor.get("experience_reward", 0)), 0),
			"gold_reward": max(int(raw_actor.get("gold_reward", 0)), 0),
			"loot_table": raw_actor.get("loot_table", [])
		}
		_next_battle_id += 1
		decorated.append(actor)

	return decorated


func _normalize_skills(raw_skills: Variant) -> Array:
	var normalized: Array = []
	if raw_skills is not Array:
		return normalized

	for raw_skill in raw_skills:
		if raw_skill is not Dictionary:
			continue

		var skill = raw_skill.duplicate(true)
		skill["skill_id"] = raw_skill.get("skill_id", null)
		skill["name"] = str(raw_skill.get("name", "Habilidad"))
		skill["description"] = str(raw_skill.get("description", ""))
		skill["mana_cost"] = max(int(raw_skill.get("mana_cost", 0)), 0)
		skill["damage"] = int(raw_skill.get("damage", 0))
		skill["damage_type"] = str(raw_skill.get("damage_type", "physical"))
		skill["target_type"] = str(raw_skill.get("target_type", "single_enemy"))
		skill["cooldown_turns"] = max(int(raw_skill.get("cooldown_turns", 0)), 0)
		skill["cooldown_remaining"] = max(int(raw_skill.get("cooldown_remaining", 0)), 0)
		normalized.append(skill)

	return normalized


func _normalize_inventory(raw_inventory: Variant) -> Array:
	var normalized: Array = []
	if raw_inventory is not Array:
		return normalized

	for raw_item in raw_inventory:
		if raw_item is not Dictionary:
			continue

		var item = raw_item.duplicate(true)
		item["inventory_id"] = raw_item.get("inventory_id", raw_item.get("id", null))
		item["item_id"] = raw_item.get("item_id", null)
		item["item_name"] = str(raw_item.get("item_name", raw_item.get("name", "Objeto")))
		item["description"] = str(raw_item.get("description", ""))
		item["item_type"] = str(raw_item.get("item_type", "consumable"))
		item["rarity"] = str(raw_item.get("rarity", "common"))
		item["slot_index"] = int(raw_item.get("slot_index", 0))
		item["quantity"] = max(int(raw_item.get("quantity", 1)), 0)
		item["max_stack"] = max(int(raw_item.get("max_stack", 1)), 1)
		item["usable_in_battle"] = bool(raw_item.get("usable_in_battle", true))
		item["effect_data"] = raw_item.get("effect_data", {})
		normalized.append(item)

	return normalized


func get_actor(actor_id: int) -> Dictionary:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return {}

	var actors: Array = location["actors"]
	return actors[int(location["index"])]


func get_living_actors(side: String = "") -> Array:
	var living: Array = []
	var sides: Array = []
	if side.is_empty():
		sides = ["party", "enemy"]
	else:
		sides = [side]
	for actor_side in sides:
		for actor in _get_actor_array(actor_side):
			if int(actor.get("current_hp", 0)) <= 0:
				continue
			living.append(actor)
	return living


func is_actor_alive(actor_id: int) -> bool:
	var actor = get_actor(actor_id)
	if actor.is_empty():
		return false
	return int(actor.get("current_hp", 0)) > 0


func is_side_defeated(side: String) -> bool:
	return get_living_actors(side).is_empty()


func prepare_actor_turn(actor_id: int) -> void:
	clear_defending(actor_id)
	_decrement_skill_cooldowns(actor_id)
	current_actor_id = actor_id


func apply_damage(actor_id: int, amount: int) -> int:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return 0

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var current_hp = int(actor.get("current_hp", 0))
	var actual_damage = mini(max(amount, 0), current_hp)
	actor["current_hp"] = current_hp - actual_damage
	if int(actor["current_hp"]) <= 0:
		actor["current_hp"] = 0
		actor["state"] = "defeated"
		actor["defending"] = false
	actors[index] = actor
	_assign_actor_array(location["side"], actors)
	return actual_damage


func heal_actor(actor_id: int, amount: int) -> int:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return 0

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var current_hp = int(actor.get("current_hp", 0))
	var max_hp = int(actor.get("max_hp", 1))
	var actual_heal = clamp(amount, 0, max_hp - current_hp)
	actor["current_hp"] = current_hp + actual_heal
	if int(actor["current_hp"]) > 0 and str(actor.get("state", "normal")) == "defeated":
		actor["state"] = "normal"
	actors[index] = actor
	_assign_actor_array(location["side"], actors)
	return actual_heal


func use_mana(actor_id: int, amount: int) -> int:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return 0

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var current_mana = int(actor.get("current_mana", 0))
	var actual_cost = mini(max(amount, 0), current_mana)
	actor["current_mana"] = current_mana - actual_cost
	actors[index] = actor
	_assign_actor_array(location["side"], actors)
	return actual_cost


func restore_mana(actor_id: int, amount: int) -> int:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return 0

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var current_mana = int(actor.get("current_mana", 0))
	var max_mana = int(actor.get("max_mana", 0))
	var restored = clamp(amount, 0, max_mana - current_mana)
	actor["current_mana"] = current_mana + restored
	actors[index] = actor
	_assign_actor_array(location["side"], actors)
	return restored


func set_defending(actor_id: int, value: bool) -> void:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	actor["defending"] = value
	actors[index] = actor
	_assign_actor_array(location["side"], actors)


func clear_defending(actor_id: int) -> void:
	set_defending(actor_id, false)


func set_actor_state(actor_id: int, new_state: String) -> void:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	actor["state"] = new_state
	actors[index] = actor
	_assign_actor_array(location["side"], actors)


func set_skill_cooldown(actor_id: int, skill_id: Variant, cooldown_turns: int) -> void:
	if skill_id == null:
		return

	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var skills: Array = actor.get("skills", [])
	for skill_index in range(skills.size()):
		var skill: Dictionary = skills[skill_index]
		if skill.get("skill_id", null) != skill_id:
			continue
		skill["cooldown_remaining"] = max(cooldown_turns, 0)
		skills[skill_index] = skill
		break
	actor["skills"] = skills
	actors[index] = actor
	_assign_actor_array(location["side"], actors)


func get_available_skills(actor_id: int) -> Array:
	var actor = get_actor(actor_id)
	if actor.is_empty():
		return []

	var available: Array = []
	var skills: Array = actor.get("skills", [])
	var current_mana = int(actor.get("current_mana", 0))
	for skill in skills:
		if int(skill.get("cooldown_remaining", 0)) > 0:
			continue
		if int(skill.get("mana_cost", 0)) > current_mana:
			continue
		available.append(skill)
	return available


func get_usable_items(actor_id: int) -> Array:
	var actor = get_actor(actor_id)
	if actor.is_empty():
		return []

	var usable: Array = []
	var inventory: Array = actor.get("inventory", [])
	for item in inventory:
		if int(item.get("quantity", 0)) <= 0:
			continue
		if not bool(item.get("usable_in_battle", false)):
			continue
		usable.append(item)
	return usable


func consume_inventory_item(actor_id: int, inventory_id: Variant, amount: int = 1) -> Dictionary:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return {}

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var inventory: Array = actor.get("inventory", [])
	for item_index in range(inventory.size()):
		var item: Dictionary = inventory[item_index]
		if item.get("inventory_id", null) != inventory_id:
			continue

		var current_quantity = int(item.get("quantity", 0))
		var new_quantity = max(current_quantity - max(amount, 1), 0)
		item["quantity"] = new_quantity
		inventory[item_index] = item
		actor["inventory"] = inventory
		actors[index] = actor
		_assign_actor_array(location["side"], actors)
		return {
			"inventory_id": inventory_id,
			"remaining_quantity": new_quantity
		}

	return {}


func get_party_leader() -> Dictionary:
	var living_party = get_living_actors("party")
	if not living_party.is_empty():
		return living_party[0]
	if not party.is_empty():
		return party[0]
	return {}


func add_log(message: String) -> void:
	if message.is_empty():
		return

	_log_lines.append(message)
	while _log_lines.size() > 12:
		_log_lines.remove_at(0)


func get_log_lines() -> Array:
	return _log_lines.duplicate(true)


func _decrement_skill_cooldowns(actor_id: int) -> void:
	var location = _find_actor_location(actor_id)
	if location.is_empty():
		return

	var actors: Array = location["actors"]
	var index = int(location["index"])
	var actor: Dictionary = actors[index]
	var skills: Array = actor.get("skills", [])
	for skill_index in range(skills.size()):
		var skill: Dictionary = skills[skill_index]
		var current_cooldown = int(skill.get("cooldown_remaining", 0))
		if current_cooldown <= 0:
			continue
		skill["cooldown_remaining"] = current_cooldown - 1
		skills[skill_index] = skill
	actor["skills"] = skills
	actors[index] = actor
	_assign_actor_array(location["side"], actors)


func _find_actor_location(actor_id: int) -> Dictionary:
	for actor_side in ["party", "enemy"]:
		var actors = _get_actor_array(actor_side)
		for index in range(actors.size()):
			var actor: Dictionary = actors[index]
			if int(actor.get("battle_id", -1)) != actor_id:
				continue
			return {
				"side": actor_side,
				"index": index,
				"actors": actors
			}
	return {}


func _get_actor_array(side: String) -> Array:
	if side == "party":
		return party
	return enemies


func _assign_actor_array(side: String, actors: Array) -> void:
	if side == "party":
		party = actors
	else:
		enemies = actors
