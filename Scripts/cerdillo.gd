extends CharacterBody2D

@onready var sprite = get_node_or_null("AnimatedSprite2D")
@onready var idle_timer = get_node_or_null("Timer")
@onready var wander_area = get_node_or_null("WanderArea")
@onready var wander_shape_node = get_node_or_null("WanderArea/CollisionShape2D")

@export var speed = 60.0
@export var idle_min_seconds = 1.2
@export var idle_max_seconds = 3.2
@export var reach_distance = 6.0
@export var fallback_wander_radius = 120.0

var target_position = Vector2.ZERO
var is_moving = false
var previous_position = Vector2.ZERO
var spawn_position = Vector2.ZERO
var wander_global_xform = Transform2D.IDENTITY
var wander_shape: Shape2D = null

func _ready():
	if sprite == null or idle_timer == null:
		push_error("Cerdillo: faltan nodos requeridos (AnimatedSprite2D o Timer).")
		set_physics_process(false)
		return

	if wander_area == null:
		wander_area = find_child("WanderArea", true, false) as Area2D
	if wander_area == null:
		wander_area = find_child("*", true, false) as Area2D
	if wander_shape_node == null and wander_area != null:
		wander_shape_node = wander_area.find_child("CollisionShape2D", true, false) as CollisionShape2D

	if wander_area == null or wander_shape_node == null or wander_shape_node.shape == null:
		push_warning("Cerdillo: falta WanderArea/CollisionShape2D con Shape. Se usara fallback_wander_radius.")
	else:
		# Importante: congelamos la transform global del area al iniciar para que
		# no se desplace con el cerdo aunque sea su nodo hijo.
		wander_global_xform = wander_shape_node.global_transform
		wander_shape = wander_shape_node.shape

	if not idle_timer.timeout.is_connected(_on_timer_timeout):
		idle_timer.timeout.connect(_on_timer_timeout)

	spawn_position = global_position
	previous_position = global_position
	entrar_idle()

func _physics_process(_delta):
	if not is_moving:
		velocity = Vector2.ZERO
		return

	var to_target = target_position - global_position
	if to_target.length() <= reach_distance:
		entrar_idle()
		return

	velocity = to_target.normalized() * speed
	move_and_slide()
	_actualizar_animacion()

func _actualizar_animacion():
	var current_position = global_position
	var v = current_position - previous_position

	if v.length() > 0.05:
		if abs(v.x) > abs(v.y):
			sprite.play("caminarEste" if v.x > 0.0 else "caminarOeste")
		else:
			sprite.play("caminarSur" if v.y > 0.0 else "caminarNorte")

	previous_position = current_position

func _on_timer_timeout():
	target_position = _get_random_point_in_wander_area()
	is_moving = true

func entrar_idle():
	is_moving = false
	velocity = Vector2.ZERO
	sprite.play("idle")
	idle_timer.start(randf_range(idle_min_seconds, idle_max_seconds))

func _get_random_point_in_wander_area() -> Vector2:
	if wander_shape != null:
		if wander_shape is RectangleShape2D:
			var rect_shape := wander_shape as RectangleShape2D
			var extents = rect_shape.size * 0.5
			var local_point = Vector2(
				randf_range(-extents.x, extents.x),
				randf_range(-extents.y, extents.y)
			)
			return wander_global_xform * local_point

		if wander_shape is CircleShape2D:
			var circle_shape := wander_shape as CircleShape2D
			var angle = randf_range(0.0, TAU)
			var radius = sqrt(randf()) * circle_shape.radius
			var local_point = Vector2(cos(angle), sin(angle)) * radius
			return wander_global_xform * local_point

		if wander_shape is CapsuleShape2D:
			var capsule_shape := wander_shape as CapsuleShape2D
			var half_h = max(0.0, (capsule_shape.height * 0.5) - capsule_shape.radius)
			var local_point = Vector2(
				randf_range(-capsule_shape.radius, capsule_shape.radius),
				randf_range(-(half_h + capsule_shape.radius), half_h + capsule_shape.radius)
			)
			return wander_global_xform * local_point

	var angle = randf_range(0.0, TAU)
	var radius = sqrt(randf()) * fallback_wander_radius
	return spawn_position + Vector2(cos(angle), sin(angle)) * radius
