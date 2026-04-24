extends Control

signal command_requested(command_name: String)
signal selection_confirmed(selected_payload: Dictionary)
signal selection_back_requested

const SELECTION_ENTRY_SCENE: PackedScene = preload("res://Scenes/battle/battle_selection_entry.tscn")

@onready var title_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/TopPanel/MarginContainer/TopContent/TitleLabel
@onready var subtitle_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/TopPanel/MarginContainer/TopContent/InfoRow/SubtitleLabel
@onready var current_turn_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/TopPanel/MarginContainer/TopContent/InfoRow/CurrentTurnLabel
@onready var queue_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/TopPanel/MarginContainer/TopContent/QueueLabel
@onready var party_header: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/Battlefield/PartyPanel/MarginContainer/PartyContent/Header
@onready var party_container: VBoxContainer = $ContentCenter/BattlePanel/MarginContainer/Layout/Battlefield/PartyPanel/MarginContainer/PartyContent/PartyScroll/Actors
@onready var enemy_header: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/Battlefield/EnemyPanel/MarginContainer/EnemyContent/Header
@onready var enemy_container: VBoxContainer = $ContentCenter/BattlePanel/MarginContainer/Layout/Battlefield/EnemyPanel/MarginContainer/EnemyContent/EnemyScroll/Actors
@onready var attack_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/AttackButton
@onready var skill_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/SkillButton
@onready var item_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/ItemButton
@onready var defend_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/DefendButton
@onready var flee_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/FleeButton
@onready var selection_panel: PanelContainer = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/SelectionPanel
@onready var selection_title_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/SelectionPanel/MarginContainer/SelectionContent/SelectionTitle
@onready var selection_scroll: ScrollContainer = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/SelectionPanel/MarginContainer/SelectionContent/SelectionScroll
@onready var selection_entries: VBoxContainer = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/SelectionPanel/MarginContainer/SelectionContent/SelectionScroll/SelectionEntries
@onready var confirm_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/SelectionPanel/MarginContainer/SelectionContent/ButtonsRow/ConfirmButton
@onready var back_button: Button = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/SelectionPanel/MarginContainer/SelectionContent/ButtonsRow/BackButton
@onready var log_panel: PanelContainer = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/LogPanel
@onready var status_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/LogPanel/MarginContainer/LogContent/StatusLabel
@onready var hint_label: Label = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/LogPanel/MarginContainer/LogContent/HintLabel
@onready var log_text: RichTextLabel = $ContentCenter/BattlePanel/MarginContainer/Layout/BottomArea/SidePanel/LogPanel/MarginContainer/LogContent/LogText

var _selection_payloads: Array = []
var _selection_buttons: Array = []
var _selected_index = -1


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	item_button.pressed.connect(_on_item_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	hide_selection()


func set_titles(title_text: String, subtitle_text: String) -> void:
	title_label.text = title_text
	subtitle_label.text = subtitle_text


func set_turn_info(actor_name: String, round_number: int, queue_text: String) -> void:
	current_turn_label.text = "Turno: %s | R%d" % [actor_name, round_number]
	queue_label.text = queue_text


func set_status(status_text: String) -> void:
	status_label.text = status_text


func set_hint(hint_text: String) -> void:
	hint_label.text = hint_text


func set_party_header(text: String) -> void:
	party_header.text = text


func set_enemy_header(text: String) -> void:
	enemy_header.text = text


func clear_actor_lists() -> void:
	for container in [party_container, enemy_container]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func get_party_container() -> VBoxContainer:
	return party_container


func get_enemy_container() -> VBoxContainer:
	return enemy_container


func set_commands_for_actor(actor_data: Dictionary, has_skills: bool, has_items: bool, can_flee: bool = true) -> void:
	var actor_name = str(actor_data.get("name", ""))
	skill_button.disabled = not has_skills
	item_button.disabled = not has_items
	flee_button.disabled = not can_flee
	set_status("Elige una accion para %s." % actor_name)
	attack_button.grab_focus()


func set_commands_enabled(enabled: bool) -> void:
	for button in [attack_button, skill_button, item_button, defend_button, flee_button]:
		button.disabled = not enabled


func show_selection(title_text: String, entries: Array) -> void:
	selection_title_label.text = title_text
	_clear_selection_entries()
	_selection_payloads.clear()
	_selection_buttons.clear()
	_selected_index = -1

	for entry in entries:
		if entry is not Dictionary:
			continue
		var entry_payload = entry.duplicate(true)
		var entry_button = SELECTION_ENTRY_SCENE.instantiate()
		if entry_button == null:
			continue

		var entry_index = _selection_payloads.size()
		_selection_payloads.append(entry_payload)
		_selection_buttons.append(entry_button)
		selection_entries.add_child(entry_button)

		if entry_button.has_method("set_entry_text"):
			entry_button.call(
				"set_entry_text",
				str(entry_payload.get("label", "Seleccion")),
				str(entry_payload.get("detail", ""))
			)

		entry_button.focus_entered.connect(_on_entry_focus_entered.bind(entry_index))
		entry_button.mouse_entered.connect(_on_entry_focus_entered.bind(entry_index))
		entry_button.pressed.connect(_on_entry_pressed.bind(entry_index))

	selection_panel.visible = true
	log_panel.visible = false
	confirm_button.disabled = _selection_payloads.is_empty()
	back_button.disabled = false
	if not _selection_buttons.is_empty():
		_set_selected_index(0)
		selection_scroll.scroll_vertical = 0


func hide_selection() -> void:
	_clear_selection_entries()
	_selection_payloads.clear()
	_selection_buttons.clear()
	_selected_index = -1
	selection_title_label.text = "Seleccion"
	selection_panel.visible = false
	log_panel.visible = true
	confirm_button.disabled = true
	back_button.disabled = true


func set_log_lines(lines: Array) -> void:
	log_text.clear()
	var formatted_lines: Array = []
	for line in lines:
		formatted_lines.append("[p]%s[/p]" % str(line))
	log_text.append_text("\n".join(formatted_lines))
	log_text.scroll_to_line(max(log_text.get_line_count() - 1, 0))


func _on_attack_pressed() -> void:
	command_requested.emit("attack")


func _on_skill_pressed() -> void:
	command_requested.emit("skill")


func _on_item_pressed() -> void:
	command_requested.emit("item")


func _on_defend_pressed() -> void:
	command_requested.emit("defend")


func _on_flee_pressed() -> void:
	command_requested.emit("flee")


func _on_confirm_pressed() -> void:
	var selection = _get_current_selection()
	if selection.is_empty():
		return
	selection_confirmed.emit(selection)


func _on_back_pressed() -> void:
	selection_back_requested.emit()


func _get_current_selection() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _selection_payloads.size():
		return {}
	return _selection_payloads[_selected_index].duplicate(true)


func _on_entry_focus_entered(index: int) -> void:
	_set_selected_index(index)


func _on_entry_pressed(index: int) -> void:
	_set_selected_index(index)
	var selection = _get_current_selection()
	if selection.is_empty():
		return
	selection_confirmed.emit(selection)


func _set_selected_index(index: int) -> void:
	if index < 0 or index >= _selection_buttons.size():
		return

	_selected_index = index
	for button_index in range(_selection_buttons.size()):
		var entry_button = _selection_buttons[button_index]
		if entry_button == null:
			continue
		entry_button.set_pressed_no_signal(button_index == _selected_index)

	if _selection_buttons[_selected_index] != null:
		_selection_buttons[_selected_index].grab_focus()


func _clear_selection_entries() -> void:
	for child in selection_entries.get_children():
		selection_entries.remove_child(child)
		child.queue_free()
