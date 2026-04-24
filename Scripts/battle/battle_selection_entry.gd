extends Button

@onready var title_label: Label = $MarginContainer/Layout/TitleLabel
@onready var detail_label: Label = $MarginContainer/Layout/DetailLabel


func set_entry_text(title_text: String, detail_text: String = "") -> void:
	title_label.text = title_text
	detail_label.text = detail_text
	detail_label.visible = not detail_text.is_empty()
