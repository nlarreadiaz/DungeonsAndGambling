extends AnimatedSprite2D

@export var default_animation: StringName = &"walk"
@export var wander_radius = 28.0
@export var walk_speed = 18.0
@export var min_wait_time = 0.5
@export var max_wait_time = 1.4
@export var dialogue_icon_path: NodePath = NodePath("DialogueIcon")
@export var dialogue_panel_path: NodePath = NodePath("DialogueMessage")
@export var dialogue_label_path: NodePath = NodePath("DialogueMessage/Message")
@export var dialogue_area_path: NodePath = NodePath("DialogueArea")

var _home_position = Vector2.ZERO
var _target_position = Vector2.ZERO
var _wait_time_left = 0.0
var _rng = RandomNumberGenerator.new()
var _dialogue_icon: CanvasItem = null
var _dialogue_panel: CanvasItem = null
var _dialogue_label: Label = null
var _dialogue_area: Area2D = null
var _has_dialogue = false


func _ready() -> void:
	_rng.randomize()
	_home_position = position
	_target_position = position
	_wait_time_left = _get_random_wait_time()

	if sprite_frames != null:
		if sprite_frames.has_animation(default_animation):
			play(default_animation)
		else:
			var animation_names = sprite_frames.get_animation_names()
			if not animation_names.is_empty():
				play(animation_names[0])

	_setup_dialogue_prompt()


func _process(delta: float) -> void:
	if _wait_time_left > 0.0:
		_wait_time_left -= delta
		return

	if position.distance_to(_target_position) <= 1.0:
		_target_position = _get_random_target_position()
		_wait_time_left = _get_random_wait_time()
		return

	var previous_position = position
	position = position.move_toward(_target_position, walk_speed * delta)
	flip_h = position.x < previous_position.x


func _get_random_target_position() -> Vector2:
	var angle = _rng.randf_range(0.0, TAU)
	var distance = _rng.randf_range(6.0, wander_radius)
	return _home_position + Vector2(cos(angle), sin(angle)) * distance


func _get_random_wait_time() -> float:
	return _rng.randf_range(min_wait_time, max_wait_time)


func _setup_dialogue_prompt() -> void:
	_dialogue_icon = get_node_or_null(dialogue_icon_path) as CanvasItem
	_dialogue_panel = get_node_or_null(dialogue_panel_path) as CanvasItem
	_dialogue_label = get_node_or_null(dialogue_label_path) as Label
	_dialogue_area = get_node_or_null(dialogue_area_path) as Area2D

	var has_message = _dialogue_label != null and not _dialogue_label.text.strip_edges().is_empty()
	_has_dialogue = _dialogue_icon != null and _dialogue_panel != null and _dialogue_area != null and has_message

	if _dialogue_icon != null:
		_dialogue_icon.visible = _has_dialogue

	if _dialogue_panel != null:
		_dialogue_panel.visible = false

	if _dialogue_area == null:
		return

	_dialogue_area.monitoring = _has_dialogue
	_dialogue_area.monitorable = false

	if _has_dialogue and not _dialogue_area.body_entered.is_connected(_on_dialogue_area_body_entered):
		_dialogue_area.body_entered.connect(_on_dialogue_area_body_entered)

	if _has_dialogue and not _dialogue_area.body_exited.is_connected(_on_dialogue_area_body_exited):
		_dialogue_area.body_exited.connect(_on_dialogue_area_body_exited)


func _on_dialogue_area_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	_set_dialogue_visible(true)


func _on_dialogue_area_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	_set_dialogue_visible(false)


func _is_player_body(body: Node2D) -> bool:
	return body != null and body.name == "player"


func _set_dialogue_visible(is_visible: bool) -> void:
	if not _has_dialogue:
		return

	if _dialogue_panel != null:
		_dialogue_panel.visible = is_visible

	if _dialogue_icon != null:
		_dialogue_icon.visible = not is_visible
