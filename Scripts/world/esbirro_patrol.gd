extends CharacterBody2D

@export var speed := 55.0
@export var walk_animation := &"walk"
@export var idle_animation := &"idle"
@export var walk_time_before_idle := 3.0
@export var idle_time := 2.0
@export var sprite_path := NodePath("AnimatedSprite2D")
@export var path_path := NodePath("Path2D")
@export var path_follow_path := NodePath("Path2D/PathFollow2D")

var _sprite: AnimatedSprite2D = null
var _path_follow: PathFollow2D = null
var _curve: Curve2D = null
var _path_global_transform := Transform2D.IDENTITY
var _root_offset_from_follow := Vector2.ZERO
var _progress := 0.0
var _direction := 1.0
var _walk_elapsed := 0.0
var _idle_remaining := 0.0
var _last_facing_left := true


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	var path = get_node_or_null(path_path) as Path2D
	_path_follow = get_node_or_null(path_follow_path) as PathFollow2D

	if path == null or path.curve == null:
		_play_idle()
		set_process(false)
		return

	_curve = path.curve.duplicate()
	_path_global_transform = path.global_transform
	var path_length = _get_path_length()
	if _path_follow != null:
		_progress = clampf(_path_follow.progress, 0.0, path_length)
		_root_offset_from_follow = global_position - _path_follow.global_position
	else:
		_root_offset_from_follow = global_position - _get_path_global_point(_progress)

	_apply_position_from_path()
	_play_walk()


func _process(delta: float) -> void:
	if _curve == null:
		return

	if _idle_remaining > 0.0:
		_idle_remaining -= delta
		if _idle_remaining <= 0.0:
			_walk_elapsed = 0.0
			_play_walk()
		return

	var previous_position = global_position
	var path_length = _get_path_length()
	if path_length <= 0.0:
		_play_idle()
		return

	_progress += speed * delta * _direction
	if _progress >= path_length:
		_progress = path_length
		_direction = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_direction = 1.0

	_apply_position_from_path()
	var movement = global_position - previous_position
	if absf(movement.x) > 0.01:
		_last_facing_left = movement.x < 0.0
	_apply_facing()

	_walk_elapsed += delta
	if _walk_elapsed >= walk_time_before_idle:
		_idle_remaining = idle_time
		_play_idle()


func _apply_position_from_path() -> void:
	if _curve == null:
		return

	global_position = _get_path_global_point(_progress) + _root_offset_from_follow
	if _path_follow != null:
		_path_follow.progress = _progress


func _play_walk() -> void:
	if _sprite == null:
		return

	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(walk_animation):
		_sprite.animation = walk_animation
	_sprite.play()
	_apply_facing()


func _play_idle() -> void:
	if _sprite == null:
		return

	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(idle_animation):
		_sprite.animation = idle_animation
	_sprite.play()
	_apply_facing()


func _apply_facing() -> void:
	if _sprite != null:
		_sprite.flip_h = _last_facing_left


func _get_path_length() -> float:
	if _curve == null:
		return 0.0
	return max(_curve.get_baked_length(), 0.0)


func _get_path_global_point(progress: float) -> Vector2:
	if _curve == null:
		return global_position
	return _path_global_transform * _curve.sample_baked(progress, true)
