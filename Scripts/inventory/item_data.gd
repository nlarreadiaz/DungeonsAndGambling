class_name ItemData
extends Resource

@export var item_id: StringName
@export var display_name: String = ""
@export var icon_texture: Texture2D
@export_range(1, 64, 1) var max_stack: int = 64
