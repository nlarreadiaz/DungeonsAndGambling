extends CheckButton

const DisplaySettings = preload("res://Scripts/display_settings.gd")


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	set_pressed_no_signal(DisplaySettings.is_fullscreen_enabled())


func _on_toggled(toggled_on: bool) -> void:
	DisplaySettings.set_fullscreen_enabled(get_window(), toggled_on)
