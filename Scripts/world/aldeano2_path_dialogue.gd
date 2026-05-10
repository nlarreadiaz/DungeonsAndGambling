extends CharacterBody2D

const INTERACT_ACTION = "interact"

@export var path_follow_path: NodePath = NodePath("Path2D/PathFollow2D")
@export var sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var interaction_area_path: NodePath = NodePath("DialogueArea")
@export var dialogue_layer_path: NodePath = NodePath("DialogueLayer")
@export var walk_animation: StringName = &"walk"
@export var idle_animation: StringName = &"idle"
@export var path_speed := 34.0
@export var walk_seconds := 4.0
@export var idle_seconds := 5.0
@export var interaction_radius := 58.0

var _path_follow: PathFollow2D = null
var _sprite: AnimatedSprite2D = null
var _collision_shape: CollisionShape2D = null
var _interaction_area: Area2D = null
var _dialogue_layer: CanvasLayer = null
var _player_near = false
var _dialogue_open = false
var _is_walking = true
var _state_time_left = 0.0
var _base_sprite_offset = Vector2.ZERO
var _base_collision_offset = Vector2.ZERO


func _ready() -> void:
	_path_follow = get_node_or_null(path_follow_path) as PathFollow2D
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape2D
	if _path_follow == null:
		_path_follow = find_child("PathFollow2D", true, false) as PathFollow2D
	if _sprite == null:
		_sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if _collision_shape == null:
		_collision_shape = find_child("CollisionShape2D", true, false) as CollisionShape2D

	if _sprite == null:
		push_warning("aldeano2 necesita AnimatedSprite2D para caminar.")
		set_process(false)
		return

	_base_sprite_offset = _sprite.position
	if _collision_shape != null:
		_base_collision_offset = _collision_shape.position

	if _path_follow == null:
		_play_animation(idle_animation)
		_setup_interaction_area()
		_setup_dialogue_ui()
		set_process(false)
		return

	_path_follow.rotates = false
	_state_time_left = walk_seconds
	_play_animation(walk_animation)
	_apply_path_position()
	_setup_interaction_area()
	_setup_dialogue_ui()


func _process(delta: float) -> void:
	if _dialogue_open:
		_play_animation(idle_animation)
		return

	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_is_walking = not _is_walking
		_state_time_left = walk_seconds if _is_walking else idle_seconds
		_play_animation(walk_animation if _is_walking else idle_animation)

	if not _is_walking:
		return

	var previous_position = _path_follow.global_position
	_path_follow.progress += path_speed * delta
	_apply_path_position()
	var moved_x = _path_follow.global_position.x - previous_position.x
	if absf(moved_x) > 0.05:
		_sprite.flip_h = moved_x < 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or not _is_interact_event(event):
		return

	get_viewport().set_input_as_handled()
	if _dialogue_open:
		_close_dialogue()
	else:
		_open_dialogue()


func _apply_path_position() -> void:
	var local_position = _path_follow.position
	_sprite.position = local_position + _base_sprite_offset
	if _collision_shape != null:
		_collision_shape.position = local_position + _base_collision_offset
	if _interaction_area != null:
		_interaction_area.position = local_position


func _setup_interaction_area() -> void:
	_interaction_area = get_node_or_null(interaction_area_path) as Area2D
	if _interaction_area == null:
		push_warning("aldeano2 necesita un Area2D DialogueArea para hablar con el jugador.")
		return

	_interaction_area.collision_layer = 0
	_interaction_area.monitorable = false
	_interaction_area.monitoring = true

	var area_shape = _interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if area_shape != null and area_shape.shape is CircleShape2D:
		var circle_shape := area_shape.shape as CircleShape2D
		circle_shape.radius = interaction_radius

	if not _interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		_interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	if not _interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		_interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func _setup_dialogue_ui() -> void:
	_dialogue_layer = get_node_or_null(dialogue_layer_path) as CanvasLayer
	if _dialogue_layer == null:
		push_warning("aldeano2 necesita un DialogueLayer configurado en la escena.")
		return

	_dialogue_layer.visible = false


func _open_dialogue() -> void:
	if _dialogue_layer == null:
		return

	_dialogue_open = true
	_state_time_left = idle_seconds
	_play_animation(idle_animation)
	_dialogue_layer.visible = true


func _close_dialogue() -> void:
	_dialogue_open = false
	if _dialogue_layer != null:
		_dialogue_layer.visible = false
	_play_animation(walk_animation if _is_walking else idle_animation)


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player_near = true


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_player_near = false
		_close_dialogue()


func _play_animation(animation_name: StringName) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(animation_name):
		return
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.play(animation_name)


func _is_player_body(body: Node2D) -> bool:
	return body != null and body.name == "player"


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
