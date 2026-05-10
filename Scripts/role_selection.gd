extends Control

const DisplaySettings = preload("res://Scripts/display_settings.gd")

const MAIN_MENU_SCENE = "res://Scenes/ui/menu.tscn"
const WORLD_SCENE = "res://Scenes/world/aldea_principal.tscn"
const SAVE_SLOT_ID = 1
const GUERRERO_TEXTURE: Texture2D = preload("res://images/guerrero.png")
const ARQUERO_TEXTURE: Texture2D = preload("res://images/Sprite-0001.png")
const MAGO_TEXTURE: Texture2D = preload("res://images/mago.png")
const ARQUERA_SHEET: Texture2D = preload("res://images/Sprite-0001.png")
const GUERRERO_SHEET: Texture2D = preload("res://images/guerrero.png")
const MAGO_SHEET: Texture2D = preload("res://images/mago.png")

const ROLE_ORDER := ["arquero", "guerrero", "mago"]
const ROLE_ANIMATION_FPS := 8.5
const SELECTED_MODULATE := Color(1, 1, 1, 1)
const DIMMED_MODULATE := Color(0.36, 0.36, 0.43, 0.88)
const SELECTED_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2(0.92, 0.92)
const LABEL_Y_OFFSET := 72.0
const STAGE_Y_RATIO := 0.37
const HIGHLIGHT_TOP_RATIO := 0.86
const HIGHLIGHT_SIZE_FACTOR := Vector2(1.08, 1.24)
const MIN_HITBOX_SIZE := Vector2(72, 96)
const ROLE_SWAP_TWEEN_DURATION := 0.22

@onready var _role_stage: Node2D = $RoleStage
@onready var _selection_highlight: Panel = $SelectionHighlight
@onready var _title_label: Label = $HUD/Title
@onready var _name_arquera_label: Label = $HUD/NameArquera
@onready var _name_guerrero_label: Label = $HUD/NameGuerrero
@onready var _name_mago_label: Label = $HUD/NameMago
@onready var _stats_panel: PanelContainer = $HUD/StatsPanel
@onready var _stats_toggle_button: Button = $HUD/StatsToggleButton
@onready var _role_name_label: Label = $HUD/StatsPanel/MarginContainer/StatsLayout/RoleName
@onready var _role_description_label: Label = $HUD/StatsPanel/MarginContainer/StatsLayout/RoleDescription
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _play_button: TextureButton = $HUD/ActionBar/PlayButton
@onready var _play_button_label: Label = $HUD/ActionBar/PlayButton/Label
@onready var _back_button: TextureButton = $HUD/ActionBar/BackButton

var _selected_role := "guerrero"
var _roles: Dictionary = {}
var _role_sprites: Dictionary = {}
var _role_hit_areas: Dictionary = {}
var _role_name_labels: Dictionary = {}
var _stat_rows: Dictionary = {}
var _buttons_locked := false
var _stats_visible := false
var _slot_positions: Dictionary = {}
var _role_layout_tween: Tween


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	_roles = _create_default_roles()
	_load_role_stats_from_database()
	_cache_scene_nodes()
	_assign_role_spriteframes()
	_normalize_role_hitboxes()
	_connect_role_signals()
	_refresh_stat_rows_maximum()
	_arrange_role_sprites()
	_select_role(_selected_role, false)
	_set_stats_visible(false)
	if _selection_highlight != null:
		_selection_highlight.visible = false
	resized.connect(_on_viewport_resized)
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if _buttons_locked:
		return
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var hovered_control = get_viewport().gui_get_hovered_control()
	if hovered_control != null and hovered_control is BaseButton:
		return

	_try_select_role_from_click(get_global_mouse_position())


func _try_select_role_from_click(click_position: Vector2) -> void:
	var picked_role := ""
	var closest_distance := INF

	for role_id in ROLE_ORDER:
		var sprite = _role_sprites.get(role_id, null) as AnimatedSprite2D
		if sprite == null:
			continue

		var hit_rect = _get_sprite_click_rect(sprite)
		if hit_rect.has_point(click_position):
			var distance = click_position.distance_squared_to(sprite.global_position)
			if distance < closest_distance:
				closest_distance = distance
				picked_role = role_id

	if picked_role != "":
		_select_role(picked_role, true)


func _get_sprite_click_rect(sprite: AnimatedSprite2D) -> Rect2:
	if sprite == null:
		return Rect2()
	var frame_size = _get_sprite_frame_size(sprite)
	var click_size = Vector2(
		max(MIN_HITBOX_SIZE.x, frame_size.x * sprite.scale.x * 0.84),
		max(MIN_HITBOX_SIZE.y, frame_size.y * sprite.scale.y * 0.94)
	)
	var top_left = Vector2(
		sprite.global_position.x - (click_size.x * 0.5),
		sprite.global_position.y - (click_size.y * 0.62)
	)
	return Rect2(top_left, click_size)


func _create_default_roles() -> Dictionary:
	return {
		"guerrero": {
			"class_id": 1,
			"name": "Guerrero",
			"short_name": "GUERRERO",
			"description": "Primera linea resistente. Aguanta golpes y pega fuerte cuerpo a cuerpo.",
			"max_hp": 160,
			"max_mana": 20,
			"attack": 18,
			"defense": 14,
			"speed": 8,
			"skill_ids": [1],
			"skill_text": "Golpe Fuerte",
			"portrait": GUERRERO_TEXTURE,
			"accent": Color(0.96, 0.46, 0.32, 1)
		},
		"arquero": {
			"class_id": 3,
			"name": "Arquera",
			"short_name": "ARQUERA",
			"description": "Clase agil de distancia. Menos defensa, mucha velocidad y precision.",
			"max_hp": 110,
			"max_mana": 35,
			"attack": 14,
			"defense": 9,
			"speed": 14,
			"skill_ids": [3],
			"skill_text": "Disparo Certero",
			"portrait": ARQUERO_TEXTURE,
			"accent": Color(0.58, 0.82, 0.34, 1)
		},
		"mago": {
			"class_id": 2,
			"name": "Mago",
			"short_name": "MAGO",
			"description": "Especialista en mana y dano magico. Fragil, pero con gran potencial.",
			"max_hp": 95,
			"max_mana": 120,
			"attack": 9,
			"defense": 7,
			"speed": 10,
			"skill_ids": [2],
			"skill_text": "Bola de Fuego",
			"portrait": MAGO_TEXTURE,
			"accent": Color(0.75, 0.38, 0.96, 1)
		}
	}


func _load_role_stats_from_database() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_classes"):
		return

	var class_rows = database_manager.call("get_classes")
	if class_rows is not Array:
		return

	for row in class_rows:
		if row is not Dictionary:
			continue

		var role_id = str(row.get("name", "")).strip_edges().to_lower()
		if not _roles.has(role_id):
			continue

		var role_data: Dictionary = _roles[role_id]
		role_data["class_id"] = int(row.get("id", role_data.get("class_id", 0)))
		role_data["description"] = str(row.get("description", role_data.get("description", "")))
		role_data["max_hp"] = int(row.get("base_max_hp", role_data.get("max_hp", 1)))
		role_data["max_mana"] = int(row.get("base_max_mana", role_data.get("max_mana", 0)))
		role_data["attack"] = int(row.get("base_attack", role_data.get("attack", 0)))
		role_data["defense"] = int(row.get("base_defense", role_data.get("defense", 0)))
		role_data["speed"] = int(row.get("base_speed", role_data.get("speed", 0)))
		_roles[role_id] = role_data


func _cache_scene_nodes() -> void:
	_role_sprites = {
		"arquero": $RoleStage/arquera as AnimatedSprite2D,
		"guerrero": $RoleStage/guerrero as AnimatedSprite2D,
		"mago": $RoleStage/mago as AnimatedSprite2D
	}
	_role_hit_areas = {
		"arquero": $RoleStage/arquera/HitArea as Area2D,
		"guerrero": $RoleStage/guerrero/HitArea as Area2D,
		"mago": $RoleStage/mago/HitArea as Area2D
	}
	_role_name_labels = {
		"arquero": _name_arquera_label,
		"guerrero": _name_guerrero_label,
		"mago": _name_mago_label
	}
	_stat_rows = {
		"max_hp": _get_stat_row_nodes("HpRow"),
		"max_mana": _get_stat_row_nodes("MpRow"),
		"attack": _get_stat_row_nodes("AttackRow"),
		"defense": _get_stat_row_nodes("DefenseRow"),
		"speed": _get_stat_row_nodes("SpeedRow")
	}

	for role_id in ROLE_ORDER:
		if not _roles.has(role_id) or not _role_name_labels.has(role_id):
			continue
		var role_data: Dictionary = _roles[role_id]
		var role_label = _role_name_labels[role_id] as Label
		if role_label != null:
			role_label.text = str(role_data.get("short_name", role_id.to_upper()))


func _get_stat_row_nodes(row_name: String) -> Dictionary:
	var row = $HUD/StatsPanel/MarginContainer/StatsLayout/StatsRows.get_node(row_name)
	return {
		"bar": row.get_node("Bar") as ProgressBar,
		"value": row.get_node("Value") as Label
	}


func _connect_role_signals() -> void:
	if _play_button != null:
		_play_button.pressed.connect(_on_play_pressed)
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _stats_toggle_button != null:
		_stats_toggle_button.pressed.connect(_on_stats_toggle_pressed)


func _normalize_role_hitboxes() -> void:
	for role_id in ROLE_ORDER:
		var hit_area = _role_hit_areas.get(role_id, null) as Area2D
		var sprite = _role_sprites.get(role_id, null) as AnimatedSprite2D
		if hit_area == null:
			continue

		hit_area.position = Vector2.ZERO
		hit_area.input_pickable = true
		hit_area.collision_layer = 1
		hit_area.collision_mask = 0

		var collision_shape = hit_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape == null:
			continue

		collision_shape.position = Vector2.ZERO
		var frame_size = _get_sprite_frame_size(sprite)
		var target_size = Vector2(
			max(MIN_HITBOX_SIZE.x, frame_size.x * 0.8),
			max(MIN_HITBOX_SIZE.y, frame_size.y * 0.92)
		)

		var rectangle_shape = collision_shape.shape as RectangleShape2D
		if rectangle_shape == null:
			rectangle_shape = RectangleShape2D.new()
			collision_shape.shape = rectangle_shape
		rectangle_shape.size = target_size


func _get_sprite_frame_size(sprite: AnimatedSprite2D) -> Vector2:
	if sprite == null or sprite.sprite_frames == null:
		return Vector2(128, 128)

	var animation_name: StringName = &"default"
	if not sprite.sprite_frames.has_animation(animation_name):
		var available_animations = sprite.sprite_frames.get_animation_names()
		if available_animations.is_empty():
			return Vector2(128, 128)
		animation_name = available_animations[0]

	if sprite.sprite_frames.get_frame_count(animation_name) <= 0:
		return Vector2(128, 128)

	var frame_texture = sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return Vector2(128, 128)

	return frame_texture.get_size()


func _on_stats_toggle_pressed() -> void:
	if _buttons_locked:
		return
	_set_stats_visible(not _stats_visible)


func _set_stats_visible(visible: bool) -> void:
	_stats_visible = visible
	if _stats_panel != null:
		_stats_panel.visible = visible
	_update_status_label()


func _assign_role_spriteframes() -> void:
	_apply_sheet_to_role("arquero", ARQUERA_SHEET)
	_apply_sheet_to_role("guerrero", GUERRERO_SHEET)
	_apply_sheet_to_role("mago", MAGO_SHEET)


func _apply_sheet_to_role(role_id: String, sprite_sheet: Texture2D) -> void:
	var sprite = _role_sprites.get(role_id, null) as AnimatedSprite2D
	if sprite == null or sprite_sheet == null:
		return

	sprite.sprite_frames = _build_sprite_frames_from_strip(sprite_sheet, ROLE_ANIMATION_FPS)
	sprite.animation = &"default"
	sprite.frame = 0


func _build_sprite_frames_from_strip(sprite_sheet: Texture2D, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var animation_name: StringName = &"default"
	if frames.has_animation(animation_name):
		frames.remove_animation(animation_name)
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, true)

	var sheet_size: Vector2 = sprite_sheet.get_size()
	var frame_size := int(sheet_size.y)
	if frame_size <= 0:
		frame_size = 128

	var frame_count := int(floor(sheet_size.x / float(frame_size)))
	if frame_count <= 0:
		frame_count = 1

	for frame_index in range(frame_count):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = sprite_sheet
		atlas_texture.region = Rect2(frame_index * frame_size, 0, frame_size, frame_size)
		atlas_texture.filter_clip = true
		frames.add_frame(animation_name, atlas_texture, 1.0)

	return frames


func _refresh_stat_rows_maximum() -> void:
	var max_stat = _get_highest_stat_value()
	for stat_name in _stat_rows.keys():
		var row: Dictionary = _stat_rows[stat_name]
		var bar = row.get("bar", null) as ProgressBar
		if bar != null:
			bar.max_value = max(1, max_stat)


func _arrange_role_sprites() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_role_stage.position = Vector2(viewport_size.x * 0.5, viewport_size.y * STAGE_Y_RATIO)
	_update_slot_positions(viewport_size)
	_apply_role_positions(_selected_role, false)


func _update_slot_positions(viewport_size: Vector2) -> void:
	var spacing = clamp(viewport_size.x * 0.28, 100.0, 150.0)
	_slot_positions = {
		"left": Vector2(-spacing, -2.0),
		"center": Vector2(0, 10.0),
		"right": Vector2(spacing, -2.0)
	}


func _get_slot_map_for_center(center_role: String) -> Dictionary:
	var role_index = ROLE_ORDER.find(center_role)
	if role_index == -1:
		role_index = ROLE_ORDER.find("guerrero")
		if role_index == -1:
			role_index = 0

	var left_role = ROLE_ORDER[(role_index - 1 + ROLE_ORDER.size()) % ROLE_ORDER.size()]
	var right_role = ROLE_ORDER[(role_index + 1) % ROLE_ORDER.size()]
	return {
		left_role: "left",
		center_role: "center",
		right_role: "right"
	}


func _apply_role_positions(center_role: String, animate: bool) -> void:
	if _slot_positions.is_empty():
		return

	var slot_map = _get_slot_map_for_center(center_role)
	if _role_layout_tween != null and _role_layout_tween.is_running():
		_role_layout_tween.kill()

	if animate:
		_role_layout_tween = create_tween()
		_role_layout_tween.set_trans(Tween.TRANS_CUBIC)
		_role_layout_tween.set_ease(Tween.EASE_OUT)

	for role_id in slot_map.keys():
		var sprite = _role_sprites.get(role_id, null) as AnimatedSprite2D
		var role_label = _role_name_labels.get(role_id, null) as Label
		if sprite == null:
			continue
		var slot_name = str(slot_map[role_id])
		var target_position = _slot_positions.get(slot_name, Vector2.ZERO)
		sprite.z_index = 3 if slot_name == "center" else 2
		var target_label_position = _get_role_name_target_position(role_id, target_position)

		if animate:
			_role_layout_tween.parallel().tween_property(sprite, "position", target_position, ROLE_SWAP_TWEEN_DURATION)
			if role_label != null:
				_role_layout_tween.parallel().tween_property(role_label, "position", target_label_position, ROLE_SWAP_TWEEN_DURATION)
		else:
			sprite.position = target_position
			if role_label != null:
				role_label.position = target_label_position

	if animate and _role_layout_tween != null:
		_role_layout_tween.finished.connect(_on_role_layout_tween_finished, CONNECT_ONE_SHOT)
	else:
		_position_role_name_labels()


func _on_role_layout_tween_finished() -> void:
	_position_role_name_labels()


func _get_role_name_target_position(role_id: String, sprite_local_position: Vector2) -> Vector2:
	var role_label = _role_name_labels.get(role_id, null) as Label
	if role_label == null or _role_stage == null:
		return Vector2.ZERO

	var role_name_size = role_label.get_combined_minimum_size()
	role_label.size = role_name_size
	var sprite_global_position = _role_stage.to_global(sprite_local_position)
	return Vector2(
		sprite_global_position.x - (role_name_size.x * 0.5),
		sprite_global_position.y + LABEL_Y_OFFSET
	)


func _position_role_name_labels() -> void:
	for role_id in _role_name_labels.keys():
		var sprite = _role_sprites.get(role_id, null) as AnimatedSprite2D
		var role_label = _role_name_labels[role_id] as Label
		if sprite == null or role_label == null:
			continue

		role_label.position = _get_role_name_target_position(role_id, sprite.position)


func _on_viewport_resized() -> void:
	_arrange_role_sprites()


func _select_role(role_id: String, animate_movement: bool = true) -> void:
	if not _roles.has(role_id):
		return

	var role_changed = role_id != _selected_role
	_selected_role = role_id
	for current_role_id in _role_sprites.keys():
		var sprite = _role_sprites[current_role_id] as AnimatedSprite2D
		if sprite == null:
			continue

		var is_selected = current_role_id == role_id
		sprite.modulate = SELECTED_MODULATE if is_selected else DIMMED_MODULATE
		sprite.scale = SELECTED_SCALE if is_selected else NORMAL_SCALE
		_set_sprite_animation_state(sprite, is_selected)
		_update_role_name_style(current_role_id, is_selected)

	_apply_role_positions(role_id, animate_movement and role_changed)
	_update_stats_panel()


func _set_sprite_animation_state(sprite: AnimatedSprite2D, is_selected: bool) -> void:
	if sprite.sprite_frames == null:
		return

	var animation_to_use: StringName = &"default"
	if not sprite.sprite_frames.has_animation(animation_to_use):
		var available_animations = sprite.sprite_frames.get_animation_names()
		if available_animations.is_empty():
			return
		animation_to_use = StringName(available_animations[0])

	sprite.animation = animation_to_use
	if is_selected:
		sprite.play(animation_to_use)
	else:
		sprite.stop()
		sprite.frame = 0


func _update_role_name_style(role_id: String, is_selected: bool) -> void:
	var role_label = _role_name_labels.get(role_id, null) as Label
	if role_label == null:
		return

	role_label.modulate = Color(1, 1, 1, 1) if is_selected else Color(0.7, 0.72, 0.78, 0.8)


func _update_stats_panel() -> void:
	if not _roles.has(_selected_role):
		return

	var role_data: Dictionary = _roles[_selected_role]
	if _title_label != null:
		_title_label.text = "SELECCIONA TU AVENTURERO"
	if _role_name_label != null:
		_role_name_label.text = "%s  |  Habilidad: %s" % [
			str(role_data.get("short_name", "ROL")),
			str(role_data.get("skill_text", "-"))
		]
	if _role_description_label != null:
		_role_description_label.text = str(role_data.get("description", ""))
	if _play_button_label != null:
		_play_button_label.text = "JUGAR CON %s" % str(role_data.get("short_name", "ROL"))
	_update_status_label()

	_update_stat_row("max_hp", int(role_data.get("max_hp", 0)))
	_update_stat_row("max_mana", int(role_data.get("max_mana", 0)))
	_update_stat_row("attack", int(role_data.get("attack", 0)))
	_update_stat_row("defense", int(role_data.get("defense", 0)))
	_update_stat_row("speed", int(role_data.get("speed", 0)))


func _update_stat_row(stat_name: String, value: int) -> void:
	if not _stat_rows.has(stat_name):
		return

	var row: Dictionary = _stat_rows[stat_name]
	var bar = row.get("bar", null) as ProgressBar
	var value_label = row.get("value", null) as Label
	if bar != null:
		bar.value = value
	if value_label != null:
		value_label.text = str(value)


func _update_selection_highlight() -> void:
	if _selection_highlight != null:
		_selection_highlight.visible = false


func _get_sprite_size(sprite: AnimatedSprite2D) -> Vector2:
	if sprite == null or sprite.sprite_frames == null:
		return Vector2(140, 210)
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return Vector2(140, 210)
	if sprite.sprite_frames.get_frame_count(sprite.animation) <= 0:
		return Vector2(140, 210)

	var frame_texture = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if frame_texture == null:
		return Vector2(140, 210)

	return frame_texture.get_size() * sprite.scale


func _on_play_pressed() -> void:
	if _buttons_locked:
		return

	_buttons_locked = true
	_set_buttons_disabled(true)
	_select_role(_selected_role, false)

	var role_name = str(_roles[_selected_role].get("name", "Rol"))
	_cache_selected_role(_selected_role)
	var persisted = _persist_selected_role(_selected_role)
	if persisted:
		_status_label.text = "%s aplicado. Entrando a la aldea..." % role_name
	else:
		_status_label.text = "%s elegido. Entrando con datos locales..." % role_name

	await get_tree().create_timer(0.28).timeout
	get_tree().change_scene_to_file(WORLD_SCENE)


func _cache_selected_role(role_id: String) -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("cache_selected_player_role"):
		return

	var role_data: Dictionary = _roles[role_id].duplicate(true)
	role_data["role_id"] = role_id
	role_data["character_name"] = _get_combat_character_name(role_id)
	role_data["current_hp"] = int(role_data.get("max_hp", 1))
	role_data["current_mana"] = int(role_data.get("max_mana", 0))
	database_manager.call("cache_selected_player_role", role_data)


func _persist_selected_role(role_id: String) -> bool:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("apply_player_role"):
		return false

	var character_id = _get_active_player_character_id(database_manager)
	if character_id <= 0:
		return false

	var role_data: Dictionary = _roles[role_id]
	var skill_ids = role_data.get("skill_ids", [])
	if skill_ids is not Array:
		skill_ids = []

	return bool(database_manager.call(
		"apply_player_role",
		SAVE_SLOT_ID,
		character_id,
		int(role_data.get("class_id", 0)),
		skill_ids,
		_get_combat_character_name(role_id)
	))


func _get_combat_character_name(role_id: String) -> String:
	match role_id:
		"guerrero":
			return "Guerrero"
		"arquero":
			return "Arquero"
		"mago":
			return "Mago"
		_:
			var role_data = _roles.get(role_id, {})
			if role_data is Dictionary:
				return str(role_data.get("name", "Aventurero"))
			return "Aventurero"


func _get_active_player_character_id(database_manager: Node) -> int:
	if not database_manager.has_method("get_characters"):
		return 1

	var rows = database_manager.call("get_characters", SAVE_SLOT_ID)
	if rows is not Array:
		return 1

	var fallback_id = 0
	for row in rows:
		if row is not Dictionary:
			continue
		if str(row.get("character_type", "")) != "player":
			continue
		if int(row.get("is_active", 1)) != 1:
			continue

		var character_id = int(row.get("id", 0))
		if fallback_id == 0:
			fallback_id = character_id
		if str(row.get("name", "")).strip_edges().to_lower() == "ariadna":
			return character_id

	return fallback_id


func _set_buttons_disabled(disabled: bool) -> void:
	if _play_button != null:
		_play_button.disabled = disabled
	if _back_button != null:
		_back_button.disabled = disabled
	if _stats_toggle_button != null:
		_stats_toggle_button.disabled = disabled


func _on_back_pressed() -> void:
	if _buttons_locked:
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _play_intro() -> void:
	pass


func _update_status_label() -> void:
	if _status_label == null:
		return

	var role_name = "rol"
	if _roles.has(_selected_role):
		role_name = str(_roles[_selected_role].get("name", _selected_role))

	if _stats_visible:
		_status_label.text = "Preseleccionado: %s" % role_name
	else:
		_status_label.text = "Preseleccionado: %s  |  pulsa ! para ver estadisticas" % role_name


func _get_highest_stat_value() -> int:
	var max_value = 1
	for role_id in _roles.keys():
		var role_data: Dictionary = _roles[role_id]
		max_value = max(max_value, int(role_data.get("max_hp", 0)))
		max_value = max(max_value, int(role_data.get("max_mana", 0)))
		max_value = max(max_value, int(role_data.get("attack", 0)))
		max_value = max(max_value, int(role_data.get("defense", 0)))
		max_value = max(max_value, int(role_data.get("speed", 0)))
	return max_value
