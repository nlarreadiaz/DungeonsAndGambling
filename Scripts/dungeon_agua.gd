extends Node2D

const PLAYER_NODE_PATH = NodePath("player")
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
const SAVE_SLOT_ID = 1
const ESBIRRO1_ENCOUNTER_ID = "dungeon_agua_esbirro_1"
const ESBIRRO2_ENCOUNTER_ID = "dungeon_agua_esbirro_2"
const ESBIRRO3_ENCOUNTER_ID = "dungeon_agua_esbirro_3"
const DARK_QUEEN_FINAL_ENCOUNTER_ID = "dungeon_agua_reina_oscura_final"
const ESBIRRO1_NODE_PATH = NodePath("Esbirro1")
const ESBIRRO2_NODE_PATH = NodePath("Esbirro2")
const ESBIRRO3_NODE_PATH = NodePath("Esbirro3")
const DARK_QUEEN_NODE_PATH = NodePath("ReinaOscura")
const ESBIRRO_IDLE_TEXTURE_PATH = "res://assets/Boss-DarkQueen/2/Idle.png"
const BOSS_FIGHT_MUSIC_PATH = "res://assets/Music/BossFight.mp3"
const DUNGEON_AGUA_BATTLE_BACKGROUND_PATH = "res://assets/battle/dungeon_Agua_Combat.png"
const BATTLE_REENTRY_COOLDOWN_MSEC = 2000

var _esbirro_battle_cooldown_until_msec = 0


func _ready() -> void:
	_apply_battle_return_position()
	_apply_defeated_encounter_state()


func _on_esbirro1_battle_area_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() < _esbirro_battle_cooldown_until_msec:
		return

	_start_battle_encounter(
		body,
		ESBIRRO1_ENCOUNTER_ID,
		"Esbirro de la Mazmorra",
		"Un guardia menor bloquea el paso entre las aguas.",
		"El esbirro se lanza al combate.",
		Vector2(-48.0, 0.0),
		[_build_esbirro_enemy("Esbirro", "Esbirro menor", 2, 42, 5, 2, 4, 30, 1000, "Golpe torpe", 6)]
	)


func _on_esbirro2_battle_area_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() < _esbirro_battle_cooldown_until_msec:
		return

	_start_battle_encounter(
		body,
		ESBIRRO2_ENCOUNTER_ID,
		"Esbirro Curtido",
		"Un esbirro algo mas fuerte guarda la mazmorra.",
		"El esbirro curtido prepara su arma.",
		Vector2(-48.0, 0.0),
		[_build_esbirro_enemy("Esbirro Curtido", "Esbirro", 3, 58, 7, 3, 5, 45, 150, "Golpe de guardia", 8)]
	)


func _on_esbirro3_battle_area_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() < _esbirro_battle_cooldown_until_msec:
		return

	_start_battle_encounter(
		body,
		ESBIRRO3_ENCOUNTER_ID,
		"Esbirro Veterano",
		"Un esbirro veterano bloquea otro tramo de la mazmorra.",
		"El esbirro veterano te corta el paso.",
		Vector2(-48.0, 0.0),
		[_build_esbirro_enemy("Esbirro Veterano", "Esbirro", 4, 72, 9, 4, 6, 60, 220, "Tajo simple", 10)]
	)


func _on_reina_oscura_kill_zone_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() < _esbirro_battle_cooldown_until_msec:
		return

	_start_battle_encounter(
		body,
		DARK_QUEEN_FINAL_ENCOUNTER_ID,
		"Reina Oscura Final",
		"El corazon de la dungeon se sumerge en oscuridad.",
		"La Reina Oscura despierta su poder final.",
		Vector2.ZERO,
		[_build_dark_queen_final_enemy()],
		BOSS_FIGHT_MUSIC_PATH
	)


func _start_battle_encounter(body: Node2D, encounter_id: String, battle_title: String, battle_subtitle: String, status_message: String, _return_offset: Vector2, enemies: Array, battle_music_path := "") -> void:
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

	var encounter_data = {
		"encounter_id": encounter_id,
		"save_slot_id": SAVE_SLOT_ID,
		"battle_title": battle_title,
		"battle_subtitle": battle_subtitle,
		"status_message": status_message,
		"world_scene_path": world_scene_path,
		"return_player_position": player.global_position,
		"battle_background_path": DUNGEON_AGUA_BATTLE_BACKGROUND_PATH,
		"enemies": enemies
	}
	if not battle_music_path.strip_edges().is_empty():
		encounter_data["battle_music_path"] = battle_music_path

	_persist_player_inventory_state()
	var encounter_started = bool(battle_manager.call("start_battle", encounter_data))
	if not encounter_started and player.has_method("morir"):
		player.call("morir")


func _build_dark_queen_final_enemy() -> Dictionary:
	return {
		"name": "Reina Oscura",
		"role": "Boss Final",
		"level": 10,
		"current_hp": 380,
		"max_hp": 380,
		"current_mana": 180,
		"max_mana": 180,
		"attack": 28,
		"defense": 15,
		"speed": 12,
		"state": "normal",
		"experience_reward": 500,
		"gold_reward": 700,
		"sprite_flip_h": true,
		"skills": [
			{
				"name": "Tajo Sombrio",
				"description": "Un golpe oscuro directo y feroz.",
				"mana_cost": 10,
				"damage": 38,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"cooldown_turns": 1
			},
			{
				"name": "Corona de Tinieblas",
				"description": "La Reina Oscura concentra su poder final.",
				"mana_cost": 18,
				"damage": 46,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"cooldown_turns": 2
			}
		],
		"loot_table": []
	}


func _build_esbirro_enemy(enemy_name: String, enemy_role: String, level: int, hp: int, attack: int, defense: int, speed: int, experience_reward: int, gold_reward: int, skill_name: String, skill_damage: int) -> Dictionary:
	return {
		"name": enemy_name,
		"role": enemy_role,
		"level": level,
		"current_hp": hp,
		"max_hp": hp,
		"current_mana": 0,
		"max_mana": 0,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"state": "normal",
		"experience_reward": experience_reward,
		"gold_reward": gold_reward,
		"sprite_texture_path": ESBIRRO_IDLE_TEXTURE_PATH,
		"sprite_frame_width": 128,
		"sprite_frame_height": 128,
		"sprite_display_width": 76.0,
		"sprite_display_height": 76.0,
		"sprite_position_x": 4.0,
		"sprite_position_y": 2.0,
		"always_use_first_skill": true,
		"skills": [
			{
				"name": skill_name,
				"description": "Un ataque debil de un guardia menor.",
				"mana_cost": 0,
				"damage": skill_damage,
				"damage_type": "physical",
				"target_type": "single_enemy",
				"cooldown_turns": 0
			}
		],
		"loot_table": []
	}


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
		_esbirro_battle_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC

	if return_data.has("player_position") and return_data["player_position"] is Vector2:
		player.global_position = return_data["player_position"]
	return true


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
	return [
		ESBIRRO1_ENCOUNTER_ID,
		ESBIRRO2_ENCOUNTER_ID,
		ESBIRRO3_ENCOUNTER_ID,
		DARK_QUEEN_FINAL_ENCOUNTER_ID
	].has(encounter_id)


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
		ESBIRRO1_ENCOUNTER_ID:
			return ESBIRRO1_NODE_PATH
		ESBIRRO2_ENCOUNTER_ID:
			return ESBIRRO2_NODE_PATH
		ESBIRRO3_ENCOUNTER_ID:
			return ESBIRRO3_NODE_PATH
		DARK_QUEEN_FINAL_ENCOUNTER_ID:
			return DARK_QUEEN_NODE_PATH
		_:
			return NodePath("")
