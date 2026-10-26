extends "res://scripts/ui/game_panel.gd"
## Korsan Kaptan Tek Göz Rıza: kürek, harita parçası, birleştirme, hazine haritası, Korsan Papağanı.

const Map = preload("res://scripts/map.gd")

var box: VBoxContainer
var chart: Control


class Chart extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#e7d3a1"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7c5a2b"), false, 4)
		var k: Rect2 = Map.KORSAN
		var sc := minf((size.x - 60) / k.size.x, (size.y - 60) / k.size.y)
		var to := func(p: Vector2) -> Vector2: return Vector2(size.x / 2.0, size.y / 2.0) + (p - k.get_center()) * sc
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			pts.append(to.call(k.get_center() + Vector2(cos(a) * k.size.x / 2.0 * (1.0 + 0.05 * sin(i * 2.3)), sin(a) * k.size.y / 2.0)))
		draw_colored_polygon(pts, Color("#c9a86a"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#7c5a2b"), 2)
		var ship: Vector2 = to.call(Map.KORSAN_SHIP)
		draw_rect(Rect2(ship - Vector2(18, 6), Vector2(36, 12)), Color("#5b3a1e"))
		draw_line(ship, ship + Vector2(0, -22), Color("#5b3a1e"), 2)
		var pier: Vector2 = to.call(Map.KORSAN_PIER.get_center())
		draw_rect(Rect2(pier - Vector2(4, 12), Vector2(8, 24)), Color("#7c5a2b"))
		if Pirates.state.get("has_map", false):
			var x: Vector2 = to.call(Pirates.map_hint)
			draw_line(x + Vector2(-12, -12), x + Vector2(12, 12), Color("#b91c1c"), 5)
			draw_line(x + Vector2(-12, 12), x + Vector2(12, -12), Color("#b91c1c"), 5)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, 22), "KORSAN ADASI", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color("#5b3a1e"))
		draw_string(font, Vector2(10, size.y - 10), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5b3a1e"))


func _ready() -> void:
	build("Korsan Kaptan Tek Göz Rıza", Vector2(600, 0))
	add_label(body, "\"Arrr! Hazine haritasının 4 parçasını getir, birleştireyim. Sonra küreğini kap, X'i kaz!\"", 15, Color("#fde68a")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	chart = Chart.new()
	chart.custom_minimum_size = Vector2(560, 220)
	body.add_child(chart)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Pirates.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	chart.queue_redraw()
	for c in box.get_children():
		c.queue_free()
	var s: Dictionary = Pirates.state
	add_label(box, "Harita parçaları: %d / %d   •   Bulunan hazine: %d" % [int(s.pieces), Pirates.PIECES, int(s.found)], 16, Color("#facc15"))
	if s.get("has_map", false):
		add_label(box, "Haritan hazır! X'e git, E ile kaz. Kazdıkça 'sıcak / soğuk' diye ipucu alırsın.", 14, Settings.ok_text()).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif int(s.pieces) >= Pirates.PIECES:
		add_button(box, "Parçaları birleştir!", Pirates.combine).custom_minimum_size = Vector2(0, 40)
	else:
		add_label(box, "Parçalar: adada kazarken, açık denizde balık tutarken ya da batık gemideki sandıktan çıkar.", 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var r := HBoxContainer.new()
	box.add_child(r)
	add_label(r, "Kürek", 15).size_flags_horizontal = SIZE_EXPAND_FILL
	if s.get("shovel", false):
		add_label(r, "Sende ✓", 14, Settings.ok_text())
	else:
		buy_button(r, Pirates.SHOVEL_PRICE, Pirates.buy.bind("shovel"))
	var r2 := HBoxContainer.new()
	box.add_child(r2)
	add_label(r2, "Harita parçası (günde bir)", 15).size_flags_horizontal = SIZE_EXPAND_FILL
	var pb := buy_button(r2, Pirates.PIECE_PRICE, Pirates.buy.bind("piece"))
	pb.disabled = pb.disabled or s.get("piece_today", false) or s.get("has_map", false) or int(s.pieces) >= Pirates.PIECES
	var r3 := HBoxContainer.new()
	box.add_child(r3)
	add_label(r3, "Korsan Papağanı (tokken harita parçası şansı ×2)", 15).size_flags_horizontal = SIZE_EXPAND_FILL
	var b3 := buy_button(r3, Pirates.PARROT_PRICE, Pirates.buy.bind("parrot"))
	if int(s.found) < 1:
		b3.disabled = true
		b3.tooltip_text = "Önce bir hazine bul."
