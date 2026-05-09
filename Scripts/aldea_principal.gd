extends Node2D

const OPTIONS_INGAME_SCENE: PackedScene = preload("res://Scenes/options_ingame.tscn")

const PLAYER_NODE_PATH = NodePath("player")
const VILLAGE_NODE_PATH = NodePath("aldea")
const BATTLE_MANAGER_ROOT_PATH = NodePath("/root/BattleManager")
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


func _ready() -> void:
	_apply_battle_return_position()
	_configure_player_camera()
	_setup_village_buildings()


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
