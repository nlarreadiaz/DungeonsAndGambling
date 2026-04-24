extends PanelContainer

@onready var avatar_label: Label = $MarginContainer/Layout/AvatarPanel/AvatarLabel
@onready var name_label: Label = $MarginContainer/Layout/Info/NameLabel
@onready var role_label: Label = $MarginContainer/Layout/Info/RoleLabel
@onready var hp_label: Label = $MarginContainer/Layout/Info/StatsRow/HpLabel
@onready var mp_label: Label = $MarginContainer/Layout/Info/StatsRow/MpLabel
@onready var state_label: Label = $MarginContainer/Layout/Info/StateLabel
@onready var avatar_panel: Panel = $MarginContainer/Layout/AvatarPanel


func apply_actor_data(actor_data: Dictionary) -> void:
	if avatar_label == null or name_label == null or role_label == null or hp_label == null or mp_label == null or state_label == null or avatar_panel == null:
		push_warning("BattleActor no encontro todos los nodos visuales esperados.")
		return

	var side = str(actor_data.get("side", "party"))
	var accent_color = Color(0.20, 0.47, 0.42, 1.0)
	if side == "enemy":
		accent_color = Color(0.52, 0.20, 0.20, 1.0)

	var actor_name = str(actor_data.get("name", "Combatiente"))
	avatar_label.text = actor_name.left(1).to_upper()
	avatar_panel.self_modulate = accent_color
	name_label.text = "%s  Lv.%d" % [actor_name, int(actor_data.get("level", 1))]
	role_label.text = str(actor_data.get("role", "Unidad"))
	hp_label.text = "HP %d / %d" % [int(actor_data.get("current_hp", 0)), int(actor_data.get("max_hp", 0))]
	mp_label.text = "MP %d / %d" % [int(actor_data.get("current_mana", 0)), int(actor_data.get("max_mana", 0))]

	var state_chunks: Array = [str(actor_data.get("state", "normal")).capitalize()]
	if bool(actor_data.get("defending", false)):
		state_chunks.append("Defiende")
	state_label.text = "Estado: %s" % " | ".join(state_chunks)

	modulate = Color(1, 1, 1, 1)
	if int(actor_data.get("current_hp", 0)) <= 0:
		modulate = Color(0.62, 0.62, 0.62, 0.92)
	elif bool(actor_data.get("is_current_turn", false)):
		modulate = Color(1.0, 0.96, 0.82, 1.0)
