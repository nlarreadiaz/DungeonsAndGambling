extends AnimatedSprite2D

@export var default_animation: StringName = &"idle"


func _ready() -> void:
	if sprite_frames == null:
		return

	if sprite_frames.has_animation(default_animation):
		play(default_animation)
		return

	var animation_names = sprite_frames.get_animation_names()
	if not animation_names.is_empty():
		play(animation_names[0])
