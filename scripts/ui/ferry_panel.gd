extends "res://scripts/ui/game_panel.gd"
## Feribot iskelesi: şehir, Martı Adası ve Sanayi Limanı arasında biletli yolculuk.

const Map = preload("res://scripts/map.gd")

var here := ""


func _ready() -> void:
	build("Feribot — %s" % Map.FERRY_STOPS.get(here, ["?"])[0], Vector2(440, 0))
	add_label(body, "Nereye? Bilet: %s (fırtınada sefer yok)" % U.money(Work.FERRY_FARE), 16, Color("#fde68a"))
	for k in Map.FERRY_STOPS:
		if k == here:
			continue
		add_button(body, Map.FERRY_STOPS[k][0], _go.bind(k)).custom_minimum_size = Vector2(0, 38)


func _go(k: String) -> void:
	Work.ride_ferry(k)
	close()
