class_name BattleActionResolver
extends RefCounted

const BASIC_ATTACK_DEFENSE_SCALE = 0.35
const PHYSICAL_ATTACK_BONUS_SCALE = 0.25
const PHYSICAL_DEFENSE_SCALE = 0.25
const MAGIC_LEVEL_BONUS_SCALE = 1.0
const MAGIC_DEFENSE_SCALE = 0.15
const DEFENDING_DAMAGE_MULTIPLIER = 0.5
const HEAL_LEVEL_BONUS_SCALE = 1.5


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

	var target_id = int(target.get("battle_id", -1))
	var target_hp_before = int(target.get("current_hp", 0))
	var calculation = _calculate_basic_attack_damage(attacker, target)
	var dealt = context.apply_damage(target_id, int(calculation.get("final_damage", 1)))
	var updated_target = context.get_actor(target_id)
	var target_hp_after = int(updated_target.get("current_hp", 0))

	var log_lines = ["%s ataca a %s: %d de dano. HP %d -> %d." % [
		str(attacker.get("name", "Actor")),
		str(target.get("name", "Objetivo")),
		dealt,
		target_hp_before,
		target_hp_after
	]]
	if not context.is_actor_alive(target_id):
		log_lines.append("%s ha sido derrotado." % str(target.get("name", "Objetivo")))

	return {
		"success": true,
		"log_lines": log_lines,
		"damage_done": dealt,
		"hp_before": target_hp_before,
		"hp_after": target_hp_after,
		"mana_spent": 0,
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

	var attacker_id = int(attacker.get("battle_id", -1))
	var mana_cost = int(skill.get("mana_cost", 0))
	var mana_before = int(attacker.get("current_mana", 0))
	if mana_before < mana_cost:
		return {
			"success": false,
			"log_lines": ["%s no tiene mana suficiente para %s." % [
				str(attacker.get("name", "Actor")),
				str(skill.get("name", "Habilidad"))
			]],
			"damage_done": 0
		}

	var mana_spent = context.use_mana(attacker_id, mana_cost)
	var updated_attacker = context.get_actor(attacker_id)
	var mana_after = int(updated_attacker.get("current_mana", 0))
	context.set_skill_cooldown(attacker_id, skill.get("skill_id", null), int(skill.get("cooldown_turns", 0)))

	var target_ids = action.get("target_ids", [])
	if target_ids is not Array:
		target_ids = [action.get("target_id", -1)]
	if target_ids.is_empty():
		target_ids = [action.get("target_id", -1)]

	var log_lines: Array = []
	if mana_cost > 0:
		log_lines.append("%s gasta %d MP en %s. MP %d -> %d." % [
			str(attacker.get("name", "Actor")),
			mana_spent,
			str(skill.get("name", "Habilidad")),
			mana_before,
			mana_after
		])

	var total_damage = 0
	var total_heal = 0
	for target_id in target_ids:
		var target = context.get_actor(int(target_id))
		if target.is_empty():
			continue

		if int(skill.get("damage", 0)) < 0:
			var heal_before = int(target.get("current_hp", 0))
			var heal_calculation = _calculate_heal(attacker, abs(int(skill.get("damage", 0))))
			var restored = context.heal_actor(int(target.get("battle_id", -1)), int(heal_calculation.get("final_heal", 1)))
			var healed_target = context.get_actor(int(target.get("battle_id", -1)))
			var heal_after = int(healed_target.get("current_hp", 0))
			total_heal += restored
			log_lines.append("%s usa %s sobre %s: recupera %d HP. HP %d -> %d." % [
				str(attacker.get("name", "Actor")),
				str(skill.get("name", "Habilidad")),
				str(target.get("name", "Objetivo")),
				restored,
				heal_before,
				heal_after
			])
			continue

		var target_hp_before = int(target.get("current_hp", 0))
		var damage_calculation = _calculate_skill_damage(attacker, target, skill)
		var dealt = context.apply_damage(int(target.get("battle_id", -1)), int(damage_calculation.get("final_damage", 1)))
		var damaged_target = context.get_actor(int(target.get("battle_id", -1)))
		var target_hp_after = int(damaged_target.get("current_hp", 0))
		total_damage += dealt
		log_lines.append("%s usa %s sobre %s: %d de dano. HP %d -> %d." % [
			str(attacker.get("name", "Actor")),
			str(skill.get("name", "Habilidad")),
			str(target.get("name", "Objetivo")),
			dealt,
			target_hp_before,
			target_hp_after
		])
		if not context.is_actor_alive(int(target.get("battle_id", -1))):
			log_lines.append("%s ha sido derrotado." % str(target.get("name", "Objetivo")))

	return {
		"success": true,
		"log_lines": log_lines,
		"damage_done": total_damage,
		"heal_done": total_heal,
		"mana_before": mana_before,
		"mana_after": mana_after,
		"mana_spent": mana_spent,
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
		var hp_before = int(target.get("current_hp", 0))
		var restored_hp = context.heal_actor(int(target.get("battle_id", -1)), int(effect_data.get("heal_hp", 0)))
		var healed_target = context.get_actor(int(target.get("battle_id", -1)))
		var hp_after = int(healed_target.get("current_hp", 0))
		total_effect += restored_hp
		log_lines.append("%s usa %s sobre %s: recupera %d HP. HP %d -> %d." % [
			str(user.get("name", "Actor")),
			str(item.get("item_name", "Objeto")),
			str(target.get("name", "Objetivo")),
			restored_hp,
			hp_before,
			hp_after
		])

	if effect_data.has("heal_mp"):
		var mp_before = int(target.get("current_mana", 0))
		var restored_mp = context.restore_mana(int(target.get("battle_id", -1)), int(effect_data.get("heal_mp", 0)))
		var restored_target = context.get_actor(int(target.get("battle_id", -1)))
		var mp_after = int(restored_target.get("current_mana", 0))
		total_effect += restored_mp
		log_lines.append("%s recupera %d MP con %s. MP %d -> %d." % [
			str(target.get("name", "Objetivo")),
			restored_mp,
			str(item.get("item_name", "Objeto")),
			mp_before,
			mp_after
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

	var actor_name = str(actor.get("name", "Actor"))
	context.escaped = true
	context.escaped_actor_name = actor_name

	return {
		"success": true,
		"log_lines": ["%s ha huido del combate." % actor_name],
		"damage_done": 0,
		"skill_id": null,
		"attacker_database_id": actor.get("database_id", null),
		"target_database_id": null
	}


func _calculate_basic_attack_damage(attacker: Dictionary, target: Dictionary) -> Dictionary:
	var base_damage = max(int(attacker.get("attack", 0)), 1)
	var defense_reduction = int(round(float(target.get("defense", 0)) * BASIC_ATTACK_DEFENSE_SCALE))
	return _finalize_damage_calculation(base_damage, 0, defense_reduction, target)


func _calculate_skill_damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> Dictionary:
	var base_damage = max(int(skill.get("damage", 0)), 0)
	var damage_type = str(skill.get("damage_type", "physical"))
	var stat_bonus = 0
	var defense_reduction = 0

	if damage_type == "physical":
		stat_bonus = int(round(float(attacker.get("attack", 0)) * PHYSICAL_ATTACK_BONUS_SCALE))
		defense_reduction = int(round(float(target.get("defense", 0)) * PHYSICAL_DEFENSE_SCALE))
	else:
		stat_bonus = int(round(float(attacker.get("level", 1)) * MAGIC_LEVEL_BONUS_SCALE))
		defense_reduction = int(round(float(target.get("defense", 0)) * MAGIC_DEFENSE_SCALE))

	return _finalize_damage_calculation(base_damage, stat_bonus, defense_reduction, target)


func _finalize_damage_calculation(base_damage: int, stat_bonus: int, defense_reduction: int, target: Dictionary) -> Dictionary:
	var raw_damage = max(base_damage + stat_bonus - defense_reduction, 1)
	var final_damage = raw_damage
	var defending = bool(target.get("defending", false))
	if defending:
		final_damage = max(int(round(float(raw_damage) * DEFENDING_DAMAGE_MULTIPLIER)), 1)

	return {
		"base_damage": base_damage,
		"stat_bonus": stat_bonus,
		"defense_reduction": defense_reduction,
		"defending": defending,
		"final_damage": final_damage
	}


func _calculate_heal(attacker: Dictionary, base_power: int) -> Dictionary:
	var stat_bonus = int(round(float(attacker.get("level", 1)) * HEAL_LEVEL_BONUS_SCALE))
	return {
		"base_heal": base_power,
		"stat_bonus": stat_bonus,
		"final_heal": max(base_power + stat_bonus, 1)
	}


func _resolve_primary_target_database_id(context: BattleContext, target_ids: Array) -> Variant:
	if target_ids.is_empty():
		return null
	var target = context.get_actor(int(target_ids[0]))
	if target.is_empty():
		return null
	return target.get("database_id", null)
