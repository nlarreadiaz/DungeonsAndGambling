class_name DatabaseManager
extends Node

const SQLITE_CLASS_NAME = &"SQLite"
const TEMPLATE_DATABASE_PATH = "res://Database/game_database.db"
const RUNTIME_DIRECTORY_PATH = "user://Database"
const RUNTIME_DATABASE_PATH = "user://Database/game_database.db"
const SCHEMA_PATH = "res://Database/schema.sql"
const SEED_PATH = "res://Database/seed_data.sql"
const QUERIES_SCRIPT = preload("res://Database/queries.gd")

var _database: Object = null
var _queries: DatabaseQueries = QUERIES_SCRIPT.new()
var _initialized = false


func _ready() -> void:
	initialize_database()


func initialize_database(force_reseed: bool = false) -> bool:
	if _initialized and _database != null and not force_reseed:
		return true

	if not has_sqlite_support():
		push_warning(get_sqlite_dependency_message())
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


func get_inventory(character_id: int, save_slot_id: int = 1) -> Array:
	if not _ensure_ready():
		return []
	return _queries.get_inventory(character_id, save_slot_id)


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
		return {}
	return _queries.get_game_state(save_slot_id)


func add_item_to_inventory(character_id: int, item_id: int, quantity: int = 1, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.add_item_to_inventory(character_id, item_id, quantity, save_slot_id)


func set_inventory_quantity(inventory_id: int, quantity: int) -> bool:
	if not _ensure_ready():
		return false
	return _queries.set_inventory_quantity(inventory_id, quantity)


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


func add_gold(save_slot_id: int, amount: int) -> bool:
	if not _ensure_ready():
		return false
	return _queries.add_gold(save_slot_id, amount)


func equip_item(character_id: int, item_id: int, equip_slot: String, save_slot_id: int = 1) -> bool:
	if not _ensure_ready():
		return false
	return _queries.equip_item(character_id, item_id, equip_slot, save_slot_id)


func save_basic_game_state(save_slot_id: int, state_data: Dictionary) -> bool:
	if not _ensure_ready():
		return false
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
