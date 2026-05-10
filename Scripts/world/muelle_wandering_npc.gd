extends CharacterBody2D

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var idle_timer: Timer = get_node_or_null("Timer") as Timer
@onready var wander_area: Area2D = get_node_or_null("WanderArea") as Area2D
@onready var wander_shape_node: CollisionShape2D = get_node_or_null("WanderArea/CollisionShape2D") as CollisionShape2D

@export var speed = 24.0
@export var idle_min_seconds = 1.0
@export var idle_max_seconds = 2.6
@export var reach_distance = 4.0
@export var min_target_distance = 18.0
@export var fallback_wander_radius = 70.0
@export var stuck_seconds = 0.5
@export var animation_fps = 6.0
@export var first_frame = 0
@export var frame_count = 0
@export var flip_when_moving_left = true

var target_position = Vector2.ZERO
var is_moving = false
var spawn_position = Vector2.ZERO
var wander_global_xform = Transform2D.IDENTITY
var wander_shape: Shape2D = null
var stuck_time = 0.0
var animation_time = 0.0


func _ready() -> void:
	if sprite == null or idle_timer == null:
		push_error("MuelleWanderingNpc: faltan nodos requeridos (Sprite2D o Timer).")
		set_physics_process(false)
		return

	if wander_area == null:
		wander_area = find_child("WanderArea", true, false) as Area2D
	if wander_shape_node == null and wander_area != null:
		wander_shape_node = wander_area.find_child("CollisionShape2D", true, false) as CollisionShape2D

	if wander_area == null or wander_shape_node == null or wander_shape_node.shape == null:
		push_warning("MuelleWanderingNpc: falta WanderArea/CollisionShape2D con Shape. Se usara fallback_wander_radius.")
	else:
		wander_global_xform = wander_shape_node.global_transform
		wander_shape = wander_shape_node.shape

	if not idle_timer.timeout.is_connected(_on_timer_timeout):
		idle_timer.timeout.connect(_on_timer_timeout)

	spawn_position = global_position
	target_position = global_position
	entrar_idle()


func _physics_process(delta: float) -> void:
	_update_animation(delta)

	if wander_shape != null and not _is_inside_wander_area(global_position):
		target_position = _closest_point_inside_wander_area(global_position)
		is_moving = true

	if not is_moving:
		velocity = Vector2.ZERO
		return

	var to_target = target_position - global_position
	if to_target.length() <= reach_distance:
		entrar_idle()
		return

	var before_move = global_position
	velocity = to_target.normalized() * speed
	move_and_slide()

	var moved = global_position - before_move
	if flip_when_moving_left and abs(moved.x) > 0.1:
		sprite.flip_h = moved.x < 0.0

	if velocity.length() > 0.1 and moved.length() < 0.15:
		stuck_time += delta
	else:
		stuck_time = 0.0

	if stuck_time >= stuck_seconds:
		target_position = _get_next_target_position()
		stuck_time = 0.0


func entrar_idle() -> void:
	is_moving = false
	velocity = Vector2.ZERO
	stuck_time = 0.0
	idle_timer.start(randf_range(idle_min_seconds, idle_max_seconds))


func _on_timer_timeout() -> void:
	target_position = _get_next_target_position()
	is_moving = true


func _update_animation(delta: float) -> void:
	var total_frames = _get_frame_count()
	if total_frames <= 1:
		return

	animation_time += delta
	var frame_offset = int(animation_time * animation_fps) % total_frames
	sprite.frame = first_frame + frame_offset


func _get_frame_count() -> int:
	if frame_count > 0:
		return frame_count
	return max(1, sprite.hframes * sprite.vframes - first_frame)


func _get_random_point_in_wander_area() -> Vector2:
	if wander_shape != null:
		if wander_shape is RectangleShape2D:
			var rect_shape := wander_shape as RectangleShape2D
			var extents = rect_shape.size * 0.5
			return wander_global_xform * Vector2(
				randf_range(-extents.x, extents.x),
				randf_range(-extents.y, extents.y)
			)

		if wander_shape is CircleShape2D:
			var circle_shape := wander_shape as CircleShape2D
			var angle = randf_range(0.0, TAU)
			var radius = sqrt(randf()) * circle_shape.radius
			return wander_global_xform * (Vector2(cos(angle), sin(angle)) * radius)

		if wander_shape is CapsuleShape2D:
			var capsule_shape := wander_shape as CapsuleShape2D
			var half_h = max(0.0, (capsule_shape.height * 0.5) - capsule_shape.radius)
			return wander_global_xform * Vector2(
				randf_range(-capsule_shape.radius, capsule_shape.radius),
				randf_range(-(half_h + capsule_shape.radius), half_h + capsule_shape.radius)
			)

	var angle = randf_range(0.0, TAU)
	var radius = sqrt(randf()) * fallback_wander_radius
	return spawn_position + Vector2(cos(angle), sin(angle)) * radius


func _get_next_target_position() -> Vector2:
	var best_candidate = global_position
	var best_distance = -1.0

	for _i in range(8):
		var candidate = _get_random_point_in_wander_area()
		var distance = global_position.distance_to(candidate)
		if distance > best_distance:
			best_distance = distance
			best_candidate = candidate
		if distance >= min_target_distance:
			return candidate

	return best_candidate


func _is_inside_wander_area(world_point: Vector2) -> bool:
	if wander_shape == null:
		return true

	var local_point = wander_global_xform.affine_inverse() * world_point

	if wander_shape is RectangleShape2D:
		var rect_shape := wander_shape as RectangleShape2D
		var extents = rect_shape.size * 0.5
		return abs(local_point.x) <= extents.x and abs(local_point.y) <= extents.y

	if wander_shape is CircleShape2D:
		var circle_shape := wander_shape as CircleShape2D
		return local_point.length() <= circle_shape.radius

	if wander_shape is CapsuleShape2D:
		var capsule_shape := wander_shape as CapsuleShape2D
		var half_h = max(0.0, (capsule_shape.height * 0.5) - capsule_shape.radius)
		if abs(local_point.y) <= half_h and abs(local_point.x) <= capsule_shape.radius:
			return true
		var cap_center_y = sign(local_point.y) * half_h
		return Vector2(local_point.x, local_point.y - cap_center_y).length() <= capsule_shape.radius

	return true


func _closest_point_inside_wander_area(world_point: Vector2) -> Vector2:
	if wander_shape == null:
		return world_point

	var local_point = wander_global_xform.affine_inverse() * world_point

	if wander_shape is RectangleShape2D:
		var rect_shape := wander_shape as RectangleShape2D
		var extents = rect_shape.size * 0.5
		local_point.x = clampf(local_point.x, -extents.x, extents.x)
		local_point.y = clampf(local_point.y, -extents.y, extents.y)
		return wander_global_xform * local_point

	if wander_shape is CircleShape2D:
		var circle_shape := wander_shape as CircleShape2D
		if local_point.length() > circle_shape.radius:
			local_point = local_point.normalized() * circle_shape.radius
		return wander_global_xform * local_point

	if wander_shape is CapsuleShape2D:
		var capsule_shape := wander_shape as CapsuleShape2D
		var half_h = max(0.0, (capsule_shape.height * 0.5) - capsule_shape.radius)
		local_point.x = clampf(local_point.x, -capsule_shape.radius, capsule_shape.radius)
		local_point.y = clampf(local_point.y, -(half_h + capsule_shape.radius), half_h + capsule_shape.radius)
		return wander_global_xform * local_point

	return world_point
