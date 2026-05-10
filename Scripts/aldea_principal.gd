extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/ui/options_ingame.tscn")

const PLAYER_NODE_PATH = NodePath("player")
const VILLAGE_NODE_PATH = NodePath("aldea")
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
const HERRERIA_SCENE = "res://Scenes/world/herreria.tscn"
const DUNGEON_AGUA_SCENE = "res://Scenes/dungeonAgua.tscn"
const INTERACT_ACTION = "interact"
const SAVE_SLOT_ID = 1
const CASTILLO_AGUA_ENTRY_SHAPE_PATH = NodePath("aldea/CastilloAgua/entrar")
const BATTLE_REENTRY_COOLDOWN_MSEC = 2000
const DARK_QUEEN_GATE_ENCOUNTER_ID = "dark_queen_gate"
const DUNGEON_QUEEN_SANCTUM_ENCOUNTER_ID = "dungeon_queen_sanctum"
const DARK_QUEEN_NODE_PATH = NodePath("npcs/ReinaOscura")
const MUELLE_BOY_AMAZED_ENCOUNTER_ID = "muelle_boy_amazed_lighthouse"
const MUELLE_BOY_AMAZED_NODE_PATH = NodePath("npcs/Niño Millonario")
const MUELLE_BOY_AMAZED_BATTLE_AREA_PATH = NodePath("npcs/Niño Millonario/BattleArea")
const FARO_BATTLE_BACKGROUND_PATH = "res://assets/battle/batalla_faro.png"
const MUELLE_BOY_AMAZED_SPRITE_PATH = "res://assets/muelle/Characters/Boy_amazed.png"
const CAMERA_LIMIT_LEFT = -560
const CAMERA_LIMIT_TOP = -360
const CAMERA_LIMIT_RIGHT = 780
const CAMERA_LIMIT_BOTTOM = 920
const BUILDING_FADE_ALPHA := 0.56
const BUILDING_FADE_SPEED := 7.5
const DEFAULT_BUILDING_ALPHA := 1.0
const PLAYER_BEHIND_ALPHA := 0.78
const PLAYER_FADE_SPEED := 8.5
const PLAYER_VISUAL_NODE_PATH = NodePath("animaciones")
const VILLAGE_BUILDINGS = [
	{
		"sprite_path": "aldea/Casa1Body/Casa1",
		"fade_size_ratio": Vector2(0.98, 0.66),
		"fade_offset_ratio_y": -0.08,
		"fade_cut_ratio_y": 0.2
	},
	{
		"sprite_path": "aldea/SmithBody/Smith",
		"fade_size_ratio": Vector2(0.98, 0.67),
		"fade_offset_ratio_y": -0.09,
		"fade_cut_ratio_y": 0.2
	},
	{
		"sprite_path": "aldea/Casa2Body/Casa2",
		"fade_size_ratio": Vector2(0.98, 0.66),
		"fade_offset_ratio_y": -0.08,
		"fade_cut_ratio_y": 0.2
	},
	{
		"sprite_path": "aldea/Casa3Body/Casa3",
		"fade_size_ratio": Vector2(0.96, 0.64),
		"fade_offset_ratio_y": -0.1,
		"fade_cut_ratio_y": 0.18
	},
	{
		"sprite_path": "aldea/CathedralBody/Cathedral",
		"fade_size_ratio": Vector2(0.92, 0.72),
		"fade_offset_ratio_y": -0.08,
		"fade_cut_ratio_y": 0.22
	},
	{
		"sprite_path": "aldea/LighthouseBody/Lighthouse",
		"fade_size_ratio": Vector2(0.68, 0.74),
		"fade_offset_ratio_y": -0.08,
		"fade_cut_ratio_y": 0.18
	}
]

var options_ingame: CanvasLayer = null
var _building_fade_data: Array[Dictionary] = []
var _player_node: Node2D = null
var _player_visual: CanvasItem = null
var _player_can_enter_herreria = false
var _player_can_enter_dungeon_agua = false
var _battle_reentry_cooldown_until_msec = 0
var _muelle_boy_amazed_cooldown_until_msec = 0
var _muelle_boy_amazed_retry_scheduled = false


func _ready() -> void:
	var used_battle_return = _apply_battle_return_position()
	if not used_battle_return:
		_apply_saved_player_position()
	_apply_defeated_encounter_state()
	_configure_player_camera()
	_setup_castillo_agua_entry_area()
	_setup_village_buildings()


func _input(event: InputEvent) -> void:
	if _is_interact_event(event) and _player_can_enter_herreria:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_try_enter_herreria()
		return

	if _is_interact_event(event) and _player_can_enter_dungeon_agua:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_try_enter_dungeon_agua()
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
	if not is_inside_tree():
		return
	_set_tree_paused(false)


func _set_tree_paused(is_paused: bool) -> void:
	if not is_inside_tree():
		return

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
		DARK_QUEEN_GATE_ENCOUNTER_ID,
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
		DUNGEON_QUEEN_SANCTUM_ENCOUNTER_ID,
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
		"Niño Millonario te desafia junto al faro.",
		Vector2.ZERO,
		1000,
		1000,
		[_build_muelle_boy_amazed_enemy()],
		FARO_BATTLE_BACKGROUND_PATH
	)


func _on_dungeon_trap_body_entered(body: Node2D) -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if body == null or player == null or body != player:
		return

	if player.has_method("recibir_dano"):
		player.call("recibir_dano")


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

	_persist_player_inventory_state()
	return tree.change_scene_to_file(HERRERIA_SCENE) == OK


func _try_enter_dungeon_agua() -> bool:
	if not _player_can_enter_dungeon_agua or is_instance_valid(options_ingame):
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		return false

	var tree = get_tree()
	if tree == null:
		return false

	_persist_player_inventory_state()
	return tree.change_scene_to_file(DUNGEON_AGUA_SCENE) == OK


func _is_player_body(body: Node2D) -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	return body != null and player != null and body == player


func _setup_castillo_agua_entry_area() -> void:
	var entry_shape = get_node_or_null(CASTILLO_AGUA_ENTRY_SHAPE_PATH) as CollisionShape2D
	if entry_shape == null or entry_shape.shape == null:
		push_warning("No se encontro la CollisionShape2D entrar del CastilloAgua.")
		return

	var entry_area = Area2D.new()
	entry_area.name = "CastilloAguaEntryArea"
	entry_area.collision_layer = 0
	entry_area.monitorable = false
	entry_area.monitoring = true
	add_child(entry_area)
	entry_area.global_transform = entry_shape.global_transform

	var area_shape = CollisionShape2D.new()
	area_shape.name = "CollisionShape2D"
	area_shape.shape = entry_shape.shape
	entry_area.add_child(area_shape)

	entry_area.body_entered.connect(_on_castillo_agua_entry_area_body_entered)
	entry_area.body_exited.connect(_on_castillo_agua_entry_area_body_exited)


func _on_castillo_agua_entry_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_enter_dungeon_agua = true


func _on_castillo_agua_entry_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_enter_dungeon_agua = false


func _start_battle_encounter(body: Node2D, encounter_id: String, battle_title: String, battle_subtitle: String, status_message: String, _return_offset: Vector2, experience_reward: int, gold_reward: int, enemies: Array = [], battle_background_path: String = "") -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if body == null or player == null or body != player:
		return

	if Time.get_ticks_msec() < _battle_reentry_cooldown_until_msec:
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
		"return_player_position": player.global_position,
		"enemies": encounter_enemies
	}
	if not battle_background_path.strip_edges().is_empty():
		encounter_data["battle_background_path"] = battle_background_path

	_persist_player_inventory_state()
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
				"skill_id": 2001,
				"name": "Tajo Sombrio",
				"description": "Un golpe oscuro directo y feroz.",
				"mana_cost": 10,
				"damage": 34,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"hit_effect": "shadow_slash",
				"cooldown_turns": 1
			},
			{
				"skill_id": 2002,
				"name": "Corona de Tinieblas",
				"description": "La Reina Oscura concentra su poder final.",
				"mana_cost": 16,
				"damage": 40,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"hit_effect": "dark_crown",
				"cooldown_turns": 2
			},
			{
				"skill_id": 2003,
				"name": "Golpe del Vacio",
				"description": "Una grieta oscura atraviesa al objetivo.",
				"mana_cost": 13,
				"damage": 37,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"hit_effect": "void_hit",
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
		"name": "Niño Millonario",
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
		"experience_reward": 1000,
		"gold_reward": 1000,
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


func _persist_player_inventory_state() -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("save_inventory_layout"):
		player.call("save_inventory_layout")


func _apply_battle_return_position() -> bool:
	var battle_manager = get_node_or_null(BATTLE_MANAGER_ROOT_PATH)
	if battle_manager == null:
		return false

	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return false

	var return_data = battle_manager.call("consume_return_data", tree.current_scene.scene_file_path)
	if return_data is not Dictionary:
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return false

	var battle_result = return_data.get("battle_result", {})
	if battle_result is Dictionary and bool(battle_result.get("player_should_respawn", false)):
		if player.has_method("morir"):
			player.call_deferred("morir")
		return true

	if battle_result is Dictionary and str(battle_result.get("outcome", "")) == "victory":
		var encounter_id = str(return_data.get("encounter_id", ""))
		if _should_hide_defeated_encounter(encounter_id):
			_apply_defeated_encounter(encounter_id)
	elif battle_result is Dictionary and str(battle_result.get("outcome", "")) == "escaped":
		_battle_reentry_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC
		if str(return_data.get("encounter_id", "")) == MUELLE_BOY_AMAZED_ENCOUNTER_ID:
			_muelle_boy_amazed_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC

	if return_data.has("player_position") and return_data["player_position"] is Vector2:
		player.global_position = return_data["player_position"]
	return true


func _apply_saved_player_position() -> void:
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

	var player_position = important_flags.get("player_position", {})
	if player_position is not Dictionary:
		return

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return

	player.global_position = Vector2(
		float(player_position.get("x", player.global_position.x)),
		float(player_position.get("y", player.global_position.y))
	)


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
	if defeated_encounters is String:
		defeated_encounters = JSON.parse_string(defeated_encounters)
	if defeated_encounters == null or defeated_encounters is not Dictionary:
		return

	for encounter_id in defeated_encounters.keys():
		var encounter_id_text = str(encounter_id)
		if bool(defeated_encounters.get(encounter_id, false)) and _should_hide_defeated_encounter(encounter_id_text):
			_apply_defeated_encounter(encounter_id_text)


func _should_hide_defeated_encounter(encounter_id: String) -> bool:
	return not str(_get_encounter_npc_path(encounter_id)).is_empty()


func _apply_defeated_encounter(encounter_id: String) -> void:
	var node_path = _get_encounter_npc_path(encounter_id)
	if str(node_path).is_empty():
		return

	var npc = get_node_or_null(node_path) as Node2D
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


func _get_encounter_npc_path(encounter_id: String) -> NodePath:
	match encounter_id:
		DARK_QUEEN_GATE_ENCOUNTER_ID, DUNGEON_QUEEN_SANCTUM_ENCOUNTER_ID:
			return DARK_QUEEN_NODE_PATH
		MUELLE_BOY_AMAZED_ENCOUNTER_ID:
			return MUELLE_BOY_AMAZED_NODE_PATH
		_:
			return NodePath("")


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


func _process(delta: float) -> void:
	if _building_fade_data.is_empty():
		return

	if _player_node == null or not is_instance_valid(_player_node):
		_player_node = get_node_or_null(PLAYER_NODE_PATH) as Node2D
		if _player_node == null:
			return
		_player_visual = _resolve_player_visual(_player_node)
	elif _player_visual == null or not is_instance_valid(_player_visual):
		_player_visual = _resolve_player_visual(_player_node)

	_update_building_fade(delta)


func _setup_village_buildings() -> void:
	if get_node_or_null(VILLAGE_NODE_PATH) == null:
		return

	_player_node = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	_player_visual = _resolve_player_visual(_player_node)
	_building_fade_data.clear()

	for building_variant in VILLAGE_BUILDINGS:
		var building = building_variant as Dictionary
		var sprite_path = NodePath(str(building.get("sprite_path", "")))
		var sprite = get_node_or_null(sprite_path) as Sprite2D
		if sprite == null:
			continue

		var sprite_world_size = _get_sprite_world_size(sprite)
		if sprite_world_size == Vector2.ZERO:
			continue

		_building_fade_data.append({
			"sprite": sprite,
			"world_size": sprite_world_size,
			"fade_size_ratio": building.get("fade_size_ratio", Vector2(0.95, 0.66)),
			"fade_offset_ratio_y": float(building.get("fade_offset_ratio_y", -0.1)),
			"fade_cut_ratio_y": float(building.get("fade_cut_ratio_y", 0.2))
		})

	set_process(not _building_fade_data.is_empty())


func _update_building_fade(delta: float) -> void:
	var is_player_behind_any_building = false

	for data in _building_fade_data:
		var sprite = data.get("sprite", null) as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue

		var should_fade = _is_player_behind_building(sprite, data)
		if should_fade:
			is_player_behind_any_building = true
		var target_alpha = BUILDING_FADE_ALPHA if should_fade else DEFAULT_BUILDING_ALPHA
		var current_modulate = sprite.self_modulate
		current_modulate.a = move_toward(current_modulate.a, target_alpha, BUILDING_FADE_SPEED * delta)
		sprite.self_modulate = current_modulate

	_update_player_behind_fade(delta, is_player_behind_any_building)


func _is_player_behind_building(sprite: Sprite2D, data: Dictionary) -> bool:
	if _player_node == null:
		return false

	var world_size = data.get("world_size", Vector2.ZERO) as Vector2
	if world_size == Vector2.ZERO:
		return false

	var fade_size_ratio = data.get("fade_size_ratio", Vector2(0.95, 0.66)) as Vector2
	var fade_offset_ratio_y = float(data.get("fade_offset_ratio_y", -0.1))
	var fade_cut_ratio_y = float(data.get("fade_cut_ratio_y", 0.2))

	var fade_size = Vector2(
		world_size.x * fade_size_ratio.x,
		world_size.y * fade_size_ratio.y
	)
	var fade_center_y = world_size.y * fade_offset_ratio_y
	var local_player_position = sprite.to_local(_player_node.global_position)

	var inside_x = absf(local_player_position.x) <= fade_size.x * 0.5
	var inside_y = absf(local_player_position.y - fade_center_y) <= fade_size.y * 0.5
	if not inside_x or not inside_y:
		return false

	var behind_cut = world_size.y * fade_cut_ratio_y
	return local_player_position.y <= behind_cut


func _get_sprite_world_size(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2.ZERO

	var texture_size = sprite.texture.get_size()
	var sprite_scale = Vector2(absf(sprite.scale.x), absf(sprite.scale.y))
	return Vector2(texture_size.x * sprite_scale.x, texture_size.y * sprite_scale.y)


func _update_player_behind_fade(delta: float, should_fade: bool) -> void:
	if _player_visual == null or not is_instance_valid(_player_visual):
		if _player_node != null and is_instance_valid(_player_node):
			_player_visual = _resolve_player_visual(_player_node)
		if _player_visual == null:
			return

	var target_alpha = PLAYER_BEHIND_ALPHA if should_fade else DEFAULT_BUILDING_ALPHA
	var visual_modulate = _player_visual.self_modulate
	visual_modulate.a = move_toward(visual_modulate.a, target_alpha, PLAYER_FADE_SPEED * delta)
	_player_visual.self_modulate = visual_modulate


func _resolve_player_visual(player: Node2D) -> CanvasItem:
	if player == null:
		return null

	var animated_sprite = player.get_node_or_null(PLAYER_VISUAL_NODE_PATH) as CanvasItem
	if animated_sprite != null:
		return animated_sprite

	for child in player.get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			return child as CanvasItem

	return null
