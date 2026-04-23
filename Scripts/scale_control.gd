extends OptionButton

const SCALE_OPTIONS := [1.0, 0.75, 0.5, 0.25]

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= SCALE_OPTIONS.size():
		return

	var window := get_window()
	if window == null:
		return

	window.content_scale_factor = SCALE_OPTIONS[index]
