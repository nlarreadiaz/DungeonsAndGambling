extends Node2D

const PLAYER_NODE_PATH = NodePath("player")
const SAVE_SLOT_ID = 1
const INTERACT_ACTION = "interact"
const ALDEA_PRINCIPAL_SCENE = "res://Scenes/world/aldea_principal.tscn"
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
const SLOTS_SCENE: PackedScene = preload("res://Scenes/slots.tscn")
const EXIT_SHAPE_PATH = NodePath("salir/salir")
const SLOT_MACHINE_PATH = NodePath("Node2D/Slotmachine")
const ALDEA_TAVERN_DOOR_POSITION = Vector2(562, 28)

var _player_can_exit = false
var _player_can_use_slots = false
var _slots_layer: CanvasLayer = null


func _ready() -> void:
	_apply_saved_player_position()
	_setup_exit_area()
	_setup_slot_machine_area()


func _input(event: InputEvent) -> void:
	if not _is_interact_event(event):
		return

	if _slots_layer != null:
		return

	if _player_can_use_slots:
		get_viewport().set_input_as_handled()
		_open_slots_overlay()
		return

	if _player_can_exit:
		get_viewport().set_input_as_handled()
		_exit_to_aldea()


func _setup_exit_area() -> void:
	var exit_shape = get_node_or_null(EXIT_SHAPE_PATH) as CollisionShape2D
	if exit_shape == null or exit_shape.shape == null:
		push_warning("No se encontro la CollisionShape2D salir de la taberna.")
		return

	var exit_area = Area2D.new()
	exit_area.name = "ExitArea"
	exit_area.collision_layer = 0
	exit_area.monitorable = false
	exit_area.monitoring = true
	add_child(exit_area)
	exit_area.global_transform = exit_shape.global_transform

	var area_shape = CollisionShape2D.new()
	area_shape.name = "CollisionShape2D"
	area_shape.shape = exit_shape.shape
	exit_area.add_child(area_shape)

	exit_area.body_entered.connect(_on_exit_area_body_entered)
	exit_area.body_exited.connect(_on_exit_area_body_exited)


func _setup_slot_machine_area() -> void:
	var slot_machine = get_node_or_null(SLOT_MACHINE_PATH) as Sprite2D
	if slot_machine == null:
		push_warning("No se encontro el Sprite2D Slotmachine en la taberna.")
		return

	var slot_area = Area2D.new()
	slot_area.name = "SlotMachineArea"
	slot_area.collision_layer = 0
	slot_area.monitorable = false
	slot_area.monitoring = true
	add_child(slot_area)
	slot_area.global_position = slot_machine.global_position

	var shape = RectangleShape2D.new()
	shape.size = Vector2(42, 44)
	var area_shape = CollisionShape2D.new()
	area_shape.name = "CollisionShape2D"
	area_shape.shape = shape
	slot_area.add_child(area_shape)

	slot_area.body_entered.connect(_on_slot_machine_area_body_entered)
	slot_area.body_exited.connect(_on_slot_machine_area_body_exited)


func _on_exit_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit = true


func _on_exit_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit = false


func _on_slot_machine_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_use_slots = true


func _on_slot_machine_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_use_slots = false


func _open_slots_overlay() -> void:
	if _slots_layer != null:
		return

	var slots_instance = SLOTS_SCENE.instantiate()
	if slots_instance == null:
		return

	_slots_layer = CanvasLayer.new()
	_slots_layer.name = "SlotsOverlay"
	_slots_layer.layer = 20
	_slots_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_slots_layer)

	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slots_layer.add_child(dim)

	slots_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_slots_layer.add_child(slots_instance)
	if slots_instance.has_signal("closed"):
		slots_instance.connect("closed", Callable(self, "_close_slots_overlay"))

	get_tree().paused = true


func _close_slots_overlay() -> void:
	get_tree().paused = false
	if _slots_layer != null:
		_slots_layer.queue_free()
		_slots_layer = null


func _exit_to_aldea() -> void:
	var battle_manager = get_node_or_null(BATTLE_MANAGER_ROOT_PATH)
	if battle_manager != null and battle_manager.has_method("return_to_scene"):
		battle_manager.call("return_to_scene", ALDEA_PRINCIPAL_SCENE, ALDEA_TAVERN_DOOR_POSITION, "tavern_exit")
		return
	get_tree().change_scene_to_file(ALDEA_PRINCIPAL_SCENE)


func save_current_game_from_pause() -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	var database_manager = get_node_or_null("/root/GameDatabase")
	if player == null or database_manager == null or not database_manager.has_method("save_player_world_position"):
		return false

	if player.has_method("save_inventory_layout"):
		player.call("save_inventory_layout")
	return bool(database_manager.call(
		"save_player_world_position",
		SAVE_SLOT_ID,
		_get_current_scene_path("res://Scenes/world/tavern.tscn"),
		player.global_position
	))


func _get_current_scene_path(fallback_scene_path: String) -> String:
	var tree = get_tree()
	if tree != null and tree.current_scene != null and not tree.current_scene.scene_file_path.is_empty():
		return tree.current_scene.scene_file_path
	return fallback_scene_path


func _apply_saved_player_position() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_game_state"):
		return

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		return

	var important_flags = _parse_flags(game_state.get("important_flags", {}))
	var saved_scene_path = str(important_flags.get("current_scene_path", ""))
	var saved_location = str(game_state.get("current_location", ""))
	if saved_scene_path != "res://Scenes/world/tavern.tscn" and saved_location != "tavern":
		return

	var player_position = important_flags.get("player_position", important_flags.get("autosave_position", {}))
	if player_position is not Dictionary:
		return

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return

	var saved_position = Vector2(
		float(player_position.get("x", player.global_position.x)),
		float(player_position.get("y", player.global_position.y))
	)
	player.global_position = saved_position
	if player.has_method("set_spawn_position"):
		player.call("set_spawn_position", saved_position)
	if database_manager.has_method("cache_player_world_position"):
		database_manager.call("cache_player_world_position", "res://Scenes/world/tavern.tscn", saved_position)


func _parse_flags(raw_flags: Variant) -> Dictionary:
	if raw_flags is Dictionary:
		return raw_flags.duplicate(true)
	if raw_flags is String:
		var parsed = JSON.parse_string(raw_flags)
		if parsed is Dictionary:
			return parsed.duplicate(true)
	return {}


func _is_player_body(body: Node2D) -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	return body != null and player != null and body == player


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed(INTERACT_ACTION):
		return true
	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
		)
	return false
