class_name InventorySlotData
extends RefCounted

var item_data: ItemData = null
var quantity: int = 0
var inventory_id: int = 0
var database_item_id: int = 0


func is_empty() -> bool:
	return item_data == null or quantity <= 0


func clear() -> void:
	item_data = null
	quantity = 0
	inventory_id = 0
	database_item_id = 0


func set_data(new_item_data: ItemData, new_quantity: int, new_inventory_id: int = 0, new_database_item_id: int = 0) -> void:
	item_data = new_item_data
	quantity = max(new_quantity, 0)
	inventory_id = max(new_inventory_id, 0)
	database_item_id = max(new_database_item_id, 0)
	if database_item_id == 0 and item_data != null:
		database_item_id = max(item_data.database_item_id, 0)
	if is_empty():
		clear()


func copy_from(other: InventorySlotData) -> void:
	if other == null or other.is_empty():
		clear()
		return

	item_data = other.item_data
	quantity = other.quantity
	inventory_id = other.inventory_id
	database_item_id = other.database_item_id


func matches_item(other_item_data: ItemData) -> bool:
	if item_data == null or other_item_data == null:
		return false

	if database_item_id > 0 and other_item_data.database_item_id > 0:
		return database_item_id == other_item_data.database_item_id

	if item_data.item_id != StringName():
		return item_data.item_id == other_item_data.item_id

	return item_data == other_item_data


func get_max_stack() -> int:
	if item_data == null:
		return 0
	return max(item_data.max_stack, 1)
