class_name BattleTurnQueue
extends RefCounted

var _queue: Array = []


func build_queue(context: BattleContext) -> Array:
	var living = context.get_living_actors()
	living.sort_custom(Callable(self, "_sort_actor_turn_order"))
	_queue.clear()
	for actor in living:
		_queue.append(int(actor.get("battle_id", -1)))
	return _queue.duplicate()


func has_next() -> bool:
	return not _queue.is_empty()


func pop_next() -> int:
	if _queue.is_empty():
		return -1
	return int(_queue.pop_front())


func peek_queue() -> Array:
	return _queue.duplicate()


func clear() -> void:
	_queue.clear()


func _sort_actor_turn_order(a: Dictionary, b: Dictionary) -> bool:
	var a_speed = int(a.get("speed", 0))
	var b_speed = int(b.get("speed", 0))
	if a_speed != b_speed:
		return a_speed > b_speed

	var a_side = str(a.get("side", "party"))
	var b_side = str(b.get("side", "party"))
	if a_side != b_side:
		return a_side == "party"

	return int(a.get("battle_id", 0)) < int(b.get("battle_id", 0))
