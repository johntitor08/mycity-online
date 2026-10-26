extends "res://scripts/ui/game_panel.gd"
## Akvaryum: müzeye bağışlanan balıklar burada canlı yüzer.

var tank: Control


class Tank extends Control:
	var fish: Array = []
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0c4a6e"))
		for k in 7:
			var x := 40.0 + k * 90.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 40, 0), Vector2(x + 90, size.y), Vector2(x + 30, size.y)]), Color(0.6, 0.9, 1.0, 0.05))
		draw_rect(Rect2(0, size.y - 30, size.x, 30), Color("#c8b27a"))
		for k in 9:
			var sx := 30.0 + k * 75.0
			for j in 4:
				draw_line(Vector2(sx, size.y - 28), Vector2(sx + sin(t * 1.5 + k + j) * 8.0, size.y - 60 - j * 12.0), Color("#15803d"), 3)
		var font := ThemeDB.fallback_font
		for i in fish.size():
			var name: String = fish[i]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(name)
			var col := Color.from_hsv(rng.randf(), 0.6, 0.95)
			var sz := rng.randf_range(10.0, 22.0)
			if name.contains("Köpek") or name.contains("Kılıç") or name.contains("Orkinos"):
				sz = 30.0
			var speed := rng.randf_range(0.15, 0.35)
			var u := fposmod(t * speed + rng.randf(), 2.0)
			var dir := 1.0 if u < 1.0 else -1.0
			var x := (u if u < 1.0 else 2.0 - u) * (size.x - 80) + 40
			var y := 40.0 + rng.randf() * (size.y - 110) + sin(t * 2.0 + i) * 8.0
			var p := Vector2(x, y)
			draw_set_transform(p, 0, Vector2(dir, 1))
			draw_colored_polygon(PackedVector2Array([Vector2(-sz, 0), Vector2(0, -sz * 0.45), Vector2(sz * 0.8, 0), Vector2(0, sz * 0.45)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(-sz, 0), Vector2(-sz * 1.5, -sz * 0.4), Vector2(-sz * 1.5, sz * 0.4)]), col.darkened(0.25))
			draw_circle(Vector2(sz * 0.4, -sz * 0.1), maxf(1.5, sz * 0.1), Color.BLACK)
			draw_set_transform(Vector2.ZERO)
			draw_string(font, p + Vector2(-40, sz + 14), name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 1, 1, 0.8))
		for k in 12:
			var bx := fmod(k * 61.0, size.x)
			var by := size.y - fmod(t * 40.0 + k * 37.0, size.y)
			draw_arc(Vector2(bx, by), 3, 0, TAU, 8, Color(1, 1, 1, 0.5), 1)


func _ready() -> void:
	build("Akvaryum", Vector2(700, 0))
	var fish: Array = []
	for k in Museum.view:
		if str(k).begins_with("fish:"):
			fish.append(str(k).substr(5))
	add_label(body, "Müzeye bağışlanan %d deniz canlısı burada yüzüyor. Daha fazlası için müzeye bağış yap!" % fish.size(), 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tank = Tank.new()
	tank.fish = fish
	tank.custom_minimum_size = Vector2(660, 360)
	body.add_child(tank)
	if fish.is_empty():
		add_label(body, "Akvaryum henüz boş... Balık bağışla, burada yüzsün!", 15, Color("#fde68a"))
	Zoo.visit_aquarium()
	Museum.refresh()
