extends RefCounted

const WINDOWED_SCALE_META = &"windowed_scale_factor"
const VIEWPORT_WIDTH_SETTING = "display/window/size/viewport_width"
const VIEWPORT_HEIGHT_SETTING = "display/window/size/viewport_height"
const WINDOW_WIDTH_SETTING = "display/window/size/window_width_override"
const WINDOW_HEIGHT_SETTING = "display/window/size/window_height_override"


static func configure_window(window: Window) -> void:
	if window == null:
		return

	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = _get_viewport_size()

	if not window.has_meta(WINDOWED_SCALE_META):
		window.set_meta(WINDOWED_SCALE_META, window.content_scale_factor)


static func is_fullscreen_enabled() -> bool:
	var mode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func set_fullscreen_enabled(window: Window, enabled: bool) -> void:
	if window == null:
		return

	configure_window(window)

	if enabled:
		window.set_meta(WINDOWED_SCALE_META, get_windowed_scale(window))
		window.content_scale_factor = 1.0
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	window.content_scale_factor = get_windowed_scale(window)
	_restore_windowed_size(window)
	_center_window(window)


static func set_windowed_scale(window: Window, scale_factor: float) -> void:
	if window == null:
		return

	configure_window(window)

	var clamped_scale = clampf(scale_factor, 0.25, 4.0)
	window.set_meta(WINDOWED_SCALE_META, clamped_scale)

	if not is_fullscreen_enabled():
		window.content_scale_factor = clamped_scale


static func get_windowed_scale(window: Window) -> float:
	if window == null:
		return 1.0

	return float(window.get_meta(WINDOWED_SCALE_META, 1.0))


static func _restore_windowed_size(window: Window) -> void:
	var windowed_size = _get_windowed_size()
	if windowed_size.x <= 0 or windowed_size.y <= 0:
		return

	window.size = windowed_size


static func _center_window(window: Window) -> void:
	var screen = window.current_screen
	var screen_position = DisplayServer.screen_get_position(screen)
	var screen_size = DisplayServer.screen_get_size(screen)
	var centered_position = Vector2i(
		screen_position.x + int((screen_size.x - window.size.x) / 2),
		screen_position.y + int((screen_size.y - window.size.y) / 2)
	)
	window.position = centered_position


static func _get_viewport_size() -> Vector2i:
	return Vector2i(
		int(ProjectSettings.get_setting(VIEWPORT_WIDTH_SETTING)),
		int(ProjectSettings.get_setting(VIEWPORT_HEIGHT_SETTING))
	)


static func _get_windowed_size() -> Vector2i:
	return Vector2i(
		int(ProjectSettings.get_setting(WINDOW_WIDTH_SETTING)),
		int(ProjectSettings.get_setting(WINDOW_HEIGHT_SETTING))
	)
