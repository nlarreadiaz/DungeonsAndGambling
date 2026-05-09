extends Node2D

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


func _ready() -> void:
	_rng.randomize()
	_reels = [_reel_left, _reel_center, _reel_right]
	_setup_machine_frames()
	_setup_slot_mask()
	_setup_reels()
	if _lever_hitbox != null:
		_lever_hitbox.input_event.connect(_on_lever_input_event)
	_result_label.text = "Tira de la palanca"


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

	_pull_lever()


func _pull_lever() -> void:
	_spinning = true
	_result_label.text = "Girando..."
	_slot_machine.play(&"pull")
	await _spin_reels()
	_slot_machine.stop()
	_slot_machine.animation = &"idle"
	_slot_machine.frame = 0
	_spinning = false


func _spin_reels() -> void:
	var elapsed := 0.0
	while elapsed < SPIN_DURATION_SECONDS:
		for reel_index in range(_reels.size()):
			var reel = _reels[reel_index]
			var base_position = _reel_base_positions[reel_index]
			_set_reel_gem(reel, _rng.randi_range(0, GEM_TEXTURES.size() - 1))
			reel.position.y = base_position.y + sin((elapsed * 28.0) + (reel_index * 1.7)) * 2.0
		await get_tree().create_timer(SPIN_STEP_SECONDS).timeout
		elapsed += SPIN_STEP_SECONDS

	var final_indices: Array[int] = []
	for _index in range(_reels.size()):
		final_indices.append(_rng.randi_range(0, GEM_TEXTURES.size() - 1))

	for reel_index in range(_reels.size()):
		await get_tree().create_timer(REEL_STOP_DELAY_SECONDS).timeout
		var reel = _reels[reel_index]
		var base_position = _reel_base_positions[reel_index]
		_set_reel_gem(reel, final_indices[reel_index])
		reel.position = base_position
		await _pop_reel(reel)

	_show_spin_result(final_indices)


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


func _show_spin_result(final_indices: Array[int]) -> void:
	if final_indices.size() < 3:
		_result_label.text = "Error en tirada"
		return

	var first = final_indices[0]
	var second = final_indices[1]
	var third = final_indices[2]

	if first == second and second == third:
		_result_label.text = "JACKPOT! 3 gemas iguales"
	elif first == second or second == third or first == third:
		_result_label.text = "Premio menor: pareja de gemas"
	else:
		_result_label.text = "Sin premio, prueba otra vez"
