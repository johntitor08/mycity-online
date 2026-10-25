extends Control
## Harita çizimi: HUD köşesindeki mini harita ve M ile açılan büyük harita aynı sınıfı kullanır.
## Binalar, arsalar, oyuncular, görev NPC'leri, etkinlik alanı, yarış hedefi ve navigasyon hedefi.

signal picked(world_pos: Vector2)

const Map = preload("res://scripts/map.gd")

var world: Node2D                  # dünya sahnesi (oyuncu konumu, hedef)
var big := false                   # büyük harita: etiketler + tıklayınca hedef
var _acc := 0.0
var font: Font

const BUILDING_COLORS := {"hospital": "#ef4444", "market": "#22c55e", "casino": "#a855f7", "poker": "#15803d",
	"realestate": "#3b82f6", "galeri": "#64748b", "pazar": "#f97316", "mobilya": "#a16207", "petshop": "#14b8a6",
	"muhtarlik": "#b91c1c", "karakol": "#1e3a8a", "banka": "#e7e5e4", "carsi": "#9a3412", "fabrika": "#64748b"}


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = MOUSE_FILTER_STOP if big else MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= (0.1 if big else 0.25):
		_acc = 0.0
		queue_redraw()


func _k() -> float:
	return minf(size.x / Map.WORLD.size.x, size.y / Map.WORLD.size.y)


func to_map(p: Vector2) -> Vector2:
	return p * _k()


func to_world(m: Vector2) -> Vector2:
	return m / _k()


func _gui_input(e: InputEvent) -> void:
	if big and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(to_world(e.position))
		accept_event()


func _rect(r: Rect2, c: Color, filled: bool = true) -> void:
	draw_rect(Rect2(to_map(r.position), r.size * _k()), c, filled, -1.0 if filled else 1.0)


func _ellipse(r: Rect2, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(to_map(r.get_center() + Vector2(cos(a), sin(a)) * r.size / 2.0))
	draw_colored_polygon(pts, c)


func _draw() -> void:
	var k := _k()
	var full := Rect2(Vector2.ZERO, Map.WORLD.size * k)
	draw_rect(full.grow(2), Color(0, 0, 0, 0.6))
	draw_rect(full, Color("#5d9c4a") if Env.season != "winter" else Color("#d6e2e6"))
	_rect(Map.BEACH, Color("#f0dba5"))
	_rect(Map.SEA, Color("#1f78b8"))
	_rect(Rect2(0, Map.DEEP_Y, Map.WORLD.size.x, Map.WORLD.end.y - Map.DEEP_Y), Color("#165d94"))
	_ellipse(Map.ISLAND, Color("#f0dba5"))
	_rect(Rect2(0, Map.SOUTH_COAST_Y, Map.WORLD.size.x, Map.WORLD.end.y - Map.SOUTH_COAST_Y), Color("#a8a29e"))
	_rect(Map.CONTAINER_YARD, Color("#b45309"))
	_rect(Map.PORT_ROAD, Color("#3f4148"))
	_rect(Map.PORT_PIER, Color("#78716c"))
	_rect(Map.FERRY_PIER, Color("#78716c"))
	_ellipse(Map.LAKE, Color("#2f7fc1"))
	_rect(Map.RIVER, Color("#2f7fc1"))
	_rect(Map.PARK, Color("#4d7c0f"))
	_rect(Map.FIRE_STATION, Color("#b91c1c"))
	for r in Map.ROADS:
		_rect(r, Color("#3f4148"))
	_rect(Map.PIER, Color("#a0703c"))
	_rect(Map.ISLAND_PIER, Color("#a0703c"))
	_rect(Map.DOCK, Color("#a0703c"))
	for i in mini(Land.view.size(), Map.PLOT_COUNT):
		var p: Dictionary = Land.view[i]
		var c := Color("#b8a06a")
		if p.owner == Net.my_name:
			c = Color("#4ade80")
		elif p.owner != "":
			c = Color("#86a35f")
		_rect(Map.plot_rect(i).grow(-6), c)
	_rect(Football.FIELD, Color("#65a30d"))
	for b in Map.BUILDINGS:
		_rect(b.rect, Color(BUILDING_COLORS.get(b.type, "#e5e7eb")))
		_rect(b.rect, Color(0, 0, 0, 0.5), false)
		if big:
			var c := to_map(b.rect.get_center())
			draw_string_outline(font, c + Vector2(-60, 4), b.label, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 4, Color(0, 0, 0, 0.8))
			draw_string(font, c + Vector2(-60, 4), b.label, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color.WHITE)
	if big:
		for t in [[Map.FERRY_PIER.get_center(), "Feribot"], [Map.CONTAINER_YARD.get_center(), "Liman"],
				[Map.DOCK.get_center(), "Göl İskelesi"], [Map.PIER_END.get_center(), "Deniz İskelesi"], [Map.ISLAND.get_center(), "Martı Adası"],
				[Football.FIELD.get_center(), "Plaj Sahası"], [Map.RACE_FLAG, "Yarış Pisti"], [Langirt.POS, "Langırt"]]:
			var c := to_map(t[0])
			draw_string_outline(font, c + Vector2(-60, 4), t[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, 4, Color(0, 0, 0, 0.8))
			draw_string(font, c + Vector2(-60, 4), t[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color("#fde68a"))
	# etkinlik alanı ve yarış hedefi
	var cur := Events.current
	if cur.get("kind", "") == "treasure" and cur.has("area"):
		draw_arc(to_map(cur.area), float(cur.area_r) * k, 0, TAU, 24, Color("#facc15"), 1.5)
	if str(Events.race.get("state", "")) == "running":
		draw_circle(to_map(Map.RACE_CPS[int(Events.race.get("next", 0))]), 4, Color("#facc15"))
	for sk in Map.BUS_STOPS:
		draw_circle(to_map(Map.BUS_STOPS[sk][1]), 2.5 if not big else 4.0, Color("#facc15"))
		if big:
			draw_string(font, to_map(Map.BUS_STOPS[sk][1]) + Vector2(5, 4), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#facc15"))
	for f in Work.fires:
		draw_circle(to_map(Vector2(float(f.x), float(f.y))), 4.0 if not big else 6.0, Color("#f97316") if int(_acc * 10) % 2 == 0 else Color("#ef4444"))
	# görev NPC'leri
	for n in Map.NPCS:
		var m := Story.marker(n)
		if m != "":
			draw_circle(to_map(Map.NPCS[n].pos), 3.5 if not big else 5.0, Color("#facc15") if m == "!" else Color("#4ade80"))
	# diğer oyuncular
	for id in Net.pos_view:
		if id == Net.my_id() or not Net.roster.has(id):
			continue
		var pp: Vector2 = Net.pos_view[id]
		if Map.WORLD.has_point(pp):
			draw_circle(to_map(pp), 2.5 if not big else 4.0, Color(Net.roster[id].get("color", Color.WHITE)))
	# navigasyon hedefi
	if world and world.nav_target != null:
		var t := to_map(world.nav_target)
		draw_line(t, t + Vector2(0, -10), Color("#ef4444"), 2)
		draw_colored_polygon(PackedVector2Array([t + Vector2(0, -10), t + Vector2(8, -7), t + Vector2(0, -4)]), Color("#ef4444"))
	# ben
	if world and Map.WORLD.has_point(world.my_pos):
		var me := to_map(world.my_pos)
		draw_circle(me, 4.5 if not big else 6.0, Color.WHITE)
		draw_circle(me, 2.5 if not big else 3.5, Color("#2563eb"))
	if not big:
		draw_rect(full, Color(1, 1, 1, 0.5), false, 1.0)
