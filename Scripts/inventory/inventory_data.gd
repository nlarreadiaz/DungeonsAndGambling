class_name InventoryData
extends RefCounted

signal inventory_changed

var slot_count: int = 16
var _slots: Array[InventorySlotData] = []


func _init(initial_slot_count: int = 16) -> void:
	slot_count = max(initial_slot_count, 1)
	_slots.resize(slot_count)
	for index in range(slot_count):
		_slots[index] = InventorySlotData.new()


func get_slot(index: int) -> InventorySlotData:
	if not _is_valid_index(index):
		return null
	return _slots[index]


func get_slots() -> Array[InventorySlotData]:
	return _slots


func clear(emit_changed: bool = true) -> void:
	for slot in _slots:
		slot.clear()
	if emit_changed:
		inventory_changed.emit()


func set_slot(index: int, item_data: ItemData, quantity: int, inventory_id: int = 0, database_item_id: int = 0, emit_changed: bool = true) -> void:
	if not _is_valid_index(index):
		return

	_slots[index].set_data(item_data, quantity, inventory_id, database_item_id)
	if emit_changed:
		inventory_changed.emit()


func can_move(from_index: int, to_index: int) -> bool:
	return _is_valid_index(from_index) and _is_valid_index(to_index)


func get_remaining_after_add(item_data: ItemData, amount: int = 1) -> int:
	if item_data == null or amount <= 0:
		return amount

	var remaining = amount
	var max_stack = max(item_data.max_stack, 1)

	for slot in _slots:
		if remaining <= 0:
			break
		if not slot.matches_item(item_data):
			continue

		var room = max_stack - slot.quantity
		if room > 0:
			remaining -= min(room, remaining)

	for slot in _slots:
		if remaining <= 0:
			break
		if slot.is_empty():
			remaining -= min(max_stack, remaining)

	return remaining


func add_item(item_data: ItemData, amount: int = 1) -> int:
	if item_data == null or amount <= 0:
		return amount

	var remaining = amount
	var has_changes = false
	var max_stack = max(item_data.max_stack, 1)

	for slot in _slots:
		if remaining <= 0:
			break
		if not slot.matches_item(item_data):
			continue

		var room = max_stack - slot.quantity
		if room <= 0:
			continue

		var added = min(room, remaining)
		slot.quantity += added
		remaining -= added
		has_changes = true

	for slot in _slots:
		if remaining <= 0:
			break
		if not slot.is_empty():
			continue

		var added = min(max_stack, remaining)
		slot.set_data(item_data, added, 0, item_data.database_item_id)
		remaining -= added
		has_changes = true

	if has_changes:
		inventory_changed.emit()

	return remaining


func move_slot(from_index: int, to_index: int) -> bool:
	if not can_move(from_index, to_index) or from_index == to_index:
		return false

	var from_slot = _slots[from_index]
	var to_slot = _slots[to_index]

	if from_slot.is_empty():
		return false

	if to_slot.is_empty():
		to_slot.copy_from(from_slot)
		from_slot.clear()
		inventory_changed.emit()
		return true

	if to_slot.matches_item(from_slot.item_data):
		var room = to_slot.get_max_stack() - to_slot.quantity
		if room > 0:
			var transfer = min(room, from_slot.quantity)
			to_slot.quantity += transfer
			from_slot.quantity -= transfer
			if from_slot.quantity <= 0:
				from_slot.clear()
			inventory_changed.emit()
			return true

	var temp_item = to_slot.item_data
	var temp_quantity = to_slot.quantity
	var temp_inventory_id = to_slot.inventory_id
	var temp_database_item_id = to_slot.database_item_id

	to_slot.item_data = from_slot.item_data
	to_slot.quantity = from_slot.quantity
	to_slot.inventory_id = from_slot.inventory_id
	to_slot.database_item_id = from_slot.database_item_id
	from_slot.item_data = temp_item
	from_slot.quantity = temp_quantity
	from_slot.inventory_id = temp_inventory_id
	from_slot.database_item_id = temp_database_item_id

	inventory_changed.emit()
	return true


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()
