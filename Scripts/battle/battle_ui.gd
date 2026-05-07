extends Control

signal command_requested(command_name: String)
signal selection_confirmed(selected_payload: Dictionary)
signal selection_back_requested

const SELECTION_ENTRY_SCENE: PackedScene = preload("res://Scenes/battle/battle_selection_entry.tscn")

@onready var title_label: Label = $TopHud/TitleBox/TitleLabel
@onready var subtitle_label: Label = $TopHud/TitleBox/SubtitleLabel
@onready var current_turn_label: Label = $TopHud/TurnBox/CurrentTurnLabel
@onready var queue_label: Label = $TopHud/TurnBox/QueueLabel
@onready var party_container: Control = $StagePanel/Stage/PartyActors
@onready var enemy_container: Control = $StagePanel/Stage/EnemyActors
@onready var battle_slots: Control = $StagePanel/Stage/BattleSlots
@onready var attack_button: TextureButton = $BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/AttackButton
@onready var skill_button: TextureButton = $BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/SkillButton
@onready var item_button: TextureButton = $BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/ItemButton
@onready var defend_button: TextureButton = $BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/DefendButton
@onready var flee_button: TextureButton = $BottomArea/CommandPanel/MarginContainer/CommandContent/Buttons/FleeButton
@onready var selection_panel: PanelContainer = $BottomArea/MessageStack/SelectionPanel
@onready var selection_title_label: Label = $BottomArea/MessageStack/SelectionPanel/MarginContainer/SelectionContent/SelectionTitle
@onready var selection_scroll: ScrollContainer = $BottomArea/MessageStack/SelectionPanel/MarginContainer/SelectionContent/SelectionScroll
@onready var selection_entries: VBoxContainer = $BottomArea/MessageStack/SelectionPanel/MarginContainer/SelectionContent/SelectionScroll/SelectionEntries
@onready var confirm_button: Button = $BottomArea/MessageStack/SelectionPanel/MarginContainer/SelectionContent/ButtonsRow/ConfirmButton
@onready var back_button: Button = $BottomArea/MessageStack/SelectionPanel/MarginContainer/SelectionContent/ButtonsRow/BackButton
@onready var log_panel: PanelContainer = $BottomArea/MessageStack/LogPanel
@onready var status_label: Label = $BottomArea/MessageStack/LogPanel/MarginContainer/LogContent/StatusLabel
@onready var hint_label: Label = $BottomArea/MessageStack/LogPanel/MarginContainer/LogContent/HintLabel
@onready var log_text: RichTextLabel = $BottomArea/MessageStack/LogPanel/MarginContainer/LogContent/LogText
@onready var outcome_overlay: Control = $OutcomeOverlay
@onready var outcome_title_label: Label = $OutcomeOverlay/CenterBox/Title
@onready var outcome_subtitle_label: Label = $OutcomeOverlay/CenterBox/Subtitle

var _selection_payloads: Array = []
var _selection_buttons: Array = []
var _selected_index = -1


func _ready() -> void:
	if battle_slots != null:
		battle_slots.visible = false
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	item_button.pressed.connect(_on_item_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	hide_selection()
	hide_outcome_banner()
	_refresh_command_button_state()


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


func set_party_header(_text: String) -> void:
	pass


func set_enemy_header(_text: String) -> void:
	pass


func clear_actor_lists() -> void:
	for container in [party_container, enemy_container]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func get_party_container() -> Control:
	return party_container


func get_enemy_container() -> Control:
	return enemy_container


func get_actor_slot_position(side: String, slot_index: int) -> Vector2:
	if battle_slots == null:
		return Vector2.ZERO

	var slot_prefix = "PartySlot"
	if side == "enemy":
		slot_prefix = "EnemySlot"

	var slot = battle_slots.get_node_or_null("%s%d" % [slot_prefix, slot_index]) as Control
	if slot == null:
		return Vector2.ZERO

	var real_actor = slot.get_node_or_null("RealActor") as Control
	if real_actor != null:
		return slot.position + real_actor.position

	return slot.position


func set_commands_for_actor(actor_data: Dictionary, has_skills: bool, has_items: bool, can_flee: bool = true) -> void:
	var actor_name = str(actor_data.get("name", ""))
	attack_button.disabled = false
	skill_button.disabled = not has_skills
	item_button.disabled = not has_items
	defend_button.disabled = false
	flee_button.disabled = not can_flee
	set_status("Que debe hacer %s?" % actor_name)
	_refresh_command_button_state()
	attack_button.grab_focus()


func set_commands_enabled(enabled: bool) -> void:
	for button in _get_command_buttons():
		button.disabled = not enabled
	_refresh_command_button_state()


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
	for line_index in range(lines.size()):
		formatted_lines.append("[p]%s[/p]" % str(lines[line_index]))
	log_text.append_text("\n".join(formatted_lines))
	log_text.scroll_to_line(max(log_text.get_line_count() - 1, 0))


func show_outcome_banner(title_text: String, subtitle_text: String = "") -> void:
	outcome_title_label.text = title_text
	outcome_subtitle_label.text = subtitle_text
	outcome_subtitle_label.visible = not subtitle_text.is_empty()
	outcome_overlay.visible = true


func hide_outcome_banner() -> void:
	outcome_overlay.visible = false
	outcome_title_label.text = ""
	outcome_subtitle_label.text = ""


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


func _get_command_buttons() -> Array:
	return [attack_button, skill_button, item_button, defend_button, flee_button]


func _refresh_command_button_state() -> void:
	for button in _get_command_buttons():
		if button == null:
			continue
		if button.disabled:
			button.modulate = Color(0.55, 0.55, 0.55, 0.72)
		else:
			button.modulate = Color(1, 1, 1, 1)
