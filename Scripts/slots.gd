extends Node2D

signal closed

const SLOT_SHEET: Texture2D = preload("res://assets/slots/slots.png")
const SLOT_MASK_SHEET: Texture2D = preload("res://assets/slots/slotcarcasa.png")
const GEM_TEXTURES: Array[Texture2D] = [
	preload("res://assets/slots/4.png"),
	preload("res://assets/slots/6.png"),
	preload("res://assets/slots/7.png")
]

const FRAME_SIZE := Vector2(128.0, 128.0)
const IDLE_FRAME := 3
const REEL_SCALE := Vector2(0.038, 0.038)
const REEL_BASE_POSITIONS := [
	Vector2(-27.0, -10.0),
	Vector2(-4.0, -10.0),
	Vector2(19.0, -10.0)
]
const SPIN_STEP_SECONDS := 0.05
const SPIN_DURATION_SECONDS := 1.1
const REEL_STOP_DELAY_SECONDS := 0.13
const SAVE_SLOT_ID = 1
const BET_STEP = 10
const MIN_BET = 10
const GEM_PURPLE = 0
const GEM_YELLOW = 1
const GEM_BLUE = 2
const GEM_WEIGHTS := [
	{"gem": GEM_BLUE, "weight": 60},
	{"gem": GEM_PURPLE, "weight": 30},
	{"gem": GEM_YELLOW, "weight": 10}
]
const GEM_NAMES := {
	GEM_BLUE: "azules",
	GEM_PURPLE: "moradas",
	GEM_YELLOW: "amarillas"
}
const PAIR_MULTIPLIERS := {
	GEM_BLUE: 1.5,
	GEM_PURPLE: 2.0,
	GEM_YELLOW: 3.0
}
const TRIPLE_MULTIPLIERS := {
	GEM_BLUE: 5.0,
	GEM_PURPLE: 20.0,
	GEM_YELLOW: 40.0
}

@onready var _slot_machine: AnimatedSprite2D = $SlotMachine
@onready var _slot_mask: Sprite2D = $SlotMachine/SlotMask
@onready var _reel_left: Sprite2D = $SlotMachine/Reels/ReelLeft
@onready var _reel_center: Sprite2D = $SlotMachine/Reels/ReelCenter
@onready var _reel_right: Sprite2D = $SlotMachine/Reels/ReelRight
@onready var _lever_hitbox: Area2D = $SlotMachine/LeverHitbox
@onready var _result_label: Label = $ResultLabel

var _rng := RandomNumberGenerator.new()
var _spinning := false
var _reels: Array[Sprite2D] = []
var _reel_base_positions: Array[Vector2] = []
var _bet := MIN_BET
var _gold := 0
var _gold_label: Label = null
var _bet_label: Label = null
var _spin_button: Button = null


func _ready() -> void:
	_rng.randomize()
	_reels = [_reel_left, _reel_center, _reel_right]
	_setup_machine_frames()
	_setup_slot_mask()
	_setup_reels()
	_setup_betting_ui()
	_refresh_gold()
	if _lever_hitbox != null:
		_lever_hitbox.input_event.connect(_on_lever_input_event)
	_result_label.text = "Elige apuesta"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _setup_machine_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_animation(&"pull")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_loop(&"pull", false)
	frames.set_animation_speed(&"idle", 1.0)
	frames.set_animation_speed(&"pull", 22.0)

	frames.add_frame(&"idle", _make_machine_frame(IDLE_FRAME))
	for frame_index in range(IDLE_FRAME, 9):
		frames.add_frame(&"pull", _make_machine_frame(frame_index))
	for frame_index in range(7, IDLE_FRAME - 1, -1):
		frames.add_frame(&"pull", _make_machine_frame(frame_index))

	_slot_machine.sprite_frames = frames
	_slot_machine.animation = &"idle"
	_slot_machine.frame = 0
	_slot_machine.stop()


func _make_machine_frame(frame_index: int) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = SLOT_SHEET
	atlas_texture.region = Rect2(FRAME_SIZE.x * frame_index, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
	atlas_texture.filter_clip = true
	return atlas_texture


func _setup_slot_mask() -> void:
	if _slot_mask == null:
		return

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = SLOT_MASK_SHEET
	atlas_texture.region = Rect2(0.0, 0.0, FRAME_SIZE.x, FRAME_SIZE.y)
	atlas_texture.filter_clip = true
	_slot_mask.texture = atlas_texture


func _setup_reels() -> void:
	_reel_base_positions.clear()
	for reel_index in range(_reels.size()):
		var reel = _reels[reel_index]
		var base_position = REEL_BASE_POSITIONS[reel_index]
		_reel_base_positions.append(base_position)
		reel.scale = REEL_SCALE
		reel.position = base_position
		_set_reel_gem(reel, _rng.randi_range(0, GEM_TEXTURES.size() - 1))


func _on_lever_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _spinning:
		return

	_try_spin()


func _setup_betting_ui() -> void:
	if _result_label != null:
		_result_label.position = Vector2(137, 176)
		_result_label.size = Vector2(206, 25)

	var root = Control.new()
	root.name = "BettingUI"
	root.position = Vector2.ZERO
	root.size = Vector2(480, 270)
	root.z_index = 100
	add_child(root)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(118, 204)
	panel.size = Vector2(244, 56)
	panel.custom_minimum_size = Vector2(244, 56)
	root.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	margin.add_child(layout)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 8)
	layout.add_child(_gold_label)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	layout.add_child(row)

	var minus_button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(24, 20)
	minus_button.pressed.connect(_decrease_bet)
	row.add_child(minus_button)

	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(72, 20)
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bet_label.add_theme_font_size_override("font_size", 8)
	row.add_child(_bet_label)

	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(24, 20)
	plus_button.pressed.connect(_increase_bet)
	row.add_child(plus_button)

	_spin_button = Button.new()
	_spin_button.text = "Tirar"
	_spin_button.custom_minimum_size = Vector2(58, 20)
	_spin_button.pressed.connect(_try_spin)
	row.add_child(_spin_button)

	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(24, 20)
	close_button.pressed.connect(func(): closed.emit())
	row.add_child(close_button)

	_update_bet_ui()


func _decrease_bet() -> void:
	_bet = max(_bet - BET_STEP, MIN_BET)
	_update_bet_ui()


func _increase_bet() -> void:
	var max_bet = max(_gold, MIN_BET)
	_bet = min(_bet + BET_STEP, max_bet)
	_update_bet_ui()


func _try_spin() -> void:
	if _spinning:
		return
	if _gold < _bet:
		_result_label.text = "No tienes oro suficiente"
		return
	_pull_lever()


func _pull_lever() -> void:
	_spinning = true
	_set_controls_enabled(false)
	_change_gold(-_bet)
	_result_label.text = "Girando..."
	_slot_machine.play(&"pull")
	var final_indices = await _spin_reels()
	_slot_machine.stop()
	_slot_machine.animation = &"idle"
	_slot_machine.frame = 0
	_resolve_spin(final_indices)
	_spinning = false
	_set_controls_enabled(true)


func _spin_reels() -> Array[int]:
	var elapsed := 0.0
	while elapsed < SPIN_DURATION_SECONDS:
		for reel_index in range(_reels.size()):
			var reel = _reels[reel_index]
			var base_position = _reel_base_positions[reel_index]
			_set_reel_gem(reel, _get_weighted_gem_index())
			reel.position.y = base_position.y + sin((elapsed * 28.0) + (reel_index * 1.7)) * 2.0
		await get_tree().create_timer(SPIN_STEP_SECONDS).timeout
		elapsed += SPIN_STEP_SECONDS

	var final_indices: Array[int] = []
	for _index in range(_reels.size()):
		final_indices.append(_get_weighted_gem_index())

	for reel_index in range(_reels.size()):
		await get_tree().create_timer(REEL_STOP_DELAY_SECONDS).timeout
		var reel = _reels[reel_index]
		var base_position = _reel_base_positions[reel_index]
		_set_reel_gem(reel, final_indices[reel_index])
		reel.position = base_position
		await _pop_reel(reel)

	return final_indices


func _pop_reel(reel: Sprite2D) -> void:
	var target_scale = REEL_SCALE
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(reel, "scale", target_scale * 1.12, 0.08)
	tween.tween_property(reel, "scale", target_scale, 0.1)
	await tween.finished


func _set_reel_gem(reel: Sprite2D, gem_index: int) -> void:
	reel.texture = GEM_TEXTURES[gem_index]
	reel.centered = true


func _resolve_spin(final_indices: Array[int]) -> void:
	if final_indices.size() < 3:
		_result_label.text = "Error en tirada"
		return

	var first = final_indices[0]
	var second = final_indices[1]
	var third = final_indices[2]

	var payout = 0
	var matched_gem = -1
	var match_count = 0
	if first == second and second == third:
		matched_gem = first
		match_count = 3
		payout = int(round(float(_bet) * float(TRIPLE_MULTIPLIERS.get(matched_gem, 0.0))))
	elif first == second or first == third:
		matched_gem = first
		match_count = 2
		payout = int(round(float(_bet) * float(PAIR_MULTIPLIERS.get(matched_gem, 0.0))))
	elif second == third:
		matched_gem = second
		match_count = 2
		payout = int(round(float(_bet) * float(PAIR_MULTIPLIERS.get(matched_gem, 0.0))))

	if payout > 0:
		_change_gold(payout)
		_result_label.text = "%d %s: +%d oro" % [match_count, str(GEM_NAMES.get(matched_gem, "gemas")), payout]
	else:
		_result_label.text = "Sin premio: -%d oro" % _bet


func _get_weighted_gem_index() -> int:
	var roll = _rng.randi_range(1, 100)
	var accumulated = 0
	for entry in GEM_WEIGHTS:
		accumulated += int(entry.get("weight", 0))
		if roll <= accumulated:
			return int(entry.get("gem", GEM_BLUE))
	return GEM_BLUE


func _refresh_gold() -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager != null and database_manager.has_method("get_game_state"):
		var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
		if game_state is Dictionary:
			_gold = int(game_state.get("gold", 0))
	_update_bet_ui()


func _change_gold(amount: int) -> void:
	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null:
		_gold = max(_gold + amount, 0)
		_update_bet_ui()
		return
	if database_manager.has_method("add_gold"):
		database_manager.call("add_gold", SAVE_SLOT_ID, amount)
	if database_manager.has_method("commit_manual_save"):
		database_manager.call("commit_manual_save", SAVE_SLOT_ID)
	_refresh_gold()


func _update_bet_ui() -> void:
	if _gold_label != null:
		_gold_label.text = "Oro: %d" % _gold
	if _bet_label != null:
		_bet_label.text = "Apuesta: %d" % _bet


func _set_controls_enabled(enabled: bool) -> void:
	if _spin_button != null:
		_spin_button.disabled = not enabled
