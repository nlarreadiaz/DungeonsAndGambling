class_name InventorySlot
extends Panel

var inventory_ui: InventoryUI = null
var slot_index: int = -1

@onready var background: Control = $Background
@onready var hover_overlay: ColorRect = $HoverOverlay
@onready var icon: TextureRect = $Icon
@onready var amount: Label = $Amount


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup(owner_ui: InventoryUI, index: int) -> void:
	inventory_ui = owner_ui
	slot_index = index
	refresh()


func refresh() -> void:
	if inventory_ui == null:
		_set_empty()
		return

	var slot_data := inventory_ui.get_slot_data(slot_index)
	if slot_data == null or slot_data.is_empty():
		_set_empty()
		return

	icon.texture = slot_data.item_data.icon_texture
	icon.visible = true

	amount.visible = slot_data.quantity > 1
	amount.text = str(slot_data.quantity)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_ui == null:
		return null

	var slot_data := inventory_ui.get_slot_data(slot_index)
	if slot_data == null or slot_data.is_empty():
		return null

	set_drag_preview(inventory_ui.create_drag_preview(slot_data))
	return inventory_ui.create_drag_data(slot_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if inventory_ui == null or not inventory_ui.is_valid_drag_data(data):
		return false

	var from_index := int(data["from_index"])
	return inventory_ui.can_move_between_slots(from_index, slot_index)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_ui == null or not inventory_ui.is_valid_drag_data(data):
		return

	var from_index := int(data["from_index"])
	inventory_ui.request_move(from_index, slot_index)


func _set_empty() -> void:
	icon.texture = null
	icon.visible = false
	amount.visible = false
	amount.text = ""


func _on_mouse_entered() -> void:
	hover_overlay.visible = true


func _on_mouse_exited() -> void:
	hover_overlay.visible = false
