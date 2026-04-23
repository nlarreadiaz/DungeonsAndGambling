class_name InventorySlotData
extends RefCounted

var item_data: ItemData = null
var quantity: int = 0


func is_empty() -> bool:
	return item_data == null or quantity <= 0


func clear() -> void:
	item_data = null
	quantity = 0


func set_data(new_item_data: ItemData, new_quantity: int) -> void:
	item_data = new_item_data
	quantity = max(new_quantity, 0)
	if is_empty():
		clear()


func copy_from(other: InventorySlotData) -> void:
	if other == null or other.is_empty():
		clear()
		return

	item_data = other.item_data
	quantity = other.quantity


func matches_item(other_item_data: ItemData) -> bool:
	if item_data == null or other_item_data == null:
		return false

	if item_data.item_id != StringName():
		return item_data.item_id == other_item_data.item_id

	return item_data == other_item_data


func get_max_stack() -> int:
	if item_data == null:
		return 0
	return max(item_data.max_stack, 1)
