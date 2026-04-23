extends Area2D

@export var item_data: ItemData
@export_range(1, 64, 1) var amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var amount_label: Label = $AmountLabel


func _ready() -> void:
	_refresh_visuals()


func configure_pickup(new_item_data: ItemData, new_amount: int) -> void:
	item_data = new_item_data
	amount = max(new_amount, 1)
	if is_node_ready():
		_refresh_visuals()


func _on_body_entered(body: Node) -> void:
	if item_data == null:
		return
	if not body.has_method("pickup_item"):
		return

	var remaining = int(body.call("pickup_item", item_data, amount))
	if remaining <= 0:
		queue_free()
		return

	amount = remaining
	_refresh_visuals()


func _refresh_visuals() -> void:
	if sprite == null or amount_label == null:
		return

	if item_data == null:
		sprite.texture = null
		amount_label.visible = false
		return

	sprite.texture = item_data.icon_texture
	amount_label.visible = amount > 1
	amount_label.text = str(amount)
