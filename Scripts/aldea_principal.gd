extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/options_ingame.tscn")

const PLAYER_NODE_PATH = NodePath("player")
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
const CAMERA_LIMIT_LEFT = -560
const CAMERA_LIMIT_TOP = -360
const CAMERA_LIMIT_RIGHT = 780
const CAMERA_LIMIT_BOTTOM = 920

var options_ingame: CanvasLayer = null


func _ready() -> void:
	_apply_battle_return_position()
	_configure_player_camera()


func _input(event: InputEvent) -> void:
	if not _is_pause_event(event):
		return

	if _close_player_inventory_if_open():
		get_viewport().set_input_as_handled()
		return

	if is_instance_valid(options_ingame):
		return

	get_viewport().set_input_as_handled()
	_open_options_ingame()


func _open_options_ingame() -> void:
	options_ingame = OPTIONS_INGAME_SCENE.instantiate() as CanvasLayer
	if options_ingame == null:
		push_warning("No se pudo cargar el menu de opciones in-game.")
		return

	options_ingame.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(options_ingame)
	options_ingame.tree_exited.connect(_on_options_ingame_closed)
	_set_tree_paused(true)


func _on_options_ingame_closed() -> void:
	options_ingame = null
	_set_tree_paused(false)


func _set_tree_paused(is_paused: bool) -> void:
	var tree = get_tree()
	if tree == null:
		return

	tree.paused = is_paused


func _configure_player_camera() -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return

	var camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	camera.limit_left = CAMERA_LIMIT_LEFT
	camera.limit_top = CAMERA_LIMIT_TOP
	camera.limit_right = CAMERA_LIMIT_RIGHT
	camera.limit_bottom = CAMERA_LIMIT_BOTTOM


func _on_dark_queen_body_entered(body: Node2D) -> void:
	_start_battle_encounter(
		body,
		"dark_queen_gate",
		"Emboscada de la Reina Oscura",
		"El mapa da paso a un combate clasico por turnos.",
		"La Reina Oscura te desafia. Selecciona comandos, objetivos y resiste su magia.",
		Vector2(-160.0, 64.0),
		220,
		150
	)


func _on_dungeon_boss_body_entered(body: Node2D) -> void:
	_start_battle_encounter(
		body,
		"dungeon_queen_sanctum",
		"Santuario de la Reina Oscura",
		"Has llegado al corazon de la dungeon.",
		"Una presencia oscura emerge del altar. Preparate para un combate decisivo.",
		Vector2(-96.0, 48.0),
		260,
		190
	)


func _on_dungeon_trap_body_entered(body: Node2D) -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if body == null or player == null or body != player:
		return

	if player.has_method("recibir_daÃ±o"):
		player.call("recibir_daÃ±o")


func _start_battle_encounter(body: Node2D, encounter_id: String, battle_title: String, battle_subtitle: String, status_message: String, return_offset: Vector2, experience_reward: int, gold_reward: int) -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if body == null or player == null or body != player:
		return

	var battle_manager = get_node_or_null(BATTLE_MANAGER_ROOT_PATH)
	if battle_manager == null:
		if player.has_method("morir"):
			player.call("morir")
		return

	if bool(battle_manager.call("has_active_encounter")):
		return

	var world_scene_path = ""
	var tree = get_tree()
	if tree != null and tree.current_scene != null:
		world_scene_path = tree.current_scene.scene_file_path

	var encounter_started = bool(battle_manager.call("start_battle", {
		"encounter_id": encounter_id,
		"save_slot_id": 1,
		"battle_title": battle_title,
		"battle_subtitle": battle_subtitle,
		"status_message": status_message,
		"world_scene_path": world_scene_path,
		"return_player_position": player.global_position + return_offset,
		"enemies": [
			{
				"name": "Reina Oscura",
				"role": "Boss",
				"level": 8,
				"current_hp": 320,
				"max_hp": 320,
				"current_mana": 160,
				"max_mana": 160,
				"attack": 24,
				"defense": 13,
				"speed": 11,
				"state": "normal",
				"experience_reward": experience_reward,
				"gold_reward": gold_reward,
				"skills": [
					{
						"name": "Tajo Sombrio",
						"description": "Un golpe oscuro directo y feroz.",
						"mana_cost": 10,
						"damage": 34,
						"damage_type": "shadow",
						"target_type": "single_enemy",
						"cooldown_turns": 1
					}
				],
				"loot_table": [
					{
						"item_id": 1,
						"item_name": "Pocion",
						"drop_chance": 0.85,
						"min_quantity": 1,
						"max_quantity": 2
					},
					{
						"item_id": 6,
						"item_name": "Hierba Antidoto",
						"drop_chance": 0.55,
						"min_quantity": 1,
						"max_quantity": 2
					}
				]
			}
		]
	}))

	if not encounter_started and player.has_method("morir"):
		player.call("morir")


func _close_player_inventory_if_open() -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player == null:
		return false

	if player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		if player.has_method("close_inventory"):
			player.call("close_inventory")
		return true

	return false


func _apply_battle_return_position() -> void:
	var battle_manager = get_node_or_null(BATTLE_MANAGER_ROOT_PATH)
	if battle_manager == null:
		return

	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var return_data = battle_manager.call("consume_return_data", tree.current_scene.scene_file_path)
	if return_data is not Dictionary:
		return

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return

	var battle_result = return_data.get("battle_result", {})
	if battle_result is Dictionary and bool(battle_result.get("player_should_respawn", false)):
		if player.has_method("morir"):
			player.call_deferred("morir")
		return

	if return_data.has("player_position") and return_data["player_position"] is Vector2:
		player.global_position = return_data["player_position"]


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		)

	return false
