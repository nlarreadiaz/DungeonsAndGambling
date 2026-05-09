extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/ui/options_ingame.tscn")

const PLAYER_NODE_PATH = NodePath("player")
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
const HERRERIA_SCENE = "res://Scenes/world/herreria.tscn"
const INTERACT_ACTION = "interact"
const SAVE_SLOT_ID = 1
const BATTLE_REENTRY_COOLDOWN_MSEC = 2000
const MUELLE_BOY_AMAZED_ENCOUNTER_ID = "muelle_boy_amazed_lighthouse"
const MUELLE_BOY_AMAZED_NODE_PATH = NodePath("npcs/MuelleBoyAmazedNpc")
const MUELLE_BOY_AMAZED_BATTLE_AREA_PATH = NodePath("npcs/MuelleBoyAmazedNpc/BattleArea")
const FARO_BATTLE_BACKGROUND_PATH = "res://assets/battle/batalla_faro.png"
const MUELLE_BOY_AMAZED_SPRITE_PATH = "res://assets/muelle/Characters/Boy_amazed.png"
const CAMERA_LIMIT_LEFT = -560
const CAMERA_LIMIT_TOP = -360
const CAMERA_LIMIT_RIGHT = 780
const CAMERA_LIMIT_BOTTOM = 920

var options_ingame: CanvasLayer = null
var _player_can_enter_herreria = false
var _muelle_boy_amazed_cooldown_until_msec = 0
var _muelle_boy_amazed_retry_scheduled = false


func _ready() -> void:
	_apply_battle_return_position()
	_apply_defeated_encounter_state()
	_configure_player_camera()


func _input(event: InputEvent) -> void:
	if _is_interact_event(event) and _player_can_enter_herreria:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_try_enter_herreria()
		return

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


func _on_muelle_boy_amazed_battle_area_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	if _is_muelle_boy_amazed_battle_on_cooldown():
		_schedule_muelle_boy_amazed_battle_retry()
		return

	_start_battle_encounter(
		body,
		MUELLE_BOY_AMAZED_ENCOUNTER_ID,
		"Duelo junto al Faro",
		"El muelle se convierte en un combate rapido.",
		"MuelleBoyAmazedNpc te desafia junto al faro.",
		Vector2.ZERO,
		18,
		6,
		[_build_muelle_boy_amazed_enemy()],
		FARO_BATTLE_BACKGROUND_PATH
	)


func _on_dungeon_trap_body_entered(body: Node2D) -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if body == null or player == null or body != player:
		return

	if player.has_method("recibir_daÃ±o"):
		player.call("recibir_daÃ±o")


func _on_smith_entry_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_enter_herreria = true


func _on_smith_entry_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_enter_herreria = false


func _try_enter_herreria() -> bool:
	if not _player_can_enter_herreria or is_instance_valid(options_ingame):
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		return false

	var tree = get_tree()
	if tree == null:
		return false

	return tree.change_scene_to_file(HERRERIA_SCENE) == OK


func _is_player_body(body: Node2D) -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	return body != null and player != null and body == player


func _start_battle_encounter(body: Node2D, encounter_id: String, battle_title: String, battle_subtitle: String, status_message: String, return_offset: Vector2, experience_reward: int, gold_reward: int, enemies: Array = [], battle_background_path: String = "") -> void:
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

	var encounter_enemies = enemies
	if encounter_enemies.is_empty():
		encounter_enemies = [_build_dark_queen_enemy(experience_reward, gold_reward)]

	var encounter_data = {
		"encounter_id": encounter_id,
		"save_slot_id": SAVE_SLOT_ID,
		"battle_title": battle_title,
		"battle_subtitle": battle_subtitle,
		"status_message": status_message,
		"world_scene_path": world_scene_path,
		"return_player_position": player.global_position + return_offset,
		"enemies": encounter_enemies
	}
	if not battle_background_path.strip_edges().is_empty():
		encounter_data["battle_background_path"] = battle_background_path

	var encounter_started = bool(battle_manager.call("start_battle", encounter_data))

	if not encounter_started and player.has_method("morir"):
		player.call("morir")


func _build_dark_queen_enemy(experience_reward: int, gold_reward: int) -> Dictionary:
	return {
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


func _build_muelle_boy_amazed_enemy() -> Dictionary:
	return {
		"name": "MuelleBoyAmazedNpc",
		"role": "Enemigo",
		"level": 1,
		"current_hp": 50,
		"max_hp": 50,
		"current_mana": 0,
		"max_mana": 0,
		"attack": 10,
		"defense": 3,
		"speed": 6,
		"state": "normal",
		"experience_reward": 18,
		"gold_reward": 6,
		"sprite_texture_path": MUELLE_BOY_AMAZED_SPRITE_PATH,
		"sprite_frame_width": 32,
		"sprite_frame_height": 48,
		"sprite_display_width": 56.0,
		"sprite_display_height": 84.0,
		"sprite_position_x": 18.0,
		"sprite_position_y": 28.0,
		"always_use_first_skill": true,
		"skills": [
			{
				"name": "Golpe Asombrado",
				"description": "Un ataque simple junto al faro.",
				"mana_cost": 0,
				"damage": 10,
				"damage_type": "physical",
				"target_type": "single_enemy",
				"cooldown_turns": 0
			}
		],
		"loot_table": []
	}


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

	if battle_result is Dictionary and str(battle_result.get("outcome", "")) == "victory":
		_apply_defeated_encounter(str(return_data.get("encounter_id", "")))
	elif battle_result is Dictionary and str(battle_result.get("outcome", "")) == "escaped":
		if str(return_data.get("encounter_id", "")) == MUELLE_BOY_AMAZED_ENCOUNTER_ID:
			_muelle_boy_amazed_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC

	if return_data.has("player_position") and return_data["player_position"] is Vector2:
		player.global_position = return_data["player_position"]


func _is_muelle_boy_amazed_battle_on_cooldown() -> bool:
	return Time.get_ticks_msec() < _muelle_boy_amazed_cooldown_until_msec


func _schedule_muelle_boy_amazed_battle_retry() -> void:
	if _muelle_boy_amazed_retry_scheduled:
		return

	var remaining_msec = max(_muelle_boy_amazed_cooldown_until_msec - Time.get_ticks_msec(), 0)
	_muelle_boy_amazed_retry_scheduled = true
	await get_tree().create_timer(float(remaining_msec) / 1000.0).timeout
	_muelle_boy_amazed_retry_scheduled = false

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	var battle_area = get_node_or_null(MUELLE_BOY_AMAZED_BATTLE_AREA_PATH) as Area2D
	if player == null or battle_area == null:
		return
	if battle_area.get_overlapping_bodies().has(player):
		_on_muelle_boy_amazed_battle_area_body_entered(player)


func _apply_defeated_encounter_state() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_game_state"):
		return

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		return

	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags == null or important_flags is not Dictionary:
		return

	var defeated_encounters = important_flags.get("defeated_encounters", {})
	if defeated_encounters is Dictionary and bool(defeated_encounters.get(MUELLE_BOY_AMAZED_ENCOUNTER_ID, false)):
		_apply_defeated_encounter(MUELLE_BOY_AMAZED_ENCOUNTER_ID)


func _apply_defeated_encounter(encounter_id: String) -> void:
	if encounter_id != MUELLE_BOY_AMAZED_ENCOUNTER_ID:
		return

	var npc = get_node_or_null(MUELLE_BOY_AMAZED_NODE_PATH) as Node2D
	if npc == null:
		return

	npc.visible = false
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	if npc is CollisionObject2D:
		var collision_object = npc as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for area in npc.find_children("*", "Area2D", true, false):
		var area_node = area as Area2D
		if area_node == null:
			continue
		area_node.monitoring = false
		area_node.monitorable = false
	for collision_shape in npc.find_children("*", "CollisionShape2D", true, false):
		var shape_node = collision_shape as CollisionShape2D
		if shape_node == null:
			continue
		shape_node.disabled = true
	if not npc.is_queued_for_deletion():
		npc.queue_free()


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


func _is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE
		)

	return false
