extends "res://scripts/ui/game_panel.gd"
## Açık Okyanus haritası (okyanusta M): keşfettiğin adalar ve deniz. Tıkla → yön oku.

const OM = preload("res://scripts/ocean_map.gd")
const Chart = preload("res://scripts/ui/ocean_chart.gd")

var world: Node2D


func _ready() -> void:
	build("Açık Okyanus Haritası", Vector2(800, 0))
	var o: Dictionary = Ocean.my
	add_label(body, "Keşfedilen ada: %d / %d   •   Yanan fener: %d   •   Sarı adlı adaların sandığı dolu" % [o.found.size(), OM.ISLANDS, o.lit.size()], 15, Color("#facc15"))
	var chart := Chart.new()
	chart.world = world
	chart.custom_minimum_size = Vector2(760, 760 * OM.OCEAN.size.y / OM.OCEAN.size.x)
	chart.picked.connect(func(p: Vector2):
		world.set_nav(p)
		close())
	body.add_child(chart)
	add_label(body, "Gri alanlar keşfedilmedi. Gezdikçe harita açılır; fenerleri yakınca geniş bir alan birden açılır. Uzak adalar (★★★★) daha tehlikeli ama daha zengin.",
		13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h := HBoxContainer.new()
	body.add_child(h)
	add_button(h, "Liman Adası'na yön", func():
		world.set_nav(OM.HOME + Vector2(0, 380))
		close())
	add_button(h, "Hedefi temizle", func():
		world.nav_target = null
		close())
