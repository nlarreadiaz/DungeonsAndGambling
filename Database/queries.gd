class_name DatabaseQueries
extends RefCounted

# Encapsula todas las consultas SQL del juego para mantener
# la logica de persistencia fuera de UI, jugador y combate.

var _database: Object = null


func bind_database(database: Object) -> void:
	_database = database


func clear_database() -> void:
	_database = null


func is_ready() -> bool:
	return _database != null


func execute(sql: String, bindings: Array = []) -> bool:
	if _database == null:
		push_error("DatabaseQueries no tiene una conexion SQLite activa.")
		return false

	if bindings.is_empty():
		return bool(_database.call("query", sql))

	return bool(_database.call("query_with_bindings", sql, bindings))


func select_rows(sql: String, bindings: Array = []) -> Array:
	if not execute(sql, bindings):
		return []

	var result = _database.get("query_result")
	if result is Array:
		return result.duplicate(true)
	return []


func get_last_insert_rowid() -> int:
	if _database == null:
		return 0
	return int(_database.get("last_insert_rowid"))


func insert_row(table_name: String, values: Dictionary) -> int:
	if values.is_empty():
		return -1

	var column_names: Array = []
	var placeholders: Array = []
	var bindings: Array = []
	for key in values.keys():
		column_names.append(_quote_identifier(str(key)))
		placeholders.append("?")
		bindings.append(values[key])

	var sql = "INSERT INTO %s (%s) VALUES (%s);" % [
		_quote_identifier(table_name),
		", ".join(column_names),
		", ".join(placeholders)
	]
	if not execute(sql, bindings):
		return -1

	return get_last_insert_rowid()


func create_character(character_data: Dictionary) -> int:
	var values = {
		"save_slot_id": int(character_data.get("save_slot_id", 1)),
		"class_id": character_data.get("class_id", null),
		"enemy_template_id": character_data.get("enemy_template_id", null),
		"name": str(character_data.get("name", "Nuevo personaje")),
		"character_type": str(character_data.get("character_type", "player")),
		"level": int(character_data.get("level", 1)),
		"experience": int(character_data.get("experience", 0)),
		"max_hp": int(character_data.get("max_hp", 100)),
		"current_hp": int(character_data.get("current_hp", character_data.get("max_hp", 100))),
		"max_mana": int(character_data.get("max_mana", 0)),
		"current_mana": int(character_data.get("current_mana", character_data.get("max_mana", 0))),
		"attack": int(character_data.get("attack", 10)),
		"defense": int(character_data.get("defense", 5)),
		"speed": int(character_data.get("speed", 5)),
		"current_state": str(character_data.get("current_state", "normal")),
		"is_active": int(character_data.get("is_active", 1))
	}
	return insert_row("characters", values)


func get_all_characters(save_slot_id: int = 1) -> Array:
	var sql = """
		SELECT
			c.id,
			c.class_id,
			c.name,
			c.character_type,
			c.level,
			c.experience,
			c.max_hp,
			c.current_hp,
			c.max_mana,
			c.current_mana,
			c.attack,
			c.defense,
			c.speed,
			c.current_state,
			c.is_active,
			cl.name AS class_name,
			e.name AS enemy_template_name
		FROM characters c
		LEFT JOIN classes cl ON cl.id = c.class_id
		LEFT JOIN enemies e ON e.id = c.enemy_template_id
		WHERE c.save_slot_id = ?
		ORDER BY c.id;
	"""
	return select_rows(sql, [save_slot_id])


func get_classes() -> Array:
	var sql = """
		SELECT
			id,
			name,
			description,
			role,
			base_max_hp,
			base_max_mana,
			base_attack,
			base_defense,
			base_speed
		FROM classes
		ORDER BY id;
	"""
	return select_rows(sql)


func get_inventory(character_id: int, save_slot_id: int = 1) -> Array:
	var sql = """
		SELECT
			i.id,
			i.slot_index,
			i.quantity,
			it.id AS item_id,
			it.name AS item_name,
			it.description,
			it.item_type,
			it.rarity,
			it.price,
			it.icon,
			it.max_stack,
			it.usable_in_battle,
			it.effect_data
		FROM inventory i
		INNER JOIN items it ON it.id = i.item_id
		WHERE i.save_slot_id = ? AND i.character_id = ?
		ORDER BY i.slot_index;
	"""
	return select_rows(sql, [save_slot_id, character_id])


func get_item_by_name(item_name: String) -> Dictionary:
	var rows = select_rows(
		"""
			SELECT
				id,
				name,
				description,
				item_type,
				rarity,
				price,
				icon,
				max_stack,
				usable_in_battle,
				effect_data
			FROM items
			WHERE name = ?
			LIMIT 1;
		""",
		[item_name]
	)
	if rows.is_empty():
		return {}
	return rows[0].duplicate(true)


func update_item_by_name(item_name: String, values: Dictionary) -> bool:
	var allowed_columns = [
		"description",
		"item_type",
		"rarity",
		"price",
		"icon",
		"max_stack",
		"usable_in_battle",
		"effect_data"
	]
	var assignments: Array = []
	var bindings: Array = []
	for column_name in allowed_columns:
		if not values.has(column_name):
			continue
		assignments.append("%s = ?" % _quote_identifier(column_name))
		bindings.append(values[column_name])

	if assignments.is_empty():
		return false

	bindings.append(item_name)
	return execute(
		"UPDATE items SET %s WHERE name = ?;" % ", ".join(assignments),
		bindings
	)


func get_character_skills(character_id: int, save_slot_id: int = 1) -> Array:
	var sql = """
		SELECT
			cs.id AS relation_id,
			cs.character_id,
			cs.skill_id,
			cs.learned_at_level,
			cs.cooldown_remaining,
			s.name,
			s.description,
			s.mana_cost,
			s.damage,
			s.damage_type,
			s.target_type,
			s.cooldown_turns
		FROM character_skills cs
		INNER JOIN skills s ON s.id = cs.skill_id
		WHERE cs.save_slot_id = ? AND cs.character_id = ?
		ORDER BY cs.skill_id;
	"""
	return select_rows(sql, [save_slot_id, character_id])


func get_enemy_template(enemy_id: int) -> Dictionary:
	var rows = select_rows(
		"""
			SELECT
				id,
				name,
				description,
				level,
				max_hp,
				max_mana,
				attack,
				defense,
				speed,
				status_default,
				experience_reward,
				gold_reward
			FROM enemies
			WHERE id = ?
			LIMIT 1;
		""",
		[enemy_id]
	)
	if rows.is_empty():
		return {}
	return rows[0].duplicate(true)


func get_enemy_loot(enemy_id: int) -> Array:
	var sql = """
		SELECT
			el.enemy_id,
			el.item_id,
			el.drop_chance,
			el.min_quantity,
			el.max_quantity,
			it.name AS item_name,
			it.item_type,
			it.rarity,
			it.effect_data,
			it.max_stack
		FROM enemy_loot el
		INNER JOIN items it ON it.id = el.item_id
		WHERE el.enemy_id = ?
		ORDER BY el.item_id;
	"""
	return select_rows(sql, [enemy_id])


func get_game_state(save_slot_id: int = 1) -> Dictionary:
	var rows = select_rows(
		"""
			SELECT
				gs.id,
				gs.save_slot_id,
				gs.gold,
				gs.current_location,
				gs.main_progress,
				gs.important_flags,
				gs.updated_at,
				ss.save_name,
				ss.playtime_seconds,
				ss.saved_at
			FROM game_state gs
			LEFT JOIN save_slots ss ON ss.id = gs.save_slot_id
			WHERE gs.save_slot_id = ?
			LIMIT 1;
		""",
		[save_slot_id]
	)
	if rows.is_empty():
		return {}
	return rows[0].duplicate(true)


func add_item_to_inventory(character_id: int, item_id: int, quantity: int = 1, save_slot_id: int = 1) -> bool:
	if quantity <= 0:
		return false

	var item_rows = select_rows("SELECT max_stack FROM items WHERE id = ? LIMIT 1;", [item_id])
	if item_rows.is_empty():
		push_warning("No existe el item %d en la base de datos." % item_id)
		return false

	var max_stack = int(item_rows[0].get("max_stack", 1))
	var remaining = quantity
	var partial_stacks = select_rows(
		"""
			SELECT id, quantity
			FROM inventory
			WHERE save_slot_id = ? AND character_id = ? AND item_id = ? AND quantity < ?
			ORDER BY slot_index;
		""",
		[save_slot_id, character_id, item_id, max_stack]
	)

	for stack in partial_stacks:
		var stack_id = int(stack.get("id", 0))
		var current_quantity = int(stack.get("quantity", 0))
		var free_space = max_stack - current_quantity
		if free_space <= 0:
			continue

		var amount_to_add = mini(free_space, remaining)
		if not execute("UPDATE inventory SET quantity = quantity + ? WHERE id = ?;", [amount_to_add, stack_id]):
			return false

		remaining -= amount_to_add
		if remaining <= 0:
			return true

	while remaining > 0:
		var slot_index = _find_next_inventory_slot(character_id, save_slot_id)
		var amount_to_insert = mini(remaining, max_stack)
		var row_id = insert_row("inventory", {
			"save_slot_id": save_slot_id,
			"character_id": character_id,
			"item_id": item_id,
			"quantity": amount_to_insert,
			"slot_index": slot_index
		})
		if row_id == -1:
			return false
		remaining -= amount_to_insert

	return true


func set_inventory_quantity(inventory_id: int, quantity: int) -> bool:
	if quantity <= 0:
		return execute("DELETE FROM inventory WHERE id = ?;", [inventory_id])
	return execute("UPDATE inventory SET quantity = ? WHERE id = ?;", [quantity, inventory_id])


func replace_inventory(character_id: int, save_slot_id: int, slot_entries: Array) -> bool:
	if character_id <= 0:
		return false

	if not execute("BEGIN TRANSACTION;"):
		return false

	if not execute("DELETE FROM inventory WHERE save_slot_id = ? AND character_id = ?;", [save_slot_id, character_id]):
		execute("ROLLBACK;")
		return false

	for raw_entry in slot_entries:
		if raw_entry is not Dictionary:
			continue

		var item_id = int(raw_entry.get("item_id", 0))
		var quantity = int(raw_entry.get("quantity", 0))
		var slot_index = int(raw_entry.get("slot_index", -1))
		if item_id <= 0 or quantity <= 0 or slot_index < 0:
			continue

		var row_id = insert_row("inventory", {
			"save_slot_id": save_slot_id,
			"character_id": character_id,
			"item_id": item_id,
			"quantity": quantity,
			"slot_index": slot_index
		})
		if row_id == -1:
			execute("ROLLBACK;")
			return false

	return execute("COMMIT;")


func set_character_health(character_id: int, new_hp: int, save_slot_id: int = 1) -> bool:
	var sql = """
		UPDATE characters
		SET current_hp = MIN(MAX(?, 0), max_hp),
			current_state = CASE
				WHEN MIN(MAX(?, 0), max_hp) <= 0 THEN 'defeated'
				ELSE 'normal'
			END,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND save_slot_id = ?;
	"""
	return execute(sql, [new_hp, new_hp, character_id, save_slot_id])


func reduce_character_health(character_id: int, damage: int, save_slot_id: int = 1) -> bool:
	if damage < 0:
		damage = 0

	var sql = """
		UPDATE characters
		SET current_hp = MAX(current_hp - ?, 0),
			current_state = CASE
				WHEN current_hp - ? <= 0 THEN 'defeated'
				ELSE current_state
			END,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND save_slot_id = ?;
	"""
	return execute(sql, [damage, damage, character_id, save_slot_id])


func update_character_battle_state(character_id: int, current_hp: int, current_mana: int, current_state: String, save_slot_id: int = 1) -> bool:
	var sql = """
		UPDATE characters
		SET current_hp = MIN(MAX(?, 0), max_hp),
			current_mana = MIN(MAX(?, 0), max_mana),
			current_state = ?,
			updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND save_slot_id = ?;
	"""
	return execute(sql, [current_hp, current_mana, current_state, character_id, save_slot_id])


func add_character_experience(character_id: int, amount: int, save_slot_id: int = 1) -> bool:
	if amount == 0:
		return true
	return execute(
		"""
			UPDATE characters
			SET experience = MAX(experience + ?, 0),
				updated_at = CURRENT_TIMESTAMP
			WHERE id = ? AND save_slot_id = ?;
		""",
		[amount, character_id, save_slot_id]
	)


func apply_player_role(save_slot_id: int, character_id: int, class_id: int, skill_ids: Array, character_name: String = "") -> bool:
	var class_rows = select_rows(
		"""
			SELECT
				id,
				base_max_hp,
				base_max_mana,
				base_attack,
				base_defense,
				base_speed
			FROM classes
			WHERE id = ?
			LIMIT 1;
		""",
		[class_id]
	)
	if class_rows.is_empty():
		push_warning("No existe la clase %d para aplicar al personaje." % class_id)
		return false

	var class_data: Dictionary = class_rows[0]
	var normalized_character_name = character_name.strip_edges()
	var updated = execute(
		"""
			UPDATE characters
			SET class_id = ?,
				name = CASE WHEN ? = '' THEN name ELSE ? END,
				max_hp = ?,
				current_hp = ?,
				max_mana = ?,
				current_mana = ?,
				attack = ?,
				defense = ?,
				speed = ?,
				current_state = 'normal',
				updated_at = CURRENT_TIMESTAMP
			WHERE id = ? AND save_slot_id = ? AND character_type = 'player';
		""",
		[
			class_id,
			normalized_character_name,
			normalized_character_name,
			int(class_data.get("base_max_hp", 1)),
			int(class_data.get("base_max_hp", 1)),
			int(class_data.get("base_max_mana", 0)),
			int(class_data.get("base_max_mana", 0)),
			int(class_data.get("base_attack", 0)),
			int(class_data.get("base_defense", 0)),
			int(class_data.get("base_speed", 0)),
			character_id,
			save_slot_id
		]
	)
	if not updated:
		return false

	if not execute("DELETE FROM character_skills WHERE save_slot_id = ? AND character_id = ?;", [save_slot_id, character_id]):
		return false

	for raw_skill_id in skill_ids:
		var skill_id = int(raw_skill_id)
		if skill_id <= 0:
			continue
		if not execute(
			"""
				INSERT OR IGNORE INTO character_skills (save_slot_id, character_id, skill_id, learned_at_level, cooldown_remaining)
				VALUES (?, ?, ?, 1, 0);
			""",
			[save_slot_id, character_id, skill_id]
		):
			return false

	return true


func add_gold(save_slot_id: int, amount: int) -> bool:
	if amount == 0:
		return true
	return execute(
		"""
			UPDATE game_state
			SET gold = MAX(gold + ?, 0),
				updated_at = CURRENT_TIMESTAMP
			WHERE save_slot_id = ?;
		""",
		[amount, save_slot_id]
	)


func equip_item(character_id: int, item_id: int, equip_slot: String, save_slot_id: int = 1) -> bool:
	var inventory_rows = select_rows(
		"""
			SELECT id
			FROM inventory
			WHERE save_slot_id = ? AND character_id = ? AND item_id = ?
			LIMIT 1;
		""",
		[save_slot_id, character_id, item_id]
	)
	if inventory_rows.is_empty():
		push_warning("No se puede equipar el item %d porque no esta en el inventario del personaje %d." % [item_id, character_id])
		return false

	var sql = """
		INSERT INTO equipment (save_slot_id, character_id, item_id, equip_slot, equipped_at)
		VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
		ON CONFLICT(save_slot_id, character_id, equip_slot)
		DO UPDATE SET
			item_id = excluded.item_id,
			equipped_at = CURRENT_TIMESTAMP;
	"""
	return execute(sql, [save_slot_id, character_id, item_id, equip_slot.to_lower()])


func save_basic_game_state(save_slot_id: int, state_data: Dictionary) -> bool:
	var save_name = str(state_data.get("save_name", "Partida %d" % save_slot_id))
	var current_location = str(state_data.get("current_location", "aldea_principal"))
	var playtime_seconds = int(state_data.get("playtime_seconds", 0))
	var gold = int(state_data.get("gold", 0))
	var main_progress = int(state_data.get("main_progress", 0))
	var important_flags = JSON.stringify(state_data.get("important_flags", {}))
	var saved_at = str(state_data.get("saved_at", Time.get_datetime_string_from_system()))

	var slot_sql = """
		INSERT INTO save_slots (id, slot_index, save_name, saved_at, current_location, playtime_seconds)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(id)
		DO UPDATE SET
			save_name = excluded.save_name,
			saved_at = excluded.saved_at,
			current_location = excluded.current_location,
			playtime_seconds = excluded.playtime_seconds;
	"""
	if not execute(slot_sql, [save_slot_id, save_slot_id, save_name, saved_at, current_location, playtime_seconds]):
		return false

	var state_sql = """
		INSERT INTO game_state (save_slot_id, gold, current_location, main_progress, important_flags, updated_at)
		VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
		ON CONFLICT(save_slot_id)
		DO UPDATE SET
			gold = excluded.gold,
			current_location = excluded.current_location,
			main_progress = excluded.main_progress,
			important_flags = excluded.important_flags,
			updated_at = CURRENT_TIMESTAMP;
	"""
	return execute(state_sql, [save_slot_id, gold, current_location, main_progress, important_flags])


func log_battle_action(save_slot_id: int, turn_number: int, attacker_character_id: Variant, target_character_id: Variant, skill_id: Variant, damage_done: int, result_text: String) -> int:
	return insert_row("battle_logs", {
		"save_slot_id": save_slot_id,
		"turn_number": max(turn_number, 1),
		"attacker_character_id": attacker_character_id,
		"target_character_id": target_character_id,
		"skill_id": skill_id,
		"damage_done": damage_done,
		"result": result_text
	})


func _find_next_inventory_slot(character_id: int, save_slot_id: int) -> int:
	var rows = select_rows(
		"""
			SELECT slot_index
			FROM inventory
			WHERE save_slot_id = ? AND character_id = ?
			ORDER BY slot_index ASC;
		""",
		[save_slot_id, character_id]
	)

	var next_slot = 0
	for row in rows:
		var used_slot = int(row.get("slot_index", next_slot))
		if used_slot != next_slot:
			return next_slot
		next_slot += 1
	return next_slot


func _quote_identifier(identifier: String) -> String:
	return "\"%s\"" % identifier.replace("\"", "\"\"")
