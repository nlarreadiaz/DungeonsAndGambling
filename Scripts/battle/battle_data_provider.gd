class_name BattleDataProvider
extends RefCounted

const DEFAULT_PARTY = [
	{
		"database_id": 1,
		"name": "Ariadna",
		"role": "Guerrero",
		"level": 4,
		"current_hp": 145,
		"max_hp": 170,
		"current_mana": 18,
		"max_mana": 25,
		"attack": 22,
		"defense": 15,
		"speed": 9,
		"state": "normal",
		"skills": [
			{
				"skill_id": 1,
				"name": "Golpe Fuerte",
				"description": "Ataque fisico potente.",
				"mana_cost": 0,
				"damage": 24,
				"damage_type": "physical",
				"target_type": "single_enemy",
				"cooldown_turns": 0
			},
			{
				"skill_id": 1002,
				"name": "Estocada Veloz",
				"description": "Ataque rapido con coste bajo de mana.",
				"mana_cost": 4,
				"damage": 18,
				"damage_type": "physical",
				"target_type": "single_enemy",
				"cooldown_turns": 0
			},
			{
				"skill_id": 1003,
				"name": "Tajo Barrido",
				"description": "Golpea a todos los enemigos con un barrido amplio.",
				"mana_cost": 10,
				"damage": 16,
				"damage_type": "physical",
				"target_type": "all_enemies",
				"cooldown_turns": 2
			},
			{
				"skill_id": 1004,
				"name": "Segundo Aliento",
				"description": "Ariadna recupera parte de su vida para seguir luchando.",
				"mana_cost": 8,
				"damage": -26,
				"damage_type": "holy",
				"target_type": "self",
				"cooldown_turns": 2
			},
			{
				"skill_id": 1005,
				"name": "Embate Heroico",
				"description": "Un golpe muy potente contra un solo enemigo.",
				"mana_cost": 12,
				"damage": 34,
				"damage_type": "physical",
				"target_type": "single_enemy",
				"cooldown_turns": 1
			}
		],
		"inventory": [
			{
				"inventory_id": 1,
				"item_id": 1,
				"item_name": "Pocion",
				"description": "Recupera 50 puntos de vida.",
				"item_type": "consumable",
				"quantity": 3,
				"max_stack": 20,
				"usable_in_battle": true,
				"effect_data": {"heal_hp": 50}
			}
		]
	}
]

const EXCLUDED_PARTY_NAMES = ["selene"]

const DEFAULT_ENEMIES = [
	{
		"name": "Reina Oscura",
		"role": "Boss",
		"level": 8,
		"current_hp": 320,
		"max_hp": 320,
		"current_mana": 160,
		"max_mana": 160,
		"attack": 24,
		"defense": 13,
		"speed": 11,
		"state": "normal",
		"experience_reward": 220,
		"gold_reward": 150,
		"skills": [
			{
				"name": "Tajo Sombrio",
				"description": "Ataque oscuro directo.",
				"mana_cost": 10,
				"damage": 34,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"cooldown_turns": 1
			}
		]
	}
]


func build_snapshot(encounter_data: Dictionary) -> Dictionary:
	return {
		"title": str(encounter_data.get("battle_title", "Combate")),
		"subtitle": str(encounter_data.get("battle_subtitle", "Combate por turnos clasico.")),
		"status_message": str(encounter_data.get("status_message", "Se ha iniciado un combate.")),
		"party": _build_party(encounter_data),
		"enemies": _build_enemies(encounter_data)
	}


func _build_party(encounter_data: Dictionary) -> Array:
	var save_slot_id = int(encounter_data.get("save_slot_id", 1))
	var database_party = _load_party_from_database(save_slot_id)
	if not database_party.is_empty():
		return _apply_selected_role_to_party(database_party)
	var selected_role_party = _build_party_from_selected_role()
	if not selected_role_party.is_empty():
		return selected_role_party
	return _normalize_actor_list(DEFAULT_PARTY, "party")


func _build_enemies(encounter_data: Dictionary) -> Array:
	var raw_enemies = encounter_data.get("enemies", DEFAULT_ENEMIES)
	return _normalize_enemy_list(raw_enemies)


func _load_party_from_database(save_slot_id: int) -> Array:
	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("get_characters"):
		return []

	var rows = database_manager.call("get_characters", save_slot_id)
	if rows is not Array:
		return []

	var party: Array = []
	for row in rows:
		if row is not Dictionary:
			continue
		if str(row.get("character_type", "")) != "player":
			continue
		if int(row.get("is_active", 1)) != 1:
			continue
		if _is_party_member_excluded(str(row.get("name", ""))):
			continue

		var character_id = int(row.get("id", 0))
		var inventory = []
		var skills = []
		if database_manager.has_method("get_inventory"):
			inventory = _normalize_inventory(database_manager.call("get_inventory", character_id, save_slot_id))
		if database_manager.has_method("get_character_skills"):
			skills = _normalize_skills(database_manager.call("get_character_skills", character_id, save_slot_id))

		if skills.is_empty():
			skills = _default_skills_for_actor(str(row.get("name", "")), str(row.get("class_name", "")))
		else:
			skills = _merge_signature_skills(str(row.get("name", "")), str(row.get("class_name", "")), skills)
		if inventory.is_empty():
			inventory = _default_inventory_for_role(str(row.get("class_name", "")))

		party.append({
			"database_id": character_id,
			"class_id": int(row.get("class_id", 0)),
			"name": str(row.get("name", "Heroe")),
			"role": str(row.get("class_name", "Aventurero")),
			"level": int(row.get("level", 1)),
			"current_hp": int(row.get("current_hp", 1)),
			"max_hp": int(row.get("max_hp", 1)),
			"current_mana": int(row.get("current_mana", 0)),
			"max_mana": int(row.get("max_mana", 0)),
			"attack": int(row.get("attack", 8)),
			"defense": int(row.get("defense", 4)),
			"speed": int(row.get("speed", 5)),
			"state": str(row.get("current_state", "normal")),
			"skills": skills,
			"inventory": inventory
		})

	return party


func _apply_selected_role_to_party(party: Array) -> Array:
	var role_data = _get_selected_role_data()
	if role_data.is_empty():
		return party

	var updated_party: Array = []
	var role_applied = false
	for actor in party:
		if actor is not Dictionary:
			continue

		var actor_copy: Dictionary = actor.duplicate(true)
		if not role_applied and _is_selected_role_actor(actor_copy):
			actor_copy = _merge_role_data_into_actor(actor_copy, role_data)
			role_applied = true
		updated_party.append(actor_copy)

	return updated_party


func _build_party_from_selected_role() -> Array:
	var role_data = _get_selected_role_data()
	if role_data.is_empty():
		return []

	return [_merge_role_data_into_actor({
		"database_id": 1,
		"name": str(role_data.get("character_name", "Ariadna")),
		"role": str(role_data.get("name", "Aventurero")),
		"level": 1,
		"current_hp": int(role_data.get("current_hp", role_data.get("max_hp", 1))),
		"max_hp": int(role_data.get("max_hp", 1)),
		"current_mana": int(role_data.get("current_mana", role_data.get("max_mana", 0))),
		"max_mana": int(role_data.get("max_mana", 0)),
		"attack": int(role_data.get("attack", 8)),
		"defense": int(role_data.get("defense", 4)),
		"speed": int(role_data.get("speed", 5)),
		"state": "normal",
		"skills": [],
		"inventory": _default_inventory_for_role(str(role_data.get("name", "")))
	}, role_data)]


func _get_selected_role_data() -> Dictionary:
	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("get_selected_player_role_data"):
		return {}

	var role_data = database_manager.call("get_selected_player_role_data")
	if role_data is Dictionary:
		return role_data.duplicate(true)
	return {}


func _is_selected_role_actor(actor: Dictionary) -> bool:
	var expected_name = str(_get_selected_role_data().get("character_name", "Ariadna")).strip_edges().to_lower()
	var actor_name = str(actor.get("name", "")).strip_edges().to_lower()
	if not expected_name.is_empty() and actor_name == expected_name:
		return true
	return int(actor.get("database_id", 0)) == 1


func _merge_role_data_into_actor(actor: Dictionary, role_data: Dictionary) -> Dictionary:
	var actor_copy = actor.duplicate(true)
	var role_name = str(role_data.get("name", actor_copy.get("role", "Aventurero")))
	var selected_class_id = int(role_data.get("class_id", actor_copy.get("class_id", 0)))
	var selected_max_hp = int(role_data.get("max_hp", actor_copy.get("max_hp", 1)))
	var selected_max_mana = int(role_data.get("max_mana", actor_copy.get("max_mana", 0)))
	var actor_already_has_selected_role = (
		int(actor_copy.get("class_id", 0)) == selected_class_id
		or str(actor_copy.get("role", "")).strip_edges().to_lower() == role_name.strip_edges().to_lower()
	)

	actor_copy["name"] = str(role_data.get("character_name", actor_copy.get("name", "Ariadna")))
	actor_copy["role"] = role_name
	actor_copy["class_id"] = selected_class_id
	actor_copy["max_hp"] = selected_max_hp
	actor_copy["current_hp"] = int(role_data.get("current_hp", selected_max_hp))
	if actor_already_has_selected_role:
		actor_copy["current_hp"] = clampi(int(actor.get("current_hp", selected_max_hp)), 0, selected_max_hp)
	actor_copy["max_mana"] = selected_max_mana
	actor_copy["current_mana"] = int(role_data.get("current_mana", selected_max_mana))
	if actor_already_has_selected_role:
		actor_copy["current_mana"] = clampi(int(actor.get("current_mana", selected_max_mana)), 0, selected_max_mana)
	actor_copy["attack"] = int(role_data.get("attack", actor_copy.get("attack", 8)))
	actor_copy["defense"] = int(role_data.get("defense", actor_copy.get("defense", 4)))
	actor_copy["speed"] = int(role_data.get("speed", actor_copy.get("speed", 5)))
	actor_copy["state"] = "normal"
	actor_copy["skills"] = _skills_for_selected_role(role_name)
	if not actor_copy.has("inventory") or actor_copy["inventory"] is not Array or actor_copy["inventory"].is_empty():
		actor_copy["inventory"] = _default_inventory_for_role(role_name)

	return actor_copy


func _skills_for_selected_role(role_name: String) -> Array:
	if role_name.strip_edges().to_lower().contains("guerrero"):
		return _ariadna_signature_skills()
	return _default_skills_for_role(role_name)


func _is_party_member_excluded(actor_name: String) -> bool:
	return EXCLUDED_PARTY_NAMES.has(actor_name.strip_edges().to_lower())


func _normalize_enemy_list(raw_enemies: Variant) -> Array:
	var normalized: Array = []
	if raw_enemies is not Array:
		return normalized

	var database_manager = _get_database_manager()
	for raw_enemy in raw_enemies:
		if raw_enemy is not Dictionary:
			continue

		var enemy = raw_enemy.duplicate(true)
		var enemy_template_id = int(raw_enemy.get("enemy_template_id", 0))
		if enemy_template_id > 0 and database_manager != null and database_manager.has_method("get_enemy_template"):
			var template = database_manager.call("get_enemy_template", enemy_template_id)
			if template is Dictionary and not template.is_empty():
				enemy["name"] = str(enemy.get("name", template.get("name", "Enemigo")))
				enemy["role"] = str(enemy.get("role", "Enemigo"))
				enemy["level"] = int(enemy.get("level", template.get("level", 1)))
				enemy["current_hp"] = int(enemy.get("current_hp", template.get("max_hp", 1)))
				enemy["max_hp"] = int(enemy.get("max_hp", template.get("max_hp", 1)))
				enemy["current_mana"] = int(enemy.get("current_mana", template.get("max_mana", 0)))
				enemy["max_mana"] = int(enemy.get("max_mana", template.get("max_mana", 0)))
				enemy["attack"] = int(enemy.get("attack", template.get("attack", 8)))
				enemy["defense"] = int(enemy.get("defense", template.get("defense", 4)))
				enemy["speed"] = int(enemy.get("speed", template.get("speed", 5)))
				enemy["state"] = str(enemy.get("state", template.get("status_default", "normal")))
				enemy["experience_reward"] = int(enemy.get("experience_reward", template.get("experience_reward", 0)))
				enemy["gold_reward"] = int(enemy.get("gold_reward", template.get("gold_reward", 0)))

		if not enemy.has("skills"):
			enemy["skills"] = _default_enemy_skills(enemy)

		normalized.append({
			"enemy_template_id": enemy.get("enemy_template_id", null),
			"name": str(enemy.get("name", "Enemigo")),
			"role": str(enemy.get("role", "Enemigo")),
			"level": int(enemy.get("level", 1)),
			"current_hp": int(enemy.get("current_hp", enemy.get("max_hp", 1))),
			"max_hp": int(enemy.get("max_hp", 1)),
			"current_mana": int(enemy.get("current_mana", enemy.get("max_mana", 0))),
			"max_mana": int(enemy.get("max_mana", 0)),
			"attack": int(enemy.get("attack", 8)),
			"defense": int(enemy.get("defense", 4)),
			"speed": int(enemy.get("speed", 5)),
			"state": str(enemy.get("state", "normal")),
			"experience_reward": int(enemy.get("experience_reward", 0)),
			"gold_reward": int(enemy.get("gold_reward", 0)),
			"sprite_texture_path": str(enemy.get("sprite_texture_path", "")),
			"sprite_frame_x": int(enemy.get("sprite_frame_x", 0)),
			"sprite_frame_y": int(enemy.get("sprite_frame_y", 0)),
			"sprite_frame_width": int(enemy.get("sprite_frame_width", 0)),
			"sprite_frame_height": int(enemy.get("sprite_frame_height", 0)),
			"sprite_display_width": float(enemy.get("sprite_display_width", 0.0)),
			"sprite_display_height": float(enemy.get("sprite_display_height", 0.0)),
			"sprite_position_x": float(enemy.get("sprite_position_x", 0.0)),
			"sprite_position_y": float(enemy.get("sprite_position_y", 0.0)),
			"sprite_flip_h": bool(enemy.get("sprite_flip_h", false)),
			"always_use_first_skill": bool(enemy.get("always_use_first_skill", false)),
			"skills": _normalize_skills(enemy.get("skills", [])),
			"loot_table": enemy.get("loot_table", [])
		})

	return normalized


func _normalize_actor_list(raw_list: Variant, side: String) -> Array:
	var normalized: Array = []
	if raw_list is not Array:
		return normalized

	for raw_actor in raw_list:
		if raw_actor is not Dictionary:
			continue
		var actor = raw_actor.duplicate(true)
		if side == "enemy":
			normalized.append_array(_normalize_enemy_list([actor]))
			continue
		var actor_name = str(actor.get("name", ""))
		var actor_role = str(actor.get("role", ""))
		actor["skills"] = _merge_signature_skills(
			actor_name,
			actor_role,
			_normalize_skills(actor.get("skills", _default_skills_for_actor(actor_name, actor_role)))
		)
		actor["inventory"] = _normalize_inventory(actor.get("inventory", _default_inventory_for_role(str(actor.get("role", "")))))
		normalized.append(actor)

	return normalized


func _normalize_skills(raw_skills: Variant) -> Array:
	var normalized: Array = []
	if raw_skills is not Array:
		return normalized

	for raw_skill in raw_skills:
		if raw_skill is not Dictionary:
			continue
		normalized.append({
			"skill_id": raw_skill.get("skill_id", null),
			"name": str(raw_skill.get("name", "Habilidad")),
			"description": str(raw_skill.get("description", "")),
			"mana_cost": int(raw_skill.get("mana_cost", 0)),
			"damage": int(raw_skill.get("damage", 0)),
			"damage_type": str(raw_skill.get("damage_type", "physical")),
			"target_type": str(raw_skill.get("target_type", "single_enemy")),
			"cooldown_turns": int(raw_skill.get("cooldown_turns", 0)),
			"cooldown_remaining": int(raw_skill.get("cooldown_remaining", 0))
		})

	return normalized


func _normalize_inventory(raw_inventory: Variant) -> Array:
	var normalized: Array = []
	if raw_inventory is not Array:
		return normalized

	for raw_item in raw_inventory:
		if raw_item is not Dictionary:
			continue

		var effect_data = raw_item.get("effect_data", {})
		if effect_data is String:
			effect_data = JSON.parse_string(effect_data)
		if effect_data == null or effect_data is not Dictionary:
			effect_data = {}

		normalized.append({
			"inventory_id": raw_item.get("inventory_id", raw_item.get("id", null)),
			"item_id": raw_item.get("item_id", null),
			"item_name": str(raw_item.get("item_name", raw_item.get("name", "Objeto"))),
			"description": str(raw_item.get("description", "")),
			"item_type": str(raw_item.get("item_type", "consumable")),
			"rarity": str(raw_item.get("rarity", "common")),
			"slot_index": int(raw_item.get("slot_index", 0)),
			"quantity": int(raw_item.get("quantity", 0)),
			"max_stack": int(raw_item.get("max_stack", 1)),
			"usable_in_battle": bool(raw_item.get("usable_in_battle", true)),
			"effect_data": effect_data
		})

	return normalized


func _default_skills_for_role(role: String) -> Array:
	var role_name = role.to_lower()
	if role_name.contains("mago") or role_name.contains("sanador"):
		return _normalize_skills([
			{
				"name": "Bola de Fuego",
				"description": "Hechizo ofensivo de fuego.",
				"mana_cost": 12,
				"damage": 36,
				"damage_type": "fire",
				"target_type": "single_enemy",
				"cooldown_turns": 1
			},
			{
				"name": "Curacion Menor",
				"description": "Restaura vida a un aliado.",
				"mana_cost": 10,
				"damage": -32,
				"damage_type": "holy",
				"target_type": "single_ally",
				"cooldown_turns": 1
			}
		])
	if role_name.contains("arquero"):
		return _normalize_skills([
			{
				"name": "Disparo Certero",
				"description": "Ataque a distancia muy preciso.",
				"mana_cost": 6,
				"damage": 22,
				"damage_type": "physical",
				"target_type": "single_enemy",
				"cooldown_turns": 0
			}
		])

	return _normalize_skills([
		{
			"name": "Golpe Fuerte",
			"description": "Ataque fisico potente.",
			"mana_cost": 0,
			"damage": 24,
			"damage_type": "physical",
			"target_type": "single_enemy",
			"cooldown_turns": 0
		}
	])


func _default_skills_for_actor(actor_name: String, role: String) -> Array:
	var normalized_name = actor_name.strip_edges().to_lower()
	if normalized_name.contains("ariadna"):
		return _ariadna_signature_skills()
	return _default_skills_for_role(role)


func _merge_signature_skills(actor_name: String, role: String, skills: Array) -> Array:
	var normalized_name = actor_name.strip_edges().to_lower()
	if not normalized_name.contains("ariadna"):
		return skills
	if not role.strip_edges().to_lower().contains("guerrero"):
		if skills.is_empty():
			return _default_skills_for_role(role)
		return skills

	var merged_skills: Array = []
	var known_names: Dictionary = {}
	for skill in skills:
		if skill is not Dictionary:
			continue
		var skill_copy: Dictionary = skill.duplicate(true)
		merged_skills.append(skill_copy)
		known_names[str(skill_copy.get("name", "")).strip_edges().to_lower()] = true

	for signature_skill in _ariadna_signature_skills():
		var signature_name = str(signature_skill.get("name", "")).strip_edges().to_lower()
		if known_names.has(signature_name):
			continue
		merged_skills.append(signature_skill.duplicate(true))

	if merged_skills.is_empty():
		return _default_skills_for_role(role)
	return merged_skills


func _ariadna_signature_skills() -> Array:
	return _normalize_skills([
		{
			"skill_id": 1,
			"name": "Golpe Fuerte",
			"description": "Ataque fisico potente.",
			"mana_cost": 0,
			"damage": 24,
			"damage_type": "physical",
			"target_type": "single_enemy",
			"cooldown_turns": 0
		},
		{
			"skill_id": 1002,
			"name": "Estocada Veloz",
			"description": "Ataque rapido con coste bajo de mana.",
			"mana_cost": 4,
			"damage": 18,
			"damage_type": "physical",
			"target_type": "single_enemy",
			"cooldown_turns": 0
		},
		{
			"skill_id": 1003,
			"name": "Tajo Barrido",
			"description": "Golpea a todos los enemigos con un barrido amplio.",
			"mana_cost": 10,
			"damage": 16,
			"damage_type": "physical",
			"target_type": "all_enemies",
			"cooldown_turns": 2
		},
		{
			"skill_id": 1004,
			"name": "Segundo Aliento",
			"description": "Ariadna recupera parte de su vida para seguir luchando.",
			"mana_cost": 8,
			"damage": -26,
			"damage_type": "holy",
			"target_type": "self",
			"cooldown_turns": 2
		},
		{
			"skill_id": 1005,
			"name": "Embate Heroico",
			"description": "Un golpe muy potente contra un solo enemigo.",
			"mana_cost": 12,
			"damage": 34,
			"damage_type": "physical",
			"target_type": "single_enemy",
			"cooldown_turns": 1
		}
	])


func _default_inventory_for_role(role: String) -> Array:
	var role_name = role.to_lower()
	if role_name.contains("mago") or role_name.contains("sanador"):
		return _normalize_inventory([
			{
				"inventory_id": 902,
				"item_id": 2,
				"item_name": "Eter",
				"description": "Recupera 30 puntos de mana.",
				"item_type": "consumable",
				"quantity": 2,
				"max_stack": 20,
				"usable_in_battle": true,
				"effect_data": {"heal_mp": 30}
			}
		])

	return _normalize_inventory([
		{
			"inventory_id": 901,
			"item_id": 1,
			"item_name": "Pocion",
			"description": "Recupera 50 puntos de vida.",
			"item_type": "consumable",
			"quantity": 3,
			"max_stack": 20,
			"usable_in_battle": true,
			"effect_data": {"heal_hp": 50}
		}
	])


func _default_enemy_skills(enemy: Dictionary) -> Array:
	return _normalize_skills([
		{
			"name": "Ataque salvaje",
			"description": "Golpe directo del enemigo.",
			"mana_cost": 0,
			"damage": max(int(enemy.get("attack", 8)) + 8, 8),
			"damage_type": "physical",
			"target_type": "single_enemy",
			"cooldown_turns": 0
		}
	])


func _get_database_manager() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameDatabase")
