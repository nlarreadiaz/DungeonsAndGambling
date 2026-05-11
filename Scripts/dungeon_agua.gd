extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/ui/options_ingame.tscn")

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
const ESBIRRO_FIGHT_MUSIC_PATH = "res://assets/Music/DungeonFight.mp3"
const BOSS_FIGHT_MUSIC_PATH = "res://assets/Music/BossFight.mp3"
const DUNGEON_AMBIENT_MUSIC_PATH = "res://assets/Music/DungeonAmbient.mp3"
const DUNGEON_AGUA_BATTLE_BACKGROUND_PATH = "res://assets/battle/dungeon_Agua_Combat.png"
const BATTLE_REENTRY_COOLDOWN_MSEC = 2000
const INTERACT_ACTION = "interact"
const EXIT_DOOR_NODE_PATH = NodePath("puerta")
const CREDITS_SCENE = "res://Scenes/ui/credits.tscn"
const EXIT_DOOR_OPEN_ANIMATION = &"abrir"
const EXIT_DOOR_FALLBACK_ANIMATION = &"cerrar abrir"
const EXIT_DOOR_FREEZE_FRAME = 3
const DARK_QUEEN_KILL_ZONE_PATH = NodePath("ReinaOscura/KillZone")
const DARK_QUEEN_TALK_PORTRAIT = "res://assets/Boss-DarkQueen/Talk.png"
const DARK_QUEEN_AGGRESSION_PORTRAIT = "res://assets/Boss-DarkQueen/Aggression.png"
const DARK_QUEEN_DEFEATED_PORTRAIT = "res://assets/Boss-DarkQueen/Defeated.png"
const DARK_QUEEN_PRE_BATTLE_DIALOGUE = [
	{
		"portrait": DARK_QUEEN_TALK_PORTRAIT,
		"text": "Qué decepción... Has llegado hasta aquí solo para perderlo todo en la última jugada. El destino ya ha repartido las cartas, y tu mano es perdedora."
	},
	{
		"portrait": DARK_QUEEN_AGGRESSION_PORTRAIT,
		"text": "¡Basta de juegos! ¡Ahora conocerás el peso de un mar de sombras! ¡Paga tu deuda con tu alma y húndete en el abismo!"
	}
]
const DARK_QUEEN_DEFEATED_DIALOGUE = [
	{
		"portrait": DARK_QUEEN_DEFEATED_PORTRAIT,
		"text": "Imposible... La marea ha cambiado... Mi corona se desvanece entre la espuma del olvido."
	}
]

var _esbirro_battle_cooldown_until_msec = 0
var options_ingame: CanvasLayer = null
var _ambient_music_player: AudioStreamPlayer = null
var _ambient_music_resume_position := 0.0
var _player_can_exit_dungeon = false
var _exit_door_unlocked = false
var _dark_queen_pending_battle_body: Node2D = null
var _dialogue_layer: CanvasLayer = null
var _dialogue_portrait: TextureRect = null
var _dialogue_message: Label = null
var _dialogue_name = ""
var _dialogue_pages: Array = []
var _dialogue_page_index = 0
var _dialogue_finished_callback: Callable = Callable()


func _ready() -> void:
	var used_battle_return = _apply_battle_return_position()
	if not used_battle_return:
		_apply_saved_player_position()
	_apply_defeated_encounter_state()
	_setup_exit_door_interaction_area()
	_setup_dark_queen_dialogue_cancel()
	if _is_final_boss_defeated() and not _is_dialogue_open():
		_set_exit_door_open(false)
	_play_dungeon_ambient_music(_ambient_music_resume_position)


func _input(event: InputEvent) -> void:
	if _is_dialogue_open():
		if _is_dialogue_advance_event(event):
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			_advance_dialogue()
		return

	if _is_interact_event(event) and _exit_door_unlocked and _player_can_exit_dungeon:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_try_exit_to_credits()
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
		[_build_esbirro_enemy("Esbirro", "Esbirro menor", 2, 42, 5, 2, 4, 30, 1000, "Golpe torpe", 6)],
		ESBIRRO_FIGHT_MUSIC_PATH
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
		[_build_esbirro_enemy("Esbirro Curtido", "Esbirro", 3, 58, 7, 3, 5, 45, 150, "Golpe de guardia", 8)],
		ESBIRRO_FIGHT_MUSIC_PATH
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
		[_build_esbirro_enemy("Esbirro Veterano", "Esbirro", 4, 72, 9, 4, 6, 60, 220, "Tajo simple", 10)],
		ESBIRRO_FIGHT_MUSIC_PATH
	)


func _on_reina_oscura_kill_zone_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() < _esbirro_battle_cooldown_until_msec:
		return

	if _is_dialogue_open() or _dark_queen_pending_battle_body != null:
		return

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if body == null or player == null or body != player:
		return

	_dark_queen_pending_battle_body = body
	_show_dialogue(
		"Reina Oscura",
		DARK_QUEEN_PRE_BATTLE_DIALOGUE,
		Callable(self, "_start_dark_queen_battle_after_dialogue")
	)


func _start_dark_queen_battle_after_dialogue() -> void:
	var body = _dark_queen_pending_battle_body
	_dark_queen_pending_battle_body = null
	if body == null or not is_instance_valid(body):
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


func _on_reina_oscura_kill_zone_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	if _dark_queen_pending_battle_body == body:
		_dark_queen_pending_battle_body = null
		_hide_dialogue()


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
		"world_music_resume_position": _pause_dungeon_ambient_music(),
		"enemies": enemies
	}
	if not battle_music_path.strip_edges().is_empty():
		encounter_data["battle_music_path"] = battle_music_path

	_persist_player_inventory_state()
	var encounter_started = bool(battle_manager.call("start_battle", encounter_data))
	if not encounter_started:
		_resume_dungeon_ambient_music()
		if player.has_method("morir"):
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
				"skill_id": 2001,
				"name": "Tajo Sombrio",
				"description": "Un golpe oscuro directo y feroz.",
				"mana_cost": 10,
				"damage": 38,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"hit_effect": "shadow_slash",
				"cooldown_turns": 1
			},
			{
				"skill_id": 2002,
				"name": "Corona de Tinieblas",
				"description": "La Reina Oscura concentra su poder final.",
				"mana_cost": 18,
				"damage": 46,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"hit_effect": "dark_crown",
				"cooldown_turns": 2
			},
			{
				"skill_id": 2003,
				"name": "Golpe del Vacio",
				"description": "Una grieta oscura atraviesa al objetivo.",
				"mana_cost": 14,
				"damage": 42,
				"damage_type": "shadow",
				"target_type": "single_enemy",
				"hit_effect": "void_hit",
				"cooldown_turns": 1
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
				"hit_effect": "water_slash",
				"cooldown_turns": 0
			}
		],
		"loot_table": []
	}


func _persist_player_inventory_state() -> void:
	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("save_inventory_layout"):
		player.call("save_inventory_layout")


func _setup_dark_queen_dialogue_cancel() -> void:
	var kill_zone = get_node_or_null(DARK_QUEEN_KILL_ZONE_PATH) as Area2D
	if kill_zone == null:
		return
	if not kill_zone.body_exited.is_connected(_on_reina_oscura_kill_zone_body_exited):
		kill_zone.body_exited.connect(_on_reina_oscura_kill_zone_body_exited)


func _show_dialogue(npc_name: String, pages: Array, finished_callback: Callable = Callable()) -> void:
	if pages.is_empty():
		if finished_callback.is_valid():
			finished_callback.call()
		return

	_ensure_dialogue_ui()
	if _dialogue_layer == null or _dialogue_message == null:
		if finished_callback.is_valid():
			finished_callback.call()
		return

	_dialogue_name = npc_name
	_dialogue_pages = pages.duplicate(true)
	_dialogue_page_index = 0
	_dialogue_finished_callback = finished_callback
	_dialogue_layer.visible = true
	_refresh_dialogue_page()


func _ensure_dialogue_ui() -> void:
	if _dialogue_layer != null:
		return

	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.name = "DarkQueenDialogueLayer"
	_dialogue_layer.layer = 40
	add_child(_dialogue_layer)

	var panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 8.0
	panel.offset_top = -76.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.075, 0.09, 0.94)
	style.border_color = Color(0.52, 0.64, 0.8, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)
	_dialogue_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	_dialogue_portrait = TextureRect.new()
	_dialogue_portrait.custom_minimum_size = Vector2(58, 58)
	_dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_dialogue_portrait)

	_dialogue_message = Label.new()
	_dialogue_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = LabelSettings.new()
	label_settings.font_size = 8
	label_settings.font_color = Color(0.95, 0.95, 0.9, 1)
	label_settings.outline_size = 1
	label_settings.outline_color = Color(0.03, 0.03, 0.04, 1)
	_dialogue_message.label_settings = label_settings
	row.add_child(_dialogue_message)

	_dialogue_layer.visible = false


func _refresh_dialogue_page() -> void:
	if _dialogue_message == null or _dialogue_pages.is_empty():
		return

	_dialogue_page_index = clampi(_dialogue_page_index, 0, _dialogue_pages.size() - 1)
	var page = _dialogue_pages[_dialogue_page_index]
	if page is not Dictionary:
		return

	var portrait_path = str(page.get("portrait", ""))
	if _dialogue_portrait != null:
		_dialogue_portrait.texture = load(portrait_path) as Texture2D

	var page_text = str(page.get("text", ""))
	if _dialogue_name.strip_edges().is_empty():
		_dialogue_message.text = page_text
	else:
		_dialogue_message.text = "%s\n%s" % [_dialogue_name, page_text]


func _advance_dialogue() -> void:
	if _dialogue_page_index < _dialogue_pages.size() - 1:
		_dialogue_page_index += 1
		_refresh_dialogue_page()
		return

	var finished_callback = _dialogue_finished_callback
	_hide_dialogue()
	if finished_callback.is_valid():
		finished_callback.call()


func _hide_dialogue() -> void:
	if _dialogue_layer != null:
		_dialogue_layer.visible = false
	_dialogue_name = ""
	_dialogue_pages = []
	_dialogue_page_index = 0
	_dialogue_finished_callback = Callable()


func _is_dialogue_open() -> bool:
	return _dialogue_layer != null and _dialogue_layer.visible


func save_current_game_from_pause() -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	var database_manager = get_node_or_null("/root/GameDatabase")
	if player == null or database_manager == null or not database_manager.has_method("save_player_world_position"):
		return false

	_persist_player_inventory_state()
	return bool(database_manager.call(
		"save_player_world_position",
		SAVE_SLOT_ID,
		_get_current_scene_path("res://Scenes/dungeonAgua.tscn"),
		player.global_position
	))


func _get_current_scene_path(fallback_scene_path: String) -> String:
	var tree = get_tree()
	if tree != null and tree.current_scene != null and not tree.current_scene.scene_file_path.is_empty():
		return tree.current_scene.scene_file_path
	return fallback_scene_path


func _play_dungeon_ambient_music(from_position := 0.0) -> void:
	var music_stream = load(DUNGEON_AMBIENT_MUSIC_PATH) as AudioStream
	if music_stream == null:
		push_warning("No se pudo cargar la musica ambiental de dungeon agua: %s" % DUNGEON_AMBIENT_MUSIC_PATH)
		return

	_ambient_music_player = AudioStreamPlayer.new()
	_ambient_music_player.name = "DungeonAmbientMusic"
	_ambient_music_player.stream = music_stream
	add_child(_ambient_music_player)
	_ambient_music_player.play(max(from_position, 0.0))


func _pause_dungeon_ambient_music() -> float:
	if _ambient_music_player == null:
		return 0.0

	var playback_position = _ambient_music_player.get_playback_position()
	_ambient_music_player.stream_paused = true
	return playback_position


func _resume_dungeon_ambient_music() -> void:
	if _ambient_music_player != null:
		_ambient_music_player.stream_paused = false


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

	_ambient_music_resume_position = max(float(return_data.get("world_music_resume_position", 0.0)), 0.0)

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
		if encounter_id == DARK_QUEEN_FINAL_ENCOUNTER_ID:
			_show_dark_queen_defeated_dialogue()
		elif _should_hide_defeated_encounter(encounter_id):
			_apply_defeated_encounter(encounter_id)
	elif battle_result is Dictionary and str(battle_result.get("outcome", "")) == "escaped":
		_esbirro_battle_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC

	if return_data.has("player_position") and return_data["player_position"] is Vector2:
		_set_player_saved_position(player, return_data["player_position"])
	return true


func _show_dark_queen_defeated_dialogue() -> void:
	_show_dialogue(
		"Reina Oscura",
		DARK_QUEEN_DEFEATED_DIALOGUE,
		Callable(self, "_finish_dark_queen_defeated_dialogue")
	)


func _finish_dark_queen_defeated_dialogue() -> void:
	_apply_defeated_encounter(DARK_QUEEN_FINAL_ENCOUNTER_ID)
	_set_exit_door_open(true)


func _apply_saved_player_position() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_game_state"):
		return

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		return

	var saved_location = str(game_state.get("current_location", ""))
	if saved_location not in ["dungeonAgua", "dungeon_agua"]:
		return

	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags == null or important_flags is not Dictionary:
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
	_set_player_saved_position(player, saved_position)


func _set_player_saved_position(player: Node2D, saved_position: Vector2) -> void:
	player.global_position = saved_position
	if player.has_method("set_spawn_position"):
		player.call("set_spawn_position", saved_position)
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager != null and database_manager.has_method("cache_player_world_position"):
		database_manager.call("cache_player_world_position", "res://Scenes/dungeonAgua.tscn", saved_position)


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
		if encounter_id_text == DARK_QUEEN_FINAL_ENCOUNTER_ID and _is_dialogue_open():
			continue
		if bool(defeated_encounters.get(encounter_id, false)) and _should_hide_defeated_encounter(encounter_id_text):
			_apply_defeated_encounter(encounter_id_text)

	if bool(defeated_encounters.get(DARK_QUEEN_FINAL_ENCOUNTER_ID, false)):
		_exit_door_unlocked = true


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


func _setup_exit_door_interaction_area() -> void:
	var door = get_node_or_null(EXIT_DOOR_NODE_PATH) as AnimatedSprite2D
	if door == null:
		push_warning("No se encontro la puerta de salida de la dungeon de agua.")
		return

	var exit_area = Area2D.new()
	exit_area.name = "ExitDoorArea"
	exit_area.collision_layer = 0
	exit_area.monitorable = false
	exit_area.monitoring = true
	add_child(exit_area)
	exit_area.global_position = door.global_position + Vector2(0.0, 12.0)

	var exit_shape = CollisionShape2D.new()
	exit_shape.name = "CollisionShape2D"
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(58.0, 44.0)
	exit_shape.shape = rectangle_shape
	exit_area.add_child(exit_shape)

	exit_area.body_entered.connect(_on_exit_door_area_body_entered)
	exit_area.body_exited.connect(_on_exit_door_area_body_exited)


func _on_exit_door_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit_dungeon = true


func _on_exit_door_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_exit_dungeon = false


func _try_exit_to_credits() -> bool:
	if not _exit_door_unlocked or not _player_can_exit_dungeon or is_instance_valid(options_ingame):
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		return false

	_persist_player_inventory_state()
	var tree = get_tree()
	if tree == null:
		return false
	return tree.change_scene_to_file(CREDITS_SCENE) == OK


func _set_exit_door_open(play_animation: bool) -> void:
	_exit_door_unlocked = true
	var door = get_node_or_null(EXIT_DOOR_NODE_PATH) as AnimatedSprite2D
	if door == null or door.sprite_frames == null:
		return

	var animation_name = _get_exit_door_open_animation(door)
	if animation_name == StringName():
		return

	door.visible = true
	door.sprite_frames.set_animation_loop(animation_name, false)
	door.animation = animation_name
	if play_animation:
		door.frame = 0
		door.play(animation_name)
		await door.animation_finished

	door.stop()
	door.animation = animation_name
	var frame_count = door.sprite_frames.get_frame_count(animation_name)
	door.frame = clampi(EXIT_DOOR_FREEZE_FRAME, 0, max(frame_count - 1, 0))
	door.frame_progress = 0.0


func _get_exit_door_open_animation(door: AnimatedSprite2D) -> StringName:
	if door.sprite_frames == null:
		return StringName()
	if door.sprite_frames.has_animation(EXIT_DOOR_OPEN_ANIMATION):
		return EXIT_DOOR_OPEN_ANIMATION
	if door.sprite_frames.has_animation(EXIT_DOOR_FALLBACK_ANIMATION):
		return EXIT_DOOR_FALLBACK_ANIMATION
	var animation_names = door.sprite_frames.get_animation_names()
	if animation_names.is_empty():
		return StringName()
	return animation_names[0]


func _is_final_boss_defeated() -> bool:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_game_state"):
		return false

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		return false

	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags == null or important_flags is not Dictionary:
		return false

	var defeated_encounters = important_flags.get("defeated_encounters", {})
	if defeated_encounters is String:
		defeated_encounters = JSON.parse_string(defeated_encounters)
	if defeated_encounters == null or defeated_encounters is not Dictionary:
		return false
	return bool(defeated_encounters.get(DARK_QUEEN_FINAL_ENCOUNTER_ID, false))


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


func _is_dialogue_advance_event(event: InputEvent) -> bool:
	if _is_interact_event(event):
		return true
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
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
