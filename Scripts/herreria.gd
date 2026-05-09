extends Node2D

const PLAYER_NODE_PATH = NodePath("player")
const ALDEA_SCENE = "res://Scenes/world/aldea_principal.tscn"
const INTERACT_ACTION = "interact"
const SAVE_SLOT_ID = 1
const SHOP_ROOT_PATH = NodePath("ShopLayer/ShopRoot")
const GOLD_LABEL_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/Header/GoldLabel")
const STATUS_LABEL_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/StatusLabel")
const CONFIRMATION_PANEL_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ConfirmationPanel")
const CONFIRMATION_LABEL_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ConfirmationPanel/Margin/Row/ConfirmationLabel")
const CLOSE_BUTTON_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/Header/CloseButton")
const BUY_BUTTON_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ConfirmationPanel/Margin/Row/BuyButton")
const CANCEL_BUTTON_PATH = NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ConfirmationPanel/Margin/Row/CancelButton")
const SHOP_ARMORS = [
	{
		"name": "Armadura de Cuero",
		"description": "Ligera y fiable.",
		"cost": 90,
		"defense_bonus": 6,
		"icon_path": "res://assets/items/generated_pixel_equipment/armor_01.png",
		"card_path": NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ShopGrid/LeatherCard"),
		"button_path": NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ShopGrid/LeatherCard/Margin/Layout/IconButton")
	},
	{
		"name": "Armadura de Malla",
		"description": "Anillas reforzadas.",
		"rarity": "uncommon",
		"cost": 145,
		"defense_bonus": 10,
		"icon_path": "res://assets/items/generated_pixel_equipment/armor_06.png",
		"card_path": NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ShopGrid/MailCard"),
		"button_path": NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ShopGrid/MailCard/Margin/Layout/IconButton")
	},
	{
		"name": "Coraza de Guardia",
		"description": "Placas resistentes.",
		"rarity": "rare",
		"cost": 220,
		"defense_bonus": 15,
		"icon_path": "res://assets/items/generated_pixel_equipment/armor_14.png",
		"card_path": NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ShopGrid/GuardCard"),
		"button_path": NodePath("ShopLayer/ShopRoot/Center/ShopPanel/Margin/Layout/ShopGrid/GuardCard/Margin/Layout/IconButton")
	}
]

var _player_can_exit = false
var _player_can_talk_to_smith = false
var _selected_shop_item_index = -1
var _cached_gold = 0
var _shop_root: Control = null
var _gold_label: Label = null
var _status_label: Label = null
var _confirmation_panel: Control = null
var _confirmation_label: Label = null
var _shop_item_cards: Array = []


func _ready() -> void:
	_bind_shop_nodes()
	_connect_shop_signals()
	_hide_purchase_confirmation()
	_refresh_shop_gold()


func _input(event: InputEvent) -> void:
	if _is_cancel_event(event) and _is_shop_open():
		_mark_input_handled()
		_close_blacksmith_shop()
		return

	if not _is_interact_event(event):
		return

	if _is_shop_open():
		_mark_input_handled()
		_close_blacksmith_shop()
		return

	if _player_can_talk_to_smith and not _is_player_inventory_open():
		_mark_input_handled()
		_open_blacksmith_shop()
		return

	if _player_can_exit:
		_mark_input_handled()
		_try_exit_herreria()


func _on_exit_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit = true


func _on_exit_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit = false


func _on_smith_interaction_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_talk_to_smith = true


func _on_smith_interaction_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_talk_to_smith = false


func _try_exit_herreria() -> bool:
	if not _player_can_exit or _is_shop_open():
		return false

	if _is_player_inventory_open():
		return false

	var tree = get_tree()
	if tree == null:
		return false

	_persist_player_inventory_state()
	return tree.change_scene_to_file(ALDEA_SCENE) == OK


func _open_blacksmith_shop() -> void:
	if _shop_root == null:
		return

	_selected_shop_item_index = -1
	_hide_purchase_confirmation()
	_refresh_shop_items()
	_refresh_shop_gold()
	if _status_label != null:
		_status_label.text = "Elige una armadura para verla en el mostrador."
	_shop_root.visible = true
	_lock_player_controls(true)


func _close_blacksmith_shop() -> void:
	if _shop_root != null:
		_shop_root.visible = false
	_lock_player_controls(false)


func _bind_shop_nodes() -> void:
	_shop_root = get_node_or_null(SHOP_ROOT_PATH) as Control
	_gold_label = get_node_or_null(GOLD_LABEL_PATH) as Label
	_status_label = get_node_or_null(STATUS_LABEL_PATH) as Label
	_confirmation_panel = get_node_or_null(CONFIRMATION_PANEL_PATH) as Control
	_confirmation_label = get_node_or_null(CONFIRMATION_LABEL_PATH) as Label

	_shop_item_cards.clear()
	for item in SHOP_ARMORS:
		var card = get_node_or_null(item.get("card_path", NodePath(""))) as Control
		_shop_item_cards.append(card)


func _connect_shop_signals() -> void:
	_connect_pressed(CLOSE_BUTTON_PATH, _close_blacksmith_shop)
	_connect_pressed(BUY_BUTTON_PATH, _on_confirm_purchase_pressed)
	_connect_pressed(CANCEL_BUTTON_PATH, _hide_purchase_confirmation)

	for index in range(SHOP_ARMORS.size()):
		var button_path = SHOP_ARMORS[index].get("button_path", NodePath(""))
		_connect_pressed(button_path, _on_shop_item_pressed.bind(index))


func _connect_pressed(button_path: NodePath, target_callable: Callable) -> void:
	var button = get_node_or_null(button_path)
	if button == null or not button.has_signal("pressed"):
		return
	if not button.is_connected("pressed", target_callable):
		button.connect("pressed", target_callable)


func _on_shop_item_pressed(index: int) -> void:
	if index < 0 or index >= SHOP_ARMORS.size():
		return

	_selected_shop_item_index = index
	var item = SHOP_ARMORS[index]
	if _confirmation_label != null:
		_confirmation_label.text = "Comprar %s por %d oro?" % [
			str(item.get("name", "Armadura")),
			int(item.get("cost", 0))
		]
	if _confirmation_panel != null:
		_confirmation_panel.visible = true
	if _status_label != null:
		_status_label.text = str(item.get("description", ""))
	_refresh_shop_items()


func _on_confirm_purchase_pressed() -> void:
	if _selected_shop_item_index < 0 or _selected_shop_item_index >= SHOP_ARMORS.size():
		if _status_label != null:
			_status_label.text = "Elige primero una armadura."
		return

	var item = SHOP_ARMORS[_selected_shop_item_index]
	var cost = int(item.get("cost", 0))
	var current_gold = _get_player_gold()
	if current_gold < cost:
		if _status_label != null:
			_status_label.text = "No tienes oro suficiente."
		return

	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("add_gold"):
		if _status_label != null:
			_status_label.text = "No se pudo acceder al oro de la partida."
		return

	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player == null or not player.has_method("pickup_item"):
		if _status_label != null:
			_status_label.text = "No se encontro el inventario del jugador."
		return

	var item_id = _ensure_shop_item_database_id(item)
	var purchased_item = _build_local_shop_item(item, item_id)
	if purchased_item == null:
		if _status_label != null:
			_status_label.text = "No se pudo preparar la armadura."
		return

	if player.has_method("can_fit_item_in_inventory"):
		if not bool(player.call("can_fit_item_in_inventory", purchased_item, 1)):
			if _status_label != null:
				_status_label.text = "Inventario lleno."
			return

	if not bool(database_manager.call("add_gold", SAVE_SLOT_ID, -cost)):
		if _status_label != null:
			_status_label.text = "No se pudo cobrar la compra."
		return

	var remaining = int(player.call("pickup_item", purchased_item, 1))
	if remaining > 0:
		database_manager.call("add_gold", SAVE_SLOT_ID, cost)
		_refresh_shop_gold()
		if _status_label != null:
			_status_label.text = "No se pudo añadir la armadura al inventario."
		return

	_refresh_shop_gold()
	_hide_purchase_confirmation()
	if _status_label != null:
		_status_label.text = "%s comprada. Oro restante: %d" % [
			str(item.get("name", "Armadura")),
			_cached_gold
		]


func _hide_purchase_confirmation() -> void:
	_selected_shop_item_index = -1
	if _confirmation_panel != null:
		_confirmation_panel.visible = false
	if _confirmation_label != null:
		_confirmation_label.text = ""
	_refresh_shop_items()


func _refresh_shop_gold() -> void:
	_cached_gold = _get_player_gold()
	if _gold_label != null:
		_gold_label.text = "Oro: %d" % _cached_gold


func _refresh_shop_items() -> void:
	for index in range(_shop_item_cards.size()):
		var card = _shop_item_cards[index] as Control
		if card == null:
			continue
		card.modulate = Color(1.1, 1.02, 0.84, 1.0) if index == _selected_shop_item_index else Color.WHITE


func _get_player_gold() -> int:
	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("get_game_state"):
		return _cached_gold

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		return _cached_gold

	return max(int(game_state.get("gold", _cached_gold)), 0)


func _ensure_shop_item_database_id(item: Dictionary) -> int:
	var database_manager = _get_database_manager()
	if database_manager == null:
		return 0

	var item_name = str(item.get("name", ""))
	if item_name.is_empty():
		return 0

	if database_manager.has_method("get_item_by_name"):
		var existing_item = database_manager.call("get_item_by_name", item_name)
		if existing_item is Dictionary and not existing_item.is_empty():
			return int(existing_item.get("id", 0))

	if database_manager.has_method("insert_data"):
		var inserted_id = int(database_manager.call("insert_data", "items", _build_database_item_values(item)))
		if inserted_id > 0:
			return inserted_id

	if database_manager.has_method("get_item_by_name"):
		var retry_item = database_manager.call("get_item_by_name", item_name)
		if retry_item is Dictionary and not retry_item.is_empty():
			return int(retry_item.get("id", 0))

	return 0


func _build_database_item_values(item: Dictionary) -> Dictionary:
	return {
		"name": str(item.get("name", "Armadura")),
		"description": str(item.get("description", "Armadura de herreria.")),
		"item_type": "armor",
		"rarity": str(item.get("rarity", "common")),
		"price": int(item.get("cost", 0)),
		"icon": str(item.get("icon_path", "")),
		"max_stack": 1,
		"usable_in_battle": 0,
		"effect_data": JSON.stringify({"defense_bonus": int(item.get("defense_bonus", 0))})
	}


func _build_local_shop_item(item: Dictionary, database_item_id: int = 0) -> ItemData:
	var local_item = ItemData.new()
	local_item.item_id = StringName(str(item.get("name", "armadura")).to_lower().replace(" ", "_"))
	local_item.database_item_id = max(database_item_id, 0)
	local_item.display_name = str(item.get("name", "Armadura"))
	local_item.description = str(item.get("description", ""))
	local_item.item_type = "armor"
	local_item.rarity = str(item.get("rarity", "common"))
	local_item.price = int(item.get("cost", 0))
	local_item.icon_texture = load(str(item.get("icon_path", ""))) as Texture2D
	local_item.max_stack = 1
	local_item.usable_in_battle = false
	local_item.effect_data = {"defense_bonus": int(item.get("defense_bonus", 0))}
	return local_item


func _lock_player_controls(is_locked: bool) -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player == null:
		return

	if is_locked and player is CharacterBody2D:
		var body = player as CharacterBody2D
		body.velocity = Vector2.ZERO

	player.set_physics_process(not is_locked)
	player.set_process_input(not is_locked)


func _persist_player_inventory_state() -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("save_inventory_layout"):
		player.call("save_inventory_layout")


func _is_shop_open() -> bool:
	return _shop_root != null and _shop_root.visible


func _is_player_inventory_open() -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH)
	return player != null and player.has_method("is_inventory_open") and bool(player.call("is_inventory_open"))


func _get_database_manager() -> Node:
	return get_node_or_null("/root/GameDatabase")


func _is_player_body(body: Node2D) -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	return body != null and player != null and body == player


func _is_interact_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if InputMap.has_action(INTERACT_ACTION) and event.is_action_pressed(INTERACT_ACTION):
			return true
		return key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E

	if InputMap.has_action(INTERACT_ACTION) and event.is_action_pressed(INTERACT_ACTION):
		return true

	return false


func _is_cancel_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		)

	return false


func _mark_input_handled() -> void:
	var viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
