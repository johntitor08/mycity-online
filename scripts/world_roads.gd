extends RefCounted
## 2.1 istemci: otoyol (şeritler, trafik, tabelalar, dinlenme tesisi), Yalıkent ve Çamlıbel kasabaları,
## şehirdeki otoyol rampası ve otogar, şehirler arası otobüs yolculuğu. world.gd'nin kancaları buraya gelir.

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")
const OtogarPanel = preload("res://scripts/ui/otogar_panel.gd")

var w: Node2D


func _init(world: Node2D) -> void:
	w = world
	Roads.trip.connect(_on_bus_trip)


func _panel(p: Control) -> void:
	if w.panel != null:
		return
	w.panel = p
	p.closed.connect(w._close_panel)
	w.ui_layer.add_child(p)
	Sfx.play("open", -4.0)


## Kasabaların yürünmez binaları ve süs evleri.
static func town_blockers() -> Array:
	var out: Array = []
	for b in Map.YK_BUILDINGS + Map.CB_BUILDINGS:
		var r: Rect2 = b.rect
		out.append(Rect2(r.position.x + 6, r.position.y + 20, r.size.x - 12, r.size.y - 30))
	for h in deco_houses():
		out.append(Rect2(h[0].x - 70, h[0].y - 90, 140, 80))
	return out


## Süs evleri: [ayak noktası, renk indeksi]
static func deco_houses() -> Array:
	var out: Array = []
	for k in 11:
		out.append([Vector2(50250 + k * 300, 1240), k])        # Yalıkent ana caddenin kuzeyi
	for k in 5:
		out.append([Vector2(52250 + k * 260, 2850), k + 3])    # Yalıkent liman yolu
	for row in 2:                                            # Yalıkent mahalleleri (caddenin iki yanı)
		for k in 4:
			out.append([Vector2(50350 + k * 300, 2080 + row * 420), k + row * 4])
			out.append([Vector2(52000 + k * 330, 2080 + row * 420), k + row * 4 + 2])
	for k in 5:
		out.append([Vector2(55950 + k * 300, 1540), k + 1])    # Çamlıbel meydan
	for k in 4:
		out.append([Vector2(56000 + k * 320, 2960), k + 5])    # Çamlıbel alt yol
	return out


func can_stand(ext: String, p: Vector2) -> bool:
	var me: Vector2 = w.my_pos
	if ext == "otoyol":
		return Map.on_road(p)
	if ext == "yalikent" and p.y > Map.YK_SEA_Y and not Map.YK_PIER.has_point(p):
		return false
	for r: Rect2 in town_blockers():
		if r.has_point(p) and not r.has_point(me):
			return false
	return not (w._blocked(p) and not w._blocked(me))


# ------------------------------------------------------------------ bölgeler

func status_line() -> String:
	var me: Vector2 = w.my_pos
	if Map.HIGHWAY.has_point(me):
		var parts: Array = []
		for k in Map.HWY_RAMPS:
			var dx := float(Map.HWY_RAMPS[k]) - me.x
			parts.append("%s %s %.1f km" % [Map.TOWN_NAMES[k], "→" if dx > 0 else "←", absf(dx) / 1000.0])
		return "OTOYOL · " + " · ".join(parts)
	return ""


func update_zone(ext: String) -> void:
	var me: Vector2 = w.my_pos
	var z := {}
	if ext == "otoyol":
		var ex := Roads.exit_at(me)
		if ex != "":
			z = {"type": "roads", "do": "exit", "to": ex, "label": "ÇIKIŞ: %s" % Map.TOWN_NAMES[ex]}
		if Map.HWY_REST.grow(40).has_point(me):
			z = {"type": "roads", "do": "service", "k": "tesis", "label": "Dinlenme tesisi — çay ve simit (%s, +30 enerji)" % U.money(Roads.SERVICES.tesis.price)}
	else:
		for i in range(Map.CITY_PLOTS, Map.PLOT_COUNT):
			if Map.plot_rect(i).has_point(me):
				z = {"type": "realestate", "label": "Arsa #%d (%s)" % [i + 1, Map.TOWN_NAMES[ext]], "plot": i}
		var stop := Work.stop_near(me)
		if stop != "":
			z = {"type": "bus", "label": "Otobüs durağı — %s" % Map.BUS_STOPS[stop][0], "stop": stop}
		var sv := Roads.service_at(me)
		if sv != "":
			var s: Dictionary = Roads.SERVICES[sv]
			var lbl: String = {"hal": "Balık Hali — kovadaki balıkları %%%d fazlasına sat" % int((Roads.HAL_BONUS - 1.0) * 100),
				"kaplica": "Kaplıca (%s): enerji dolar, 15 dk maaş bonusu" % U.money(int(s.price)),
				"lokanta": "Yayla Lokantası: gözleme ve ayran (%s)" % U.money(int(s.price)),
				"kafe": "Martı Kafe: çay ve poğaça (%s)" % U.money(int(s.price))}.get(sv, s.name)
			z = {"type": "roads", "do": "service", "k": sv, "label": lbl}
			for b in Map.YK_BUILDINGS + Map.CB_BUILDINGS:
				if str(b.type) in Map.INST_TYPES and (b.rect as Rect2).grow(40).has_point(me):
					z = w.inside.enter_zone(str(b.type), str(b.label))     # 2.3: içeri girilir
		var spot := Map.fishing_spot(me)
		if spot != "":
			z = {"type": "fishing", "label": "Yalıkent İskelesi — Balık Tut", "spot": spot}
		z = extra_zone(z)
	w.zone = z
	w._g_action = {}
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	w.hud.set_hint("" if w.panel != null else w.adv.decorate(hint))


## Her yerde: otoyol rampası ve otogar (şehir dahil).
func extra_zone(z: Dictionary) -> Dictionary:
	var me: Vector2 = w.my_pos
	var ramp := Roads.ramp_at(me)
	if ramp != "":
		z = {"type": "roads", "do": "ramp", "label": "OTOYOLA ÇIK (arabayla) — Yalıkent, Çamlıbel%s" % (", Şehir" if ramp != "sehir" else "")}
	var og := Roads.otogar_at(me)
	if og != "":
		z = {"type": "roads", "do": "otogar", "here": og, "label": "Otogar — şehirler arası otobüs (%s)" % U.money(Roads.BUS_PRICE)}
	return z


func open(z: Dictionary) -> bool:
	if str(z.get("type", "")) != "roads":
		return false
	match str(z.get("do", "")):
		"ramp":
			if w.my_ride() != "car":
				w.hud.show_toast("Otoyola sadece arabayla çıkılır (F ile bin).", false)
			else:
				Roads.enter_highway()
				Sfx.play("engine", -4.0, 1.2)
		"exit":
			Roads.exit_highway(str(z.to))
		"otogar":
			var p := OtogarPanel.new()
			p.here = str(z.here)
			_panel(p)
		"service":
			Roads.use(str(z.k))
			Sfx.play("cash", -6.0)
	return true


func _on_bus_trip(d: Dictionary) -> void:
	if w.panel != null:
		w._close_panel()
	var layer := CanvasLayer.new()
	layer.layer = 6
	w.add_child(layer)
	var art := BusArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.to = str(d.get("to", ""))
	art.dest = str(d.get("name", ""))
	layer.add_child(art)
	Sfx.play("engine", -6.0, 0.7)
	var tw := w.create_tween()
	tw.tween_interval(float(d.get("time", 8.0)))
	tw.tween_property(art, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


## Otobüs penceresinden otoyol manzarası.
class BusArt extends Control:
	var to := ""
	var dest := ""
	var t0 := Time.get_ticks_msec() / 1000.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0 - t0
		var sw := size.x
		var sh := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("#93c5fd"))
		# uzak tepeler / dağlar
		var far := Color("#94a3b8") if to == "camlibel" else Color("#86b98a")
		var pts := PackedVector2Array([Vector2(0, sh)])
		for i in 41:
			var x := sw * i / 40.0
			var wx := x + t * 40.0
			var hh := 60.0 + 40.0 * sin(wx / 160.0) + 25.0 * sin(wx / 57.0)
			if to == "camlibel":
				hh *= 2.2
			pts.append(Vector2(x, sh * 0.55 - hh))
		pts.append(Vector2(sw, sh))
		draw_colored_polygon(pts, far)
		if to == "yalikent":
			draw_rect(Rect2(0, sh * 0.5, sw, sh * 0.12), Color("#38bdf8"))
			for k in 6:
				var bx := fposmod(k * 260.0 - t * 30.0, sw + 200.0) - 100.0
				draw_line(Vector2(bx, sh * 0.56), Vector2(bx + 40, sh * 0.56), Color(1, 1, 1, 0.6), 2)
		draw_rect(Rect2(0, sh * 0.62, sw, sh * 0.38), Color("#65a30d"))
		# yol ve şeritler
		draw_rect(Rect2(0, sh * 0.7, sw, sh * 0.12), Color("#374151"))
		for k in 12:
			var lx := fposmod(k * 160.0 - t * 700.0, sw + 160.0) - 80.0
			draw_rect(Rect2(lx, sh * 0.76, 70, 6), Color.WHITE)
		# ağaçlar ve direkler hızla geçer
		for k in 9:
			var tx := fposmod(sw - (t * 420.0 + k * 230.0), sw + 200.0) - 100.0
			if to == "camlibel":
				draw_colored_polygon(PackedVector2Array([Vector2(tx, sh * 0.66), Vector2(tx - 26, sh * 0.68), Vector2(tx, sh * 0.5), Vector2(tx + 26, sh * 0.68)]), Color("#14532d"))
			else:
				draw_circle(Vector2(tx, sh * 0.6), 26, Color("#15803d"))
				draw_rect(Rect2(tx - 4, sh * 0.6, 8, 30), Color("#78350f"))
		# otobüs penceresi çerçevesi
		var fr := Color("#1e3a8a")
		draw_rect(Rect2(0, 0, sw, 80), fr)
		draw_rect(Rect2(0, sh - 120, sw, 120), fr)
		draw_rect(Rect2(0, 0, 40, sh), fr)
		draw_rect(Rect2(sw - 40, 0, 40, sh), fr)
		for k in 3:
			draw_rect(Rect2(sw * (k + 1) / 4.0 - 10, 0, 20, sh), fr)
		draw_string(ThemeDB.fallback_font, Vector2(0, sh - 56), "Şehirler arası otobüs: %s" % dest, HORIZONTAL_ALIGNMENT_CENTER, sw, 28, Color("#fde68a"))


# ------------------------------------------------------------------ çizim: otoyol

func draw_highway(view: Rect2, items: Array) -> void:
	var hw: Rect2 = Map.HIGHWAY
	var t := Land.server_now()
	w.draw_rect(view, Color("#4d7c0f"))
	w.draw_rect(hw, Color("#65a30d"))
	var road: Rect2 = Map.HWY_ROAD
	# manzara: kuzeyde dağlar (Çamlıbel tarafında karlı), güneyde tarlalar ya da deniz (Yalıkent tarafı)
	var g := 160
	var x0 := int(floor(maxf(hw.position.x, view.position.x) / g)) * g
	var x1 := int(minf(hw.end.x, view.end.x))
	for gx in range(x0, x1, g):
		var h := absi(gx * 73856093)
		var top := hw.position.y + 20.0
		if gx > 63000:
			var mh := 120.0 + float(h % 60)
			w.draw_colored_polygon(PackedVector2Array([Vector2(gx - 120, road.position.y - 10), Vector2(gx + 10, road.position.y - 10 - mh), Vector2(gx + 140, road.position.y - 10)]), Color("#64748b"))
			w.draw_colored_polygon(PackedVector2Array([Vector2(gx - 18, road.position.y - mh * 0.8), Vector2(gx + 10, road.position.y - 10 - mh), Vector2(gx + 38, road.position.y - mh * 0.8)]), Color("#f1f5f9"))
		elif h % 3 == 0:
			w.draw_circle(Vector2(gx + h % 100, top + 60 + h % 80), 26, Color("#166534"))
			w.draw_rect(Rect2(gx + h % 100 - 4, top + 80 + h % 80, 8, 26), Color("#78350f"))
		var below := road.end.y + 20.0
		if gx > 55500 and gx < 61500:
			w.draw_rect(Rect2(gx, below + 40, g, hw.end.y - below - 40), Color("#0ea5e9"))
			w.draw_rect(Rect2(gx, below, g, 40), Color("#fde68a"))
			if h % 2 == 0:
				w.draw_line(Vector2(gx + h % 90, below + 100 + h % 60), Vector2(gx + h % 90 + 30, below + 100 + h % 60), Color(1, 1, 1, 0.5), 2)
		else:
			w.draw_rect(Rect2(gx, below, g - 6, hw.end.y - below), Color("#a3a948") if (gx / g) % 2 == 0 else Color("#84cc16"))
			for k in 4:
				w.draw_line(Vector2(gx + 6, below + 20 + k * 50), Vector2(gx + g - 12, below + 20 + k * 50), Color(0, 0, 0, 0.08), 3)
	# yol
	w.draw_rect(road.grow(8), Color("#9ca3af"))
	w.draw_rect(road, Color("#374151"))
	var lanes := [road.position.y + 60.0, road.position.y + 180.0]
	w.draw_rect(Rect2(x0, road.position.y + 118, x1 - x0, 4), Color("#facc15"))
	for ly in lanes:
		for x in range(int(floor(x0 / 80.0)) * 80, x1, 80):
			w.draw_rect(Rect2(x, ly - 2, 44, 4), Color.WHITE)
	w.draw_rect(Rect2(x0, road.position.y - 10, x1 - x0, 4), Color("#d1d5db"))
	w.draw_rect(Rect2(x0, road.end.y + 6, x1 - x0, 4), Color("#d1d5db"))
	# tabelalar
	for sx in range(int(hw.position.x) + 2200, int(hw.end.x), 2500):
		if not view.grow(200).has_point(Vector2(sx, road.position.y)):
			continue
		var sign_r := Rect2(sx - 130, road.position.y - 110, 260, 70)
		w.draw_rect(Rect2(sx - 4, road.position.y - 40, 8, 32), Color("#6b7280"))
		w.draw_rect(sign_r, Color("#15803d"))
		w.draw_rect(sign_r, Color.WHITE, false, 2)
		var parts: Array = []
		for k in Map.HWY_RAMPS:
			var dx := float(Map.HWY_RAMPS[k]) - sx
			if dx > 200.0:
				parts.append("%s %.0f km" % [Map.TOWN_NAMES[k], dx / 1000.0])
		_sign_text(sign_r, ("→ " + " · ".join(PackedStringArray(parts))) if not parts.is_empty() else "SON ÇIKIŞ", 13, Color.WHITE)
	# rampalar
	for k in Map.HWY_RAMPS:
		var rx := float(Map.HWY_RAMPS[k])
		if absf(rx - view.get_center().x) > view.size.x:
			continue
		w.draw_rect(Rect2(rx - 260, road.position.y, 520, road.size.y), Color(0.98, 0.8, 0.2, 0.12))
		var sr := Rect2(rx - 150, road.position.y - 120, 300, 80)
		w.draw_rect(sr, Color("#1d4ed8"))
		w.draw_rect(sr, Color.WHITE, false, 3)
		_sign_text(sr, "ÇIKIŞ: %s" % U.upper_tr(Map.TOWN_NAMES[k]), 22, Color.WHITE)
	# dinlenme tesisi
	var rs: Rect2 = Map.HWY_REST
	if view.intersects(rs.grow(100)):
		w.draw_rect(rs, Color("#4b5563"))
		for k in 6:
			w.draw_rect(Rect2(rs.position.x + 20 + k * 100, rs.position.y + 120, 4, 60), Color.WHITE)
		w.draw_rect(Rect2(rs.position.x + 40, rs.position.y + 20, 240, 90), Color("#f8fafc"))
		w.draw_rect(Rect2(rs.position.x + 40, rs.position.y + 20, 240, 20), Color("#dc2626"))
		w._text(Vector2(rs.position.x + 40, rs.position.y - 20), "DİNLENME TESİSİ", 14, Color("#fde68a"), 240)
		for k in 3:
			var pp := Vector2(rs.position.x + 360 + k * 80, rs.position.y + 60)
			w.draw_rect(Rect2(pp.x - 12, pp.y - 30, 24, 40), Color("#ef4444"))
			w.draw_rect(Rect2(pp.x - 8, pp.y - 24, 16, 10), Color("#fef3c7"))
	# trafik
	for k in 10:
		var east := k % 2 == 0
		var spd := 520.0 + float((k * 53) % 200)
		var span := hw.size.x
		var off := fposmod(float(k) * 2700.0 + (t * spd if east else -t * spd), span)
		var lane_y := (30.0 if k % 4 < 2 else 90.0) if east else (150.0 if k % 4 < 2 else 210.0)
		var cp := Vector2(hw.position.x + off, road.position.y + lane_y)
		if view.grow(150).has_point(cp):
			items.append([cp.y, "npccar", [cp, "right" if east else "left", Color.from_hsv(fmod(k * 0.23, 1.0), 0.6, 0.85)]])


# ------------------------------------------------------------------ çizim: kasabalar

func draw_town(ext: String, view: Rect2, items: Array) -> void:
	var r: Rect2 = Map.YALIKENT if ext == "yalikent" else Map.CAMLIBEL
	w.draw_rect(view, Color("#365314") if ext == "camlibel" else Color("#0284c7"))
	w.draw_rect(r, Color("#4d7c0f") if ext == "camlibel" else Color("#84cc16"))
	if ext == "yalikent":
		_draw_yalikent(view, items)
	else:
		_draw_camlibel(view, items)
	for rr: Rect2 in (Map.YK_ROADS if ext == "yalikent" else Map.CB_ROADS):
		_road(rr)
	for i in range(Map.CITY_PLOTS, Map.PLOT_COUNT):
		if view.intersects(Map.plot_rect(i).grow(100)):
			w._draw_plot(i)
	for b in (Map.YK_BUILDINGS if ext == "yalikent" else Map.CB_BUILDINGS):
		if view.intersects((b.rect as Rect2).grow(60)):
			items.append([(b.rect as Rect2).end.y, "tbuild", b])
	for h in deco_houses():
		if r.has_point(h[0]) and view.grow(150).has_point(h[0]):
			items.append([h[0].y, "thouse", h])
	for k in Map.BUS_STOPS:
		var sp: Vector2 = Map.BUS_STOPS[k][1]
		if r.has_point(sp) and view.has_point(sp):
			_bus_stop(sp, str(Map.BUS_STOPS[k][0]))
	var rp: Vector2 = Map.TOWN_RAMPS[ext]
	_ramp_sign(rp, ext == "camlibel")
	items.append([float(Map.OTOGARS[ext].y) + 2.0, "otogar", Map.OTOGARS[ext]])
	# kasaba halkı
	var tt: float = w._t
	var road: Rect2 = (Map.YK_ROADS if ext == "yalikent" else Map.CB_ROADS)[0]
	for k in 6:
		var px := r.position.x + fposmod(k * 610.0 + tt * (40.0 + k * 6.0) * (1 if k % 2 == 0 else -1), r.size.x)
		var pp := Vector2(px, road.end.y + 26.0 if k % 2 == 0 else road.position.y - 18.0)
		items.append([pp.y, "townnpc", [pp, k, "right" if k % 2 == 0 else "left"]])
	# yol trafiği
	for k in 3:
		var cx := road.position.x + fposmod(k * 1300.0 + tt * 260.0 * (1 if k % 2 == 0 else -1), road.size.x)
		var cp := Vector2(cx, road.position.y + (28.0 if k % 2 == 0 else 62.0))
		items.append([cp.y, "npccar", [cp, "right" if k % 2 == 0 else "left", Color.from_hsv(fmod(0.15 + k * 0.31, 1.0), 0.55, 0.9)]])


func _road(r: Rect2) -> void:
	w.draw_rect(r.grow(10), Color("#a8acb3"))
	w.draw_rect(r, Color("#3f4148"))
	if r.size.x > r.size.y:
		for x in range(int(r.position.x) + 20, int(r.end.x), 70):
			w.draw_rect(Rect2(x, r.get_center().y - 3, 34, 6), Color(1, 1, 1, 0.6))
	else:
		for y in range(int(r.position.y) + 20, int(r.end.y), 70):
			w.draw_rect(Rect2(r.get_center().x - 3, y, 6, 34), Color(1, 1, 1, 0.6))


func _bus_stop(p: Vector2, name: String) -> void:
	w.draw_rect(Rect2(p.x - 40, p.y - 40, 80, 8), Color("#1d4ed8"))
	w.draw_line(p + Vector2(-36, -32), p + Vector2(-36, 8), Color("#6b7280"), 3)
	w.draw_line(p + Vector2(36, -32), p + Vector2(36, 8), Color("#6b7280"), 3)
	w.draw_rect(Rect2(p.x - 30, p.y - 6, 60, 8), Color("#78350f"))
	w.draw_rect(Rect2(p.x + 44, p.y - 50, 26, 26), Color("#facc15"))
	w._text(p + Vector2(-80, -52), "DURAK: %s" % name, 11, Color.WHITE, 160)


func _ramp_sign(p: Vector2, flip: bool) -> void:
	var sx := p.x + (-60.0 if flip else 60.0)
	w.draw_rect(Rect2(sx - 4, p.y - 140, 8, 90), Color("#6b7280"))
	var sr := Rect2(sx - 90, p.y - 190, 180, 60)
	w.draw_rect(sr, Color("#1d4ed8"))
	w.draw_rect(sr, Color.WHITE, false, 2)
	_sign_text(Rect2(sr.position, Vector2(sr.size.x, 36)), "OTOYOL %s" % ("→" if not flip else "←"), 18, Color.WHITE)
	_sign_text(Rect2(sr.position + Vector2(0, 34), Vector2(sr.size.x, 22)), "Yalıkent · Çamlıbel · Şehir", 10, Color("#bfdbfe"))


func _otogar(p: Vector2) -> void:
	# levha: direk + turuncu tabela, yazı tabelanın tam ortasında
	w.draw_rect(Rect2(p.x - 3, p.y - 40, 6, 40), Color("#6b7280"))
	var sr := Rect2(p.x - 70, p.y - 74, 140, 34)
	w.draw_rect(sr, Color("#ea580c"))
	w.draw_rect(sr, Color.WHITE, false, 2)
	_sign_text(sr, "OTOGAR", 16, Color.WHITE)
	# bekleyen şehirler arası otobüs
	var bp := p + Vector2(130, 0)
	w.draw_rect(Rect2(bp.x - 70, bp.y - 26, 140, 44), Color("#e5e7eb"))
	w.draw_rect(Rect2(bp.x - 70, bp.y - 26, 140, 8), Color("#f97316"))
	for k in 5:
		w.draw_rect(Rect2(bp.x - 62 + k * 26, bp.y - 14, 20, 12), Color("#38bdf8"))
	w.draw_circle(bp + Vector2(-44, 20), 8, Color("#111827"))
	w.draw_circle(bp + Vector2(44, 20), 8, Color("#111827"))


## Yazıyı bir tabela kutusunun tam ortasına yaz (yatay ve dikey).
func _sign_text(box: Rect2, text: String, size: int, col: Color) -> void:
	var baseline := box.position.y + box.size.y / 2.0 + size * 0.36
	w._text(Vector2(box.position.x, baseline), text, size, col, box.size.x, false)


func _draw_yalikent(view: Rect2, items: Array) -> void:
	var r: Rect2 = Map.YALIKENT
	# kasaba zemini ve sahil
	w.draw_rect(Rect2(r.position.x, r.position.y + 260, r.size.x, Map.YK_SEA_Y - r.position.y - 340), Color("#d9cba3"))
	w.draw_rect(Rect2(r.position.x, Map.YK_SEA_Y - 80, r.size.x, 80), Color("#fde68a"))
	w.draw_rect(Rect2(r.position.x, Map.YK_SEA_Y, r.size.x, r.end.y - Map.YK_SEA_Y), Color("#0ea5e9"))
	var tt: float = w._t
	for k in 20:
		var wx := r.position.x + fposmod(k * 190.0 + tt * 12.0, r.size.x)
		var wy := Map.YK_SEA_Y + 40.0 + (k % 5) * 60.0
		w.draw_line(Vector2(wx, wy), Vector2(wx + 30, wy), Color(1, 1, 1, 0.5), 2)
	# iskele, tekneler, fener
	w.draw_rect(Map.YK_PIER, Color("#92400e"))
	for k in 6:
		w.draw_line(Vector2(Map.YK_PIER.position.x, Map.YK_PIER.position.y + k * 55), Vector2(Map.YK_PIER.end.x, Map.YK_PIER.position.y + k * 55), Color("#78350f"), 2)
	for k in 3:
		var bp := Vector2(52700 + k * 200, Map.YK_SEA_Y + 120 + sin(tt * 1.4 + k) * 3.0)
		w.draw_colored_polygon(PackedVector2Array([bp + Vector2(-50, 0), bp + Vector2(50, 0), bp + Vector2(36, 18), bp + Vector2(-36, 18)]), [Color("#ef4444"), Color("#f8fafc"), Color("#2563eb")][k])
		w.draw_line(bp, bp + Vector2(0, -50), Color("#78350f"), 3)
		w.draw_colored_polygon(PackedVector2Array([bp + Vector2(2, -48), bp + Vector2(30, -10), bp + Vector2(2, -10)]), Color("#f1f5f9"))
	var lh: Vector2 = Map.YK_LIGHTHOUSE
	if view.grow(200).has_point(lh):
		w.draw_circle(lh + Vector2(0, 10), 50, Color("#78716c"))
		w.draw_rect(Rect2(lh.x - 16, lh.y - 120, 32, 120), Color("#f8fafc"))
		for k in 3:
			w.draw_rect(Rect2(lh.x - 16, lh.y - 110 + k * 36, 32, 14), Color("#dc2626"))
		w.draw_circle(lh + Vector2(0, -130), 12, Color("#fde047"))
	# palmiyeler (sahil ve cadde boyu)
	for k in 8:
		var pp := Vector2(50200 + k * 440, Map.YK_SEA_Y - 40)
		items.append([pp.y, "palm", pp])
	for k in 6:
		items.append([1760.0 + k * 190.0, "palm", Vector2(51640, 1760 + k * 190)])
		items.append([1760.0 + k * 190.0, "palm", Vector2(51850, 1760 + k * 190)])
	# meydan: çeşme ve çiçekler (cadde ile liman arasında)
	var sq := Vector2(51450, 2290)
	w.draw_circle(sq, 120, Color("#e7e5e4"))
	w.draw_circle(sq, 60, Color("#a8a29e"))
	w.draw_circle(sq, 50, Color("#38bdf8"))
	for k in 3:
		var u := fmod(tt * 1.1 + k / 3.0, 1.0)
		w.draw_circle(sq + Vector2(0, -u * 30.0), 5.0 - u * 3.0, Color(1, 1, 1, 0.7 * (1.0 - u)))
	for k in 12:
		var fp := sq + Vector2.from_angle(k * TAU / 12.0) * 92.0
		w.draw_circle(fp, 7, [Color("#f472b6"), Color("#facc15"), Color("#f87171")][k % 3])
	# çim adacıkları
	for k in 14:
		var gp := Vector2(50150 + (k * 263) % 3300, 1800 + (k * 157) % 900)
		if not Map.on_road(gp, 80.0) and gp.distance_to(sq) > 200.0:
			w.draw_circle(gp, 46, Color("#a3c95a"))
	w._text(r.position + Vector2(0, 40), "YALIKENT", 40, Color("#0c4a6e"), r.size.x, false)


func _draw_camlibel(view: Rect2, items: Array) -> void:
	var r: Rect2 = Map.CAMLIBEL
	# kuzeyde karlı dağlar
	for k in 9:
		var mx := r.position.x + k * 450.0
		var mh := 260.0 + float((k * 97) % 160)
		w.draw_colored_polygon(PackedVector2Array([Vector2(mx - 260, r.position.y + 520), Vector2(mx, r.position.y + 520 - mh), Vector2(mx + 260, r.position.y + 520)]), Color("#64748b"))
		w.draw_colored_polygon(PackedVector2Array([Vector2(mx - 60, r.position.y + 520 - mh * 0.77), Vector2(mx, r.position.y + 520 - mh), Vector2(mx + 60, r.position.y + 520 - mh * 0.77)]), Color("#f1f5f9"))
	# gölet
	var pond := Rect2(54700, 2300, 700, 400)
	w.draw_set_transform(pond.get_center(), 0, Vector2(1, pond.size.y / pond.size.x))
	w.draw_circle(Vector2.ZERO, pond.size.x / 2.0, Color("#0ea5e9"))
	w.draw_set_transform(Vector2.ZERO)
	# kaplıca buharı
	var kp: Rect2 = Map.CB_BUILDINGS[0].rect
	for k in 5:
		var u := fmod(float(w._t) * 0.4 + k * 0.2, 1.0)
		w.draw_circle(Vector2(kp.get_center().x - 120 + k * 60, kp.position.y - u * 80.0), 14 + u * 16, Color(1, 1, 1, 0.35 * (1.0 - u)))
	# çam ağaçları
	var rng_seed := 4242
	for k in 90:
		var h := absi(hash(rng_seed + k * 31))
		var p := Vector2(r.position.x + 40 + h % int(r.size.x - 80), r.position.y + 560 + (h / 97) % int(r.size.y - 640))
		if Map.on_road(p, 60.0) or pond.grow(40).has_point(p):
			continue
		var bad := false
		for b in Map.CB_BUILDINGS:
			if (b.rect as Rect2).grow(70).has_point(p):
				bad = true
		for i in range(Map.CITY_PLOTS + 4, Map.PLOT_COUNT):
			if Map.plot_rect(i).grow(60).has_point(p):
				bad = true
		for hs in deco_houses():
			if (hs[0] as Vector2).distance_to(p) < 120.0:
				bad = true
		if not bad and view.grow(100).has_point(p):
			items.append([p.y, "pine", p])
	w._text(r.position + Vector2(0, 540), "ÇAMLIBEL", 40, Color("#f8fafc"), r.size.x, false)


func draw_item(kind: String, d) -> bool:
	match kind:
		"npccar":
			w._draw_vehicle(d[0], "car", str(d[1]), d[2])
		"townnpc":
			var apps := [{"skin": 1, "hair": 2, "hair_color": 1, "shirt": 3, "pants": 2}, {"skin": 3, "hair": 0, "hair_color": 0, "shirt": 7, "pants": 1},
				{"skin": 0, "hair": 4, "hair_color": 3, "shirt": 1, "pants": 4}, {"skin": 2, "hair": 1, "hair_color": 5, "shirt": 9, "pants": 0}]
			Avatar.draw(w, d[0], apps[int(d[1]) % apps.size()], str(d[2]), int(float(w._t) * 5.0 + int(d[1])) % 2)
		"palm":
			var p: Vector2 = d
			w.draw_line(p, p + Vector2(10, -90), Color("#92400e"), 8)
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.55
				w.draw_line(p + Vector2(10, -90), p + Vector2(10, -90) + Vector2.from_angle(a) * 50.0 + Vector2(0, 14), Color("#16a34a"), 7)
		"pine":
			var p2: Vector2 = d
			w.draw_set_transform(p2 + Vector2(4, 4), 0, Vector2(1, 0.4))
			w.draw_circle(Vector2.ZERO, 24, Color(0, 0, 0, 0.25))
			w.draw_set_transform(Vector2.ZERO)
			w.draw_rect(Rect2(p2.x - 5, p2.y - 20, 10, 22), Color("#78350f"))
			for k in 3:
				var y := p2.y - 20 - k * 26
				w.draw_colored_polygon(PackedVector2Array([Vector2(p2.x - 34 + k * 7, y), Vector2(p2.x + 34 - k * 7, y), Vector2(p2.x, y - 46)]), Color("#14532d").lightened(k * 0.06))
		"thouse":
			var hp: Vector2 = d[0]
			var cols := [Color("#fca5a5"), Color("#fde68a"), Color("#a5f3fc"), Color("#bbf7d0"), Color("#e9d5ff"), Color("#fed7aa"), Color("#fecdd3"), Color("#d9f99d"), Color("#bae6fd")]
			var c: Color = cols[int(d[1]) % cols.size()]
			var wood := Map.CAMLIBEL.has_point(hp)
			w.draw_rect(Rect2(hp.x - 64, hp.y - 84, 136, 92), Color(0, 0, 0, 0.2))
			w.draw_rect(Rect2(hp.x - 70, hp.y - 90, 140, 90), Color("#a16207") if wood else c)
			w.draw_colored_polygon(PackedVector2Array([Vector2(hp.x - 82, hp.y - 90), Vector2(hp.x + 82, hp.y - 90), Vector2(hp.x, hp.y - 140)]),
				Color("#7c2d12") if wood else Color("#b91c1c"))
			if wood:
				w.draw_colored_polygon(PackedVector2Array([Vector2(hp.x - 30, hp.y - 122), Vector2(hp.x + 30, hp.y - 122), Vector2(hp.x, hp.y - 140)]), Color("#f1f5f9"))
			w.draw_rect(Rect2(hp.x - 14, hp.y - 46, 28, 46), Color("#78350f"))
			w.draw_rect(Rect2(hp.x - 56, hp.y - 70, 28, 24), Color("#bfdbfe"))
			w.draw_rect(Rect2(hp.x + 28, hp.y - 70, 28, 24), Color("#bfdbfe"))
		"tbuild":
			_draw_town_building(d)
		"otogar":
			_otogar(d)
		_:
			return false
	return true


func _draw_town_building(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var t := str(b.type)
	var wall: Color = {"balikhali": Color("#e0f2fe"), "otogar_yk": Color("#fed7aa"), "yk_kafe": Color("#fef3c7"),
		"kaplica": Color("#ccfbf1"), "lokanta": Color("#d6b98c"), "otogar_cb": Color("#fed7aa")}.get(t, Color("#e5e7eb"))
	var roof: Color = {"balikhali": Color("#0369a1"), "otogar_yk": Color("#c2410c"), "yk_kafe": Color("#0ea5e9"),
		"kaplica": Color("#0f766e"), "lokanta": Color("#7c2d12"), "otogar_cb": Color("#c2410c")}.get(t, Color("#475569"))
	w.draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.22))
	w.draw_rect(r, wall)
	w.draw_rect(Rect2(r.position.x - 8, r.position.y, r.size.x + 16, 44), roof)
	for k in int(r.size.x / 90.0):
		w.draw_rect(Rect2(r.position.x + 24 + k * 90, r.position.y + 70, 46, 46), Color("#93c5fd"))
	w.draw_rect(Rect2(r.get_center().x - 30, r.end.y - 70, 60, 70), Color("#78350f"))
	if t == "balikhali":
		for k in 3:
			var fp := r.position + Vector2(60 + k * 60, r.size.y - 30)
			w.draw_set_transform(fp, 0, Vector2(1, 0.5))
			w.draw_circle(Vector2.ZERO, 16, Color("#94a3b8"))
			w.draw_set_transform(Vector2.ZERO)
	_sign_text(Rect2(r.position.x, r.position.y, r.size.x, 44), U.upper_tr(str(b.label)), 18, Color.WHITE)


## Şehirde (ana harita): batı ucundaki otoyol rampası ve otogar.
func draw_city_ground() -> void:
	var view: Rect2 = w._view_rect().grow(250)
	var rp: Vector2 = Map.TOWN_RAMPS.sehir
	if view.has_point(rp):
		_ramp_sign(rp + Vector2(40, -20), true)
	var og: Vector2 = Map.OTOGARS.sehir
	if view.has_point(og):
		_otogar(og)
