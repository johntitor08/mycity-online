extends "res://scripts/ui/game_panel.gd"
## Otobüs durağı: gideceğin durağı seç (bilet ücretli).

const Map = preload("res://scripts/map.gd")

var here := ""


func _ready() -> void:
	build("Otobüs Durağı — %s" % Map.BUS_STOPS.get(here, ["?"])[0], Vector2(440, 0))
	add_label(body, "Nereye gitmek istersin? Bilet: %s" % U.money(Work.BUS_FARE), 16, Color("#fde68a"))
	for k in Map.BUS_STOPS:
		if k == here:
			continue
		var b := add_button(body, Map.BUS_STOPS[k][0], _go.bind(k))
		b.custom_minimum_size = Vector2(0, 38)
	add_label(body, "Sarı otobüs şehri dolaşır; bilet alınca hemen o durağa varırsın.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _go(k: String) -> void:
	Work.ride_bus(k)
	close()
