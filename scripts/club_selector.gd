extends VBoxContainer

# One toggle button per club type. Each resolves to whatever club the player has
# slotted in that type via the clubhouse loadout, so swapping a club in the clubhouse
# carries straight into the on-course selector.
const CLUB_TYPES  : Array[String] = ["driver", "iron", "wedge", "putter"]
const TYPE_LABELS : Array[String] = ["Driver", "Iron", "Wedge", "Putter"]

func _ready() -> void:
	for i in range(CLUB_TYPES.size()):
		var btn := Button.new()
		btn.text = TYPE_LABELS[i]
		btn.custom_minimum_size = Vector2(108.0, 56.0)
		btn.toggle_mode = true
		btn.pressed.connect(_on_pressed.bind(CLUB_TYPES[i]))
		add_child(btn)
	_refresh()

func _on_pressed(type: String) -> void:
	var id := EquipmentManager.get_loadout_club(type)
	if id != "":
		EquipmentManager.equip_club(id)
	_refresh()

func _refresh() -> void:
	var equipped : String = SaveManager.data.get("equipped", {}).get("club", "driver_default")
	for i in range(get_child_count()):
		var btn : Button = get_child(i)
		btn.button_pressed = (EquipmentManager.get_loadout_club(CLUB_TYPES[i]) == equipped)
