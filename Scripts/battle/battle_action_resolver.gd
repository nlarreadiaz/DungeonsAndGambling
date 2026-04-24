class_name BattleActionResolver
extends RefCounted

var _rng = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func resolve_action(context: BattleContext, action: Dictionary) -> Dictionary:
	var action_type = str(action.get("type", "attack"))
	match action_type:
		"attack":
			return _resolve_attack(context, action)
		"skill":
			return _resolve_skill(context, action)
		"item":
			return _resolve_item(context, action)
		"defend":
			return _resolve_defend(context, action)
		"flee":
			return _resolve_flee(context, action)
		_:
			return {
				"success": false,
				"log_lines": ["Accion desconocida."],
				"damage_done": 0
			}


func _resolve_attack(context: BattleContext, action: Dictionary) -> Dictionary:
	var attacker = context.get_actor(int(action.get("attacker_id", -1)))
	var target = context.get_actor(int(action.get("target_id", -1)))
	if attacker.is_empty() or target.is_empty():
		return {
			"success": false,
			"log_lines": ["No se encontro el objetivo del ataque."],
			"damage_done": 0
		}

	var base_power = max(int(attacker.get("attack", 0)), 1)
	var damage = _calculate_damage(attacker, target, base_power, "physical")
	var dealt = context.apply_damage(int(target.get("battle_id", -1)), damage)
	var log_lines = ["%s ataca a %s y causa %d de dano." % [
		str(attacker.get("name", "Actor")),
		str(target.get("name", "Objetivo")),
		dealt
	]]
	if not context.is_actor_alive(int(target.get("battle_id", -1))):
		log_lines.append("%s ha sido derrotado." % str(target.get("name", "Objetivo")))

	return {
		"success": true,
		"log_lines": log_lines,
		"damage_done": dealt,
		"skill_id": null,
		"attacker_database_id": attacker.get("database_id", null),
		"target_database_id": target.get("database_id", null)
	}


func _resolve_skill(context: BattleContext, action: Dictionary) -> Dictionary:
	var attacker = context.get_actor(int(action.get("attacker_id", -1)))
	var skill: Dictionary = action.get("skill", {})
	if attacker.is_empty() or skill.is_empty():
		return {
			"success": false,
			"log_lines": ["No se pudo usar la habilidad."],
			"damage_done": 0
		}

	var mana_cost = int(skill.get("mana_cost", 0))
	if int(attacker.get("current_mana", 0)) < mana_cost:
		return {
			"success": false,
			"log_lines": ["%s no tiene mana suficiente para %s." % [
				str(attacker.get("name", "Actor")),
				str(skill.get("name", "Habilidad"))
			]],
			"damage_done": 0
		}

	context.use_mana(int(attacker.get("battle_id", -1)), mana_cost)
	context.set_skill_cooldown(int(attacker.get("battle_id", -1)), skill.get("skill_id", null), int(skill.get("cooldown_turns", 0)))

	var target_ids = action.get("target_ids", [])
	if target_ids is not Array:
		target_ids = [action.get("target_id", -1)]
	if target_ids.is_empty():
		target_ids = [action.get("target_id", -1)]

	var log_lines: Array = []
	var total_damage = 0
	for target_id in target_ids:
		var target = context.get_actor(int(target_id))
		if target.is_empty():
			continue

		if int(skill.get("damage", 0)) < 0:
			var heal_amount = _calculate_heal(attacker, abs(int(skill.get("damage", 0))))
			var restored = context.heal_actor(int(target.get("battle_id", -1)), heal_amount)
			log_lines.append("%s usa %s sobre %s y recupera %d de vida." % [
				str(attacker.get("name", "Actor")),
				str(skill.get("name", "Habilidad")),
				str(target.get("name", "Objetivo")),
				restored
			])
			continue

		var damage = _calculate_damage(attacker, target, int(skill.get("damage", 0)), str(skill.get("damage_type", "physical")))
		var dealt = context.apply_damage(int(target.get("battle_id", -1)), damage)
		total_damage += dealt
		log_lines.append("%s usa %s sobre %s y causa %d de dano." % [
			str(attacker.get("name", "Actor")),
			str(skill.get("name", "Habilidad")),
			str(target.get("name", "Objetivo")),
			dealt
		])
		if not context.is_actor_alive(int(target.get("battle_id", -1))):
			log_lines.append("%s ha sido derrotado." % str(target.get("name", "Objetivo")))

	return {
		"success": true,
		"log_lines": log_lines,
		"damage_done": total_damage,
		"skill_id": skill.get("skill_id", null),
		"attacker_database_id": attacker.get("database_id", null),
		"target_database_id": _resolve_primary_target_database_id(context, target_ids)
	}


func _resolve_item(context: BattleContext, action: Dictionary) -> Dictionary:
	var user = context.get_actor(int(action.get("attacker_id", -1)))
	var target = context.get_actor(int(action.get("target_id", -1)))
	var item: Dictionary = action.get("item", {})
	if user.is_empty() or item.is_empty() or target.is_empty():
		return {
			"success": false,
			"log_lines": ["No se pudo usar el objeto seleccionado."],
			"damage_done": 0
		}

	var effect_data = item.get("effect_data", {})
	if effect_data is String:
		effect_data = JSON.parse_string(effect_data)
	if effect_data == null or effect_data is not Dictionary:
		effect_data = {}

	var log_lines: Array = []
	var total_effect = 0
	if effect_data.has("heal_hp"):
		var restored_hp = context.heal_actor(int(target.get("battle_id", -1)), int(effect_data.get("heal_hp", 0)))
		total_effect += restored_hp
		log_lines.append("%s usa %s sobre %s y recupera %d de vida." % [
			str(user.get("name", "Actor")),
			str(item.get("item_name", "Objeto")),
			str(target.get("name", "Objetivo")),
			restored_hp
		])

	if effect_data.has("heal_mp"):
		var restored_mp = context.restore_mana(int(target.get("battle_id", -1)), int(effect_data.get("heal_mp", 0)))
		total_effect += restored_mp
		log_lines.append("%s recupera %d de mana con %s." % [
			str(target.get("name", "Objetivo")),
			restored_mp,
			str(item.get("item_name", "Objeto"))
		])

	if effect_data.has("cure_status"):
		context.set_actor_state(int(target.get("battle_id", -1)), "normal")
		log_lines.append("%s queda libre del estado alterado gracias a %s." % [
			str(target.get("name", "Objetivo")),
			str(item.get("item_name", "Objeto"))
		])

	if log_lines.is_empty():
		log_lines.append("%s usa %s, pero no ocurre nada." % [
			str(user.get("name", "Actor")),
			str(item.get("item_name", "Objeto"))
		])

	var consume_result = context.consume_inventory_item(int(user.get("battle_id", -1)), item.get("inventory_id", null), 1)
	return {
		"success": true,
		"log_lines": log_lines,
		"damage_done": total_effect,
		"skill_id": null,
		"item_consumed": true,
		"consumed_inventory_id": consume_result.get("inventory_id", null),
		"remaining_quantity": int(consume_result.get("remaining_quantity", 0)),
		"attacker_database_id": user.get("database_id", null),
		"target_database_id": target.get("database_id", null)
	}


func _resolve_defend(context: BattleContext, action: Dictionary) -> Dictionary:
	var actor = context.get_actor(int(action.get("attacker_id", -1)))
	if actor.is_empty():
		return {
			"success": false,
			"log_lines": ["No se pudo activar la defensa."],
			"damage_done": 0
		}

	context.set_defending(int(actor.get("battle_id", -1)), true)
	return {
		"success": true,
		"log_lines": ["%s adopta una postura defensiva." % str(actor.get("name", "Actor"))],
		"damage_done": 0,
		"skill_id": null,
		"attacker_database_id": actor.get("database_id", null),
		"target_database_id": actor.get("database_id", null)
	}


func _resolve_flee(context: BattleContext, action: Dictionary) -> Dictionary:
	var actor = context.get_actor(int(action.get("attacker_id", -1)))
	if actor.is_empty():
		return {
			"success": false,
			"log_lines": ["No se pudo intentar la huida."],
			"damage_done": 0
		}

	var party_speed = _average_speed(context.get_living_actors("party"))
	var enemy_speed = _average_speed(context.get_living_actors("enemy"))
	var chance = clampf(55.0 + float(party_speed - enemy_speed) * 4.0, 20.0, 95.0)
	var success = _rng.randf_range(0.0, 100.0) <= chance
	if success:
		context.escaped = true
		return {
			"success": true,
			"log_lines": ["%s logra escapar del combate." % str(actor.get("name", "Actor"))],
			"damage_done": 0,
			"skill_id": null,
			"attacker_database_id": actor.get("database_id", null),
			"target_database_id": null
		}

	return {
		"success": false,
		"log_lines": ["%s intenta huir, pero falla." % str(actor.get("name", "Actor"))],
		"damage_done": 0,
		"skill_id": null,
		"attacker_database_id": actor.get("database_id", null),
		"target_database_id": null
	}


func _calculate_damage(attacker: Dictionary, target: Dictionary, base_power: int, damage_type: String) -> int:
	var attack_stat = int(attacker.get("attack", 0))
	var defense_stat = int(target.get("defense", 0))
	var variance = _rng.randi_range(-2, 3)
	var damage = base_power + int(round(float(attack_stat) * 0.65)) - int(round(float(defense_stat) * 0.45)) + variance
	if damage_type != "physical":
		damage += int(round(float(attacker.get("level", 1)) * 0.8))
	if bool(target.get("defending", false)):
		damage = int(round(float(damage) * 0.5))
	return max(damage, 1)


func _calculate_heal(attacker: Dictionary, base_power: int) -> int:
	var magic_bonus = int(round(float(attacker.get("level", 1)) * 1.5))
	return max(base_power + magic_bonus, 1)


func _average_speed(actors: Array) -> float:
	if actors.is_empty():
		return 0.0

	var total_speed = 0.0
	for actor in actors:
		total_speed += float(actor.get("speed", 0))
	return total_speed / float(actors.size())


func _resolve_primary_target_database_id(context: BattleContext, target_ids: Array) -> Variant:
	if target_ids.is_empty():
		return null
	var target = context.get_actor(int(target_ids[0]))
	if target.is_empty():
		return null
	return target.get("database_id", null)
