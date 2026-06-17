extends HBoxContainer

const CLUB_IDS    : Array[String] = ["driver_default", "iron_default", "wedge_default", "putter_default"]
const CLUB_LABELS : Array[String] = ["Driver", "Iron", "Wedge", "Putter"]

func _ready() -> void:
	for i in range(CLUB_IDS.size()):
		var btn := Button.new()
		btn.text = CLUB_LABELS[i]
		btn.custom_minimum_size = Vector2(108.0, 56.0)
		btn.toggle_mode = true
		btn.pressed.connect(_on_pressed.bind(CLUB_IDS[i]))
		add_child(btn)
	_refresh()

func _on_pressed(id: String) -> void:
	EquipmentManager.equip_club(id)
	_refresh()

func _refresh() -> void:
	var equipped : String = SaveManager.data.get("equipped", {}).get("club", "driver_default")
	for i in range(get_child_count()):
		var btn : Button = get_child(i)
		btn.button_pressed = (CLUB_IDS[i] == equipped)
