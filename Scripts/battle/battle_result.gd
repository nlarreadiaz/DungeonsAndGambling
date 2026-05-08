class_name BattleResult
extends RefCounted

var _rng = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func build_result(context: BattleContext, outcome: String) -> Dictionary:
	var rewards = {
		"experience": 0,
		"gold": 0,
		"loot": []
	}
	if outcome == "victory":
		rewards = _build_victory_rewards(context)

	var summary = _build_summary(context, outcome, rewards)
	return {
		"outcome": outcome,
		"rewards": rewards,
		"summary": summary,
		"player_should_respawn": outcome == "defeat"
	}


func _build_victory_rewards(context: BattleContext) -> Dictionary:
	var rewards = {
		"experience": 0,
		"gold": 0,
		"loot": []
	}

	for enemy in context.enemies:
		rewards["experience"] += _to_int(enemy.get("experience_reward", 0))
		rewards["gold"] += _to_int(enemy.get("gold_reward", 0))
		rewards["loot"] += _roll_enemy_loot(enemy)

	return rewards


func _roll_enemy_loot(enemy: Dictionary) -> Array:
	var loot_results: Array = []
	var raw_loot_table = enemy.get("loot_table", [])
	if raw_loot_table is Array and not raw_loot_table.is_empty():
		for raw_loot in raw_loot_table:
			if raw_loot is not Dictionary:
				continue
			if _rng.randf() > _to_float(raw_loot.get("drop_chance", 0.0)):
				continue
			var quantity = _rng.randi_range(
				_to_int(raw_loot.get("min_quantity", 1), 1),
				_to_int(raw_loot.get("max_quantity", raw_loot.get("min_quantity", 1)), 1)
			)
			loot_results.append({
				"item_id": raw_loot.get("item_id", null),
				"item_name": str(raw_loot.get("item_name", "Objeto")),
				"quantity": quantity
			})
		return loot_results

	var enemy_template_id = _to_int(enemy.get("enemy_template_id", 0))
	if enemy_template_id <= 0:
		return loot_results

	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("get_enemy_loot"):
		return loot_results

	var loot_rows = database_manager.call("get_enemy_loot", enemy_template_id)
	if loot_rows is not Array:
		return loot_results

	for row in loot_rows:
		if row is not Dictionary:
			continue
		if _rng.randf() > _to_float(row.get("drop_chance", 0.0)):
			continue
		var quantity = _rng.randi_range(
			_to_int(row.get("min_quantity", 1), 1),
			_to_int(row.get("max_quantity", row.get("min_quantity", 1)), 1)
		)
		loot_results.append({
			"item_id": row.get("item_id", null),
			"item_name": str(row.get("item_name", "Objeto")),
			"quantity": quantity
		})

	return loot_results


func _build_summary(context: BattleContext, outcome: String, rewards: Dictionary) -> String:
	match outcome:
		"victory":
			var loot_summary = _format_loot(rewards.get("loot", []))
			return "Victoria. EXP +%d, Oro +%d%s" % [
				_to_int(rewards.get("experience", 0)),
				_to_int(rewards.get("gold", 0)),
				loot_summary
			]
		"defeat":
			return "Derrota. El grupo cae en combate."
		"escaped":
			var actor_name = str(context.escaped_actor_name)
			if actor_name.is_empty():
				actor_name = "El jugador"
			return "%s ha huido del combate." % actor_name
		_:
			return "El combate ha terminado."


func _format_loot(loot_entries: Variant) -> String:
	if loot_entries is not Array or loot_entries.is_empty():
		return ""

	var chunks: Array = []
	for entry in loot_entries:
		if entry is not Dictionary:
			continue
		chunks.append("%s x%d" % [
			str(entry.get("item_name", "Objeto")),
			_to_int(entry.get("quantity", 1), 1)
		])

	if chunks.is_empty():
		return ""
	return ", Loot: %s" % ", ".join(chunks)


func _get_database_manager() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameDatabase")


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


func _to_float(value: Variant, default_value: float = 0.0) -> float:
	if value == null:
		return default_value
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	if value is String:
		var text = value.strip_edges()
		if text.is_empty():
			return default_value
		if text.is_valid_float():
			return text.to_float()
	return default_value
