extends CharacterBody2D

@export var SPEED: float = 150.0
@export var RUN_SPEED: float = 240.0
@export var JUMP_FORCE: float = 400.0
@export var FAKE_GRAVITY: float = 1500.0

const INVENTORY_UI_SCENE: PackedScene = preload("res://Scenes/ui/inventory_ui.tscn")
const INVENTORY_TOGGLE_ACTION = "inventory_toggle"
const INVENTORY_SLOT_COUNT = 34

const ANIM_IDLE = "idle"
const ANIM_RUN = "run"
const ANIM_ATTACK = "golpe"
const ANIM_HURT = "da\u00f1o"
const ANIM_DEATH = "muerte"
const WALK_ANIMATION_SPEED = 0.82
const RUN_ANIMATION_SPEED = 1.2

var z_height = 0.0
var z_velocity = 0.0
var is_jumping = false
var is_attacking = false
var is_dead = false
var is_hurt = false
var is_running = false
var spawn_position = Vector2.ZERO

var inventory_data: InventoryData = null
var inventory_ui: InventoryUI = null

@onready var anim: AnimatedSprite2D = $animaciones


func _ready() -> void:
	is_attacking = false
	is_hurt = false
	spawn_position = global_position
	anim.speed_scale = 1.0
	anim.play(ANIM_IDLE)

	if anim.sprite_frames:
		anim.sprite_frames.set_animation_loop(ANIM_ATTACK, false)
		anim.sprite_frames.set_animation_loop(ANIM_HURT, false)
		anim.sprite_frames.set_animation_loop(ANIM_DEATH, false)

	_initialize_inventory()


func _input(event: InputEvent) -> void:
	if is_dead:
		return

	if not _is_inventory_toggle_event(event):
		return

	get_viewport().set_input_as_handled()
	_toggle_inventory()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	handle_movement(delta)
	handle_jump(delta)
	handle_attack()
	update_animations()


func handle_movement(_delta: float) -> void:
	if is_attacking or is_hurt or is_inventory_open():
		is_running = false
		velocity = Vector2.ZERO
		return

	var direction = _get_movement_direction()
	if direction:
		is_running = _is_run_pressed()
		var current_speed = RUN_SPEED if is_running else SPEED
		velocity = direction * current_speed
		if direction.x != 0:
			anim.flip_h = direction.x < 0
	else:
		is_running = false
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()


func _get_movement_direction() -> Vector2:
	var arrow_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd_direction = Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)

	return (arrow_direction + wasd_direction).limit_length(1.0)


func handle_jump(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") and not is_jumping and not is_attacking and not is_inventory_open():
		z_velocity = JUMP_FORCE
		is_jumping = true

	if is_jumping:
		z_height += z_velocity * delta
		z_velocity -= FAKE_GRAVITY * delta

		if z_height <= 0.0:
			z_height = 0.0
			is_jumping = false

	anim.position.y = -z_height


func handle_attack() -> void:
	if Input.is_action_just_pressed("click_izquierdo") and not is_attacking and not is_jumping and not is_hurt and not is_inventory_open():
		is_attacking = true
		anim.speed_scale = 1.0
		anim.play(ANIM_ATTACK)

		await anim.animation_finished
		is_attacking = false


func update_animations() -> void:
	if is_dead or is_attacking or is_hurt:
		return

	if velocity != Vector2.ZERO:
		anim.speed_scale = RUN_ANIMATION_SPEED if is_running else WALK_ANIMATION_SPEED
		anim.play(ANIM_RUN)
	else:
		anim.speed_scale = 1.0
		anim.play(ANIM_IDLE)


func recibir_daño() -> void:
	if is_dead or is_hurt:
		return

	is_hurt = true
	is_attacking = false
	anim.speed_scale = 1.0
	anim.play(ANIM_HURT)

	await anim.animation_finished
	is_hurt = false


func morir() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_hurt = false
	is_running = false
	is_jumping = false
	z_height = 0.0
	z_velocity = 0.0
	velocity = Vector2.ZERO
	close_inventory()
	anim.position.y = 0.0
	anim.speed_scale = 1.0
	anim.play(ANIM_DEATH)

	await anim.animation_finished
	_respawn()


func pickup_item(item_data: ItemData, amount: int = 1) -> int:
	if inventory_data == null:
		return amount
	return inventory_data.add_item(item_data, amount)


func is_inventory_open() -> bool:
	return inventory_ui != null and inventory_ui.is_inventory_open()


func close_inventory() -> void:
	if inventory_ui == null:
		return
	inventory_ui.set_inventory_visible(false)


func _initialize_inventory() -> void:
	inventory_data = InventoryData.new(INVENTORY_SLOT_COUNT)
	inventory_ui = INVENTORY_UI_SCENE.instantiate() as InventoryUI
	if inventory_ui == null:
		push_warning("No se pudo crear la UI de inventario.")
		return

	add_child(inventory_ui)
	inventory_ui.bind_inventory(inventory_data)


func _toggle_inventory() -> void:
	if inventory_ui == null:
		return
	inventory_ui.toggle_inventory()


func _is_inventory_toggle_event(event: InputEvent) -> bool:
	if event.is_action_pressed(INVENTORY_TOGGLE_ACTION):
		return true

	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_I or key_event.physical_keycode == KEY_I
		)

	return false


func _is_run_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)


func set_spawn_position(new_spawn_position: Vector2) -> void:
	spawn_position = new_spawn_position


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	z_height = 0.0
	z_velocity = 0.0
	is_jumping = false
	is_attacking = false
	is_hurt = false
	is_dead = false
	is_running = false
	anim.position.y = 0.0
	anim.speed_scale = 1.0
	anim.play(ANIM_IDLE)
