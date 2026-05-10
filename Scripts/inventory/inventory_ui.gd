class_name InventoryUI
extends CanvasLayer

signal inventory_slots_moved(from_index: int, to_index: int)

const SLOT_SCENE: PackedScene = preload("res://Scenes/ui/inventory_slot.tscn")
const SAVE_SLOT_ID = 1
const SLOT_POSITIONS = [
	Vector2(77, 5),
	Vector2(100, 5),
	Vector2(123, 5),
	Vector2(146, 5),
	Vector2(169, 5),
	Vector2(77, 28),
	Vector2(100, 28),
	Vector2(123, 28),
	Vector2(146, 28),
	Vector2(169, 28),
	Vector2(77, 51),
	Vector2(100, 51),
	Vector2(123, 51),
	Vector2(146, 51),
	Vector2(169, 51),
	Vector2(77, 74),
	Vector2(100, 74),
	Vector2(123, 74),
	Vector2(146, 74),
	Vector2(169, 74),
	Vector2(77, 131),
	Vector2(100, 131),
	Vector2(123, 131),
	Vector2(146, 131),
	Vector2(169, 131),
	Vector2(27, 5),
	Vector2(5, 16),
	Vector2(49, 16),
	Vector2(27, 27),
	Vector2(5, 38),
	Vector2(49, 38),
	Vector2(27, 49),
	Vector2(5, 60),
	Vector2(49, 60),
]

var inventory_data: InventoryData = null
var slot_widgets: Array[InventorySlot] = []

@onready var root: Control = $Root
@onready var slots_layer: Control = $Root/CenterContainer/InventoryPanel/SlotsLayer
@onready var gold_label: Label = $Root/CenterContainer/InventoryPanel/GoldLabel


func _ready() -> void:
	layer = 8
	root.visible = false
	_refresh_gold_amount()


func bind_inventory(data: InventoryData) -> void:
	if inventory_data != null and inventory_data.inventory_changed.is_connected(_on_inventory_changed):
		inventory_data.inventory_changed.disconnect(_on_inventory_changed)

	inventory_data = data

	if inventory_data != null:
		inventory_data.inventory_changed.connect(_on_inventory_changed)

	_rebuild_slots()
	_refresh_slots()


func is_inventory_open() -> bool:
	return root.visible


func toggle_inventory() -> void:
	set_inventory_visible(not root.visible)


func set_inventory_visible(is_visible: bool) -> void:
	root.visible = is_visible
	if is_visible:
		_refresh_slots()
		_refresh_gold_amount()


func get_slot_data(index: int) -> InventorySlotData:
	if inventory_data == null:
		return null
	return inventory_data.get_slot(index)


func can_move_between_slots(from_index: int, to_index: int) -> bool:
	if inventory_data == null:
		return false
	if from_index == to_index:
		return false
	return inventory_data.can_move(from_index, to_index)


func request_move(from_index: int, to_index: int) -> void:
	if inventory_data == null:
		return
	if inventory_data.move_slot(from_index, to_index):
		inventory_slots_moved.emit(from_index, to_index)


func create_drag_data(from_index: int) -> Dictionary:
	if inventory_data == null:
		return {}

	var slot_data = inventory_data.get_slot(from_index)
	if slot_data == null or slot_data.is_empty():
		return {}

	return {
		"inventory_ui": self,
		"from_index": from_index,
	}


func is_valid_drag_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("inventory_ui") or not data.has("from_index"):
		return false

	return data["inventory_ui"] == self


func create_drag_preview(slot_data: InventorySlotData) -> Control:
	var preview = Control.new()
	preview.custom_minimum_size = Vector2(20, 20)

	var icon = TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = slot_data.item_data.icon_texture
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.add_child(icon)

	return preview


func _rebuild_slots() -> void:
	for child in slots_layer.get_children():
		child.queue_free()
	slot_widgets.clear()

	if inventory_data == null:
		return

	var slot_total = min(inventory_data.slot_count, SLOT_POSITIONS.size())
	if inventory_data.slot_count > SLOT_POSITIONS.size():
		push_warning("No hay suficientes posiciones visuales para todos los slots del inventario.")

	for index in range(slot_total):
		var slot_widget = SLOT_SCENE.instantiate() as InventorySlot
		if slot_widget == null:
			continue

		slots_layer.add_child(slot_widget)
		slot_widget.position = SLOT_POSITIONS[index]
		slot_widget.setup(self, index)
		slot_widgets.append(slot_widget)


func _refresh_slots() -> void:
	for slot_widget in slot_widgets:
		slot_widget.refresh()


func _on_inventory_changed() -> void:
	_refresh_slots()
	_refresh_gold_amount()


func _refresh_gold_amount() -> void:
	if gold_label == null:
		return

	var database_manager = get_node_or_null("/root/GameDatabase")
	if database_manager == null or not database_manager.has_method("get_game_state"):
		gold_label.text = "0"
		return

	var game_state = database_manager.call("get_game_state", SAVE_SLOT_ID)
	if game_state is not Dictionary:
		gold_label.text = "0"
		return

	gold_label.text = str(max(int(game_state.get("gold", 0)), 0))
