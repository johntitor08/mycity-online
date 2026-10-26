extends "res://scripts/ui/game_panel.gd"
## Sinema (1.7): perdede o anki seansın filmi (herkes aynı sahneyi görür), bilet, patlamış mısır,
## tepkiler ve karaoke. Filmler ve şarkı sözleri oyuna özgüdür.

var screen: Control
var side: VBoxContainer
var kara_box: VBoxContainer
var status: Label
var viewers_label: Label
var _acc := 0.0
var _hits: Array = []
var _played := {}
var _result := {}


class Screen extends Control:
	var reacts: Array = []           # [{text, who, t0, x}]
	var panel_ref = null

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0b0f"))
		var now := Land.server_now()
		if not Cinema.karaoke.is_empty():
			_draw_karaoke(w, h)
		else:
			var s := Cinema.session_at(now)
			if s.playing and Cinema.has_ticket(int(s.n)):
				_draw_film(int(s.film), float(s.t), w, h)
			else:
				_draw_curtain(w, h, s)
		# tepkiler
		var t := Time.get_ticks_msec() / 1000.0
		var keep: Array = []
		for r in reacts:
			var age := t - float(r.t0)
			if age > 2.5:
				continue
			keep.append(r)
			var y := h - 40 - age * 60.0
			draw_string(ThemeDB.fallback_font, Vector2(float(r.x) * w - 80, y), "%s: %s" % [r.who, r.text], HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(1, 0.9, 0.5, 1.0 - age / 2.5))
		reacts = keep

	func _draw_curtain(w: float, h: float, s: Dictionary) -> void:
		for i in 14:
			var x := w * i / 14.0
			draw_rect(Rect2(x, 0, w / 14.0, h), Color("#7f1d1d") if i % 2 == 0 else Color("#991b1b"))
		var f := ThemeDB.fallback_font
		var film: Dictionary = Cinema.FILMS[int(s.film) if not s.playing else (int(s.film) + 1) % Cinema.FILMS.size()]
		var line1 := "Şimdi: %s" % Cinema.FILMS[int(s.film)].name if s.playing else "Sıradaki film: %s" % film.name
		var line2 := "Bu seansa biletin yok. Bilet al!" if s.playing else "Başlamasına %d sn" % int(ceil(float(s.left)))
		if s.playing and Cinema.has_ticket(int(s.n) + 1):
			line2 = "Biletin sonraki seans için (%s). %d sn sonra." % [Cinema.FILMS[(int(s.film) + 1) % Cinema.FILMS.size()].name, int(ceil(float(s.left)))]
		draw_string(f, Vector2(0, h * 0.42), line1, HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color("#fde68a"))
		draw_string(f, Vector2(0, h * 0.42 + 36), line2, HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color.WHITE)
		draw_string(f, Vector2(40, h * 0.42 + 70), film.desc, HORIZONTAL_ALIGNMENT_CENTER, w - 80, 14, Color("#fecaca"))

	func _cap(text: String, w: float, h: float) -> void:
		draw_rect(Rect2(0, h - 44, w, 44), Color(0, 0, 0, 0.55))
		draw_string(ThemeDB.fallback_font, Vector2(0, h - 16), text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color.WHITE)

	func _stars(w: float, h: float, t: float, speed: float) -> void:
		for i in 60:
			var x := fposmod(float((i * 137) % 997) / 997.0 * w - t * speed * (0.3 + float(i % 5) * 0.2), w)
			var y := float((i * 271) % 991) / 991.0 * h
			draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.6, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 3.0 + i)))

	func _cat(p: Vector2, s: float, col: Color = Color("#f59e0b")) -> void:
		draw_circle(p, 22 * s, col)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-20, -10) * s, p + Vector2(-14, -34) * s, p + Vector2(-4, -18) * s]), col)
		draw_colored_polygon(PackedVector2Array([p + Vector2(20, -10) * s, p + Vector2(14, -34) * s, p + Vector2(4, -18) * s]), col)
		draw_circle(p + Vector2(-8, -4) * s, 3.5 * s, Color.BLACK)
		draw_circle(p + Vector2(8, -4) * s, 3.5 * s, Color.BLACK)
		draw_circle(p + Vector2(0, 5) * s, 2.5 * s, Color("#f472b6"))

	func _draw_film(film: int, t: float, w: float, h: float) -> void:
		match film:
			0:
				_film_cat(t, w, h)
			1:
				_film_pirate(t, w, h)
			2:
				_film_robot(t, w, h)
			_:
				_film_turtle(t, w, h)
		if t > Cinema.FILM_LEN - 4.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0, 0, 0, (t - Cinema.FILM_LEN + 4.0) / 4.0))
			draw_string(ThemeDB.fallback_font, Vector2(0, h / 2), "SON", HORIZONTAL_ALIGNMENT_CENTER, w, 40, Color.WHITE)

	func _film_cat(t: float, w: float, h: float) -> void:
		draw_rect(Rect2(0, 0, w, h), Color("#0f172a"))
		_stars(w, h, t, 30.0 if t < 20.0 else 220.0)
		if t < 20.0:
			draw_circle(Vector2(w * 0.78, h * 0.25), 46, Color("#fef9c3"))
			for i in 6:
				draw_rect(Rect2(i * w / 6.0, h * 0.62 + (i % 2) * 20, w / 6.0 - 6, h), Color("#1e293b"))
			_cat(Vector2(w * 0.3, h * 0.58 + sin(t * 2.0) * 2.0), 1.2)
			_cap("Kedi Minnoş her gece Ay'a bakar: \"Orada balık şeklinde bir yıldız var!\"", w, h)
		elif t < 45.0:
			var u := (t - 20.0) / 25.0
			var rp := Vector2(w * 0.5, h * (0.75 - u * 0.9))
			draw_rect(Rect2(0, h * 0.8, w, h * 0.2), Color("#334155"))
			draw_colored_polygon(PackedVector2Array([rp + Vector2(-26, 40), rp + Vector2(26, 40), rp + Vector2(26, -40), rp + Vector2(0, -80), rp + Vector2(-26, -40)]), Color("#e5e7eb"))
			draw_circle(rp + Vector2(0, -20), 14, Color("#7dd3fc"))
			_cat(rp + Vector2(0, -20), 0.45)
			for k in 8:
				draw_circle(rp + Vector2(randf_range(-16, 16), 50 + k * 10), 10 - k, Color(1, 0.5 + k * 0.05, 0.1, 0.9))
			_cap("Çöp kutularından bir roket yaptı. Geri sayım: 3... 2... 1... Fırlat!", w, h)
		elif t < 70.0:
			var u2 := (t - 45.0) / 25.0
			draw_circle(Vector2(w * (1.1 - u2 * 0.8), h * 0.3), 60, Color("#c084fc"))
			draw_arc(Vector2(w * (1.1 - u2 * 0.8), h * 0.3), 90, -0.3, 0.3 + PI, 32, Color("#e9d5ff"), 4)
			var rp2 := Vector2(w * 0.3, h * 0.55 + sin(t * 3.0) * 12.0)
			draw_colored_polygon(PackedVector2Array([rp2 + Vector2(-40, -20), rp2 + Vector2(40, -20), rp2 + Vector2(80, 0), rp2 + Vector2(40, 20), rp2 + Vector2(-40, 20)]), Color("#e5e7eb"))
			_cat(rp2 + Vector2(20, 0), 0.4)
			_cap("Gezegenlerin arasından geçti. Bir uzay balinası ona el salladı!", w, h)
		else:
			draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("#d1d5db"))
			for k in 5:
				draw_circle(Vector2(w * (0.1 + k * 0.2), h * 0.8), 14, Color("#9ca3af"))
			var fp := Vector2(w * 0.65, h * 0.3 + sin(t * 2.0) * 6.0)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-40, 0), fp + Vector2(0, -22), fp + Vector2(30, 0), fp + Vector2(0, 22)]), Color("#fde047"))
			draw_colored_polygon(PackedVector2Array([fp + Vector2(28, 0), fp + Vector2(54, -18), fp + Vector2(54, 18)]), Color("#fde047"))
			_cat(Vector2(w * 0.3, h * 0.66 + absf(sin(t * 5.0)) * -18.0), 1.0)
			_cap("Ve işte oradaydı: balık yıldızı! Minnoş sevinçten zıpladı.", w, h)

	func _film_pirate(t: float, w: float, h: float) -> void:
		var storm := t >= 25.0 and t < 50.0
		draw_rect(Rect2(0, 0, w, h * 0.55), Color("#1e293b") if storm else Color("#7dd3fc"))
		draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color("#0c4a6e") if storm else Color("#0284c7"))
		for i in 12:
			var wx := fposmod(i * 90.0 - t * 40.0, w + 90.0) - 45.0
			draw_arc(Vector2(wx, h * 0.6 + (i % 3) * 30), 20, PI, TAU, 10, Color(1, 1, 1, 0.6), 3)
		if t < 50.0:
			var sp := Vector2(w * 0.45, h * 0.55 + sin(t * (3.0 if storm else 1.2)) * (14.0 if storm else 5.0))
			draw_set_transform(sp, sin(t * 2.0) * (0.15 if storm else 0.04), Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(-90, -10), Vector2(90, -10), Vector2(70, 26), Vector2(-74, 26)]), Color("#5b3a1e"))
			draw_line(Vector2(0, -10), Vector2(0, -130), Color("#3f2a1a"), 5)
			draw_colored_polygon(PackedVector2Array([Vector2(4, -124), Vector2(70, -110), Vector2(64, -40), Vector2(4, -30)]), Color("#f8fafc"))
			draw_set_transform(Vector2.ZERO)
			if storm and fmod(t, 3.0) < 0.15:
				draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(1, 1, 1, 0.5))
			for k in (40 if storm else 0):
				var rx := fposmod(k * 47.0 + t * 300.0, w)
				var ry := fposmod(k * 83.0 + t * 500.0, h)
				draw_line(Vector2(rx, ry), Vector2(rx - 6, ry + 16), Color(0.8, 0.9, 1, 0.5), 1.5)
			_cap("Genç Rıza ilk gemisiyle denize açıldı. Haritada bir X vardı..." if not storm else "Fırtına! Dalgalar gemiyi bir o yana bir bu yana savurdu!", w, h)
		elif t < 70.0:
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, h * 0.6), Vector2(w * 0.9, h * 0.6), Vector2(w * 0.75, h * 0.42), Vector2(w * 0.25, h * 0.42)]), Color("#f0dba5"))
			draw_line(Vector2(w * 0.5, h * 0.55), Vector2(w * 0.5 + sin(t * 6.0) * 20.0, h * 0.4), Color("#78350f"), 4)
			draw_line(Vector2(w * 0.47, h * 0.57), Vector2(w * 0.53, h * 0.53), Color("#b91c1c"), 4)
			draw_line(Vector2(w * 0.47, h * 0.53), Vector2(w * 0.53, h * 0.57), Color("#b91c1c"), 4)
			_cap("Fırtına dindi, gemi bir adaya vurdu. X tam buradaydı. Kaz Rıza, kaz!", w, h)
		else:
			var c := Vector2(w * 0.5, h * 0.55)
			draw_rect(Rect2(c.x - 70, c.y - 30, 140, 60), Color("#92400e"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -30), c + Vector2(70, -30), c + Vector2(60, -80), c + Vector2(-60, -80)]), Color("#b45309"))
			for k in 16:
				var a := TAU * k / 16.0 + t
				draw_circle(c + Vector2(cos(a), sin(a) * 0.5) * (90.0 + sin(t * 4 + k) * 10.0) + Vector2(0, -40), 4, Color("#fde047"))
			_cap("Sandık açıldı... İçinde altın ve bir not: \"Asıl hazine yolculuktu.\" Rıza güldü.", w, h)

	func _film_robot(t: float, w: float, h: float) -> void:
		var sunset := t >= 75.0
		draw_rect(Rect2(0, 0, w, h), Color("#fb923c") if sunset else Color("#94a3b8") if t < 25.0 else Color("#bae6fd"))
		draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color("#57534e") if t < 25.0 else Color("#65a30d"))
		if t >= 25.0:
			for k in 7:
				var bh := 80.0 + float((k * 37) % 70)
				draw_rect(Rect2(k * w / 7.0 + 6, h * 0.72 - bh, w / 7.0 - 12, bh), Color("#64748b").darkened(0.3 if sunset else 0.0))
		var rx := w * (0.3 if t < 25.0 else 0.2 + 0.2 * sin(t * 0.5) + 0.1)
		var rp := Vector2(rx, h * 0.6)
		draw_rect(Rect2(rp.x - 24, rp.y - 40, 48, 50), Color("#9ca3af"))
		draw_rect(Rect2(rp.x - 18, rp.y - 74, 36, 30), Color("#d1d5db"))
		var eye := Color("#22d3ee") if t > 8.0 else Color("#334155")
		draw_circle(rp + Vector2(-8, -60), 5, eye)
		draw_circle(rp + Vector2(8, -60), 5, eye)
		draw_line(rp + Vector2(0, -74), rp + Vector2(0, -88), Color("#6b7280"), 2)
		draw_circle(rp + Vector2(0, -90), 4, Color("#ef4444"))
		if t >= 35.0:
			var dp := Vector2(rx + 90 + sin(t * 4.0) * 10.0, h * 0.68)
			draw_circle(dp, 16, Color("#a16207"))
			draw_circle(dp + Vector2(16, -12), 10, Color("#a16207"))
			draw_circle(dp + Vector2(20, -14), 2.5, Color.BLACK)
			if t >= 50.0 and t < 75.0:
				var bp := Vector2(rx + 40 + fposmod(t * 160.0, 300.0), h * 0.6 - absf(sin(t * 4.0)) * 60.0)
				draw_circle(bp, 7, Color("#ef4444"))
		if sunset:
			draw_circle(Vector2(w * 0.8, h * 0.5), 50, Color("#fde047"))
			var hp := Vector2(rx + 50, h * 0.35 + sin(t * 2.0) * 6.0)
			draw_circle(hp + Vector2(-8, 0), 10, Color("#ef4444"))
			draw_circle(hp + Vector2(8, 0), 10, Color("#ef4444"))
			draw_colored_polygon(PackedVector2Array([hp + Vector2(-17, 4), hp + Vector2(17, 4), hp + Vector2(0, 22)]), Color("#ef4444"))
		var caps := ["Hurdalıkta bir robot gözlerini açtı. \"Ben... kimim?\"", "Şehre yürüdü. Herkes çok aceleciydi. Sonra bir köpek ona kuyruk salladı.",
			"Robot top atmayı öğrendi. Köpek getirmeyi zaten biliyordu!", "Gün batarken robot anladı: dost olmak için kalp gerekmez, zaman gerekir."]
		_cap(caps[0 if t < 25.0 else (1 if t < 50.0 else (2 if t < 75.0 else 3))], w, h)

	func _film_turtle(t: float, w: float, h: float) -> void:
		var dark := clampf((t - 30.0) / 10.0, 0.0, 1.0) * (1.0 - clampf((t - 65.0) / 10.0, 0.0, 1.0))
		draw_rect(Rect2(0, 0, w, h), Color("#0369a1").lerp(Color("#0c1a2e"), dark))
		draw_rect(Rect2(0, h * 0.85, w, h * 0.15), Color("#c2b280").darkened(dark * 0.5))
		for k in 14:
			var bx := float((k * 113) % 997) / 997.0 * w
			var by := fposmod(h - t * (20.0 + k * 3.0) - k * 50.0, h)
			draw_arc(Vector2(bx, by), 4 + k % 3, 0, TAU, 10, Color(1, 1, 1, 0.5), 1.5)
		for k in 5:
			var fx := fposmod(k * 200.0 + t * (40.0 + k * 10.0), w + 60.0) - 30.0
			var fy := h * (0.2 + k * 0.12)
			draw_colored_polygon(PackedVector2Array([Vector2(fx, fy), Vector2(fx - 14, fy - 7), Vector2(fx - 14, fy + 7)]), Color("#fbbf24"))
			draw_circle(Vector2(fx + 4, fy), 6, Color("#fbbf24"))
		if t >= 30.0:
			for i in 6:
				var a := PI + i * 0.25
				var base := Vector2(w * 0.85, h * 0.9)
				var pts := PackedVector2Array()
				for s in 8:
					var u := s / 7.0
					pts.append(base + Vector2(cos(a), sin(a)) * u * 260.0 + Vector2(sin(t * 2.0 + i + u * 4.0) * 20.0 * u, 0))
				draw_polyline(pts, Color("#7e22ce"), 12.0)
		var tp := Vector2(w * (0.25 + 0.25 * clampf((t - 60.0) / 25.0, 0.0, 1.0)), h * 0.45 + sin(t) * 10.0)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(-50, 0), tp + Vector2(-30, -30), tp + Vector2(30, -30), tp + Vector2(50, 0), tp + Vector2(30, 20), tp + Vector2(-30, 20)]), Color("#15803d"))
		draw_circle(tp + Vector2(62, -6), 14, Color("#86efac"))
		draw_circle(tp + Vector2(68, -10), 3, Color.BLACK)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(-20, 14), tp + Vector2(-44, 40 + sin(t * 3.0) * 6.0), tp + Vector2(-8, 20)]), Color("#86efac"))
		if t >= 60.0:
			draw_circle(Vector2(w * 0.5, h * 0.1), 80 + sin(t) * 10.0, Color(1, 1, 0.8, 0.25))
		var caps := ["Okyanusun dibinde, yüz yaşında bir kaplumbağa yaşardı: Bilge Tosbi.", "Bir gün karanlıktan dokunaçlar uzandı. Herkes kaçtı... Tosbi kaçmadı.",
			"\"Kaybolmuşsun, değil mi?\" dedi Kraken'e. \"Gel, ışığa giden yolu göstereyim.\"", "O günden sonra Kraken denizcileri korkutmadı; sadece biraz... şaka yaptı."]
		_cap(caps[0 if t < 30.0 else (1 if t < 45.0 else (2 if t < 70.0 else 3))], w, h)

	func _draw_karaoke(w: float, h: float) -> void:
		var k: Dictionary = Cinema.karaoke
		var song: Dictionary = Cinema.SONGS[int(k.song)]
		var el := Time.get_ticks_msec() / 1000.0 - float(k.t0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color("#1e1b4b"))
		for i in 8:
			var a := el * 0.6 + i * TAU / 8.0
			draw_line(Vector2(w / 2, -40), Vector2(w / 2 + cos(a) * w, h), Color(1, 0.4 + 0.07 * i, 0.9, 0.08), 30)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, 40), "KARAOKE: %s" % song.name, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color("#f0abfc"))
		if el < 3.0:
			draw_string(f, Vector2(0, h / 2), str(3 - int(el)), HORIZONTAL_ALIGNMENT_CENTER, w, 60, Color.WHITE)
		var bs: Array = k.beats
		var cur_line := 0
		for b in bs:
			if float(b.t) <= el + 0.6:
				cur_line = int(b.line)
		for li in [cur_line, cur_line + 1]:
			if li >= song.lines.size():
				continue
			var y := h * (0.5 if li == cur_line else 0.66)
			var words: Array = []
			for b in bs:
				if int(b.line) == li:
					words.append(b)
			var total := 0.0
			for b in words:
				total += f.get_string_size(str(b.w) + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			var x := (w - total) / 2.0
			for b in words:
				var txt := str(b.w) + " "
				var dt := el - float(b.t)
				var col := Color(1, 1, 1, 0.55 if li != cur_line else 0.9)
				if li == cur_line and dt >= -0.05:
					col = Color("#facc15")
				var sz := 28 if li == cur_line else 22
				draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
				if li == cur_line and absf(dt) < 0.6:
					var bw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
					var bounce := absf(sin(clampf(dt + 0.6, 0.0, 1.2) / 1.2 * PI)) * 30.0
					if dt < 0.0:
						draw_circle(Vector2(x + bw / 2.0 - 6, y - 34 - bounce), 7, Color("#f472b6"))
				x += f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(f, Vector2(0, h - 20), "Top heceye düştüğü an BOŞLUK'a bas!", HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color("#c4b5fd"))


func _ready() -> void:
	build("Sinema", Vector2(980, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	screen = Screen.new()
	screen.clip_contents = true
	screen.custom_minimum_size = Vector2(640, 380)
	h.add_child(screen)
	side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.add_theme_constant_override("separation", 6)
	h.add_child(side)
	status = add_label(side, "", 15, Color("#facc15"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy_button(side, Cinema.TICKET, Cinema.buy_ticket, 0, "Bilet al")
	buy_button(side, Cinema.POPCORN, Cinema.buy_popcorn, 0, "Patlamış mısır (+%d enerji)" % Cinema.POPCORN_ENERGY)
	var rr := HBoxContainer.new()
	side.add_child(rr)
	for k in Cinema.REACTIONS:
		add_button(rr, {"alkis": "Alkış", "kahkaha": "Güldüm", "ciglik": "Korktum", "vay": "Vay"}[k], Cinema.react.bind(k))
	viewers_label = add_label(side, "", 13, Color("#94a3b8"))
	viewers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(HSeparator.new())
	add_label(side, "KARAOKE", 16, Color("#f0abfc"))
	kara_box = VBoxContainer.new()
	side.add_child(kara_box)
	Cinema.changed.connect(_refresh)
	Cinema.reaction.connect(_on_reaction)
	Cinema.karaoke_result.connect(_on_result)
	Net.roster_changed.connect(_refresh)
	Cinema.watch(true)
	_refresh()


func _exit_tree() -> void:
	Cinema.watch(false)
	if not Cinema.karaoke.is_empty():
		Cinema.karaoke_finish(_hits)


func _refresh() -> void:
	var s := Cinema.session_at(Land.server_now())
	var film: Dictionary = Cinema.FILMS[int(s.film)]
	if s.playing:
		status.text = "Şimdi: %s (%d sn kaldı)%s" % [film.name, int(Cinema.FILM_LEN - float(s.t)), "\nBiletin var ✓" if Cinema.has_ticket(int(s.n)) else ""]
	else:
		status.text = "Ara. Sıradaki: %s (%d sn)%s" % [Cinema.FILMS[(int(s.film) + 1) % Cinema.FILMS.size()].name, int(s.left),
			"\nBiletin var ✓" if Cinema.has_ticket(int(s.n) + 1) else ""]
	viewers_label.text = "Salonda: %s\nİzlediğin film: %d" % [", ".join(Cinema.viewers) if not Cinema.viewers.is_empty() else "-", int(Cinema.my.get("films", 0))]
	for c in kara_box.get_children():
		c.queue_free()
	if not Cinema.karaoke.is_empty():
		add_label(kara_box, "Söylüyorsun... (BOŞLUK)", 14, Color("#f0abfc"))
		add_button(kara_box, "Bitir", func(): Cinema.karaoke_finish(_hits))
	else:
		for i in Cinema.SONGS.size():
			add_button(kara_box, "♪ %s" % Cinema.SONGS[i].name, _start_karaoke.bind(i))
	var kb: Dictionary = Cinema.kara_best
	add_label(kara_box, "Günün rekoru: %s" % ("%d (%s)" % [int(kb.best), kb.by] if int(kb.get("best", 0)) > 0 else "-"), 13, Color("#94a3b8"))
	if not _result.is_empty():
		add_label(kara_box, "Puanın: %d / %d  (tam %d, iyi %d, kaçan %d)%s" % [int(_result.score), int(_result.max), int(_result.perfect), int(_result.good), int(_result.miss),
			"  +%s" % U.money(int(_result.money)) if int(_result.money) > 0 else ""], 13, Color("#fde68a")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _start_karaoke(i: int) -> void:
	_hits = []
	_played = {}
	_result = {}
	Cinema.karaoke_start(i)


func _on_reaction(d: Dictionary) -> void:
	screen.reacts.append({"text": Cinema.REACTIONS.get(str(d.k), "!"), "who": str(d.who), "t0": Time.get_ticks_msec() / 1000.0, "x": randf_range(0.2, 0.8)})


func _on_result(d: Dictionary) -> void:
	_result = d
	_refresh()


func _input(e: InputEvent) -> void:
	if Cinema.karaoke.is_empty():
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_SPACE:
		var el := Time.get_ticks_msec() / 1000.0 - float(Cinema.karaoke.t0)
		_hits.append(snappedf(el, 0.001))
		# en yakın hecenin notasını çal
		var best = null
		var bd := 1e9
		for b in Cinema.karaoke.beats:
			var dd := absf(float(b.t) - el)
			if dd < bd:
				bd = dd
				best = b
		if best != null and bd < Cinema.HIT_GOOD:
			Sfx.play("piyano", -4.0, pow(2.0, float(best.note) / 12.0))
		else:
			Sfx.play("piyano", -10.0, 0.5)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not Cinema.karaoke.is_empty():
		var el := Time.get_ticks_msec() / 1000.0 - float(Cinema.karaoke.t0)
		if el > Cinema.song_length(int(Cinema.karaoke.song)):
			Cinema.karaoke_finish(_hits)
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		_refresh()
