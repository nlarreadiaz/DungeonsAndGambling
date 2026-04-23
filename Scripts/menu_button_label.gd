extends Label


@onready var initial_y = position.y


func _ready() -> void:
	var button = get_parent()
	if button is TextureButton:
		button.mouse_entered.connect(_on_hover)
		button.mouse_exited.connect(_on_normal)
		button.button_down.connect(_on_pressed)
		button.button_up.connect(_on_hover)


func _on_hover() -> void:
	position.y = initial_y + 1


func _on_normal() -> void:
	position.y = initial_y


func _on_pressed() -> void:
	position.y = initial_y + 2
