extends CharacterBody2D

@export var SPEED: float = 150.0
@export var RUN_SPEED: float = 240.0
@export var JUMP_FORCE: float = 400.0
@export var FAKE_GRAVITY: float = 1500.0

const INVENTORY_UI_SCENE: PackedScene = preload("res://Scenes/ui/inventory_ui.tscn")
const INVENTORY_TOGGLE_ACTION = "inventory_toggle"
const INVENTORY_SLOT_COUNT = 34
const SAVE_SLOT_ID = 1

const ANIM_IDLE = "idle"
const ANIM_RUN = "run"
const ANIM_ATTACK = "golpe"
const ANIM_HURT = "hurt"
const ANIM_DEATH = "muerte"
const WALK_ANIMATION_SPEED = 0.82
const RUN_ANIMATION_SPEED = 1.2

var z_height = 0.0
var z_velocity = 0.0
var is_jumping = false
var is_attacking = false
var is_dead = false
var is_hurt = false
var is_running = false
var spawn_position = Vector2.ZERO
var _base_anim_offset_x = 0.0

var inventory_data: InventoryData = null
var inventory_ui: InventoryUI = null

@onready var anim: AnimatedSprite2D = $animaciones


func _ready() -> void:
	is_attacking = false
	is_hurt = false
	spawn_position = global_position
	_base_anim_offset_x = absf(anim.offset.x)
	_set_facing_left(anim.flip_h)
	anim.speed_scale = 1.0
	anim.play(ANIM_IDLE)

	if anim.sprite_frames:
		anim.sprite_frames.set_animation_loop(ANIM_ATTACK, false)
		anim.sprite_frames.set_animation_loop(ANIM_HURT, false)
		anim.sprite_frames.set_animation_loop(ANIM_DEATH, false)

	_initialize_inventory()


func _exit_tree() -> void:
	if inventory_data != null:
		_persist_current_inventory_layout(false)


func _input(event: InputEvent) -> void:
	if is_dead:
		return

	if not _is_inventory_toggle_event(event):
		return

	get_viewport().set_input_as_handled()
	_toggle_inventory()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	handle_movement(delta)
	handle_jump(delta)
	handle_attack()
	update_animations()


func handle_movement(_delta: float) -> void:
	if is_attacking or is_hurt or is_inventory_open():
		is_running = false
		velocity = Vector2.ZERO
		return

	var direction = _get_movement_direction()
	if direction:
		is_running = _is_run_pressed()
		var current_speed = RUN_SPEED if is_running else SPEED
		velocity = direction * current_speed
		if direction.x != 0:
			_set_facing_left(direction.x < 0)
	else:
		is_running = false
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()


func _get_movement_direction() -> Vector2:
	var arrow_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd_direction = Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)

	return (arrow_direction + wasd_direction).limit_length(1.0)


func _set_facing_left(is_facing_left: bool) -> void:
	anim.flip_h = is_facing_left
	anim.offset.x = -_base_anim_offset_x if is_facing_left else _base_anim_offset_x


func handle_jump(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") and not is_jumping and not is_attacking and not is_inventory_open():
		z_velocity = JUMP_FORCE
		is_jumping = true

	if is_jumping:
		z_height += z_velocity * delta
		z_velocity -= FAKE_GRAVITY * delta

		if z_height <= 0.0:
			z_height = 0.0
			is_jumping = false

	anim.position.y = -z_height


func handle_attack() -> void:
	if Input.is_action_just_pressed("click_izquierdo") and not is_attacking and not is_jumping and not is_hurt and not is_inventory_open():
		is_attacking = true
		anim.speed_scale = 1.0
		anim.play(ANIM_ATTACK)

		await anim.animation_finished
		is_attacking = false


func update_animations() -> void:
	if is_dead or is_attacking or is_hurt:
		return

	if velocity != Vector2.ZERO:
		anim.speed_scale = RUN_ANIMATION_SPEED if is_running else WALK_ANIMATION_SPEED
		anim.play(ANIM_RUN)
	else:
		anim.speed_scale = 1.0
		anim.play(ANIM_IDLE)


func recibir_daño() -> void:
	if is_dead or is_hurt:
		return

	is_hurt = true
	is_attacking = false
	anim.speed_scale = 1.0
	anim.play(ANIM_HURT)

	await anim.animation_finished
	is_hurt = false


func morir() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_hurt = false
	is_running = false
	is_jumping = false
	z_height = 0.0
	z_velocity = 0.0
	velocity = Vector2.ZERO
	close_inventory()
	anim.position.y = 0.0
	anim.speed_scale = 1.0
	anim.play(ANIM_DEATH)

	await anim.animation_finished
	_respawn()


func pickup_item(item_data: ItemData, amount: int = 1) -> int:
	if inventory_data == null:
		return amount

	if _save_item_to_database(item_data, amount):
		sync_inventory_from_database()
		return 0

	return inventory_data.add_item(item_data, amount)


func add_item_to_local_inventory(item_data: ItemData, amount: int = 1) -> int:
	if inventory_data == null:
		return amount
	return inventory_data.add_item(item_data, amount)


func can_fit_item_in_inventory(item_data: ItemData, amount: int = 1) -> bool:
	return inventory_data != null and inventory_data.get_remaining_after_add(item_data, amount) <= 0


func sync_inventory_from_database() -> bool:
	if inventory_data == null:
		return false

	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("get_inventory"):
		return false

	var character_id = _get_active_player_character_id(database_manager)
	if character_id <= 0:
		return false

	var rows = database_manager.call("get_inventory", character_id, SAVE_SLOT_ID)
	if rows is not Array:
		return false

	inventory_data.clear(false)
	for row in rows:
		if row is not Dictionary:
			continue

		var slot_index = int(row.get("slot_index", -1))
		if slot_index < 0 or slot_index >= inventory_data.slot_count:
			continue

		var database_item_id = int(row.get("item_id", 0))
		var quantity = int(row.get("quantity", 0))
		var item_data_from_database = _build_item_data_from_database_row(row)
		if item_data_from_database == null or quantity <= 0:
			continue

		inventory_data.set_slot(
			slot_index,
			item_data_from_database,
			quantity,
			int(row.get("id", row.get("inventory_id", 0))),
			database_item_id,
			false
		)

	inventory_data.inventory_changed.emit()
	return true


func is_inventory_open() -> bool:
	return inventory_ui != null and inventory_ui.is_inventory_open()


func close_inventory() -> void:
	if inventory_ui == null:
		return
	inventory_ui.set_inventory_visible(false)


func save_inventory_layout() -> void:
	_persist_current_inventory_layout()


func _initialize_inventory() -> void:
	inventory_data = InventoryData.new(INVENTORY_SLOT_COUNT)
	inventory_ui = INVENTORY_UI_SCENE.instantiate() as InventoryUI
	if inventory_ui == null:
		push_warning("No se pudo crear la UI de inventario.")
		return

	add_child(inventory_ui)
	inventory_ui.bind_inventory(inventory_data)
	inventory_ui.inventory_slots_moved.connect(_on_inventory_slots_moved)
	sync_inventory_from_database()


func _toggle_inventory() -> void:
	if inventory_ui == null:
		return
	inventory_ui.toggle_inventory()


func _is_inventory_toggle_event(event: InputEvent) -> bool:
	if InputMap.has_action(INVENTORY_TOGGLE_ACTION) and event.is_action_pressed(INVENTORY_TOGGLE_ACTION):
		return true

	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_I or key_event.physical_keycode == KEY_I
		)

	return false


func _is_run_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)


func set_spawn_position(new_spawn_position: Vector2) -> void:
	spawn_position = new_spawn_position


func _save_item_to_database(item_data: ItemData, amount: int) -> bool:
	if item_data == null or amount <= 0:
		return false

	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("add_item_to_inventory"):
		return false

	var character_id = _get_active_player_character_id(database_manager)
	var database_item_id = _ensure_database_item_id(database_manager, item_data)
	if character_id <= 0 or database_item_id <= 0:
		return false
	if not can_fit_item_in_inventory(item_data, amount):
		return false

	if not bool(database_manager.call("add_item_to_inventory", character_id, database_item_id, amount, SAVE_SLOT_ID)):
		return false

	return _commit_inventory_autosave(database_manager)


func _persist_current_inventory_layout(refresh_after_save: bool = true) -> void:
	if inventory_data == null:
		return

	var database_manager = _get_database_manager()
	if database_manager == null or not database_manager.has_method("replace_inventory"):
		return

	var character_id = _get_active_player_character_id(database_manager)
	if character_id <= 0:
		return

	var slot_entries: Array = []
	for index in range(inventory_data.slot_count):
		var slot = inventory_data.get_slot(index)
		if slot == null or slot.is_empty():
			continue

		var database_item_id = slot.database_item_id
		if database_item_id <= 0 and slot.item_data != null:
			database_item_id = _ensure_database_item_id(database_manager, slot.item_data)
		if database_item_id <= 0:
			continue

		slot_entries.append({
			"slot_index": index,
			"item_id": database_item_id,
			"quantity": slot.quantity
		})

	if refresh_after_save and bool(database_manager.call("replace_inventory", character_id, SAVE_SLOT_ID, slot_entries)):
		sync_inventory_from_database()
	elif not refresh_after_save:
		database_manager.call("replace_inventory", character_id, SAVE_SLOT_ID, slot_entries)


func _on_inventory_slots_moved(_from_index: int, _to_index: int) -> void:
	_persist_current_inventory_layout()


func _commit_inventory_autosave(database_manager: Node) -> bool:
	if database_manager == null:
		return false
	if not database_manager.has_method("commit_manual_save"):
		return true
	return bool(database_manager.call("commit_manual_save", SAVE_SLOT_ID))


func _build_item_data_from_database_row(row: Dictionary) -> ItemData:
	var loaded_item_data: ItemData = null
	var icon_path = str(row.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var loaded_resource = load(icon_path)
		if loaded_resource is ItemData:
			loaded_item_data = (loaded_resource as ItemData).duplicate(true) as ItemData

	var built_item_data: ItemData = loaded_item_data if loaded_item_data != null else ItemData.new()
	built_item_data.database_item_id = int(row.get("item_id", 0))
	built_item_data.item_id = StringName(str(row.get("item_name", "item")).to_lower().replace(" ", "_"))
	built_item_data.display_name = str(row.get("item_name", row.get("name", "Objeto")))
	built_item_data.description = str(row.get("description", ""))
	built_item_data.item_type = str(row.get("item_type", "misc"))
	built_item_data.rarity = str(row.get("rarity", "common"))
	built_item_data.price = int(row.get("price", 0))
	built_item_data.max_stack = max(int(row.get("max_stack", 1)), 1)
	built_item_data.usable_in_battle = bool(row.get("usable_in_battle", false))
	built_item_data.effect_data = _parse_effect_data(row.get("effect_data", {}))

	if built_item_data.icon_texture == null and not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_resource = load(icon_path)
		if icon_resource is Texture2D:
			built_item_data.icon_texture = icon_resource as Texture2D

	return built_item_data


func _ensure_database_item_id(database_manager: Node, item_data: ItemData) -> int:
	if item_data == null:
		return 0

	if item_data.database_item_id > 0:
		return item_data.database_item_id

	var item_name = _get_item_display_name(item_data)
	if item_name.is_empty():
		return 0

	if database_manager.has_method("get_item_by_name"):
		var existing_item = database_manager.call("get_item_by_name", item_name)
		if existing_item is Dictionary and not existing_item.is_empty():
			item_data.database_item_id = int(existing_item.get("id", 0))
			return item_data.database_item_id

	if database_manager.has_method("insert_data"):
		var inserted_id = int(database_manager.call("insert_data", "items", _build_database_item_values(item_data, item_name)))
		if inserted_id > 0:
			item_data.database_item_id = inserted_id
			return inserted_id

	return 0


func _build_database_item_values(item_data: ItemData, item_name: String) -> Dictionary:
	return {
		"name": item_name,
		"description": item_data.description,
		"item_type": item_data.item_type,
		"rarity": item_data.rarity,
		"price": max(item_data.price, 0),
		"icon": _get_item_icon_path(item_data),
		"max_stack": max(item_data.max_stack, 1),
		"usable_in_battle": 1 if item_data.usable_in_battle else 0,
		"effect_data": JSON.stringify(item_data.effect_data)
	}


func _get_item_display_name(item_data: ItemData) -> String:
	if item_data == null:
		return ""
	if not item_data.display_name.strip_edges().is_empty():
		return item_data.display_name.strip_edges()
	if item_data.item_id != StringName():
		return str(item_data.item_id)
	return "Objeto"


func _get_item_icon_path(item_data: ItemData) -> String:
	if item_data == null:
		return ""
	if not item_data.resource_path.is_empty():
		return item_data.resource_path
	if item_data.icon_texture != null and not item_data.icon_texture.resource_path.is_empty():
		return item_data.icon_texture.resource_path
	return ""


func _parse_effect_data(raw_effect_data: Variant) -> Dictionary:
	if raw_effect_data is Dictionary:
		return raw_effect_data.duplicate(true)
	if raw_effect_data is String:
		var parsed = JSON.parse_string(raw_effect_data)
		if parsed is Dictionary:
			return parsed
	return {}


func _get_active_player_character_id(database_manager: Node) -> int:
	if database_manager == null or not database_manager.has_method("get_characters"):
		return 0

	var characters = database_manager.call("get_characters", SAVE_SLOT_ID)
	if characters is not Array:
		return 0

	var first_player_id = 0
	for character in characters:
		if character is not Dictionary:
			continue
		if str(character.get("character_type", "")) != "player":
			continue
		var character_id = int(character.get("id", 0))
		if first_player_id == 0:
			first_player_id = character_id
		if int(character.get("is_active", 1)) == 1:
			return character_id

	return first_player_id


func _get_database_manager() -> Node:
	return get_node_or_null("/root/GameDatabase")


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	z_height = 0.0
	z_velocity = 0.0
	is_jumping = false
	is_attacking = false
	is_hurt = false
	is_dead = false
	is_running = false
	anim.position.y = 0.0
	anim.speed_scale = 1.0
	anim.play(ANIM_IDLE)
