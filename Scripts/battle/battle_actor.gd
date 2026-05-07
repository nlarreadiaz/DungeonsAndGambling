@tool
extends Control

const HERO_TEXTURE: Texture2D = preload("res://assets/NightBorne.png")
const MAGE_TEXTURE: Texture2D = preload("res://assets/npcs/Peasants_3/Idle.png")
const SUPPORT_TEXTURE: Texture2D = preload("res://assets/npcs/Peasants_4/Idle.png")
const DARK_QUEEN_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/1/Idle.png")
const DARK_QUEEN_ATTACK_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/1/Attack_1.png")

const HERO_FRAME = Rect2(0, 0, 80, 80)
const HERO_FRAME_SIZE = Vector2(80, 80)
const HERO_IDLE_FRAME_COUNT = 9
const HERO_ATTACK_FRAME_COUNT = 12
const HERO_IDLE_OFFSET = Vector2(0, 0)
const HERO_ATTACK_OFFSET = Vector2(0, 160)
const HERO_IDLE_ANIMATION = &"idle"
const HERO_ATTACK_ANIMATION = &"attack"
const NPC_FRAME = Rect2(0, 0, 128, 128)
const DARK_QUEEN_FRAME = Rect2(0, 0, 128, 128)
const DARK_QUEEN_FRAME_SIZE = Vector2(128, 128)
const DARK_QUEEN_FRAME_COUNT = 7
const DARK_QUEEN_ATTACK_FRAME_COUNT = 6
const DARK_QUEEN_ANIMATION = &"idle"
const DARK_QUEEN_ATTACK_ANIMATION = &"attack"
const HP_BAR_WIDTH = 42.0
const HP_BAR_HEIGHT = 2.0
const HP_COLOR_HIGH = Color(0.34509805, 0.8627451, 0.3137255, 1.0)
const HP_COLOR_MID = Color(0.972549, 0.7921569, 0.19607843, 1.0)
const HP_COLOR_LOW = Color(0.92156863, 0.27450982, 0.23921569, 1.0)

var _is_ariadna = false
var _is_dark_queen = false

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
@onready var status_panel: PanelContainer = $StatusPanel
@onready var name_label: Label = $StatusPanel/MarginContainer/Layout/NameLabel
@onready var role_label: Label = $StatusPanel/MarginContainer/Layout/RoleLabel
@onready var hp_bar_bg: ColorRect = $StatusPanel/MarginContainer/Layout/HpBarBg
@onready var hp_bar_fill: ColorRect = $StatusPanel/MarginContainer/Layout/HpBarBg/HpBarFill
@onready var hp_label: Label = $StatusPanel/MarginContainer/Layout/StatsRow/HpLabel
@onready var mp_label: Label = $StatusPanel/MarginContainer/Layout/StatsRow/MpLabel
@onready var state_label: Label = $StatusPanel/MarginContainer/Layout/StateLabel


func _ready() -> void:
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
	return sprite_rect != null and animated_sprite != null and shadow_rect != null and turn_marker != null and status_panel != null and name_label != null and role_label != null and hp_bar_bg != null and hp_bar_fill != null and hp_label != null and mp_label != null and state_label != null


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
	_is_ariadna = false
	_is_dark_queen = false
	animated_sprite.visible = false
	animated_sprite.stop()
	sprite_rect.texture = _make_atlas_texture(HERO_TEXTURE, HERO_FRAME)
	sprite_rect.visible = true
	sprite_rect.flip_h = false
	sprite_rect.position = Vector2(2, 8)
	sprite_rect.size = Vector2(76, 76)
	shadow_rect.position = Vector2(9, 66)
	shadow_rect.size = Vector2(66, 6)

	if side == "enemy":
		_is_dark_queen = true
		sprite_rect.visible = false
		animated_sprite.visible = true
		animated_sprite.position = Vector2(12, 0)
		animated_sprite.scale = Vector2(0.6875, 0.6875)
		_play_dark_queen_idle()
		shadow_rect.position = Vector2(23, 75)
		shadow_rect.size = Vector2(72, 7)
		status_panel.position = Vector2(-48, 60)
		status_panel.size = Vector2(84, 38)
		turn_marker.position = Vector2(-62, 67)
		return

	if actor_name.contains("ariadna"):
		_is_ariadna = true
		sprite_rect.visible = false
		animated_sprite.visible = true
		animated_sprite.position = Vector2(2, 8)
		animated_sprite.scale = Vector2(0.95, 0.95)
		_play_hero_idle()
	elif actor_name.contains("selene") or role_name.contains("mago"):
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

	if actor_name.contains("ariadna"):
		status_panel.position.x = status_panel.position.x + 10.0
		status_panel.size.x = 96.0
		turn_marker.position.x = turn_marker.position.x + 10.0


func _apply_status(actor_data: Dictionary) -> void:
	var actor_name = str(actor_data.get("name", "Combatiente"))
	var current_hp = int(actor_data.get("current_hp", 0))
	var max_hp = max(int(actor_data.get("max_hp", 1)), 1)
	var current_mp = int(actor_data.get("current_mana", 0))
	var max_mp = max(int(actor_data.get("max_mana", 0)), 0)
	var hp_ratio = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)

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


func _apply_turn_state(actor_data: Dictionary) -> void:
	var is_defeated = int(actor_data.get("current_hp", 0)) <= 0
	var is_current_turn = bool(actor_data.get("is_current_turn", false))
	turn_marker.visible = is_current_turn and not is_defeated
	modulate = Color(1, 1, 1, 1)

	if is_defeated:
		modulate = Color(0.48, 0.48, 0.48, 0.82)
	elif is_current_turn:
		modulate = Color(1.0, 0.98, 0.78, 1.0)


func play_action_animation(action_type: String = "attack") -> void:
	if not animated_sprite.visible:
		return
	if action_type == "defend" or action_type == "flee":
		return

	if _is_ariadna:
		if action_type != "attack" and action_type != "skill":
			return
		animated_sprite.sprite_frames = _make_sprite_frames(
			HERO_TEXTURE,
			HERO_FRAME_SIZE,
			HERO_ATTACK_FRAME_COUNT,
			HERO_ATTACK_ANIMATION,
			12.0,
			false,
			HERO_ATTACK_OFFSET
		)
		animated_sprite.animation = HERO_ATTACK_ANIMATION
		animated_sprite.play(HERO_ATTACK_ANIMATION)
		await animated_sprite.animation_finished
		_play_hero_idle()
		return

	if not _is_dark_queen:
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
