@tool
extends Control

const HERO_TEXTURE: Texture2D = preload("res://assets/player/guerrero/Idle.png")
const HERO_ATTACK_1_TEXTURE: Texture2D = preload("res://assets/player/guerrero/Attack 1.png")
const HERO_ATTACK_2_TEXTURE: Texture2D = preload("res://assets/player/guerrero/Attack 2.png")
const HERO_ATTACK_3_TEXTURE: Texture2D = preload("res://assets/player/guerrero/Attack 3.png")
const HERO_SWORD_ATTACK_TEXTURE: Texture2D = preload("res://assets/player/guerrero/Run+Attack.png")
const ARCHER_ROLE_TEXTURE: Texture2D = preload("res://images/Sprite-0001.png")
const MAGE_ROLE_TEXTURE: Texture2D = preload("res://images/mago.png")
const MAGE_TEXTURE: Texture2D = preload("res://assets/npcs/Peasants_3/Idle.png")
const SUPPORT_TEXTURE: Texture2D = preload("res://assets/npcs/Peasants_4/Idle.png")
const DARK_QUEEN_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/1/Idle.png")
const DARK_QUEEN_ATTACK_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/1/Attack_1.png")
const ESBIRRO_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/2/Idle.png")
const ESBIRRO_ATTACK_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/2/Attack.png")

const HERO_FRAME = Rect2(0, 56, 128, 72)
const HERO_FRAME_SIZE = Vector2(128, 72)
const HERO_IDLE_FRAME_COUNT = 4
const HERO_ATTACK_1_FRAME_COUNT = 5
const HERO_ATTACK_2_FRAME_COUNT = 4
const HERO_ATTACK_3_FRAME_COUNT = 4
const HERO_SWORD_ATTACK_FRAME_COUNT = 6
const HERO_IDLE_OFFSET = Vector2(0, 56)
const HERO_ATTACK_OFFSET = Vector2(0, 56)
const HERO_SWORD_ATTACK_OFFSET = Vector2(0, 56)
const HERO_IDLE_ANIMATION = &"idle"
const HERO_ATTACK_ANIMATION = &"attack"
const ROLE_IDLE_ANIMATION = &"role_idle"
const NPC_FRAME = Rect2(0, 0, 128, 128)
const DARK_QUEEN_FRAME = Rect2(0, 0, 128, 128)
const DARK_QUEEN_FRAME_SIZE = Vector2(128, 128)
const DARK_QUEEN_FRAME_COUNT = 7
const DARK_QUEEN_ATTACK_FRAME_COUNT = 6
const DARK_QUEEN_ANIMATION = &"idle"
const DARK_QUEEN_ATTACK_ANIMATION = &"attack"
const ESBIRRO_FRAME_SIZE = Vector2(128, 128)
const ESBIRRO_FRAME_COUNT = 6
const ESBIRRO_ATTACK_FRAME_COUNT = 6
const ESBIRRO_ANIMATION = &"idle"
const ESBIRRO_ATTACK_ANIMATION = &"attack"
const HP_BAR_WIDTH = 42.0
const HP_BAR_HEIGHT = 2.0
const MINI_HP_BAR_WIDTH = 52.0
const MINI_HP_BAR_HEIGHT = 3.0
const HP_COLOR_HIGH = Color(0.34509805, 0.8627451, 0.3137255, 1.0)
const HP_COLOR_MID = Color(0.972549, 0.7921569, 0.19607843, 1.0)
const HP_COLOR_LOW = Color(0.92156863, 0.27450982, 0.23921569, 1.0)
const WATER_SLASH_COLOR = Color(0.32, 0.86, 1.0, 0.92)
const WATER_SLASH_HIGHLIGHT_COLOR = Color(0.82, 0.98, 1.0, 0.9)
const WATER_DROPLET_COLOR = Color(0.58, 0.9, 1.0, 0.82)
const SHADOW_SLASH_COLOR = Color(0.35, 0.08, 0.48, 0.95)
const SHADOW_SLASH_HIGHLIGHT_COLOR = Color(0.86, 0.44, 1.0, 0.88)
const DARK_CROWN_COLOR = Color(0.48, 0.12, 0.76, 0.9)
const DARK_CROWN_HIGHLIGHT_COLOR = Color(0.95, 0.65, 1.0, 0.86)
const VOID_FLASH_COLOR = Color(0.04, 0.0, 0.09, 0.72)
const VOID_RIFT_COLOR = Color(0.72, 0.16, 1.0, 0.9)

var _is_warrior = false
var _is_dark_queen = false
var _is_esbirro = false
var _attack_lunge_direction = 1.0

@export var editor_preview_enabled = false:
	set(value):
		editor_preview_enabled = value
		_refresh_editor_preview()
@export_enum("party", "enemy") var editor_preview_side = "party":
	set(value):
		editor_preview_side = value
		_refresh_editor_preview()
@export var editor_preview_name = "Ariadna":
	set(value):
		editor_preview_name = value
		_refresh_editor_preview()
@export var editor_preview_role = "Guerrero":
	set(value):
		editor_preview_role = value
		_refresh_editor_preview()
@export var editor_preview_level = 4:
	set(value):
		editor_preview_level = value
		_refresh_editor_preview()

@onready var sprite_rect: TextureRect = $Sprite
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var shadow_rect: ColorRect = $Shadow
@onready var turn_marker: Label = $TurnMarker
@onready var level_label: Label = $LevelLabel
@onready var mini_hp_bar_bg: ColorRect = $MiniHpBarBg
@onready var mini_hp_bar_fill: ColorRect = $MiniHpBarBg/MiniHpBarFill
@onready var status_panel: PanelContainer = $StatusPanel
@onready var name_label: Label = $StatusPanel/MarginContainer/Layout/NameLabel
@onready var role_label: Label = $StatusPanel/MarginContainer/Layout/RoleLabel
@onready var hp_bar_bg: ColorRect = $StatusPanel/MarginContainer/Layout/HpBarBg
@onready var hp_bar_fill: ColorRect = $StatusPanel/MarginContainer/Layout/HpBarBg/HpBarFill
@onready var hp_label: Label = $StatusPanel/MarginContainer/Layout/StatsRow/HpLabel
@onready var mp_label: Label = $StatusPanel/MarginContainer/Layout/StatsRow/MpLabel
@onready var state_label: Label = $StatusPanel/MarginContainer/Layout/StateLabel


func _ready() -> void:
	_set_status_panel_visible()
	_hide_mini_hp_bar()
	_hide_outer_level_label()
	_refresh_editor_preview()


func apply_actor_data(actor_data: Dictionary) -> void:
	if not _has_required_nodes():
		push_warning("BattleActor no encontro todos los nodos visuales esperados.")
		return

	var side = str(actor_data.get("side", "party"))
	var slot_index = int(actor_data.get("battle_slot_index", 0))
	_apply_stage_position(side, slot_index, actor_data.get("battle_stage_position", null))
	_apply_sprite(actor_data, side)
	_apply_status(actor_data)
	_apply_turn_state(actor_data)


func _has_required_nodes() -> bool:
	return sprite_rect != null and animated_sprite != null and shadow_rect != null and turn_marker != null and level_label != null and mini_hp_bar_bg != null and mini_hp_bar_fill != null and status_panel != null and name_label != null and role_label != null and hp_bar_bg != null and hp_bar_fill != null and hp_label != null and mp_label != null and state_label != null


func _apply_stage_position(side: String, slot_index: int, slot_position: Variant = null) -> void:
	if slot_position is Vector2:
		position = slot_position
		z_index = 20 + slot_index
		if side != "enemy":
			z_index = 40 + slot_index
		return

	var party_slots = [
		Vector2(72, 54),
		Vector2(113, 61),
		Vector2(51, 63)
	]
	var enemy_slots = [
		Vector2(282, -50),
		Vector2(252, -50),
		Vector2(312, -41)
	]

	if side == "enemy":
		position = enemy_slots[slot_index % enemy_slots.size()]
		z_index = 20 + slot_index
	else:
		position = party_slots[slot_index % party_slots.size()]
		z_index = 40 + slot_index


func _apply_sprite(actor_data: Dictionary, side: String) -> void:
	var actor_name = str(actor_data.get("name", "")).to_lower()
	var role_name = str(actor_data.get("role", "")).to_lower()
	_is_warrior = false
	_is_dark_queen = false
	_is_esbirro = false
	_attack_lunge_direction = -1.0 if side == "enemy" else 1.0
	animated_sprite.visible = false
	animated_sprite.stop()
	animated_sprite.flip_h = false
	sprite_rect.texture = _make_atlas_texture(HERO_TEXTURE, HERO_FRAME)
	sprite_rect.visible = true
	sprite_rect.flip_h = false
	sprite_rect.position = Vector2(2, 8)
	sprite_rect.size = Vector2(76, 76)
	shadow_rect.position = Vector2(9, 66)
	shadow_rect.size = Vector2(66, 6)
	_apply_minimal_status_layout(Vector2(24, 9), Vector2(18, 73))

	if side == "enemy":
		if _try_apply_custom_enemy_sprite(actor_data):
			return
		_is_dark_queen = true
		sprite_rect.visible = false
		animated_sprite.visible = true
		animated_sprite.flip_h = bool(actor_data.get("sprite_flip_h", false))
		animated_sprite.position = Vector2(12, 0)
		animated_sprite.scale = Vector2(0.6875, 0.6875)
		_play_dark_queen_idle()
		shadow_rect.position = Vector2(23, 75)
		shadow_rect.size = Vector2(72, 7)
		_apply_enemy_status_layout()
		_apply_minimal_status_layout(Vector2(30, 4), Vector2(28, 82))
		return

	if _uses_hero_attack_sprite(actor_name, role_name):
		_is_warrior = true
		sprite_rect.visible = false
		animated_sprite.visible = true
		animated_sprite.position = Vector2(-7, 16)
		animated_sprite.scale = Vector2(0.72, 0.72)
		_play_hero_idle()
	elif _uses_mage_role_sprite(actor_name, role_name):
		_apply_party_role_sprite(MAGE_ROLE_TEXTURE)
	elif _uses_archer_role_sprite(actor_name, role_name):
		_apply_party_role_sprite(ARCHER_ROLE_TEXTURE)
	elif actor_name.contains("selene"):
		sprite_rect.texture = _make_atlas_texture(MAGE_TEXTURE, NPC_FRAME)
		sprite_rect.position = Vector2(7, 15)
		sprite_rect.size = Vector2(72, 72)
	elif role_name.contains("sanador"):
		sprite_rect.texture = _make_atlas_texture(SUPPORT_TEXTURE, NPC_FRAME)
		sprite_rect.position = Vector2(7, 15)
		sprite_rect.size = Vector2(72, 72)

	status_panel.position = Vector2(55, 5)
	status_panel.size = Vector2(80, 38)
	turn_marker.position = Vector2(43, 15)
	_apply_minimal_status_layout(Vector2(24, 9), Vector2(18, 73))

	if _is_warrior:
		status_panel.position.x = status_panel.position.x + 10.0
		status_panel.size.x = 96.0
		turn_marker.position.x = turn_marker.position.x + 10.0
		_apply_minimal_status_layout(Vector2(26, 9), Vector2(20, 80))


func _uses_hero_attack_sprite(actor_name: String, role_name: String) -> bool:
	return actor_name.contains("ariadna") or actor_name.contains("guerrero") or role_name.contains("guerrero")


func _uses_mage_role_sprite(actor_name: String, role_name: String) -> bool:
	return actor_name.contains("mago") or role_name.contains("mago")


func _uses_archer_role_sprite(actor_name: String, role_name: String) -> bool:
	return actor_name.contains("arquero") or actor_name.contains("arquera") or role_name.contains("arquero") or role_name.contains("arquera")


func _apply_party_role_sprite(texture: Texture2D) -> void:
	sprite_rect.visible = false
	animated_sprite.visible = true
	animated_sprite.position = Vector2(3, 1)
	animated_sprite.scale = Vector2(0.62, 0.62)
	animated_sprite.sprite_frames = _make_role_strip_sprite_frames(texture)
	animated_sprite.animation = ROLE_IDLE_ANIMATION
	animated_sprite.play(ROLE_IDLE_ANIMATION)
	shadow_rect.position = Vector2(14, 74)
	shadow_rect.size = Vector2(58, 6)
	_apply_minimal_status_layout(Vector2(24, 9), Vector2(18, 81))


func _try_apply_custom_enemy_sprite(actor_data: Dictionary) -> bool:
	var texture_path = str(actor_data.get("sprite_texture_path", "")).strip_edges()
	if texture_path.is_empty():
		return false

	if texture_path == "res://assets/Boss-DarkQueen/2/Idle.png":
		_apply_esbirro_sprite(actor_data)
		return true

	var texture = load(texture_path) as Texture2D
	if texture == null:
		push_warning("No se pudo cargar el sprite de enemigo: %s" % texture_path)
		return false

	var frame_x = int(actor_data.get("sprite_frame_x", 0))
	var frame_y = int(actor_data.get("sprite_frame_y", 0))
	var frame_width = int(actor_data.get("sprite_frame_width", 0))
	var frame_height = int(actor_data.get("sprite_frame_height", 0))
	if frame_width <= 0:
		frame_width = texture.get_width()
	if frame_height <= 0:
		frame_height = texture.get_height()

	var display_width = float(actor_data.get("sprite_display_width", 0.0))
	var display_height = float(actor_data.get("sprite_display_height", 0.0))
	if display_width <= 0.0:
		display_width = float(frame_width)
	if display_height <= 0.0:
		display_height = float(frame_height)

	sprite_rect.texture = _make_atlas_texture(texture, Rect2(frame_x, frame_y, frame_width, frame_height))
	sprite_rect.visible = true
	sprite_rect.flip_h = bool(actor_data.get("sprite_flip_h", false))
	sprite_rect.position = Vector2(
		float(actor_data.get("sprite_position_x", 0.0)),
		float(actor_data.get("sprite_position_y", 0.0))
	)
	sprite_rect.size = Vector2(display_width, display_height)
	animated_sprite.visible = false
	animated_sprite.stop()
	shadow_rect.position = Vector2(19, 75)
	shadow_rect.size = Vector2(60, 7)
	_apply_enemy_status_layout()
	_apply_minimal_status_layout(Vector2(25, 6), Vector2(21, 82))
	return true


func _apply_esbirro_sprite(actor_data: Dictionary) -> void:
	_is_esbirro = true
	sprite_rect.visible = false
	animated_sprite.visible = true
	animated_sprite.flip_h = bool(actor_data.get("sprite_flip_h", false))
	animated_sprite.position = Vector2(
		float(actor_data.get("sprite_position_x", 4.0)),
		float(actor_data.get("sprite_position_y", 2.0))
	)
	var display_width = max(float(actor_data.get("sprite_display_width", 76.0)), 1.0)
	var display_height = max(float(actor_data.get("sprite_display_height", 76.0)), 1.0)
	animated_sprite.scale = Vector2(display_width / ESBIRRO_FRAME_SIZE.x, display_height / ESBIRRO_FRAME_SIZE.y)
	_play_esbirro_idle()
	shadow_rect.position = Vector2(19, 75)
	shadow_rect.size = Vector2(60, 7)
	_apply_enemy_status_layout()
	_apply_minimal_status_layout(Vector2(25, 6), Vector2(21, 82))


func _apply_enemy_status_layout() -> void:
	status_panel.position = Vector2(-48, 60)
	status_panel.size = Vector2(84, 38)
	turn_marker.position = Vector2(-62, 67)


func _apply_status(actor_data: Dictionary) -> void:
	var actor_name = str(actor_data.get("name", "Combatiente"))
	var current_hp = int(actor_data.get("current_hp", 0))
	var max_hp = max(int(actor_data.get("max_hp", 1)), 1)
	var current_mp = int(actor_data.get("current_mana", 0))
	var max_mp = max(int(actor_data.get("max_mana", 0)), 0)
	var hp_ratio = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)

	level_label.text = "lvl.%d" % int(actor_data.get("level", 1))
	_hide_outer_level_label()
	name_label.text = "%s Lv.%d" % [actor_name, int(actor_data.get("level", 1))]
	role_label.text = str(actor_data.get("role", "Unidad"))
	hp_label.text = "HP %d/%d" % [current_hp, max_hp]
	mp_label.text = "MP %d/%d" % [current_mp, max_mp]

	var state_chunks: Array = [str(actor_data.get("state", "normal")).capitalize()]
	if bool(actor_data.get("defending", false)):
		state_chunks.append("Defiende")
	if actor_name.to_lower().contains("ariadna"):
		state_label.text = "Mana %d/%d" % [current_mp, max_mp]
	else:
		state_label.text = " | ".join(state_chunks)

	hp_bar_bg.clip_contents = true
	hp_bar_bg.custom_minimum_size = Vector2(HP_BAR_WIDTH + 2.0, HP_BAR_HEIGHT + 2.0)
	hp_bar_bg.size = hp_bar_bg.custom_minimum_size
	hp_bar_fill.position = Vector2(1.0, 1.0)
	var hp_fill_width = roundi(HP_BAR_WIDTH * hp_ratio)
	if current_hp > 0:
		hp_fill_width = max(hp_fill_width, 1)
	hp_bar_fill.size = Vector2(hp_fill_width, HP_BAR_HEIGHT)
	hp_bar_fill.color = _get_hp_bar_color(hp_ratio)
	_hide_mini_hp_bar()


func _apply_turn_state(actor_data: Dictionary) -> void:
	var is_defeated = int(actor_data.get("current_hp", 0)) <= 0
	var is_current_turn = bool(actor_data.get("is_current_turn", false))
	turn_marker.visible = is_current_turn and not is_defeated
	modulate = Color(1, 1, 1, 1)

	if is_defeated:
		modulate = Color(0.48, 0.48, 0.48, 0.82)
	elif is_current_turn:
		modulate = Color(1.0, 0.98, 0.78, 1.0)


func _apply_minimal_status_layout(level_position: Vector2, hp_bar_position: Vector2) -> void:
	level_label.position = level_position
	level_label.size = Vector2(42, 12)
	_hide_outer_level_label()
	mini_hp_bar_bg.position = hp_bar_position
	mini_hp_bar_bg.size = Vector2(MINI_HP_BAR_WIDTH + 2.0, MINI_HP_BAR_HEIGHT + 2.0)
	_hide_mini_hp_bar()


func _set_status_panel_visible() -> void:
	if status_panel != null:
		status_panel.visible = true


func _hide_mini_hp_bar() -> void:
	if mini_hp_bar_bg != null:
		mini_hp_bar_bg.visible = false


func _hide_outer_level_label() -> void:
	if level_label != null:
		level_label.visible = false


func play_action_animation(action_type: String = "attack") -> void:
	if action_type == "defend" or action_type == "flee":
		return
	if action_type != "attack" and action_type != "skill":
		return

	if not animated_sprite.visible:
		await _play_static_attack_animation()
		return

	if _is_warrior:
		animated_sprite.sprite_frames = _make_hero_attack_sprite_frames(action_type)
		animated_sprite.animation = HERO_ATTACK_ANIMATION
		animated_sprite.play(HERO_ATTACK_ANIMATION)
		await animated_sprite.animation_finished
		_play_hero_idle()
		return

	if _is_esbirro:
		if action_type != "attack" and action_type != "skill":
			return
		animated_sprite.sprite_frames = _make_sprite_frames(
			ESBIRRO_ATTACK_TEXTURE,
			ESBIRRO_FRAME_SIZE,
			ESBIRRO_ATTACK_FRAME_COUNT,
			ESBIRRO_ATTACK_ANIMATION,
			10.0,
			false
		)
		animated_sprite.animation = ESBIRRO_ATTACK_ANIMATION
		animated_sprite.play(ESBIRRO_ATTACK_ANIMATION)
		await animated_sprite.animation_finished
		_play_esbirro_idle()
		return

	if not _is_dark_queen:
		await _play_static_attack_animation()
		return

	animated_sprite.sprite_frames = _make_sprite_frames(
		DARK_QUEEN_ATTACK_TEXTURE,
		DARK_QUEEN_FRAME_SIZE,
		DARK_QUEEN_ATTACK_FRAME_COUNT,
		DARK_QUEEN_ATTACK_ANIMATION,
		10.0,
		false
	)
	animated_sprite.animation = DARK_QUEEN_ATTACK_ANIMATION
	animated_sprite.play(DARK_QUEEN_ATTACK_ANIMATION)
	await animated_sprite.animation_finished
	_play_dark_queen_idle()


func _play_static_attack_animation() -> void:
	if not is_inside_tree():
		return

	var original_position = position
	var attack_offset = Vector2(10.0 * _attack_lunge_direction, -2.0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", original_position + attack_offset, 0.08)
	tween.tween_property(self, "position", original_position, 0.12)
	await tween.finished
	position = original_position


func play_hit_effect(effect_name: String) -> void:
	match effect_name:
		"water_slash":
			await _play_water_slash_impact()
		"shadow_slash":
			await _play_shadow_slash_impact()
		"dark_crown":
			await _play_dark_crown_impact()
		"void_hit":
			await _play_void_hit_impact()


func _play_water_slash_impact() -> void:
	if not is_inside_tree():
		return

	var original_position = position
	var overlay = Node2D.new()
	overlay.name = "WaterSlashImpact"
	overlay.z_index = 120
	overlay.position = Vector2(4.0, 6.0)
	overlay.scale = Vector2(0.82, 0.82)
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(overlay)

	overlay.add_child(_make_hit_line(
		[Vector2(15.0, 18.0), Vector2(76.0, 57.0)],
		7.0,
		WATER_SLASH_COLOR
	))
	overlay.add_child(_make_hit_line(
		[Vector2(18.0, 18.0), Vector2(74.0, 54.0)],
		2.0,
		WATER_SLASH_HIGHLIGHT_COLOR
	))

	var droplet_specs = [
		[Vector2(21.0, 50.0), Vector2(10.0, 58.0), 2.0],
		[Vector2(34.0, 24.0), Vector2(26.0, 16.0), 1.6],
		[Vector2(62.0, 42.0), Vector2(77.0, 37.0), 1.8],
		[Vector2(69.0, 60.0), Vector2(83.0, 68.0), 1.5]
	]
	for droplet_spec in droplet_specs:
		overlay.add_child(_make_hit_line(
			[droplet_spec[0], droplet_spec[1]],
			float(droplet_spec[2]),
			WATER_DROPLET_COLOR
		))

	var shake_tween = create_tween()
	shake_tween.tween_property(self, "position", original_position + Vector2(-4.0, 1.0), 0.04)
	shake_tween.tween_property(self, "position", original_position + Vector2(3.0, -1.0), 0.05)
	shake_tween.tween_property(self, "position", original_position, 0.06)

	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	effect_tween.tween_property(overlay, "scale", Vector2(1.12, 1.12), 0.28)
	effect_tween.tween_property(overlay, "modulate:a", 1.0, 0.06)
	effect_tween.tween_property(overlay, "modulate:a", 0.0, 0.22).set_delay(0.12)
	await effect_tween.finished

	if is_instance_valid(overlay):
		overlay.queue_free()
	position = original_position


func _play_shadow_slash_impact() -> void:
	if not is_inside_tree():
		return

	var original_position = position
	var overlay = _make_hit_overlay("ShadowSlashImpact", Vector2(2.0, 2.0), Vector2(0.88, 0.88))
	add_child(overlay)
	overlay.add_child(_make_hit_line([Vector2(12.0, 64.0), Vector2(78.0, 17.0)], 9.0, SHADOW_SLASH_COLOR))
	overlay.add_child(_make_hit_line([Vector2(15.0, 61.0), Vector2(76.0, 19.0)], 2.4, SHADOW_SLASH_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(32.0, 69.0), Vector2(47.0, 55.0)], 2.0, SHADOW_SLASH_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(58.0, 24.0), Vector2(75.0, 8.0)], 2.0, SHADOW_SLASH_COLOR))

	_play_position_shake(original_position, Vector2(-5.0, -1.0), Vector2(4.0, 1.0))
	await _fade_and_expand_overlay(overlay, Vector2(1.18, 1.18), 0.28)
	position = original_position


func _play_dark_crown_impact() -> void:
	if not is_inside_tree():
		return

	var original_position = position
	var overlay = _make_hit_overlay("DarkCrownImpact", Vector2(4.0, 0.0), Vector2(0.78, 0.78))
	add_child(overlay)
	overlay.add_child(_make_circle_line(Vector2(46.0, 42.0), 30.0, 28, 4.5, DARK_CROWN_COLOR))
	overlay.add_child(_make_circle_line(Vector2(46.0, 42.0), 19.0, 22, 2.0, DARK_CROWN_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(26.0, 24.0), Vector2(34.0, 8.0), Vector2(43.0, 24.0)], 3.0, DARK_CROWN_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(43.0, 22.0), Vector2(48.0, 3.0), Vector2(55.0, 22.0)], 3.0, DARK_CROWN_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(55.0, 24.0), Vector2(64.0, 8.0), Vector2(70.0, 24.0)], 3.0, DARK_CROWN_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(19.0, 43.0), Vector2(74.0, 43.0)], 2.0, DARK_CROWN_COLOR))

	_play_position_shake(original_position, Vector2(0.0, -4.0), Vector2(0.0, 3.0))
	await _fade_and_expand_overlay(overlay, Vector2(1.24, 1.24), 0.34)
	position = original_position


func _play_void_hit_impact() -> void:
	if not is_inside_tree():
		return

	var original_position = position
	var overlay = _make_hit_overlay("VoidHitImpact", Vector2(-8.0, -4.0), Vector2.ONE)
	add_child(overlay)

	var flash = ColorRect.new()
	flash.position = Vector2(0.0, 0.0)
	flash.size = Vector2(98.0, 92.0)
	flash.color = VOID_FLASH_COLOR
	overlay.add_child(flash)
	overlay.add_child(_make_hit_line([Vector2(52.0, 6.0), Vector2(45.0, 27.0), Vector2(56.0, 45.0), Vector2(47.0, 78.0)], 4.0, VOID_RIFT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(38.0, 20.0), Vector2(47.0, 30.0)], 2.0, DARK_CROWN_HIGHLIGHT_COLOR))
	overlay.add_child(_make_hit_line([Vector2(59.0, 50.0), Vector2(73.0, 62.0)], 2.0, DARK_CROWN_HIGHLIGHT_COLOR))

	_play_position_shake(original_position, Vector2(-3.0, 3.0), Vector2(4.0, -3.0))
	await _fade_and_expand_overlay(overlay, Vector2(1.08, 1.08), 0.3)
	position = original_position


func _make_hit_overlay(overlay_name: String, overlay_position: Vector2, overlay_scale: Vector2) -> Node2D:
	var overlay = Node2D.new()
	overlay.name = overlay_name
	overlay.z_index = 120
	overlay.position = overlay_position
	overlay.scale = overlay_scale
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return overlay


func _play_position_shake(original_position: Vector2, first_offset: Vector2, second_offset: Vector2) -> void:
	var shake_tween = create_tween()
	shake_tween.tween_property(self, "position", original_position + first_offset, 0.04)
	shake_tween.tween_property(self, "position", original_position + second_offset, 0.05)
	shake_tween.tween_property(self, "position", original_position, 0.06)


func _fade_and_expand_overlay(overlay: Node2D, target_scale: Vector2, duration: float) -> void:
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	effect_tween.tween_property(overlay, "scale", target_scale, duration)
	effect_tween.tween_property(overlay, "modulate:a", 1.0, 0.06)
	effect_tween.tween_property(overlay, "modulate:a", 0.0, max(duration - 0.08, 0.1)).set_delay(0.12)
	await effect_tween.finished

	if is_instance_valid(overlay):
		overlay.queue_free()


func _make_hit_line(points: Array, width: float, color: Color) -> Line2D:
	var line = Line2D.new()
	line.points = PackedVector2Array(points)
	line.width = width
	line.default_color = color
	return line


func _make_circle_line(center: Vector2, radius: float, segments: int, width: float, color: Color) -> Line2D:
	var points: Array = []
	var safe_segments = max(segments, 8)
	for point_index in range(safe_segments + 1):
		var angle = TAU * float(point_index) / float(safe_segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return _make_hit_line(points, width, color)


func _make_hero_attack_sprite_frames(action_type: String = "attack") -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(HERO_ATTACK_ANIMATION)
	frames.set_animation_loop(HERO_ATTACK_ANIMATION, false)
	frames.set_animation_speed(HERO_ATTACK_ANIMATION, 14.0)
	if action_type == "attack":
		_add_sprite_sheet_frames(frames, HERO_ATTACK_ANIMATION, HERO_ATTACK_1_TEXTURE, HERO_FRAME_SIZE, HERO_ATTACK_1_FRAME_COUNT, HERO_ATTACK_OFFSET)
		_add_sprite_sheet_frames(frames, HERO_ATTACK_ANIMATION, HERO_ATTACK_2_TEXTURE, HERO_FRAME_SIZE, HERO_ATTACK_2_FRAME_COUNT, HERO_ATTACK_OFFSET)
		_add_sprite_sheet_frames(frames, HERO_ATTACK_ANIMATION, HERO_ATTACK_3_TEXTURE, HERO_FRAME_SIZE, HERO_ATTACK_3_FRAME_COUNT, HERO_ATTACK_OFFSET)
	else:
		_add_sprite_sheet_frames(frames, HERO_ATTACK_ANIMATION, HERO_ATTACK_3_TEXTURE, HERO_FRAME_SIZE, HERO_ATTACK_3_FRAME_COUNT, HERO_ATTACK_OFFSET)
		_add_sprite_sheet_frames(frames, HERO_ATTACK_ANIMATION, HERO_SWORD_ATTACK_TEXTURE, HERO_FRAME_SIZE, HERO_SWORD_ATTACK_FRAME_COUNT, HERO_SWORD_ATTACK_OFFSET)
	return frames


func _add_sprite_sheet_frames(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_size: Vector2, frame_count: int, start_offset: Vector2 = Vector2.ZERO) -> void:
	for frame_index in range(frame_count):
		frames.add_frame(
			animation_name,
			_make_atlas_texture(texture, Rect2(start_offset.x + frame_size.x * frame_index, start_offset.y, frame_size.x, frame_size.y))
		)


func _make_role_strip_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ROLE_IDLE_ANIMATION)
	frames.set_animation_loop(ROLE_IDLE_ANIMATION, true)
	frames.set_animation_speed(ROLE_IDLE_ANIMATION, 8.5)

	if texture == null:
		return frames

	var frame_size = int(texture.get_height())
	if frame_size <= 0:
		frame_size = 128
	var frame_count = max(int(floor(float(texture.get_width()) / float(frame_size))), 1)
	for frame_index in range(frame_count):
		frames.add_frame(
			ROLE_IDLE_ANIMATION,
			_make_atlas_texture(texture, Rect2(frame_size * frame_index, 0, frame_size, frame_size))
		)
	return frames


func _play_hero_idle() -> void:
	animated_sprite.sprite_frames = _make_sprite_frames(
		HERO_TEXTURE,
		HERO_FRAME_SIZE,
		HERO_IDLE_FRAME_COUNT,
		HERO_IDLE_ANIMATION,
		12.0,
		true,
		HERO_IDLE_OFFSET
	)
	animated_sprite.animation = HERO_IDLE_ANIMATION
	animated_sprite.play(HERO_IDLE_ANIMATION)


func _play_dark_queen_idle() -> void:
	animated_sprite.sprite_frames = _make_sprite_frames(
		DARK_QUEEN_TEXTURE,
		DARK_QUEEN_FRAME_SIZE,
		DARK_QUEEN_FRAME_COUNT,
		DARK_QUEEN_ANIMATION,
		7.0,
		true
	)
	animated_sprite.animation = DARK_QUEEN_ANIMATION
	animated_sprite.play(DARK_QUEEN_ANIMATION)


func _play_esbirro_idle() -> void:
	animated_sprite.sprite_frames = _make_sprite_frames(
		ESBIRRO_TEXTURE,
		ESBIRRO_FRAME_SIZE,
		ESBIRRO_FRAME_COUNT,
		ESBIRRO_ANIMATION,
		7.0,
		true
	)
	animated_sprite.animation = ESBIRRO_ANIMATION
	animated_sprite.play(ESBIRRO_ANIMATION)


func _make_atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = region
	return atlas_texture


func _make_sprite_frames(texture: Texture2D, frame_size: Vector2, frame_count: int, animation_name: StringName, speed: float, loop: bool = true, start_offset: Vector2 = Vector2.ZERO) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)
	for frame_index in range(frame_count):
		frames.add_frame(
			animation_name,
			_make_atlas_texture(texture, Rect2(start_offset.x + frame_size.x * frame_index, start_offset.y, frame_size.x, frame_size.y))
		)
	return frames


func _get_hp_bar_color(hp_ratio: float) -> Color:
	if hp_ratio <= 0.2:
		return HP_COLOR_LOW
	if hp_ratio <= 0.5:
		return HP_COLOR_MID
	return HP_COLOR_HIGH


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not editor_preview_enabled:
		return
	if not is_inside_tree() or not _has_required_nodes():
		return

	apply_actor_data({
		"side": editor_preview_side,
		"battle_slot_index": 0,
		"battle_stage_position": Vector2.ZERO,
		"name": editor_preview_name,
		"role": editor_preview_role,
		"level": editor_preview_level,
		"current_hp": 320 if editor_preview_side == "enemy" else 145,
		"max_hp": 320 if editor_preview_side == "enemy" else 170,
		"current_mana": 160 if editor_preview_side == "enemy" else 18,
		"max_mana": 160 if editor_preview_side == "enemy" else 35,
		"state": "normal",
		"defending": false,
		"is_current_turn": false
	})
