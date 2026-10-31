extends "res://scripts/ui/game_panel.gd"
## Otogar (2.1): şehirler arası otobüs bileti.

const Map = preload("res://scripts/map.gd")

var here := "sehir"


func _ready() -> void:
	build("%s Otogarı" % Map.TOWN_NAMES.get(here, ""), Vector2(440, 0))
	money_hint(body)
	add_label(body, "Şehirler arası otobüs — bilet %s, yolculuk %d sn" % [U.money(Roads.BUS_PRICE), int(Roads.BUS_TIME)], 16, Color("#fde68a"))
	for k in Map.OTOGARS:
		if k == here:
			continue
		var b := buy_button(body, Roads.BUS_PRICE, func(): Roads.take_bus(k); close(), 0, "→ %s" % Map.TOWN_NAMES[k])
		b.custom_minimum_size = Vector2(0, 40)
	add_label(body, "Kendi arabanla da gidebilirsin: rampadan otoyola çık, yolculuğun tadını çıkar.", 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
