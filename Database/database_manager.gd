class_name DatabaseManager
extends Node

const SQLITE_CLASS_NAME = &"SQLite"
const TEMPLATE_DATABASE_PATH = "res://Database/game_database.db"
const RUNTIME_DIRECTORY_PATH = "user://Database"
const RUNTIME_DATABASE_PATH = "user://Database/game_database.db"
const FALLBACK_STATE_PATH = "user://Database/fallback_game_state.json"
const STARTING_GOLD = 235
const SCHEMA_PATH = "res://Database/schema.sql"
const SEED_PATH = "res://Database/seed_data.sql"
const QUERIES_SCRIPT = preload("res://Database/queries.gd")

var _database: Object = null
var _queries: DatabaseQueries = QUERIES_SCRIPT.new()
var _initialized = false
var _sqlite_unavailable = false
var _sqlite_notice_shown = false
var _selected_player_role_data: Dictionary = {}
var _fallback_game_states: Dictionary = {}
var _fallback_inventories: Dictionary = {}
var _fallback_items: Dictionary = {}
var _fallback_state_loaded = false
var _pending_game_states: Dictionary = {}
var _pending_character_rows: Dictionary = {}
var _pending_inventories: Dictionary = {}
var _next_pending_inventory_id = -1
var _next_fallback_inventory_id = 1
var _next_fallback_item_id = 1000


func _ready() -> void:
	initialize_database()


func initialize_database(force_reseed: bool = false) -> bool:
	if _initialized and _database != null and not force_reseed:
		return true

	if _sqlite_unavailable and not force_reseed:
		return false

	if not has_sqlite_support():
		_sqlite_unavailable = true
		_show_sqlite_dependency_notice()
		return false

	_ensure_runtime_directory()
	_prepare_runtime_database_file()

	if not open_connection():
		return false

	if not create_tables_if_needed():
		return false

	if force_reseed:
		if not seed_initial_data():
			return false
	elif not _has_any_save_slot():
		if not seed_initial_data():
			return false

	_initialized = true
	return true


func has_sqlite_support() -> bool:
	return ClassDB.class_exists(SQLITE_CLASS_NAME)


func get_sqlite_dependency_message() -> String:
	return "Falta el plugin godot-sqlite. Instalala desde AssetLib o desde https://github.com/2shady4u/godot-sqlite y activa el plugin antes de usar la base de datos."


func _show_sqlite_dependency_notice() -> void:
	if _sqlite_notice_shown:
		return
	_sqlite_notice_shown = true
	print_verbose("%s Se usaran datos por defecto cuando sea posible." % get_sqlite_dependency_message())


func open_connection() -> bool:
	if _database != null:
		return true

	var sqlite_instance = ClassDB.instantiate(SQLITE_CLASS_NAME)
	if sqlite_instance == null:
		push_error("No se pudo instanciar la clase SQLite. " + get_sqlite_dependency_message())
		return false

	sqlite_instance.set("path", RUNTIME_DATABASE_PATH)
	sqlite_instance.set("foreign_keys", true)
	sqlite_instance.set("verbosity_level", 0)

	var success = bool(sqlite_instance.call("open_db"))
	if not success:
		var error_message = str(sqlite_instance.get("error_message"))
		push_error("No se pudo abrir la base de datos SQLite: %s" % error_message)
		return false

	_database = sqlite_instance
	_queries.bind_database(_database)
	return true


func close_connection() -> void:
	if _database == null:
		return

	if _database.has_method("close_db"):
		_database.call("close_db")

	_queries.clear_database()
	_database = null
	_initialized = false


func create_tables_if_needed() -> bool:
	return _execute_sql_file(SCHEMA_PATH)


func seed_initial_data() -> bool:
	return _execute_sql_file(SEED_PATH)


func insert_data(table_name: String, values: Dictionary) -> int:
	if not _ensure_ready():
		if table_name == "items":
			return _insert_fallback_item(values)
		return -1
	return _queries.insert_row(table_name, values)


func create_character(character_data: Dictionary) -> int:
	if not _ensure_ready():
		return -1
	return _queries.create_character(character_data)


func get_characters(save_slot_id: int = 1) -> Array:
	if not _ensure_ready():
		return _get_fallback_characters(save_slot_id)
	var rows = _queries.get_all_characters(save_slot_id)
	for index in range(rows.size()):
		var row = rows[index]
		if row is not Dictionary:
			continue
		var character_key = _make_character_key(save_slot_id, int(row.get("id", 0)))
		if _pending_character_rows.has(character_key):
			rows[index] = _pending_character_rows[character_key].duplicate(true)
	return rows


func cache_selected_player_role(role_data: Dictionary) -> void:
	_selected_player_role_data = role_data.duplicate(true)


func get_selected_player_role_data() -> Dictionary:
	return _selected_player_role_data.duplicate(true)


func get_classes() -> Array:
	if not _ensure_ready():
		return []
	return _queries.get_classes()


func get_inventory(character_id: int, save_slot_id: int = 1) -> Array:
	if not _ensure_ready():
		return _get_fallback_inventory(character_id, save_slot_id)
	var inventory_key = _make_inventory_key(save_slot_id, character_id)
	if _pending_inventories.has(inventory_key):
		return _duplicate_array_of_dictionaries(_pending_inventories[inventory_key])
	return _queries.get_inventory(character_id, save_slot_id)


func get_item_by_name(item_name: String) -> Dictionary:
	if not _ensure_ready():
		return _get_fallback_item_by_name(item_name)
	return _queries.get_item_by_name(item_name)


func update_item_by_name(item_name: String, values: Dictionary) -> bool:
	if not _ensure_ready():
		return _update_fallback_item_by_name(item_name, values)
	return _queries.update_item_by_name(item_name, values)


func get_character_skills(character_id: int, save_slot_id: int = 1) -> Array:
	if not _ensure_ready():
		return []
	return _queries.get_character_skills(character_id, save_slot_id)


func get_enemy_template(enemy_id: int) -> Dictionary:
	if not _ensure_ready():
		return {}
	return _queries.get_enemy_template(enemy_id)


func get_enemy_loot(enemy_id: int) -> Array:
	if not _ensure_ready():
		return []
	return _queries.get_enemy_loot(enemy_id)


func get_game_state(save_slot_id: int = 1) -> Dictionary:
	if not _ensure_ready():
		return _get_fallback_game_state(save_slot_id)
	var state_key = str(save_slot_id)
	if _pending_game_states.has(state_key):
		return _pending_game_states[state_key].duplicate(true)
	return _queries.get_game_state(save_slot_id)


func add_item_to_inventory(character_id: int, item_id: int, quantity: int = 1, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return _add_fallback_item_to_inventory(character_id, item_id, quantity, save_slot_id)
	return _stage_add_item_to_inventory(character_id, item_id, quantity, save_slot_id)


func set_inventory_quantity(inventory_id: int, quantity: int) -> bool:
	if not _ensure_ready():
		return _set_fallback_inventory_quantity(inventory_id, quantity)
	return _stage_inventory_quantity(inventory_id, quantity)


func replace_inventory(character_id: int, save_slot_id: int, slot_entries: Array) -> bool:
	if not _ensure_ready():
		return _replace_fallback_inventory(character_id, save_slot_id, slot_entries)
	return _stage_replace_inventory(character_id, save_slot_id, slot_entries)


func update_character_health(character_id: int, new_hp: int, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	var row = _get_pending_character_row(save_slot_id, character_id)
	if row.is_empty():
		return false
	var clamped_hp = clampi(new_hp, 0, int(row.get("max_hp", new_hp)))
	row["current_hp"] = clamped_hp
	row["current_state"] = "defeated" if clamped_hp <= 0 else "normal"
	_pending_character_rows[_make_character_key(save_slot_id, character_id)] = row
	return true


func reduce_character_health(character_id: int, damage: int, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	var row = _get_pending_character_row(save_slot_id, character_id)
	if row.is_empty():
		return false
	var new_hp = max(int(row.get("current_hp", 0)) - max(damage, 0), 0)
	row["current_hp"] = new_hp
	if new_hp <= 0:
		row["current_state"] = "defeated"
	_pending_character_rows[_make_character_key(save_slot_id, character_id)] = row
	return true


func update_character_battle_state(character_id: int, current_hp: int, current_mana: int, current_state: String, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	var row = _get_pending_character_row(save_slot_id, character_id)
	if row.is_empty():
		return false
	row["current_hp"] = clampi(current_hp, 0, int(row.get("max_hp", current_hp)))
	row["current_mana"] = clampi(current_mana, 0, int(row.get("max_mana", current_mana)))
	row["current_state"] = current_state
	_pending_character_rows[_make_character_key(save_slot_id, character_id)] = row
	return true


func add_character_experience(character_id: int, amount: int, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	var row = _get_pending_character_row(save_slot_id, character_id)
	if row.is_empty():
		return false
	row["experience"] = max(int(row.get("experience", 0)) + amount, 0)
	_pending_character_rows[_make_character_key(save_slot_id, character_id)] = row
	return true


func apply_player_role(save_slot_id: int, character_id: int, class_id: int, skill_ids: Array) -> bool:
	if not _ensure_ready():
		return false
	return _queries.apply_player_role(save_slot_id, character_id, class_id, skill_ids)


func add_gold(save_slot_id: int, amount: int) -> bool:
	if not _ensure_ready():
		return _add_fallback_gold(save_slot_id, amount)
	var state = _get_pending_game_state(save_slot_id)
	state["gold"] = max(int(state.get("gold", 0)) + amount, 0)
	_pending_game_states[str(save_slot_id)] = state
	return true


func equip_item(character_id: int, item_id: int, equip_slot: String, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.equip_item(character_id, item_id, equip_slot, save_slot_id)


func save_basic_game_state(save_slot_id: int, state_data: Dictionary) -> bool:
	if not _ensure_ready():
		return _save_fallback_game_state(save_slot_id, state_data)
	return _stage_basic_game_state(save_slot_id, state_data)


func commit_manual_save(save_slot_id: int = 1, state_data: Dictionary = {}) -> bool:
	if not _ensure_ready():
		return _save_fallback_game_state(save_slot_id, state_data)

	if not state_data.is_empty():
		_stage_basic_game_state(save_slot_id, state_data)

	var has_pending_data = (
		_pending_game_states.has(str(save_slot_id))
		or _has_pending_characters_for_slot(save_slot_id)
		or _has_pending_inventories_for_slot(save_slot_id)
	)
	if not has_pending_data:
		var current_state = _queries.get_game_state(save_slot_id)
		if current_state.is_empty():
			current_state = _build_default_fallback_game_state(save_slot_id)
		current_state["important_flags"] = _normalize_flags_value(current_state.get("important_flags", {}))
		current_state["saved_at"] = Time.get_datetime_string_from_system()
		return _queries.save_basic_game_state(save_slot_id, current_state)

	if not _queries.execute("BEGIN TRANSACTION;"):
		return false

	if not _commit_pending_characters(save_slot_id):
		_queries.execute("ROLLBACK;")
		return false
	if not _commit_pending_inventories(save_slot_id):
		_queries.execute("ROLLBACK;")
		return false
	if not _commit_pending_game_state(save_slot_id):
		_queries.execute("ROLLBACK;")
		return false
	if not _queries.execute("COMMIT;"):
		_queries.execute("ROLLBACK;")
		return false

	_clear_pending_for_slot(save_slot_id)
	return true


func has_pending_manual_save(save_slot_id: int = 1) -> bool:
	return (
		_pending_game_states.has(str(save_slot_id))
		or _has_pending_characters_for_slot(save_slot_id)
		or _has_pending_inventories_for_slot(save_slot_id)
	)


func log_battle_action(save_slot_id: int, turn_number: int, attacker_character_id: Variant, target_character_id: Variant, skill_id: Variant, damage_done: int, result_text: String) -> int:
	if not _ensure_ready():
		return -1
	return _queries.log_battle_action(save_slot_id, turn_number, attacker_character_id, target_character_id, skill_id, damage_done, result_text)


func get_runtime_database_path() -> String:
	return RUNTIME_DATABASE_PATH


func get_template_database_path() -> String:
	return TEMPLATE_DATABASE_PATH


func _stage_basic_game_state(save_slot_id: int, state_data: Dictionary) -> bool:
	var state = _get_pending_game_state(save_slot_id)
	var updated_at = Time.get_datetime_string_from_system()
	state["id"] = int(state.get("id", save_slot_id))
	state["save_slot_id"] = save_slot_id
	state["save_name"] = str(state_data.get("save_name", state.get("save_name", "Partida %d" % save_slot_id)))
	state["current_location"] = str(state_data.get("current_location", state.get("current_location", "aldea_principal")))
	state["playtime_seconds"] = max(int(state_data.get("playtime_seconds", state.get("playtime_seconds", 0))), 0)
	state["gold"] = max(int(state_data.get("gold", state.get("gold", 0))), 0)
	state["main_progress"] = max(int(state_data.get("main_progress", state.get("main_progress", 0))), 0)
	state["important_flags"] = _normalize_flags_value(state_data.get("important_flags", state.get("important_flags", {})))
	state["updated_at"] = updated_at
	state["saved_at"] = str(state.get("saved_at", state_data.get("saved_at", updated_at)))
	_pending_game_states[str(save_slot_id)] = state
	return true


func _get_pending_game_state(save_slot_id: int) -> Dictionary:
	var state_key = str(save_slot_id)
	if _pending_game_states.has(state_key):
		return _pending_game_states[state_key].duplicate(true)

	var state = _queries.get_game_state(save_slot_id)
	if state.is_empty():
		state = _build_default_fallback_game_state(save_slot_id)
	state["important_flags"] = _normalize_flags_value(state.get("important_flags", {}))
	return state.duplicate(true)


func _get_pending_character_row(save_slot_id: int, character_id: int) -> Dictionary:
	var character_key = _make_character_key(save_slot_id, character_id)
	if _pending_character_rows.has(character_key):
		return _pending_character_rows[character_key].duplicate(true)

	for row in _queries.get_all_characters(save_slot_id):
		if row is Dictionary and int(row.get("id", 0)) == character_id:
			return row.duplicate(true)
	return {}


func _stage_add_item_to_inventory(character_id: int, item_id: int, quantity: int, save_slot_id: int) -> bool:
	if character_id <= 0 or item_id <= 0 or quantity <= 0:
		return false

	var item_row = _get_item_row(item_id)
	if item_row.is_empty():
		push_warning("No existe el item %d en la base de datos." % item_id)
		return false

	var inventory_key = _make_inventory_key(save_slot_id, character_id)
	var inventory = _get_pending_inventory_snapshot(save_slot_id, character_id)
	var max_stack = max(int(item_row.get("max_stack", 1)), 1)
	var remaining = quantity

	for index in range(inventory.size()):
		if remaining <= 0:
			break
		var row = inventory[index]
		if row is not Dictionary:
			continue
		if int(row.get("item_id", 0)) != item_id:
			continue
		var current_quantity = int(row.get("quantity", 0))
		var free_space = max_stack - current_quantity
		if free_space <= 0:
			continue
		var added = mini(free_space, remaining)
		row["quantity"] = current_quantity + added
		inventory[index] = row
		remaining -= added

	while remaining > 0:
		var added_to_new_slot = mini(max_stack, remaining)
		inventory.append(_build_inventory_row_from_item(
			item_row,
			_get_next_pending_inventory_id(),
			_find_next_pending_inventory_slot(inventory),
			added_to_new_slot
		))
		remaining -= added_to_new_slot

	_pending_inventories[inventory_key] = inventory
	return true


func _stage_inventory_quantity(inventory_id: int, quantity: int) -> bool:
	for inventory_key in _pending_inventories.keys():
		var inventory = _pending_inventories[inventory_key]
		if inventory is not Array:
			continue
		for index in range(inventory.size()):
			var row = inventory[index]
			if row is not Dictionary or int(row.get("id", 0)) != inventory_id:
				continue
			if quantity <= 0:
				inventory.remove_at(index)
			else:
				row["quantity"] = quantity
				inventory[index] = row
			_pending_inventories[inventory_key] = inventory
			return true

	var owner_rows = _queries.select_rows(
		"SELECT save_slot_id, character_id FROM inventory WHERE id = ? LIMIT 1;",
		[inventory_id]
	)
	if owner_rows.is_empty():
		return false

	var owner = owner_rows[0]
	var save_slot_id = int(owner.get("save_slot_id", 1))
	var character_id = int(owner.get("character_id", 0))
	var inventory_key = _make_inventory_key(save_slot_id, character_id)
	_pending_inventories[inventory_key] = _get_pending_inventory_snapshot(save_slot_id, character_id)
	return _stage_inventory_quantity(inventory_id, quantity)


func _stage_replace_inventory(character_id: int, save_slot_id: int, slot_entries: Array) -> bool:
	if character_id <= 0:
		return false

	var inventory: Array = []
	for raw_entry in slot_entries:
		if raw_entry is not Dictionary:
			continue

		var item_id = int(raw_entry.get("item_id", 0))
		var quantity = int(raw_entry.get("quantity", 0))
		var slot_index = int(raw_entry.get("slot_index", -1))
		if item_id <= 0 or quantity <= 0 or slot_index < 0:
			continue

		var item_row = _get_item_row(item_id)
		if item_row.is_empty():
			continue

		inventory.append(_build_inventory_row_from_item(
			item_row,
			_get_next_pending_inventory_id(),
			slot_index,
			quantity
		))

	_pending_inventories[_make_inventory_key(save_slot_id, character_id)] = inventory
	return true


func _get_pending_inventory_snapshot(save_slot_id: int, character_id: int) -> Array:
	var inventory_key = _make_inventory_key(save_slot_id, character_id)
	if _pending_inventories.has(inventory_key):
		return _duplicate_array_of_dictionaries(_pending_inventories[inventory_key])
	return _queries.get_inventory(character_id, save_slot_id)


func _build_inventory_row_from_item(item_row: Dictionary, inventory_id: int, slot_index: int, quantity: int) -> Dictionary:
	return {
		"id": inventory_id,
		"slot_index": slot_index,
		"quantity": quantity,
		"item_id": int(item_row.get("id", 0)),
		"item_name": str(item_row.get("name", "Objeto")),
		"description": str(item_row.get("description", "")),
		"item_type": str(item_row.get("item_type", "misc")),
		"rarity": str(item_row.get("rarity", "common")),
		"price": int(item_row.get("price", 0)),
		"icon": str(item_row.get("icon", "")),
		"max_stack": max(int(item_row.get("max_stack", 1)), 1),
		"usable_in_battle": item_row.get("usable_in_battle", false),
		"effect_data": item_row.get("effect_data", {})
	}


func _get_item_row(item_id: int) -> Dictionary:
	var rows = _queries.select_rows(
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
			WHERE id = ?
			LIMIT 1;
		""",
		[item_id]
	)
	if rows.is_empty():
		return {}
	return rows[0].duplicate(true)


func _find_next_pending_inventory_slot(inventory: Array) -> int:
	var used_slots: Array = []
	for row in inventory:
		if row is Dictionary:
			used_slots.append(int(row.get("slot_index", -1)))

	var next_slot = 0
	while used_slots.has(next_slot):
		next_slot += 1
	return next_slot


func _get_next_pending_inventory_id() -> int:
	var inventory_id = _next_pending_inventory_id
	_next_pending_inventory_id -= 1
	return inventory_id


func _commit_pending_characters(save_slot_id: int) -> bool:
	for character_key in _pending_character_rows.keys():
		if _get_save_slot_from_key(str(character_key)) != save_slot_id:
			continue

		var row = _pending_character_rows[character_key]
		if row is not Dictionary:
			continue

		if not _queries.execute(
			"""
				UPDATE characters
				SET class_id = ?,
					level = ?,
					experience = ?,
					max_hp = ?,
					current_hp = ?,
					max_mana = ?,
					current_mana = ?,
					attack = ?,
					defense = ?,
					speed = ?,
					current_state = ?,
					is_active = ?,
					updated_at = CURRENT_TIMESTAMP
				WHERE id = ? AND save_slot_id = ?;
			""",
			[
				row.get("class_id", null),
				int(row.get("level", 1)),
				int(row.get("experience", 0)),
				int(row.get("max_hp", 1)),
				int(row.get("current_hp", 1)),
				int(row.get("max_mana", 0)),
				int(row.get("current_mana", 0)),
				int(row.get("attack", 0)),
				int(row.get("defense", 0)),
				int(row.get("speed", 0)),
				str(row.get("current_state", "normal")),
				int(row.get("is_active", 1)),
				int(row.get("id", 0)),
				save_slot_id
			]
		):
			return false
	return true


func _commit_pending_inventories(save_slot_id: int) -> bool:
	for inventory_key in _pending_inventories.keys():
		if _get_save_slot_from_key(str(inventory_key)) != save_slot_id:
			continue

		var character_id = _get_character_id_from_inventory_key(str(inventory_key))
		if character_id <= 0:
			continue

		if not _queries.execute("DELETE FROM inventory WHERE save_slot_id = ? AND character_id = ?;", [save_slot_id, character_id]):
			return false

		var inventory = _pending_inventories[inventory_key]
		if inventory is not Array:
			continue

		for row in inventory:
			if row is not Dictionary:
				continue
			var item_id = int(row.get("item_id", 0))
			var quantity = int(row.get("quantity", 0))
			var slot_index = int(row.get("slot_index", -1))
			if item_id <= 0 or quantity <= 0 or slot_index < 0:
				continue
			if _queries.insert_row("inventory", {
				"save_slot_id": save_slot_id,
				"character_id": character_id,
				"item_id": item_id,
				"quantity": quantity,
				"slot_index": slot_index
			}) == -1:
				return false
	return true


func _commit_pending_game_state(save_slot_id: int) -> bool:
	var state_key = str(save_slot_id)
	var state = _pending_game_states.get(state_key, _queries.get_game_state(save_slot_id))
	if state is not Dictionary or state.is_empty():
		state = _build_default_fallback_game_state(save_slot_id)

	state = state.duplicate(true)
	state["important_flags"] = _normalize_flags_value(state.get("important_flags", {}))
	state["saved_at"] = Time.get_datetime_string_from_system()
	return _queries.save_basic_game_state(save_slot_id, state)


func _has_pending_characters_for_slot(save_slot_id: int) -> bool:
	for character_key in _pending_character_rows.keys():
		if _get_save_slot_from_key(str(character_key)) == save_slot_id:
			return true
	return false


func _has_pending_inventories_for_slot(save_slot_id: int) -> bool:
	for inventory_key in _pending_inventories.keys():
		if _get_save_slot_from_key(str(inventory_key)) == save_slot_id:
			return true
	return false


func _clear_pending_for_slot(save_slot_id: int) -> void:
	_pending_game_states.erase(str(save_slot_id))

	for character_key in _pending_character_rows.keys():
		if _get_save_slot_from_key(str(character_key)) == save_slot_id:
			_pending_character_rows.erase(character_key)

	for inventory_key in _pending_inventories.keys():
		if _get_save_slot_from_key(str(inventory_key)) == save_slot_id:
			_pending_inventories.erase(inventory_key)


func _make_character_key(save_slot_id: int, character_id: int) -> String:
	return "%d:%d" % [save_slot_id, character_id]


func _make_inventory_key(save_slot_id: int, character_id: int) -> String:
	return "%d:%d" % [save_slot_id, character_id]


func _get_save_slot_from_key(key: String) -> int:
	var parts = key.split(":")
	if parts.is_empty():
		return 0
	return int(parts[0])


func _get_character_id_from_inventory_key(key: String) -> int:
	var parts = key.split(":")
	if parts.size() < 2:
		return 0
	return int(parts[1])


func _duplicate_array_of_dictionaries(source: Variant) -> Array:
	var duplicated: Array = []
	if source is not Array:
		return duplicated
	for value in source:
		if value is Dictionary:
			duplicated.append(value.duplicate(true))
		else:
			duplicated.append(value)
	return duplicated


func _normalize_flags_value(raw_flags: Variant) -> Dictionary:
	if raw_flags is Dictionary:
		return raw_flags.duplicate(true)
	if raw_flags is String:
		var parsed = JSON.parse_string(raw_flags)
		if parsed is Dictionary:
			return parsed.duplicate(true)
	return {}


func _ensure_ready() -> bool:
	if _sqlite_unavailable:
		return false
	if _database != null:
		return true
	return initialize_database()


func _ensure_runtime_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_DIRECTORY_PATH))


func _prepare_runtime_database_file() -> void:
	if FileAccess.file_exists(RUNTIME_DATABASE_PATH):
		return
	if not FileAccess.file_exists(TEMPLATE_DATABASE_PATH):
		return

	var source_path = ProjectSettings.globalize_path(TEMPLATE_DATABASE_PATH)
	var target_path = ProjectSettings.globalize_path(RUNTIME_DATABASE_PATH)
	var copy_error = DirAccess.copy_absolute(source_path, target_path)
	if copy_error != OK:
		push_warning("No se pudo copiar la base de datos plantilla a user://. Se intentara crear desde schema.sql.")


func _execute_sql_file(sql_path: String) -> bool:
	if _database == null:
		push_error("No hay conexion SQLite activa para ejecutar %s." % sql_path)
		return false
	if not FileAccess.file_exists(sql_path):
		push_error("No existe el archivo SQL: %s" % sql_path)
		return false

	var sql_script = FileAccess.get_file_as_string(sql_path)
	for statement in _split_sql_statements(sql_script):
		if not _queries.execute(statement):
			var error_message = str(_database.get("error_message"))
			push_error("Error al ejecutar SQL desde %s: %s" % [sql_path, error_message])
			return false

	return true


func _split_sql_statements(sql_script: String) -> Array:
	var statements: Array = []
	for raw_chunk in sql_script.split(";"):
		var cleaned_statement = _strip_sql_comments(raw_chunk).strip_edges()
		if cleaned_statement.is_empty():
			continue
		statements.append(cleaned_statement + ";")
	return statements


func _strip_sql_comments(sql_chunk: String) -> String:
	var lines = sql_chunk.split("\n")
	var filtered_lines: Array = []
	for line in lines:
		var stripped_line = line.strip_edges()
		if stripped_line.begins_with("--"):
			continue
		filtered_lines.append(line)
	return "\n".join(filtered_lines)


func _has_any_save_slot() -> bool:
	if _database == null:
		return false
	if not _queries.execute("SELECT id FROM save_slots LIMIT 1;"):
		return false

	var result = _database.get("query_result")
	return result is Array and not result.is_empty()


func _get_fallback_game_state(save_slot_id: int) -> Dictionary:
	_ensure_fallback_state_loaded()
	var slot_key = str(save_slot_id)
	var state = _fallback_game_states.get(slot_key, {})
	if state is not Dictionary:
		state = {}
	if state.is_empty():
		state = _build_default_fallback_game_state(save_slot_id)
		_fallback_game_states[slot_key] = state
		_save_fallback_state_file()
	return state.duplicate(true)


func _get_fallback_characters(save_slot_id: int) -> Array:
	return [
		{
			"id": 1,
			"class_id": 1,
			"name": "Ariadna",
			"character_type": "player",
			"level": 1,
			"experience": 0,
			"max_hp": 100,
			"current_hp": 100,
			"max_mana": 0,
			"current_mana": 0,
			"attack": 10,
			"defense": 5,
			"speed": 5,
			"current_state": "normal",
			"is_active": 1,
			"class_name": "Aventurero",
			"enemy_template_name": ""
		}
	]


func _get_fallback_inventory(character_id: int, save_slot_id: int) -> Array:
	_ensure_fallback_state_loaded()
	var inventory_key = _make_inventory_key(save_slot_id, character_id)
	return _duplicate_array_of_dictionaries(_fallback_inventories.get(inventory_key, []))


func _insert_fallback_item(values: Dictionary) -> int:
	_ensure_fallback_state_loaded()
	var item_name = str(values.get("name", "")).strip_edges()
	if item_name.is_empty():
		return -1

	var existing_item = _get_fallback_item_by_name(item_name)
	if not existing_item.is_empty():
		return int(existing_item.get("id", -1))

	var item_id = _next_fallback_item_id
	_next_fallback_item_id += 1
	_fallback_items[str(item_id)] = {
		"id": item_id,
		"name": item_name,
		"description": str(values.get("description", "")),
		"item_type": str(values.get("item_type", "misc")),
		"rarity": str(values.get("rarity", "common")),
		"price": int(values.get("price", 0)),
		"icon": str(values.get("icon", "")),
		"max_stack": max(int(values.get("max_stack", 1)), 1),
		"usable_in_battle": bool(values.get("usable_in_battle", false)),
		"effect_data": values.get("effect_data", {})
	}
	if not _save_fallback_state_file():
		return -1
	return item_id


func _get_fallback_item_by_name(item_name: String) -> Dictionary:
	_ensure_fallback_state_loaded()
	var normalized_name = item_name.strip_edges().to_lower()
	for item in _fallback_items.values():
		if item is Dictionary and str(item.get("name", "")).strip_edges().to_lower() == normalized_name:
			return item.duplicate(true)
	return {}


func _update_fallback_item_by_name(item_name: String, values: Dictionary) -> bool:
	_ensure_fallback_state_loaded()
	var normalized_name = item_name.strip_edges().to_lower()
	for item_id in _fallback_items.keys():
		var item = _fallback_items[item_id]
		if item is not Dictionary:
			continue
		if str(item.get("name", "")).strip_edges().to_lower() != normalized_name:
			continue

		for key in [
			"description",
			"item_type",
			"rarity",
			"price",
			"icon",
			"max_stack",
			"usable_in_battle",
			"effect_data"
		]:
			if values.has(key):
				item[key] = values[key]
		_fallback_items[item_id] = item
		return _save_fallback_state_file()
	return false


func _get_fallback_item_by_id(item_id: int) -> Dictionary:
	_ensure_fallback_state_loaded()
	var item = _fallback_items.get(str(item_id), {})
	if item is Dictionary and not item.is_empty():
		return item.duplicate(true)
	return {
		"id": item_id,
		"name": "Objeto %d" % item_id,
		"description": "",
		"item_type": "misc",
		"rarity": "common",
		"price": 0,
		"icon": "",
		"max_stack": 64,
		"usable_in_battle": false,
		"effect_data": {}
	}


func _add_fallback_item_to_inventory(character_id: int, item_id: int, quantity: int, save_slot_id: int) -> bool:
	if character_id <= 0 or item_id <= 0 or quantity <= 0:
		return false

	_ensure_fallback_state_loaded()
	var inventory_key = _make_inventory_key(save_slot_id, character_id)
	var inventory = _duplicate_array_of_dictionaries(_fallback_inventories.get(inventory_key, []))
	var item = _get_fallback_item_by_id(item_id)
	var max_stack = max(int(item.get("max_stack", 1)), 1)
	var remaining = quantity

	for index in range(inventory.size()):
		if remaining <= 0:
			break
		var row = inventory[index]
		if row is not Dictionary or int(row.get("item_id", 0)) != item_id:
			continue
		var current_quantity = int(row.get("quantity", 0))
		var free_space = max_stack - current_quantity
		if free_space <= 0:
			continue
		var added = mini(free_space, remaining)
		row["quantity"] = current_quantity + added
		inventory[index] = row
		remaining -= added

	while remaining > 0:
		var added_to_new_slot = mini(max_stack, remaining)
		inventory.append(_build_fallback_inventory_row(
			item,
			_get_next_fallback_inventory_id(),
			_find_next_pending_inventory_slot(inventory),
			added_to_new_slot
		))
		remaining -= added_to_new_slot

	_fallback_inventories[inventory_key] = inventory
	return _save_fallback_state_file()


func _replace_fallback_inventory(character_id: int, save_slot_id: int, slot_entries: Array) -> bool:
	if character_id <= 0:
		return false

	_ensure_fallback_state_loaded()
	var inventory: Array = []
	for raw_entry in slot_entries:
		if raw_entry is not Dictionary:
			continue

		var item_id = int(raw_entry.get("item_id", 0))
		var quantity = int(raw_entry.get("quantity", 0))
		var slot_index = int(raw_entry.get("slot_index", -1))
		if item_id <= 0 or quantity <= 0 or slot_index < 0:
			continue

		inventory.append(_build_fallback_inventory_row(
			_get_fallback_item_by_id(item_id),
			_get_next_fallback_inventory_id(),
			slot_index,
			quantity
		))

	_fallback_inventories[_make_inventory_key(save_slot_id, character_id)] = inventory
	return _save_fallback_state_file()


func _set_fallback_inventory_quantity(inventory_id: int, quantity: int) -> bool:
	_ensure_fallback_state_loaded()
	for inventory_key in _fallback_inventories.keys():
		var inventory = _fallback_inventories[inventory_key]
		if inventory is not Array:
			continue
		for index in range(inventory.size()):
			var row = inventory[index]
			if row is not Dictionary or int(row.get("id", 0)) != inventory_id:
				continue
			if quantity <= 0:
				inventory.remove_at(index)
			else:
				row["quantity"] = quantity
				inventory[index] = row
			_fallback_inventories[inventory_key] = inventory
			return _save_fallback_state_file()
	return false


func _build_fallback_inventory_row(item: Dictionary, inventory_id: int, slot_index: int, quantity: int) -> Dictionary:
	return {
		"id": inventory_id,
		"slot_index": slot_index,
		"quantity": quantity,
		"item_id": int(item.get("id", 0)),
		"item_name": str(item.get("name", "Objeto")),
		"description": str(item.get("description", "")),
		"item_type": str(item.get("item_type", "misc")),
		"rarity": str(item.get("rarity", "common")),
		"price": int(item.get("price", 0)),
		"icon": str(item.get("icon", "")),
		"max_stack": max(int(item.get("max_stack", 1)), 1),
		"usable_in_battle": bool(item.get("usable_in_battle", false)),
		"effect_data": item.get("effect_data", {})
	}


func _get_next_fallback_inventory_id() -> int:
	var inventory_id = _next_fallback_inventory_id
	_next_fallback_inventory_id += 1
	return inventory_id


func _add_fallback_gold(save_slot_id: int, amount: int) -> bool:
	if amount == 0:
		return true

	var state = _get_fallback_game_state(save_slot_id)
	state["gold"] = max(int(state.get("gold", 0)) + amount, 0)
	state["updated_at"] = Time.get_datetime_string_from_system()
	_fallback_game_states[str(save_slot_id)] = state
	return _save_fallback_state_file()


func _save_fallback_game_state(save_slot_id: int, state_data: Dictionary) -> bool:
	_ensure_fallback_state_loaded()
	var slot_key = str(save_slot_id)
	var existing_state = _fallback_game_states.get(slot_key, {})
	if existing_state is not Dictionary or existing_state.is_empty():
		existing_state = _build_default_fallback_game_state(save_slot_id)

	var updated_at = Time.get_datetime_string_from_system()
	var state: Dictionary = existing_state.duplicate(true)
	state["id"] = int(state.get("id", save_slot_id))
	state["save_slot_id"] = save_slot_id
	state["save_name"] = str(state_data.get("save_name", state.get("save_name", "Partida %d" % save_slot_id)))
	state["current_location"] = str(state_data.get("current_location", state.get("current_location", "aldea_principal")))
	state["playtime_seconds"] = max(int(state_data.get("playtime_seconds", state.get("playtime_seconds", 0))), 0)
	state["gold"] = max(int(state_data.get("gold", state.get("gold", 0))), 0)
	state["main_progress"] = max(int(state_data.get("main_progress", state.get("main_progress", 0))), 0)
	state["important_flags"] = state_data.get("important_flags", state.get("important_flags", {}))
	state["saved_at"] = str(state_data.get("saved_at", updated_at))
	state["updated_at"] = updated_at

	_fallback_game_states[slot_key] = state
	return _save_fallback_state_file()


func _build_default_fallback_game_state(save_slot_id: int) -> Dictionary:
	var now = Time.get_datetime_string_from_system()
	return {
		"id": save_slot_id,
		"save_slot_id": save_slot_id,
		"gold": STARTING_GOLD,
		"current_location": "aldea_principal",
		"main_progress": 0,
		"important_flags": {},
		"updated_at": now,
		"save_name": "Partida %d" % save_slot_id,
		"playtime_seconds": 0,
		"saved_at": now
	}


func _ensure_fallback_state_loaded() -> void:
	if _fallback_state_loaded:
		return

	_fallback_state_loaded = true
	if not FileAccess.file_exists(FALLBACK_STATE_PATH):
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FALLBACK_STATE_PATH))
	if parsed is not Dictionary:
		return

	var loaded_states = parsed.get("game_states", {})
	if loaded_states is not Dictionary:
		loaded_states = {}

	for raw_key in loaded_states.keys():
		var loaded_state = loaded_states[raw_key]
		if loaded_state is Dictionary:
			_fallback_game_states[str(raw_key)] = loaded_state.duplicate(true)

	var loaded_inventories = parsed.get("inventories", {})
	if loaded_inventories is Dictionary:
		for raw_key in loaded_inventories.keys():
			var loaded_inventory = loaded_inventories[raw_key]
			if loaded_inventory is Array:
				_fallback_inventories[str(raw_key)] = _duplicate_array_of_dictionaries(loaded_inventory)
				for row in loaded_inventory:
					if row is Dictionary:
						_next_fallback_inventory_id = max(_next_fallback_inventory_id, int(row.get("id", 0)) + 1)

	var loaded_items = parsed.get("items", {})
	if loaded_items is Dictionary:
		for raw_key in loaded_items.keys():
			var loaded_item = loaded_items[raw_key]
			if loaded_item is Dictionary:
				_fallback_items[str(raw_key)] = loaded_item.duplicate(true)
				_next_fallback_item_id = max(_next_fallback_item_id, int(loaded_item.get("id", 0)) + 1)


func _save_fallback_state_file() -> bool:
	_ensure_runtime_directory()
	var file = FileAccess.open(FALLBACK_STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el estado de respaldo de la partida.")
		return false

	file.store_string(JSON.stringify({
		"game_states": _fallback_game_states,
		"inventories": _fallback_inventories,
		"items": _fallback_items
	}))
	return true
