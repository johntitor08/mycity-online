extends "res://scripts/ui/game_panel.gd"
## Havalimanı terminali: uçuş seç.

func _ready() -> void:
	build("Havalimanı — Kalkışlar", Vector2(460, 0))
	add_label(body, "Hızlı uçuşlar. Fırtınada iptal.", 14, Color("#94a3b8"))
	money_hint(body)
	var d: Dictionary = Airport.destinations()
	for k in d:
		var r := HBoxContainer.new()
		body.add_child(r)
		add_label(r, "✈  %s" % d[k][0], 17).size_flags_horizontal = SIZE_EXPAND_FILL
		buy_button(r, int(d[k][2]), func(): Airport.fly(k); close(), 0, "Uç")
