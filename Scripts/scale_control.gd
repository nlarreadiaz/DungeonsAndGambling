extends OptionButton

const DisplaySettings = preload("res://Scripts/display_settings.gd")
const SCALE_OPTIONS = [1.0, 0.75, 0.5, 0.25]


func _ready() -> void:
	DisplaySettings.configure_window(get_window())
	selected = _find_closest_scale_index(DisplaySettings.get_windowed_scale(get_window()))


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= SCALE_OPTIONS.size():
		return

	DisplaySettings.set_windowed_scale(get_window(), SCALE_OPTIONS[index])


func _find_closest_scale_index(scale_factor: float) -> int:
	var closest_index = 0
	var closest_distance = INF

	for index in range(SCALE_OPTIONS.size()):
		var distance = absf(SCALE_OPTIONS[index] - scale_factor)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index

	return closest_index
