extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/ui/options_ingame.tscn")

const PLAYER_NODE_PATH = NodePath("player")
const VILLAGE_NODE_PATH = NodePath("aldea")
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
const HERRERIA_SCENE = "res://Scenes/world/herreria.tscn"
const DUNGEON_AGUA_SCENE = "res://Scenes/dungeonAgua.tscn"
const TAVERN_SCENE = "res://Scenes/world/tavern.tscn"
const INTERACT_ACTION = "interact"
const SAVE_SLOT_ID = 1
const CASTILLO_AGUA_ENTRY_SHAPE_PATH = NodePath("aldea/CastilloAgua/entrar")
const TAVERN_ENTRY_SHAPE_PATH = NodePath("tavern/entrar/entrar")
const BATTLE_REENTRY_COOLDOWN_MSEC = 2000
const DARK_QUEEN_GATE_ENCOUNTER_ID = "dark_queen_gate"
const DUNGEON_QUEEN_SANCTUM_ENCOUNTER_ID = "dungeon_queen_sanctum"
const DARK_QUEEN_NODE_PATH = NodePath("npcs/ReinaOscura")
const MUELLE_BOY_AMAZED_ENCOUNTER_ID = "muelle_boy_amazed_lighthouse"
const MUELLE_BOY_AMAZED_NODE_PATH = NodePath("npcs/Niño Millonario")
const MUELLE_BOY_AMAZED_BATTLE_AREA_PATH = NodePath("npcs/Niño Millonario/BattleArea")
const FARO_BATTLE_BACKGROUND_PATH = "res://assets/battle/batalla_faro.png"
const MUELLE_BOY_AMAZED_SPRITE_PATH = "res://assets/muelle/Characters/Boy_amazed.png"
const MUELLE_BOY_PRE_BATTLE_DIALOGUE = "¿Ves esta caña? Es de oro macizo. ¡Te apuesto 1000 monedas a que no me vences en un duelo! ¿Aceptas?"
const MUELLE_BOY_POST_BATTLE_DIALOGUE = "¡Maldición! Mi equipo era mejor... Toma tu oro y lárgate, suertudo."
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
var _player_can_enter_tavern = false
var _battle_reentry_cooldown_until_msec = 0
var _muelle_boy_amazed_cooldown_until_msec = 0
var _muelle_boy_amazed_retry_scheduled = false
var _muelle_boy_pending_battle_body: Node2D = null
var _world_dialogue_layer: CanvasLayer = null
var _world_dialogue_portrait: TextureRect = null
var _world_dialogue_message: Label = null
var _world_dialogue_npc_name = ""
var _world_dialogue_pages: PackedStringArray = []
var _world_dialogue_page_index = 0
var _world_dialogue_finished_callback: Callable = Callable()


func _ready() -> void:
	var used_battle_return = _apply_battle_return_position()
	if not used_battle_return and not _apply_transition_spawn_position():
		_apply_saved_player_position()
	_apply_defeated_encounter_state()
	_configure_player_camera()
	_setup_castillo_agua_entry_area()
	_setup_tavern_entry_area()
	_setup_muelle_boy_dialogue_cancel()
	_setup_village_buildings()


func _input(event: InputEvent) -> void:
	if _is_world_dialogue_open():
		if _is_dialogue_advance_event(event):
			var viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			_advance_world_dialogue()
		return

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

	if _is_interact_event(event) and _player_can_enter_tavern:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_try_enter_tavern()
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

	if _is_world_dialogue_open() or _muelle_boy_pending_battle_body != null:
		return

	if _is_muelle_boy_amazed_battle_on_cooldown():
		_schedule_muelle_boy_amazed_battle_retry()
		return

	_muelle_boy_pending_battle_body = body
	_show_world_dialogue(
		"Niño Millonario",
		PackedStringArray([MUELLE_BOY_PRE_BATTLE_DIALOGUE]),
		MUELLE_BOY_AMAZED_SPRITE_PATH,
		Callable(self, "_start_muelle_boy_battle_after_dialogue")
	)


func _start_muelle_boy_battle_after_dialogue() -> void:
	var body = _muelle_boy_pending_battle_body
	_muelle_boy_pending_battle_body = null
	if body == null or not is_instance_valid(body) or _is_muelle_boy_amazed_battle_on_cooldown():
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


func _on_muelle_boy_amazed_battle_area_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	if _muelle_boy_pending_battle_body == body:
		_muelle_boy_pending_battle_body = null
		_hide_world_dialogue()


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


func _try_enter_tavern() -> bool:
	if not _player_can_enter_tavern or is_instance_valid(options_ingame):
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH)
	if player != null and player.has_method("is_inventory_open") and bool(player.call("is_inventory_open")):
		return false

	var tree = get_tree()
	if tree == null:
		return false

	_persist_player_inventory_state()
	return tree.change_scene_to_file(TAVERN_SCENE) == OK


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


func _setup_tavern_entry_area() -> void:
	var entry_shape = get_node_or_null(TAVERN_ENTRY_SHAPE_PATH) as CollisionShape2D
	if entry_shape == null or entry_shape.shape == null:
		push_warning("No se encontro la CollisionShape2D entrar de la taberna.")
		return

	var entry_area = Area2D.new()
	entry_area.name = "TavernEntryArea"
	entry_area.collision_layer = 0
	entry_area.monitorable = false
	entry_area.monitoring = true
	add_child(entry_area)
	entry_area.global_transform = entry_shape.global_transform

	var area_shape = CollisionShape2D.new()
	area_shape.name = "CollisionShape2D"
	area_shape.shape = entry_shape.shape
	entry_area.add_child(area_shape)

	entry_area.body_entered.connect(_on_tavern_entry_area_body_entered)
	entry_area.body_exited.connect(_on_tavern_entry_area_body_exited)


func _on_tavern_entry_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_enter_tavern = true


func _on_tavern_entry_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_can_enter_tavern = false


func _setup_muelle_boy_dialogue_cancel() -> void:
	var battle_area = get_node_or_null(MUELLE_BOY_AMAZED_BATTLE_AREA_PATH) as Area2D
	if battle_area == null:
		return
	if not battle_area.body_exited.is_connected(_on_muelle_boy_amazed_battle_area_body_exited):
		battle_area.body_exited.connect(_on_muelle_boy_amazed_battle_area_body_exited)


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


func _show_world_dialogue(npc_name: String, pages: PackedStringArray, portrait_path: String, finished_callback: Callable = Callable()) -> void:
	if pages.is_empty():
		if finished_callback.is_valid():
			finished_callback.call()
		return

	_ensure_world_dialogue_ui()
	if _world_dialogue_layer == null or _world_dialogue_message == null:
		if finished_callback.is_valid():
			finished_callback.call()
		return

	_world_dialogue_pages = pages
	_world_dialogue_page_index = 0
	_world_dialogue_npc_name = npc_name
	_world_dialogue_finished_callback = finished_callback
	if _world_dialogue_portrait != null:
		_world_dialogue_portrait.texture = _load_dialogue_portrait(portrait_path)
	_world_dialogue_layer.visible = true
	_set_world_dialogue_text(npc_name, _world_dialogue_pages[_world_dialogue_page_index])


func _ensure_world_dialogue_ui() -> void:
	if _world_dialogue_layer != null:
		return

	_world_dialogue_layer = CanvasLayer.new()
	_world_dialogue_layer.name = "WorldDialogueLayer"
	_world_dialogue_layer.layer = 40
	add_child(_world_dialogue_layer)

	var panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 8.0
	panel.offset_top = -72.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.11, 0.92)
	style.border_color = Color(0.74, 0.7, 0.58, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)
	_world_dialogue_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	_world_dialogue_portrait = TextureRect.new()
	_world_dialogue_portrait.custom_minimum_size = Vector2(54, 54)
	_world_dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_world_dialogue_portrait)

	_world_dialogue_message = Label.new()
	_world_dialogue_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_dialogue_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_world_dialogue_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_dialogue_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = LabelSettings.new()
	label_settings.font_size = 8
	label_settings.font_color = Color(0.95, 0.95, 0.9, 1)
	label_settings.outline_size = 1
	label_settings.outline_color = Color(0.08, 0.08, 0.08, 1)
	_world_dialogue_message.label_settings = label_settings
	row.add_child(_world_dialogue_message)

	_world_dialogue_layer.visible = false


func _load_dialogue_portrait(texture_path: String) -> Texture2D:
	var texture = load(texture_path) as Texture2D
	if texture == null:
		return null
	if texture_path == MUELLE_BOY_AMAZED_SPRITE_PATH:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0, 0, 32, 48)
		return atlas
	return texture


func _set_world_dialogue_text(npc_name: String, page_text: String) -> void:
	if _world_dialogue_message == null:
		return
	if npc_name.strip_edges().is_empty():
		_world_dialogue_message.text = page_text
	else:
		_world_dialogue_message.text = "%s\n%s" % [npc_name, page_text]


func _advance_world_dialogue() -> void:
	if _world_dialogue_page_index < _world_dialogue_pages.size() - 1:
		_world_dialogue_page_index += 1
		_set_world_dialogue_text(_world_dialogue_npc_name, _world_dialogue_pages[_world_dialogue_page_index])
		return

	var finished_callback = _world_dialogue_finished_callback
	_hide_world_dialogue()
	if finished_callback.is_valid():
		finished_callback.call()


func _hide_world_dialogue() -> void:
	if _world_dialogue_layer != null:
		_world_dialogue_layer.visible = false
	_world_dialogue_pages = []
	_world_dialogue_npc_name = ""
	_world_dialogue_page_index = 0
	_world_dialogue_finished_callback = Callable()


func _is_world_dialogue_open() -> bool:
	return _world_dialogue_layer != null and _world_dialogue_layer.visible


func _is_dialogue_advance_event(event: InputEvent) -> bool:
	if _is_interact_event(event):
		return true
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return false


func save_current_game_from_pause() -> bool:
	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	var database_manager = get_node_or_null("/root/GameDatabase")
	if player == null or database_manager == null or not database_manager.has_method("save_player_world_position"):
		return false

	_persist_player_inventory_state()
	return bool(database_manager.call(
		"save_player_world_position",
		SAVE_SLOT_ID,
		_get_current_scene_path("res://Scenes/world/aldea_principal.tscn"),
		player.global_position
	))


func _get_current_scene_path(fallback_scene_path: String) -> String:
	var tree = get_tree()
	if tree != null and tree.current_scene != null and not tree.current_scene.scene_file_path.is_empty():
		return tree.current_scene.scene_file_path
	return fallback_scene_path


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
		if bool(battle_result.get("restore_full_health", false)):
			if return_data.has("player_position") and return_data["player_position"] is Vector2:
				_set_player_saved_position(player, return_data["player_position"])
			_restore_active_party_to_full_health()
			_save_respawn_state(player.global_position)
		elif not _restore_player_from_autosave(player):
			if player.has_method("morir"):
				player.call_deferred("morir")
		return true

	if battle_result is Dictionary and str(battle_result.get("outcome", "")) == "victory":
		var encounter_id = str(return_data.get("encounter_id", ""))
		if encounter_id == MUELLE_BOY_AMAZED_ENCOUNTER_ID:
			_show_muelle_boy_post_battle_dialogue()
		elif _should_hide_defeated_encounter(encounter_id):
			_apply_defeated_encounter(encounter_id)
	elif battle_result is Dictionary and str(battle_result.get("outcome", "")) == "escaped":
		_battle_reentry_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC
		if str(return_data.get("encounter_id", "")) == MUELLE_BOY_AMAZED_ENCOUNTER_ID:
			_muelle_boy_amazed_cooldown_until_msec = Time.get_ticks_msec() + BATTLE_REENTRY_COOLDOWN_MSEC

	if return_data.has("player_position") and return_data["player_position"] is Vector2:
		_set_player_saved_position(player, return_data["player_position"])
	return true


func _show_muelle_boy_post_battle_dialogue() -> void:
	_show_world_dialogue(
		"Niño Millonario",
		PackedStringArray([MUELLE_BOY_POST_BATTLE_DIALOGUE]),
		MUELLE_BOY_AMAZED_SPRITE_PATH,
		Callable(self, "_finish_muelle_boy_post_battle_dialogue")
	)


func _finish_muelle_boy_post_battle_dialogue() -> void:
	_apply_defeated_encounter(MUELLE_BOY_AMAZED_ENCOUNTER_ID)


func _restore_active_party_to_full_health() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null:
		return
	if database_manager.has_method("discard_pending_changes"):
		database_manager.call("discard_pending_changes", SAVE_SLOT_ID)
	if database_manager.has_method("restore_active_party_to_full"):
		database_manager.call("restore_active_party_to_full", SAVE_SLOT_ID)


func _save_respawn_state(player_position: Vector2) -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("save_basic_game_state"):
		return

	var game_state = {}
	if database_manager.has_method("get_game_state"):
		game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		game_state = {}

	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags == null or important_flags is not Dictionary:
		important_flags = {}

	var saved_position = {
		"x": player_position.x,
		"y": player_position.y
	}
	important_flags["game_started"] = true
	important_flags["player_position"] = saved_position
	important_flags["autosave_position"] = saved_position
	important_flags["autosave_location"] = "aldea_principal"

	database_manager.call("save_basic_game_state", SAVE_SLOT_ID, {
		"save_name": str(game_state.get("save_name", "Partida %d" % SAVE_SLOT_ID)),
		"current_location": "aldea_principal",
		"gold": int(game_state.get("gold", 0)),
		"main_progress": int(game_state.get("main_progress", 0)),
		"important_flags": important_flags,
		"playtime_seconds": int(game_state.get("playtime_seconds", 0))
	})
	if database_manager.has_method("commit_manual_save"):
		database_manager.call("commit_manual_save", SAVE_SLOT_ID)


func _restore_player_from_autosave(player: Node2D) -> bool:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null:
		return false
	if database_manager.has_method("discard_pending_changes"):
		database_manager.call("discard_pending_changes", SAVE_SLOT_ID)
	if not database_manager.has_method("get_game_state"):
		return false

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		return false

	var saved_location = str(game_state.get("current_location", "aldea_principal"))
	if saved_location not in ["aldea_principal", "aldea"]:
		var scene_path = _get_scene_path_for_saved_location(saved_location)
		if not scene_path.is_empty():
			get_tree().call_deferred("change_scene_to_file", scene_path)
			return true
		return false

	var important_flags = game_state.get("important_flags", {})
	if important_flags is String:
		important_flags = JSON.parse_string(important_flags)
	if important_flags == null or important_flags is not Dictionary:
		return false

	var player_position = important_flags.get("player_position", important_flags.get("autosave_position", {}))
	if player_position is not Dictionary:
		return false

	var saved_position = Vector2(
		float(player_position.get("x", player.global_position.x)),
		float(player_position.get("y", player.global_position.y))
	)
	_set_player_saved_position(player, saved_position)
	return true


func _get_scene_path_for_saved_location(location_name: String) -> String:
	if location_name.begins_with("res://"):
		return location_name
	match location_name:
		"dungeonAgua", "dungeon_agua":
			return DUNGEON_AGUA_SCENE
		_:
			return ""


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


func _apply_transition_spawn_position() -> bool:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("consume_next_scene_spawn"):
		return false

	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return false

	var spawn_data = database_manager.call("consume_next_scene_spawn", tree.current_scene.scene_file_path)
	if spawn_data is not Dictionary or spawn_data.is_empty():
		return false

	var saved_position = spawn_data.get("position", null)
	if saved_position is not Vector2:
		return false

	var player = get_node_or_null(PLAYER_NODE_PATH) as Node2D
	if player == null:
		return false

	_set_player_saved_position(player, saved_position)
	return true


func _set_player_saved_position(player: Node2D, saved_position: Vector2) -> void:
	player.global_position = saved_position
	if player.has_method("set_spawn_position"):
		player.call("set_spawn_position", saved_position)
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager != null and database_manager.has_method("cache_player_world_position"):
		database_manager.call("cache_player_world_position", "res://Scenes/world/aldea_principal.tscn", saved_position)


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
