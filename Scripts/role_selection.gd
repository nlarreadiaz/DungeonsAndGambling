extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

const MAIN_MENU_SCENE = "res://Scenes/menu.tscn"
const WORLD_SCENE = "res://Scenes/aldea_principal.tscn"
const SAVE_SLOT_ID = 1
const GUERRERO_TEXTURE: Texture2D = preload("res://assets/role_selection/role_guerrero.png")
const ARQUERO_TEXTURE: Texture2D = preload("res://assets/role_selection/role_arquero.png")
const MAGO_TEXTURE: Texture2D = preload("res://assets/role_selection/role_mago.png")

@onready var _main_panel: PanelContainer = $ContentCenter/MainPanel
@onready var _cards_container: HBoxContainer = $ContentCenter/MainPanel/MarginContainer/Layout/Cards
@onready var _status_label: Label = $ContentCenter/MainPanel/MarginContainer/Layout/Footer/StatusLabel
@onready var _detail_name_label: Label = $ContentCenter/MainPanel/MarginContainer/Layout/DetailPanel/MarginContainer/DetailLayout/DetailName
@onready var _detail_description_label: Label = $ContentCenter/MainPanel/MarginContainer/Layout/DetailPanel/MarginContainer/DetailLayout/DetailDescription
@onready var _detail_stats_label: Label = $ContentCenter/MainPanel/MarginContainer/Layout/DetailPanel/MarginContainer/DetailLayout/DetailStats
@onready var _back_button: TextureButton = $ContentCenter/MainPanel/MarginContainer/Layout/Footer/BackButton

var _selected_role = "guerrero"
var _roles: Dictionary = {}
var _role_cards: Dictionary = {}
var _buttons_locked = false


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	_roles = _create_default_roles()
	_load_role_stats_from_database()
	_cache_role_nodes()
	_connect_role_signals()
	_populate_role_cards()
	_select_role(_selected_role)
	_fit_panel_to_viewport()
	resized.connect(_fit_panel_to_viewport)
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _create_default_roles() -> Dictionary:
	return {
		"guerrero": {
			"class_id": 1,
			"name": "Guerrero",
			"description": "Primera linea resistente. Aguanta golpes y pega fuerte cuerpo a cuerpo.",
			"max_hp": 160,
			"max_mana": 20,
			"attack": 18,
			"defense": 14,
			"speed": 8,
			"skill_ids": [1],
			"skill_text": "Golpe Fuerte",
			"portrait": GUERRERO_TEXTURE,
			"accent": Color(0.96, 0.46, 0.32, 1)
		},
		"arquero": {
			"class_id": 3,
			"name": "Arquero",
			"description": "Clase agil de distancia. Menos defensa, mucha velocidad y precision.",
			"max_hp": 110,
			"max_mana": 35,
			"attack": 14,
			"defense": 9,
			"speed": 14,
			"skill_ids": [3],
			"skill_text": "Disparo Certero",
			"portrait": ARQUERO_TEXTURE,
			"accent": Color(0.58, 0.82, 0.34, 1)
		},
		"mago": {
			"class_id": 2,
			"name": "Mago",
			"description": "Especialista en mana y dano magico. Fragil, pero con gran potencial.",
			"max_hp": 95,
			"max_mana": 120,
			"attack": 9,
			"defense": 7,
			"speed": 10,
			"skill_ids": [2],
			"skill_text": "Bola de Fuego",
			"portrait": MAGO_TEXTURE,
			"accent": Color(0.75, 0.38, 0.96, 1)
		}
	}


func _load_role_stats_from_database() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_classes"):
		return

	var class_rows = database_manager.call("get_classes")
	if class_rows is not Array:
		return

	for row in class_rows:
		if row is not Dictionary:
			continue

		var role_id = str(row.get("name", "")).strip_edges().to_lower()
		if not _roles.has(role_id):
			continue

		var role_data: Dictionary = _roles[role_id]
		role_data["class_id"] = int(row.get("id", role_data.get("class_id", 0)))
		role_data["description"] = str(row.get("description", role_data.get("description", "")))
		role_data["max_hp"] = int(row.get("base_max_hp", role_data.get("max_hp", 1)))
		role_data["max_mana"] = int(row.get("base_max_mana", role_data.get("max_mana", 0)))
		role_data["attack"] = int(row.get("base_attack", role_data.get("attack", 0)))
		role_data["defense"] = int(row.get("base_defense", role_data.get("defense", 0)))
		role_data["speed"] = int(row.get("base_speed", role_data.get("speed", 0)))
		_roles[role_id] = role_data


func _cache_role_nodes() -> void:
	_role_cards = {
		"guerrero": _get_role_card_nodes("GuerreroCard"),
		"arquero": _get_role_card_nodes("ArqueroCard"),
		"mago": _get_role_card_nodes("MagoCard")
	}


func _get_role_card_nodes(card_name: String) -> Dictionary:
	var card = _cards_container.get_node(card_name) as PanelContainer
	var stats_root = card.get_node("MarginContainer/Layout/Stats")
	return {
		"card": card,
		"name": card.get_node("MarginContainer/Layout/Name") as Label,
		"portrait": card.get_node("MarginContainer/Layout/Portrait") as TextureRect,
		"hp": _get_stat_nodes(stats_root, "HpRow"),
		"mp": _get_stat_nodes(stats_root, "MpRow"),
		"attack": _get_stat_nodes(stats_root, "AttackRow"),
		"defense": _get_stat_nodes(stats_root, "DefenseRow"),
		"speed": _get_stat_nodes(stats_root, "SpeedRow"),
		"button": card.get_node("MarginContainer/Layout/ChooseButton") as TextureButton
	}


func _get_stat_nodes(stats_root: Node, row_name: String) -> Dictionary:
	var row = stats_root.get_node(row_name)
	return {
		"bar": row.get_node("Bar") as ProgressBar,
		"value": row.get_node("Value") as Label
	}


func _connect_role_signals() -> void:
	for role_id in _role_cards.keys():
		var card_data: Dictionary = _role_cards[role_id]
		var card = card_data.get("card", null) as Control
		var button = card_data.get("button", null) as TextureButton

		if card != null:
			card.mouse_entered.connect(_select_role.bind(role_id))
		if button != null:
			button.mouse_entered.connect(_select_role.bind(role_id))
			button.pressed.connect(_on_choose_role_pressed.bind(role_id))

	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)


func _populate_role_cards() -> void:
	var max_stat = _get_highest_stat_value()
	for role_id in _role_cards.keys():
		if not _roles.has(role_id):
			continue

		var role_data: Dictionary = _roles[role_id]
		var card_data: Dictionary = _role_cards[role_id]
		var name_label = card_data.get("name", null) as Label
		var portrait = card_data.get("portrait", null) as TextureRect

		if name_label != null:
			name_label.text = str(role_data.get("name", role_id)).to_upper()
		if portrait != null and role_data.get("portrait", null) is Texture2D:
			portrait.texture = role_data.get("portrait", null)

		_set_stat_row(card_data["hp"], int(role_data.get("max_hp", 0)), max_stat)
		_set_stat_row(card_data["mp"], int(role_data.get("max_mana", 0)), max_stat)
		_set_stat_row(card_data["attack"], int(role_data.get("attack", 0)), max_stat)
		_set_stat_row(card_data["defense"], int(role_data.get("defense", 0)), max_stat)
		_set_stat_row(card_data["speed"], int(role_data.get("speed", 0)), max_stat)


func _set_stat_row(row: Dictionary, value: int, max_stat: int) -> void:
	var bar = row.get("bar", null) as ProgressBar
	var value_label = row.get("value", null) as Label
	if bar != null:
		bar.max_value = max(max_stat, 1)
		bar.value = value
	if value_label != null:
		value_label.text = str(value)


func _select_role(role_id: String) -> void:
	if not _roles.has(role_id):
		return

	_selected_role = role_id
	var selected_data: Dictionary = _roles[role_id]
	for current_role_id in _role_cards.keys():
		var card_data: Dictionary = _role_cards[current_role_id]
		var card = card_data.get("card", null) as PanelContainer
		if card == null:
			continue

		var role_data: Dictionary = _roles[current_role_id]
		var is_selected = current_role_id == role_id
		card.add_theme_stylebox_override("panel", _make_card_style(is_selected, role_data.get("accent", Color.WHITE)))
		card.modulate = Color(1, 1, 1, 1) if is_selected else Color(0.82, 0.88, 0.9, 1)

	_detail_name_label.text = "%s | Habilidad inicial: %s" % [
		str(selected_data.get("name", "Rol")).to_upper(),
		str(selected_data.get("skill_text", "-"))
	]
	_detail_description_label.text = str(selected_data.get("description", ""))
	_detail_stats_label.text = "HP %d  MP %d  ATQ %d  DEF %d  VEL %d" % [
		int(selected_data.get("max_hp", 0)),
		int(selected_data.get("max_mana", 0)),
		int(selected_data.get("attack", 0)),
		int(selected_data.get("defense", 0)),
		int(selected_data.get("speed", 0))
	]


func _on_choose_role_pressed(role_id: String) -> void:
	if _buttons_locked:
		return

	_buttons_locked = true
	_select_role(role_id)
	_set_buttons_disabled(true)

	var role_name = str(_roles[role_id].get("name", "Rol"))
	_cache_selected_role(role_id)
	var persisted = _persist_selected_role(role_id)
	if persisted:
		_status_label.text = "%s aplicado. Entrando a la aldea..." % role_name
	else:
		_status_label.text = "%s elegido. Entrando con datos locales..." % role_name

	await get_tree().create_timer(0.28).timeout
	get_tree().change_scene_to_file(WORLD_SCENE)


func _cache_selected_role(role_id: String) -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("cache_selected_player_role"):
		return

	var role_data: Dictionary = _roles[role_id].duplicate(true)
	role_data["role_id"] = role_id
	role_data["character_name"] = "Ariadna"
	role_data["current_hp"] = int(role_data.get("max_hp", 1))
	role_data["current_mana"] = int(role_data.get("max_mana", 0))
	database_manager.call("cache_selected_player_role", role_data)


func _persist_selected_role(role_id: String) -> bool:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("apply_player_role"):
		return false

	var character_id = _get_active_player_character_id(database_manager)
	if character_id <= 0:
		return false

	var role_data: Dictionary = _roles[role_id]
	var skill_ids = role_data.get("skill_ids", [])
	if skill_ids is not Array:
		skill_ids = []

	return bool(database_manager.call(
		"apply_player_role",
		SAVE_SLOT_ID,
		character_id,
		int(role_data.get("class_id", 0)),
		skill_ids
	))


func _get_active_player_character_id(database_manager: Node) -> int:
	if not database_manager.has_method("get_characters"):
		return 1

	var rows = database_manager.call("get_characters", SAVE_SLOT_ID)
	if rows is not Array:
		return 1

	var fallback_id = 0
	for row in rows:
		if row is not Dictionary:
			continue
		if str(row.get("character_type", "")) != "player":
			continue
		if int(row.get("is_active", 1)) != 1:
			continue

		var character_id = int(row.get("id", 0))
		if fallback_id == 0:
			fallback_id = character_id
		if str(row.get("name", "")).strip_edges().to_lower() == "ariadna":
			return character_id

	return fallback_id


func _set_buttons_disabled(disabled: bool) -> void:
	for role_id in _role_cards.keys():
		var card_data: Dictionary = _role_cards[role_id]
		var button = card_data.get("button", null) as TextureButton
		if button != null:
			button.disabled = disabled
	if _back_button != null:
		_back_button.disabled = disabled


func _on_back_pressed() -> void:
	if _buttons_locked:
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _play_intro() -> void:
	if _main_panel == null:
		return

	_main_panel.modulate.a = 0.0
	var target_scale = _main_panel.scale
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_main_panel, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_main_panel, "scale", target_scale, 0.25).from(target_scale * 0.97)


func _fit_panel_to_viewport() -> void:
	if _main_panel == null:
		return

	await get_tree().process_frame
	if _main_panel == null:
		return

	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var panel_size = _main_panel.get_combined_minimum_size()
	panel_size.x = max(panel_size.x, _main_panel.size.x)
	panel_size.y = max(panel_size.y, _main_panel.size.y)
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return

	var max_size = viewport_size - Vector2(24.0, 28.0)
	var fit_scale = min(max_size.x / panel_size.x, max_size.y / panel_size.y, 0.92)
	_main_panel.pivot_offset = panel_size * 0.5
	_main_panel.scale = Vector2(fit_scale, fit_scale)


func _make_card_style(selected: bool, accent: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.17, 0.98) if selected else Color(0.05, 0.09, 0.12, 0.96)
	style.border_width_left = 3 if selected else 2
	style.border_width_top = 3 if selected else 2
	style.border_width_right = 3 if selected else 2
	style.border_width_bottom = 3 if selected else 2
	style.border_color = accent if selected else Color(0.62, 0.75, 0.82, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	return style


func _get_highest_stat_value() -> int:
	var max_value = 1
	for role_id in _roles.keys():
		var role_data: Dictionary = _roles[role_id]
		max_value = max(max_value, int(role_data.get("max_hp", 0)))
		max_value = max(max_value, int(role_data.get("max_mana", 0)))
		max_value = max(max_value, int(role_data.get("attack", 0)))
		max_value = max(max_value, int(role_data.get("defense", 0)))
		max_value = max(max_value, int(role_data.get("speed", 0)))
	return max_value
