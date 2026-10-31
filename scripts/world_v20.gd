extends RefCounted
## 2.0 istemci: Batık Şehir ve denizaltı, belediye projeleri (şehirde yapılar), plaj festivali (sahne, DJ, dans,
## havai fişek, müzik), Aşçılık Akademisi ve mahalle muhtarlığı. world.gd'nin kancaları buraya gelir.

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")
const KitchenPanel = preload("res://scripts/ui/kitchen_panel.gd")
const AcademyPanel = preload("res://scripts/ui/academy_panel.gd")
const SubPanel = preload("res://scripts/ui/sub_panel.gd")
const ProjectsPanel = preload("res://scripts/ui/projects_panel.gd")
const MahallePanel = preload("res://scripts/ui/mahalle_panel.gd")
const FestivalPanel = preload("res://scripts/ui/festival_panel.gd")

var w: Node2D
var sparks: Array = []                # havai fişek parçacıkları {p, v, c, t0, life}
var _last_beat := -1
var _last_half := -1
var _tower_until := 0.0
var _tower_zoom := Vector2.ONE


func _init(world: Node2D) -> void:
	w = world
	Festival.fireworks.connect(_on_fireworks)
	Festival.changed.connect(func() -> void:
		if Festival.active() and str(Festival.st.get("dj", "")) == Net.my_name:
			w.hud.show_toast("Sahne senin! Vuruşta Boşluk, DROP anında E.", true)
			if w.panel == null:
				var p := FestivalPanel.new()
				p.mode = "dj"
				_panel(p))
	Projects.changed.connect(func() -> void:
		if is_instance_valid(w):              # oyundan çıkınca dünya silinmiş olabilir
			w._rebuild_blockers())


func _panel(p: Control) -> void:
	if w.panel != null:
		return
	w.panel = p
	p.closed.connect(w._close_panel)
	w.ui_layer.add_child(p)
	Sfx.play("open", -4.0)


# ------------------------------------------------------------------ hareket

func sub_mult() -> float:
	return Deep.MOTOR[int(Deep.my.get("motor_lv", 0))] / 2.4


func can_stand_deep(p: Vector2) -> bool:
	if w.my_ride() == "sub":
		return true
	return Deep.in_dome(p) >= 0          # yaya ancak hava kubbesinde


func bike_mult() -> float:
	return 1.15 if Projects.done("bisiklet") else 1.0


## F tuşu: Batık Şehir'de denizaltıdan in/bin.
func toggle_vehicle() -> bool:
	if not Map.DEEP.has_point(w.my_pos):
		return false
	Deep.toggle_sub()
	return true


# ------------------------------------------------------------------ bölgeler

func status_line() -> String:
	var parts: Array = []
	if Map.DEEP.has_point(w.my_pos):
		var mx: float = Deep.BATTERY[int(Deep.my.get("battery_lv", 0))]
		parts.append("Akü %d/%d sn%s" % [int(Deep.bat), int(mx), " — KUBBEYE DÖN!" if Deep.bat < 30.0 else ""])
		parts.append("Ansiklopedi %d/%d" % [Deep.my.get("found", []).size(), Deep.CREATURES.size()])
		if Deep.in_jelly(w.my_pos):
			parts.append("DENİZANASI TARLASI (akü 3 kat hızlı biter)")
	if Festival.active() and w.my_pos.distance_to(Map.FEST_STAGE.get_center()) < 900.0:
		var st: Dictionary = Festival.st
		parts.append("FESTİVAL · DJ %s · %s · coşku %d" % [st.get("dj", "-"), Festival.TRACKS[int(st.get("track", 0)) % Festival.TRACKS.size()].name, int(st.get("hype", 0))])
	return "  ·  ".join(parts)


func deep_zone() -> void:
	var me: Vector2 = w.my_pos
	var z := {}
	var di := Deep.in_dome(me)
	if di >= 0:
		var dm: Dictionary = Deep.DOMES[di]
		match str(dm.kind):
			"pazar":
				z = {"type": "v20", "do": "deep_sell", "label": "Deniz Pazarı — antik eserleri sat"}
			"tapinak":
				z = {"type": "v20", "do": "deep_book", "label": "Tapınak — deniz canlıları ansiklopedisi"}
			"sarj":
				z = {"type": "v20", "do": "deep_book", "label": "Şarj istasyonu (akü dolar) — ansiklopedi"}
	if me.distance_to(Map.DEEP_GATE) < 200.0:
		z = {"type": "v20", "do": "deep_up", "label": "Yüzeye çık (tersaneye dön)"}
	var ps := Deep.ruin_positions()
	for i in ps.size():
		if me.distance_to(ps[i]) < 100.0:
			var full: bool = Deep.loot_ready[i] if i < Deep.loot_ready.size() else true
			z = {"type": "v20", "do": "deep_loot", "i": i, "label": "Harabe sandığını aç" if full else "Boş sandık (sonra dolar)"}
	var t := Land.server_now()
	var found: Array = Deep.my.get("found", [])
	for k in Deep.CREATURES:
		if me.distance_to(Deep.creature_pos(k, t)) < Deep.SCAN_RANGE:
			z = {"type": "v20", "do": "deep_scan", "k": k, "label": "Tara: %s%s" % [Deep.CREATURES[k][0], " (biliniyor)" if k in found else " — YENİ!"]}
			break
	w.zone = z
	w._g_action = {}
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	if di >= 0:
		hint += ("\n" if hint != "" else "") + "[%s]  %s" % [Settings.key_name("vehicle"), "Denizaltıdan in" if w.my_ride() == "sub" else "Denizaltına bin"]
	w.hud.set_hint("" if w.panel != null else w.adv.decorate(hint))


func extra_zone(z: Dictionary) -> Dictionary:
	var me: Vector2 = w.my_pos
	if Map.TOWN.has_point(me):
		if (Map.ACADEMY.rect as Rect2).grow(40).has_point(me):
			z = {"type": "v20", "do": "academy", "label": "Aşçılık Akademisi — yarışma"}
		if (Map.MAHALLE_OFFICE.rect as Rect2).grow(40).has_point(me):
			z = {"type": "v20", "do": "mahalle", "label": "Mahalle Muhtarlığı — seçim ve pazar"}
		return z
	if w._room >= 0 or w._fair or w._mount:
		return z
	if me.distance_to(Map.PROJECT_BOARD) < 110.0:
		z = {"type": "v20", "do": "projects", "label": "Belediye proje panosu"}
	if me.distance_to(Map.SUB_DOCK) < 140.0:
		z = {"type": "v20", "do": "sub", "label": "Denizaltı tersanesi — Batık Şehir"}
	if Projects.done("kule") and me.distance_to(Map.PROJECT_SITES.kule) < 90.0:
		z = {"type": "v20", "do": "tower", "label": "Gözlem kulesi — dürbünle bak"}
	if Festival.active():
		if me.distance_to(Map.FEST_GATE) < 110.0:
			z = {"type": "v20", "do": "fest_ticket", "label": "Festival bilekliği (%s)" % U.money(Festival.TICKET) if not bool(Festival.st.get("ticket", false)) else "Bilekliğin var — dans pistine geç"}
		if me.distance_to(Map.DJ_BOOTH) < 130.0:
			z = {"type": "v20", "do": "fest_dj", "label": "DJ kabini — sıraya gir (%d kişi bekliyor)" % Festival.st.get("queue", []).size()}
		if Map.DANCE_FLOOR.has_point(me):
			z = {"type": "v20", "do": "fest_dance", "label": "Dans et (ok tuşları)" if bool(Festival.st.get("ticket", false)) else "Dans için gişeden bileklik al"}
	return z


func open(z: Dictionary) -> bool:
	if str(z.get("type", "")) != "v20":
		return false
	match str(z.get("do", "")):
		"academy":
			_panel(AcademyPanel.new())
		"mahalle":
			_panel(MahallePanel.new())
		"projects":
			_panel(ProjectsPanel.new())
		"sub":
			_panel(SubPanel.new())
		"tower":
			_tower_zoom = w.camera.zoom
			w.camera.zoom = Vector2(0.35, 0.35)
			_tower_until = Time.get_ticks_msec() / 1000.0 + 12.0
			w.hud.show_toast("Dürbünle şehri seyrediyorsun...", true)
		"fest_ticket":
			Festival.buy_ticket()
		"fest_dj":
			Festival.dj_join()
		"fest_dance":
			if bool(Festival.st.get("ticket", false)):
				var p := FestivalPanel.new()
				p.mode = "dance"
				_panel(p)
		"deep_up":
			Deep.surface()
		"deep_loot":
			Deep.loot(int(z.i))
			Sfx.play("open", -4.0, 0.8)
		"deep_scan":
			Deep.scan(str(z.k))
			Sfx.play("coin", -4.0, 1.6)
		"deep_sell":
			Deep.sell()
		"deep_book":
			var sp := SubPanel.new()
			sp.mode = "book"
			_panel(sp)
	return true


func tick(_delta: float) -> void:
	if _tower_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _tower_until:
		_tower_until = 0.0
		w.camera.zoom = _tower_zoom
	_festival_music()
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(sparks.size() - 1, -1, -1):
		if now - float(sparks[i].t0) > float(sparks[i].life):
			sparks.remove_at(i)


## Festival müziği: sunucu saatine göre vuruşlar (davul ve piyano örnekleri).
func _festival_music() -> void:
	if not Festival.active() or w.my_pos.distance_to(Map.FEST_STAGE.get_center()) > 1400.0 or not Map.WORLD.has_point(w.my_pos):
		return
	var bp := Festival.beat_pos()
	if bp < 0.0:
		return
	var vol: float = -6.0 - w.my_pos.distance_to(Map.FEST_STAGE.get_center()) / 90.0
	var beat := int(floor(bp))
	var half := int(floor(bp * 2.0))
	if beat != _last_beat:
		_last_beat = beat
		Sfx.play("davul_0", vol, 0.9)
		if beat % 4 == 1 or beat % 4 == 3:
			Sfx.play("davul_1", vol - 2.0)
		var tr: Dictionary = Festival.TRACKS[int(Festival.st.get("track", 0)) % Festival.TRACKS.size()]
		var scale := [0, 2, 4, 7, 9, 12, 9, 7]
		var n := int(scale[absi(hash(beat / 2 + int(Festival.st.get("t0", 0)))) % scale.size()]) + int(tr.key)
		if beat % 2 == 0:
			Sfx.play("piyano", vol - 3.0, pow(2.0, n / 12.0) * 0.8)
	elif half != _last_half and half % 2 == 1:
		Sfx.play("davul_2", vol - 6.0, 1.2)
	_last_half = half


func _on_fireworks(d: Dictionary) -> void:
	var c := Map.FEST_STAGE.get_center() + Vector2(0, -120)
	var n := 8 if bool(d.get("big", false)) else 4
	var now := Time.get_ticks_msec() / 1000.0
	for k in n:
		var center := c + Vector2(randf_range(-400, 400), randf_range(-220, 40))
		var col := Color.from_hsv(randf(), 0.8, 1.0)
		for j in 28:
			var a := TAU * j / 28.0
			sparks.append({"p": center, "v": Vector2(cos(a), sin(a)) * randf_range(120, 220), "c": col, "t0": now + k * 0.35, "life": 1.6 + k * 0.35})
	Sfx.play("thunder", -10.0, 1.8)


func input(event: InputEvent) -> bool:
	if w.panel != null:
		return false
	return false


# ------------------------------------------------------------------ çizim: Batık Şehir

func draw_deep(view: Rect2, items: Array) -> void:
	w.draw_rect(view, Color("#04121f"))
	var d: Rect2 = Map.DEEP
	w.draw_rect(d, Color("#0b3b52"))
	var g := 110
	for gx in range(int(maxf(d.position.x, view.position.x) / g) * g, int(minf(d.end.x, view.end.x)), g):
		for gy in range(int(maxf(d.position.y, view.position.y) / g) * g, int(minf(d.end.y, view.end.y)), g):
			var h := absi((gx * 73856093) ^ (gy * 19349663))
			if h % 3 == 0:
				w.draw_circle(Vector2(gx + h % 90, gy + h % 70), 6 + h % 10, Color("#0e4a63"))
			if h % 7 == 0:
				var sp := Vector2(gx + h % 60, gy + h % 80)
				for k in 3:
					w.draw_line(sp + Vector2(k * 6 - 6, 0), sp + Vector2(k * 6 - 6 + sin(float(w._t) + k + h) * 6.0, -30 - k * 8), Color("#15803d"), 3)
			if h % 11 == 0:
				w.draw_circle(Vector2(gx + h % 40, gy + h % 90), 9, Color("#f472b6"))
				w.draw_circle(Vector2(gx + h % 40 + 10, gy + h % 90 - 6), 7, Color("#fb7185"))
	# harabeler: sütunlar ve yıkık duvarlar
	var ps := Deep.ruin_positions()
	for i in ps.size():
		var p: Vector2 = ps[i]
		if not view.grow(200).has_point(p):
			continue
		w.draw_rect(Rect2(p + Vector2(-90, 10), Vector2(180, 20)), Color("#7c8b8f"))
		for k in 3:
			var cx := p.x - 70 + k * 70
			var hgt := 80.0 + float((i * 7 + k * 13) % 50)
			w.draw_rect(Rect2(cx - 10, p.y + 10 - hgt, 20, hgt), Color("#9aa9ad"))
			w.draw_rect(Rect2(cx - 14, p.y + 10 - hgt - 8, 28, 8), Color("#b6c2c5"))
		var full: bool = Deep.loot_ready[i] if i < Deep.loot_ready.size() else true
		w._draw_ocean_chest(p + Vector2(0, 30), full)
	# hava kubbeleri
	for dm in Deep.DOMES:
		var c: Vector2 = dm.c
		var r: float = dm.r
		if not view.grow(r).has_point(c):
			continue
		w.draw_circle(c, r, Color(0.55, 0.8, 0.95, 0.25))
		w.draw_circle(c, r - 20, Color("#c9d6c3"))
		for k in 6:
			w.draw_line(c + Vector2.from_angle(k * PI / 3.0) * 30.0, c + Vector2.from_angle(k * PI / 3.0) * (r - 24), Color("#a3b18a"), 3)
		match str(dm.kind):
			"tapinak":
				w.draw_rect(Rect2(c + Vector2(-90, -70), Vector2(180, 90)), Color("#e7e5e4"))
				w.draw_colored_polygon(PackedVector2Array([c + Vector2(-110, -70), c + Vector2(110, -70), c + Vector2(0, -130)]), Color("#d6d3d1"))
				for k in 4:
					w.draw_rect(Rect2(c.x - 80 + k * 50, c.y - 64, 12, 80), Color("#a8a29e"))
			"sarj":
				w.draw_rect(Rect2(c + Vector2(-30, -60), Vector2(60, 80)), Color("#334155"))
				w.draw_rect(Rect2(c + Vector2(-20, -50), Vector2(40, 30)), Color(0.3, 1.0, 0.5, 0.6 + 0.3 * sin(float(w._t) * 3.0)))
			"pazar":
				for k in 3:
					var sp := c + Vector2(-110 + k * 110, -20)
					w.draw_rect(Rect2(sp + Vector2(-40, -30), Vector2(80, 50)), Color("#92400e"))
					w.draw_rect(Rect2(sp + Vector2(-44, -46), Vector2(88, 18)), [Color("#0ea5e9"), Color("#f59e0b"), Color("#22c55e")][k])
		w.draw_arc(c, r, 0, TAU, 64, Color(0.75, 0.92, 1.0, 0.8), 4)
		w._text(c + Vector2(-120, -r - 28), U.upper_tr(str(dm.name)), 16, Color("#bae6fd"), 240)
	# denizanası tarlaları
	for j in Deep.JELLY:
		var jc: Vector2 = j[0]
		if not view.grow(300).has_point(jc):
			continue
		for k in 9:
			var jp := jc + Vector2(cos(k * 1.7 + float(w._t) * 0.3), sin(k * 2.3 + float(w._t) * 0.25)) * float(j[1]) * 0.7
			items.append([jp.y, "jelly", jp])
	# iniş kapısı
	var gp: Vector2 = Map.DEEP_GATE
	w.draw_circle(gp, 80, Color("#475569"))
	w.draw_circle(gp, 60, Color("#0f172a"))
	for k in 3:
		w.draw_arc(gp, 70.0 + k * 10 + sin(float(w._t) * 2.0) * 4.0, 0, TAU, 32, Color(0.6, 0.85, 1.0, 0.4 - k * 0.1), 3)
	w._text(gp + Vector2(-100, -110), "YÜZEYE ÇIKIŞ", 16, Color("#bae6fd"), 200)
	# canlılar
	var t := Land.server_now()
	for k in Deep.CREATURES:
		var cp := Deep.creature_pos(k, t)
		if view.grow(200).has_point(cp):
			var nx := Deep.creature_pos(k, t + 0.2)
			items.append([cp.y, "creature", [k, cp, nx.x >= cp.x]])
	# kabarcıklar
	for k in 30:
		var bx := fposmod(k * 191.0, view.size.x)
		var by := fposmod(-float(w._t) * (30.0 + k % 5 * 10.0) + k * 97.0, view.size.y)
		w.draw_circle(view.position + Vector2(bx, by), 2.0 + k % 3, Color(0.8, 0.95, 1.0, 0.35))


func draw_item(kind: String, d) -> bool:
	match kind:
		"creature":
			_draw_creature(str(d[0]), d[1], bool(d[2]))
		"jelly":
			_draw_jelly(d)
		"crowd":
			_draw_dancer(d)
		_:
			return false
	return true


func _draw_jelly(p: Vector2) -> void:
	var t: float = w._t + p.x * 0.01
	w.draw_arc(p, 16, PI, TAU, 16, Color(0.85, 0.55, 1.0, 0.8), 6)
	w.draw_circle(p, 12, Color(0.85, 0.55, 1.0, 0.35))
	for k in 4:
		var x := -9.0 + k * 6.0
		w.draw_line(p + Vector2(x, 0), p + Vector2(x + sin(t * 3.0 + k) * 4.0, 22), Color(0.85, 0.6, 1.0, 0.6), 2)


func _draw_creature(k: String, p: Vector2, right: bool) -> void:
	var info: Array = Deep.CREATURES[k]
	var col := Color(str(info[1]))
	var s: float = info[2]
	var f := 1.0 if right else -1.0
	var t: float = w._t
	match k:
		"kalamar", "ahtapot", "murekkep":
			w.draw_set_transform(p, 0, Vector2(1, 1.2))
			w.draw_circle(Vector2(0, -s * 0.5), s * 0.6, col)
			w.draw_set_transform(Vector2.ZERO)
			for j in 6:
				var x := -s * 0.5 + j * s * 0.2
				w.draw_line(p + Vector2(x, 0), p + Vector2(x + sin(t * 3.0 + j) * s * 0.2, s * 0.9), col, 3 if k != "kalamar" else 6)
			w.draw_circle(p + Vector2(-s * 0.2, -s * 0.5), s * 0.1, Color.WHITE)
			w.draw_circle(p + Vector2(s * 0.2, -s * 0.5), s * 0.1, Color.WHITE)
		"denizanasi":
			_draw_jelly(p)
		"kaplumbaga":
			w.draw_set_transform(p, 0, Vector2(1.2, 0.8))
			w.draw_circle(Vector2.ZERO, s * 0.6, col)
			w.draw_circle(Vector2.ZERO, s * 0.45, col.darkened(0.2))
			w.draw_set_transform(Vector2.ZERO)
			w.draw_circle(p + Vector2(f * s * 0.8, 0), s * 0.22, Color("#86efac"))
			for sgn in [-1.0, 1.0]:
				w.draw_line(p + Vector2(f * s * 0.3, sgn * s * 0.4), p + Vector2(f * s * 0.5, sgn * s * (0.8 + 0.1 * sin(t * 2.0))), Color("#86efac"), 6)
		"vatoz":
			w.draw_colored_polygon(PackedVector2Array([p + Vector2(f * s, 0), p + Vector2(0, -s * (0.7 + 0.15 * sin(t * 2.0))), p + Vector2(-f * s * 0.6, 0),
				p + Vector2(0, s * (0.7 + 0.15 * sin(t * 2.0)))]), col)
			w.draw_line(p + Vector2(-f * s * 0.6, 0), p + Vector2(-f * s * 1.4, 0), col, 2)
		"denizati", "nautilus":
			w.draw_circle(p, s * 0.6, col)
			w.draw_arc(p, s * 0.4, 0, TAU * 0.8, 12, col.darkened(0.3), 2)
			w.draw_circle(p + Vector2(f * s * 0.4, -s * 0.5), s * 0.3, col)
		"yengec":
			w.draw_set_transform(p, 0, Vector2(1.3, 0.8))
			w.draw_circle(Vector2.ZERO, s * 0.5, col)
			w.draw_set_transform(Vector2.ZERO)
			for sgn in [-1.0, 1.0]:
				w.draw_circle(p + Vector2(sgn * s * 0.8, -s * 0.4), s * 0.22, col)
				for j in 3:
					w.draw_line(p + Vector2(sgn * s * 0.4, j * 4.0), p + Vector2(sgn * s * 0.9, s * 0.4 + j * 4.0), col, 2)
		"yilan":
			var pts := PackedVector2Array()
			for j in 10:
				pts.append(p + Vector2(-f * j * s * 0.25, sin(t * 4.0 + j * 0.7) * s * 0.2))
			w.draw_polyline(pts, col, 6)
			w.draw_circle(p, 6, col)
		_:
			# balık biçimi: gövde + kuyruk
			w.draw_set_transform(p, 0, Vector2(1.0, 0.55))
			w.draw_circle(Vector2.ZERO, s * 0.6, col)
			w.draw_set_transform(Vector2.ZERO)
			var tail := sin(t * 6.0) * s * 0.15
			w.draw_colored_polygon(PackedVector2Array([p + Vector2(-f * s * 0.5, 0), p + Vector2(-f * s * 1.0, -s * 0.35 + tail), p + Vector2(-f * s * 1.0, s * 0.35 + tail)]), col)
			w.draw_circle(p + Vector2(f * s * 0.35, -s * 0.08), maxf(2.0, s * 0.07), Color.WHITE)
			if k == "fener":
				w.draw_line(p + Vector2(f * s * 0.3, -s * 0.3), p + Vector2(f * s * 0.8, -s * 0.8), col, 2)
				w.draw_circle(p + Vector2(f * s * 0.8, -s * 0.8), 5, Color(1.0, 1.0, 0.6, 0.6 + 0.4 * sin(t * 5.0)))
			elif k == "cekic":
				w.draw_line(p + Vector2(f * s * 0.55, -s * 0.3), p + Vector2(f * s * 0.55, s * 0.3), col, 8)
			elif k == "kilic":
				w.draw_line(p + Vector2(f * s * 0.55, 0), p + Vector2(f * s * 1.4, 0), col.lightened(0.3), 3)
			elif k == "hayalet":
				w.draw_circle(p, s * 0.7, Color(0.9, 0.97, 1.0, 0.15))
	var found: Array = Deep.my.get("found", [])
	if w.my_pos.distance_to(p) < Deep.SCAN_RANGE + 40.0:
		w._text(p + Vector2(-90, -s - 26), str(info[0]) + ("" if k in found else " (?)"), 12, Color("#bae6fd") if k in found else Color("#fde68a"), 180)


# ------------------------------------------------------------------ çizim: şehir ve mahalle eklemeleri

func draw_ground() -> void:
	var view: Rect2 = w._view_rect().grow(250)
	if view.has_point(Map.SUB_DOCK):
		_draw_sub_dock(Map.SUB_DOCK)
	if view.has_point(Map.PROJECT_BOARD):
		_draw_board(Map.PROJECT_BOARD)
	_draw_projects(view)
	if view.intersects(Map.FEST_STAGE.grow(300)):
		_draw_festival()


## Mahalle çiziminin üstüne: akademi ve mahalle muhtarlığı.
func draw_town(view: Rect2) -> void:
	w.draw_rect(Map.TOWN_AVE2, Color("#374151"))
	for y in range(int(Map.TOWN_AVE2.position.y) + 20, int(Map.TOWN_AVE2.end.y), 80):
		w.draw_rect(Rect2(Map.TOWN_AVE2.get_center().x - 2, y, 4, 40), Color("#f8fafc"))
	for b in [Map.ACADEMY, Map.MAHALLE_OFFICE]:
		var r: Rect2 = b.rect
		if not view.intersects(r):
			continue
		w.draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.22))
		var akademi: bool = b.type == "akademi"
		w.draw_rect(r, Color("#fef3c7") if akademi else Color("#e0f2fe"))
		w.draw_rect(Rect2(r.position, Vector2(r.size.x, 46)), Color("#b91c1c") if akademi else Color("#1d4ed8"))
		for k in int(r.size.x / 90.0):
			w.draw_rect(Rect2(r.position.x + 24 + k * 90, r.position.y + 80, 50, 50), Color("#93c5fd"))
		w.draw_rect(Rect2(r.get_center().x - 34, r.end.y - 76, 68, 76), Color("#78350f"))
		if akademi:
			# aşçı şapkası tabelası
			var c := r.position + Vector2(r.size.x - 60, 26)
			w.draw_circle(c + Vector2(-10, -6), 12, Color.WHITE)
			w.draw_circle(c + Vector2(10, -6), 12, Color.WHITE)
			w.draw_circle(c + Vector2(0, -14), 13, Color.WHITE)
			w.draw_rect(Rect2(c + Vector2(-14, 0), Vector2(28, 12)), Color.WHITE)
		w._text(Vector2(r.position.x, r.position.y + 23.0 + 20 * 0.36), U.upper_tr(b.label), 20, Color.WHITE, r.size.x)


func _draw_sub_dock(p: Vector2) -> void:
	w.draw_rect(Rect2(p.x - 120, p.y - 120, 240, 90), Color("#334155"))
	w.draw_rect(Rect2(p.x - 120, p.y - 120, 240, 22), Color("#facc15"))
	w.draw_rect(Rect2(p.x - 40, p.y - 76, 80, 46), Color("#1e293b"))
	w._text(p + Vector2(-140, -160), "DENİZALTI TERSANESİ", 16, Color("#bae6fd"), 280)
	# iskeleye bağlı denizaltı
	var sp := p + Vector2(170, -60)
	w.draw_set_transform(sp, 0, Vector2(1, 0.6))
	w.draw_circle(Vector2.ZERO, 50, Color("#f59e0b"))
	w.draw_set_transform(Vector2.ZERO)
	w.draw_rect(Rect2(sp + Vector2(-14, -48), Vector2(28, 24)), Color("#d97706"))
	w.draw_line(sp + Vector2(0, -48), sp + Vector2(0, -66), Color("#475569"), 3)
	for k in 3:
		w.draw_circle(sp + Vector2(-26 + k * 26, 0), 7, Color("#7dd3fc"))


func _draw_board(p: Vector2) -> void:
	w.draw_rect(Rect2(p.x - 4, p.y - 10, 6, 40), Color("#78350f"))
	w.draw_rect(Rect2(p.x - 40, p.y - 70, 80, 60), Color("#a16207"))
	w.draw_rect(Rect2(p.x - 34, p.y - 64, 68, 48), Color("#fef3c7"))
	var cur: Dictionary = Projects.state.get("cur", {})
	if not cur.is_empty():
		w.draw_rect(Rect2(p.x - 28, p.y - 58, 56, 14), Color("#22c55e") if str(cur.get("phase", "")) != "oylama" else Color("#f59e0b"))
	w._text(p + Vector2(-80, -96), "PROJELER", 13, Color("#7c2d12"), 160, false)


func _draw_projects(view: Rect2) -> void:
	var done: Dictionary = Projects.state.get("done", {})
	var cur: Dictionary = Projects.state.get("cur", {})
	var building := str(cur.get("k", "")) if str(cur.get("phase", "")) == "insaat" else ""
	var t: float = w._t
	for k in Map.PROJECT_SITES:
		var p: Vector2 = Map.PROJECT_SITES[k]
		if not done.has(k) and k != building:
			continue
		if k == building:
			if view.has_point(p):
				w.draw_rect(Rect2(p.x - 60, p.y - 80, 120, 80), Color(0.95, 0.7, 0.2, 0.25))
				for j in 4:
					w.draw_line(Vector2(p.x - 60 + j * 40, p.y - 80), Vector2(p.x - 60 + j * 40, p.y), Color("#ca8a04"), 3)
				w.draw_line(Vector2(p.x - 60, p.y - 40), Vector2(p.x + 60, p.y - 40), Color("#ca8a04"), 3)
				w._text(p + Vector2(-90, -110), "İNŞAAT: %s" % Projects.PROJECTS[k].name, 13, Color("#fde68a"), 180)
			continue
		match k:
			"heykel":
				if view.has_point(p):
					w.draw_rect(Rect2(p.x - 30, p.y - 20, 60, 30), Color("#a8a29e"))
					w.draw_rect(Rect2(p.x - 36, p.y + 6, 72, 10), Color("#78716c"))
					w.draw_rect(Rect2(p.x - 18, p.y - 12, 36, 12), Color("#ca8a04"))         # isim plaketi
					var look: Dictionary = done.heykel.get("look", {})
					w.draw_set_transform(p + Vector2(0, -20), 0, Vector2(1.6, 1.6))
					Avatar.draw(w, Vector2.ZERO, look if not look.is_empty() else {"skin": 1}, "down", 0)
					w.draw_set_transform(Vector2.ZERO)
					w._text(p + Vector2(-90, 18), str(done.heykel.get("by", "")), 13, Color("#fde68a"), 180)
			"cicek":
				for j in 18:
					var fp := p + Vector2(-380 + j * 44, sin(j) * 6.0)
					if view.has_point(fp):
						w.draw_circle(fp, 9, Color("#16a34a"))
						w.draw_circle(fp + Vector2(0, -4), 5, [Color("#f472b6"), Color("#facc15"), Color("#f87171"), Color("#c084fc")][j % 4])
			"fiskiye":
				if view.has_point(p):
					for j in 12:
						var a := j * TAU / 12.0
						var u := fmod(t * 0.8 + j * 0.08, 1.0)
						var sp := p + Vector2(cos(a), sin(a) * 0.5) * 70.0 * u + Vector2(0, -sin(u * PI) * 90.0)
						w.draw_circle(sp, 4, Color(0.8, 0.95, 1.0, 0.8 - u * 0.5))
					w.draw_circle(p, 16, Color("#e2e8f0"))
					if Env.darkness() > 0.3:
						w.draw_circle(p + Vector2(0, -40), 60, Color(Color.from_hsv(fmod(t * 0.1, 1.0), 0.6, 1.0), 0.18))
			"led":
				pass                      # ışıklandırma (lighting.gd) güçlenir
			"bisiklet":
				for seg in [[Vector2(60, 470), Vector2(2740, 470)], [Vector2(1030, 470), Vector2(1030, 1540)], [Vector2(1060, 847), Vector2(2740, 847)]]:
					var a: Vector2 = seg[0]
					var b: Vector2 = seg[1]
					if not view.intersects(Rect2(a, Vector2.ZERO).expand(b).grow(20)):
						continue
					w.draw_line(a, b, Color(0.13, 0.7, 0.35, 0.55), 10)
					var n := int(a.distance_to(b) / 300.0)
					for j in n:
						var bp := a.lerp(b, (j + 0.5) / float(n))
						w.draw_circle(bp, 7, Color.WHITE)
						w.draw_circle(bp + Vector2(10, 0), 7, Color.WHITE)
			"plaj":
				if view.has_point(p):
					w.draw_line(p + Vector2(-80, 0), p + Vector2(80, 0), Color("#e5e7eb"), 2)
					for j in 9:
						w.draw_line(p + Vector2(-80 + j * 20, -26), p + Vector2(-80 + j * 20, 0), Color(1, 1, 1, 0.5), 1)
					w.draw_line(p + Vector2(-80, -26), p + Vector2(80, -26), Color.WHITE, 3)
					for j in 2:
						var sh := p + Vector2(-220 + j * 440, -40)
						w.draw_line(sh, sh + Vector2(0, -70), Color("#94a3b8"), 4)
						w.draw_circle(sh + Vector2(10, -70), 8, Color("#cbd5e1"))
						for q in 4:
							w.draw_line(sh + Vector2(10 + q * 3 - 4, -62), sh + Vector2(10 + q * 4 - 6, -20 - fmod(t * 60.0 + q * 9.0, 30.0)), Color(0.6, 0.85, 1.0, 0.6), 1)
			"kule":
				if view.has_point(p):
					w.draw_line(p + Vector2(-30, 0), p + Vector2(-16, -150), Color("#78350f"), 6)
					w.draw_line(p + Vector2(30, 0), p + Vector2(16, -150), Color("#78350f"), 6)
					for j in 4:
						w.draw_line(p + Vector2(-28 + j * 4, -j * 36), p + Vector2(28 - j * 4, -j * 36 - 30), Color("#92400e"), 3)
					w.draw_rect(Rect2(p.x - 34, p.y - 180, 68, 32), Color("#b45309"))
					w.draw_colored_polygon(PackedVector2Array([p + Vector2(-42, -180), p + Vector2(42, -180), p + Vector2(0, -212)]), Color("#7c2d12"))
					w._text(p + Vector2(-80, -240), "GÖZLEM KULESİ", 12, Color("#fde68a"), 160)


func _draw_festival() -> void:
	var s: Rect2 = Map.FEST_STAGE
	var on := Festival.active()
	var t: float = w._t
	var bp := Festival.beat_pos()
	var pulse := 0.0 if bp < 0.0 else 1.0 - fmod(bp, 1.0)
	# sahne
	w.draw_rect(Rect2(s.position + Vector2(8, 12), s.size), Color(0, 0, 0, 0.3))
	w.draw_rect(s, Color("#1f2937"))
	w.draw_rect(Rect2(s.position.x - 40, s.position.y - 70, 30, s.size.y + 70), Color("#111827"))
	w.draw_rect(Rect2(s.end.x + 10, s.position.y - 70, 30, s.size.y + 70), Color("#111827"))
	w.draw_rect(Rect2(s.position.x - 40, s.position.y - 90, s.size.x + 80, 24), Color("#374151"))
	for k in 6:
		var lc := Color.from_hsv(fmod(k * 0.17 + t * 0.2, 1.0), 0.8, 1.0)
		var lp := Vector2(s.position.x + 20 + k * (s.size.x - 40) / 5.0, s.position.y - 74)
		w.draw_circle(lp, 7, lc if on else Color("#4b5563"))
		if on:
			var tgt := Map.DANCE_FLOOR.get_center() + Vector2(sin(t * 1.3 + k) * 150.0, cos(t * 1.1 + k) * 30.0)
			w.draw_colored_polygon(PackedVector2Array([lp, tgt + Vector2(-40, 0), tgt + Vector2(40, 0)]), Color(lc, 0.12))
	for sgn in [0, 1]:
		var sx: float = s.position.x - 34 + sgn * (s.size.x + 50)
		for k in 3:
			w.draw_circle(Vector2(sx + 9, s.position.y - 40 + k * 34), 10 + pulse * 3.0, Color("#020617"))
			w.draw_circle(Vector2(sx + 9, s.position.y - 40 + k * 34), 4, Color("#475569"))
	# DJ masası
	var db: Vector2 = Map.DJ_BOOTH
	w.draw_rect(Rect2(db.x - 60, db.y - 30, 120, 30), Color("#4c1d95"))
	w.draw_circle(db + Vector2(-30, -16), 10, Color("#0f172a"))
	w.draw_circle(db + Vector2(30, -16), 10, Color("#0f172a"))
	w.draw_rect(Rect2(db.x - 6, db.y - 24, 12, 16), Color("#a78bfa"))
	w._text(s.position + Vector2(0, 8), "PLAJ FESTİVALİ" if on else "FESTİVAL SAHNESİ", 18, Color("#f0abfc") if on else Color("#9ca3af"), s.size.x)
	if on:
		var dj := str(Festival.st.get("dj", ""))
		w._text(s.position + Vector2(0, 30), "DJ %s" % dj if dj != "" else "", 14, Color("#fde68a"), s.size.x)
		# NPC DJ figürü
		if dj == Festival.NPC_DJ:
			Avatar.draw(w, db + Vector2(0, -26), {"skin": 2, "hair": 4, "hair_color": 6, "shirt": 7, "pants": 1}, "down", int(t * 4.0) % 2)
	# dans pisti
	var df: Rect2 = Map.DANCE_FLOOR
	var cells := 8
	for i in cells:
		for j in 3:
			var cell := Rect2(df.position + Vector2(i * df.size.x / cells, j * df.size.y / 3.0), Vector2(df.size.x / cells, df.size.y / 3.0))
			var hue := fmod(i * 0.13 + j * 0.31 + (floor(bp) * 0.17 if bp >= 0.0 else 0.0), 1.0)
			w.draw_rect(cell.grow(-2), Color.from_hsv(hue, 0.7, 0.9, 0.55 if on else 0.15))
	# gişe
	var gp: Vector2 = Map.FEST_GATE
	w.draw_rect(Rect2(gp.x - 30, gp.y - 50, 60, 50), Color("#db2777"))
	w.draw_rect(Rect2(gp.x - 36, gp.y - 60, 72, 14), Color("#fbcfe8"))
	w._text(gp + Vector2(-60, -88), "BİLEKLİK", 12, Color("#fbcfe8"), 120)


## Festival kalabalığı (NPC dansçılar) ve havai fişekler.
func add_items(items: Array) -> void:
	if not Festival.active():
		return
	var df: Rect2 = Map.DANCE_FLOOR
	for k in 10:
		var p := df.position + Vector2(20 + (k * 37) % int(df.size.x - 40), 18 + (k * 23) % int(df.size.y - 30))
		items.append([p.y, "v20", ["crowd", p, k]])


func draw_city_item(d: Array) -> void:
	if str(d[0]) == "crowd":
		_draw_dancer([d[1], d[2]])


func _draw_dancer(d: Array) -> void:
	var p: Vector2 = d[0]
	var k := int(d[1])
	var bp := Festival.beat_pos()
	var hop := absf(sin((bp if bp >= 0.0 else float(w._t)) * PI)) * 8.0
	var apps := [{"skin": 1, "hair": 2, "hair_color": 1, "shirt": 3, "pants": 2}, {"skin": 3, "hair": 0, "hair_color": 0, "shirt": 7, "pants": 1},
		{"skin": 0, "hair": 4, "hair_color": 3, "shirt": 1, "pants": 4}, {"skin": 2, "hair": 1, "hair_color": 5, "shirt": 9, "pants": 0}]
	Avatar.draw(w, p + Vector2(0, -hop), apps[k % apps.size()], ["down", "left", "right", "up"][(k + int(maxf(bp, 0.0))) % 4], int(maxf(bp, 0.0) * 2.0) % 2)
	if k % 3 == 0:
		w.draw_line(p + Vector2(-8, -42 - hop), p + Vector2(-16, -62 - hop), Color("#e8b48a"), 3)


func draw_overlay() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for s in sparks:
		var dt := now - float(s.t0)
		if dt < 0.0:
			# yükselen fişek
			var up: Vector2 = s.p + Vector2(0, 300.0 * (-dt))
			if dt > -0.35:
				w.draw_circle(up, 2.5, Color(1, 0.9, 0.6, 0.8))
			continue
		var p: Vector2 = s.p + (s.v as Vector2) * dt + Vector2(0, 60.0 * dt * dt)
		var a := clampf(1.0 - dt / 1.6, 0.0, 1.0)
		w.draw_circle(p, 3.0, Color(s.c, a))
		w.draw_line(p, p - (s.v as Vector2) * 0.05, Color(s.c, a * 0.5), 2)
