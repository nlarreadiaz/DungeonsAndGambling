extends Control

const HERO_TEXTURE: Texture2D = preload("res://assets/NightBorne.png")
const MAGE_TEXTURE: Texture2D = preload("res://assets/npcs/Peasants_3/Idle.png")
const SUPPORT_TEXTURE: Texture2D = preload("res://assets/npcs/Peasants_4/Idle.png")
const DARK_QUEEN_TEXTURE: Texture2D = preload("res://assets/Boss-DarkQueen/1/Idle.png")

const HERO_FRAME = Rect2(0, 0, 80, 80)
const NPC_FRAME = Rect2(0, 0, 128, 128)
const DARK_QUEEN_FRAME = Rect2(0, 0, 128, 128)
const HP_BAR_WIDTH = 42.0
const HP_BAR_HEIGHT = 2.0
const HP_COLOR_HIGH = Color(0.34509805, 0.8627451, 0.3137255, 1.0)
const HP_COLOR_MID = Color(0.972549, 0.7921569, 0.19607843, 1.0)
const HP_COLOR_LOW = Color(0.92156863, 0.27450982, 0.23921569, 1.0)

@onready var sprite_rect: TextureRect = $Sprite
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


func apply_actor_data(actor_data: Dictionary) -> void:
	if not _has_required_nodes():
		push_warning("BattleActor no encontro todos los nodos visuales esperados.")
		return

	var side = str(actor_data.get("side", "party"))
	var slot_index = int(actor_data.get("battle_slot_index", 0))
	_apply_stage_position(side, slot_index)
	_apply_sprite(actor_data, side)
	_apply_status(actor_data)
	_apply_turn_state(actor_data)


func _has_required_nodes() -> bool:
	return sprite_rect != null and shadow_rect != null and turn_marker != null and status_panel != null and name_label != null and role_label != null and hp_bar_bg != null and hp_bar_fill != null and hp_label != null and mp_label != null and state_label != null


func _apply_stage_position(side: String, slot_index: int) -> void:
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
	sprite_rect.texture = _make_atlas_texture(HERO_TEXTURE, HERO_FRAME)
	sprite_rect.flip_h = false
	sprite_rect.position = Vector2(2, 8)
	sprite_rect.size = Vector2(76, 76)
	shadow_rect.position = Vector2(9, 66)
	shadow_rect.size = Vector2(66, 6)

	if side == "enemy":
		sprite_rect.texture = _make_atlas_texture(DARK_QUEEN_TEXTURE, DARK_QUEEN_FRAME)
		sprite_rect.flip_h = false
		sprite_rect.position = Vector2(12, 0)
		sprite_rect.size = Vector2(88, 88)
		shadow_rect.position = Vector2(23, 75)
		shadow_rect.size = Vector2(72, 7)
		status_panel.position = Vector2(-48, 60)
		status_panel.size = Vector2(84, 38)
		turn_marker.position = Vector2(-62, 67)
		return

	if actor_name.contains("selene") or role_name.contains("mago"):
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


func _make_atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = region
	return atlas_texture


func _get_hp_bar_color(hp_ratio: float) -> Color:
	if hp_ratio <= 0.2:
		return HP_COLOR_LOW
	if hp_ratio <= 0.5:
		return HP_COLOR_MID
	return HP_COLOR_HIGH
