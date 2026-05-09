class_name ItemData
extends Resource

@export var item_id: StringName
@export var database_item_id: int = 0
@export var display_name: String = ""
@export var description: String = ""
@export var item_type: String = "misc"
@export var rarity: String = "common"
@export var price: int = 0
@export var icon_texture: Texture2D
@export_range(1, 64, 1) var max_stack: int = 64
@export var usable_in_battle: bool = false
@export var effect_data: Dictionary = {}
