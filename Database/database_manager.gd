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
var _fallback_state_loaded = false


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
		return -1
	return _queries.insert_row(table_name, values)


func create_character(character_data: Dictionary) -> int:
	if not _ensure_ready():
		return -1
	return _queries.create_character(character_data)


func get_characters(save_slot_id: int = 1) -> Array:
	if not _ensure_ready():
		return []
	return _queries.get_all_characters(save_slot_id)


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
		return []
	return _queries.get_inventory(character_id, save_slot_id)


func get_item_by_name(item_name: String) -> Dictionary:
	if not _ensure_ready():
		return {}
	return _queries.get_item_by_name(item_name)


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
	return _queries.get_game_state(save_slot_id)


func add_item_to_inventory(character_id: int, item_id: int, quantity: int = 1, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.add_item_to_inventory(character_id, item_id, quantity, save_slot_id)


func set_inventory_quantity(inventory_id: int, quantity: int) -> bool:
	if not _ensure_ready():
		return false
	return _queries.set_inventory_quantity(inventory_id, quantity)


func replace_inventory(character_id: int, save_slot_id: int, slot_entries: Array) -> bool:
	if not _ensure_ready():
		return false
	return _queries.replace_inventory(character_id, save_slot_id, slot_entries)


func update_character_health(character_id: int, new_hp: int, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.set_character_health(character_id, new_hp, save_slot_id)


func reduce_character_health(character_id: int, damage: int, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.reduce_character_health(character_id, damage, save_slot_id)


func update_character_battle_state(character_id: int, current_hp: int, current_mana: int, current_state: String, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.update_character_battle_state(character_id, current_hp, current_mana, current_state, save_slot_id)


func add_character_experience(character_id: int, amount: int, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.add_character_experience(character_id, amount, save_slot_id)


func apply_player_role(save_slot_id: int, character_id: int, class_id: int, skill_ids: Array) -> bool:
	if not _ensure_ready():
		return false
	return _queries.apply_player_role(save_slot_id, character_id, class_id, skill_ids)


func add_gold(save_slot_id: int, amount: int) -> bool:
	if not _ensure_ready():
		return _add_fallback_gold(save_slot_id, amount)
	return _queries.add_gold(save_slot_id, amount)


func equip_item(character_id: int, item_id: int, equip_slot: String, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.equip_item(character_id, item_id, equip_slot, save_slot_id)


func save_basic_game_state(save_slot_id: int, state_data: Dictionary) -> bool:
	if not _ensure_ready():
		return _save_fallback_game_state(save_slot_id, state_data)
	return _queries.save_basic_game_state(save_slot_id, state_data)


func log_battle_action(save_slot_id: int, turn_number: int, attacker_character_id: Variant, target_character_id: Variant, skill_id: Variant, damage_done: int, result_text: String) -> int:
	if not _ensure_ready():
		return -1
	return _queries.log_battle_action(save_slot_id, turn_number, attacker_character_id, target_character_id, skill_id, damage_done, result_text)


func get_runtime_database_path() -> String:
	return RUNTIME_DATABASE_PATH


func get_template_database_path() -> String:
	return TEMPLATE_DATABASE_PATH


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
		return

	for raw_key in loaded_states.keys():
		var loaded_state = loaded_states[raw_key]
		if loaded_state is Dictionary:
			_fallback_game_states[str(raw_key)] = loaded_state.duplicate(true)


func _save_fallback_state_file() -> bool:
	_ensure_runtime_directory()
	var file = FileAccess.open(FALLBACK_STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el estado de respaldo de la partida.")
		return false

	file.store_string(JSON.stringify({"game_states": _fallback_game_states}))
	return true
