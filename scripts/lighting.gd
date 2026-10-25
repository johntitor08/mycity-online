extends Node2D
## Gün/gece ışıklandırması: CanvasModulate ile karartma; sokak lambaları, bina kapıları,
## ev içi tavan ışıkları ve lambaderler (PointLight2D); gece oyuncunun etrafında hafif ışık.

const Map = preload("res://scripts/map.gd")

var canvas_mod: CanvasModulate
var street: Array = []              # sabit ışıklar (lamba + bina)
var rooms: Array = []               # ev içi ışıkları (arsalar değişince yeniden kurulur)
var player_light: PointLight2D
var fire_lights: Array = []         # 1.3: kamp ateşleri (yanınca)
var mountain_lights: Array = []     # dağ evi ve teleferik istasyonu
var _tex: Texture2D


func _ready() -> void:
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_tex = _make_texture()
	for p in Map.lamp_positions():
		street.append(_light(p + Vector2(0, -20), Color("#ffd58a"), 0.85, 0.75))
	for b in Map.BUILDINGS:
		street.append(_light(Vector2(b.rect.get_center().x, b.rect.end.y - 6), Color("#ffcf8a"), 1.1, 0.65))
	for p in [Map.DOCK.get_center(), Map.PIER_END.get_center()]:
		street.append(_light(p, Color("#ffe2a8"), 0.9, 0.7))
	player_light = _light(Vector2.ZERO, Color("#fff4dc"), 0.7, 0.45)
	for f in Map.CAMPFIRES:
		fire_lights.append(_light(f + Vector2(0, -10), Color("#ff9a3c"), 1.6, 1.2))
	for p in [Map.FERRIS, Map.GALLERY, Map.TICKET_BOOTH, Map.CANDY, Map.BUMPER.get_center(), Map.SHUTTLE_FAIR, Map.BALLOON_FIELD]:
		mountain_lights.append(_light(p, Color("#ffd1f0"), 1.6, 0.8))
	for b in Map.FAIR_BUILDINGS:
		mountain_lights.append(_light(Vector2(b.rect.get_center().x, b.rect.end.y - 6), Color("#ffcf8a"), 1.3, 0.7))
	for b in Map.MOUNTAIN_BUILDINGS:
		mountain_lights.append(_light(Vector2(b.rect.get_center().x, b.rect.end.y - 6), Color("#ffcf8a"), 1.1, 0.7))
	Land.plots_changed.connect(_rebuild_rooms)
	_rebuild_rooms()


func _make_texture() -> Texture2D:
	var g := Gradient.new()
	# merkezde parlak, kenarlara doğru hızla sönen ışık
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.55))
	g.add_point(0.65, Color(1, 1, 1, 0.12))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _light(pos: Vector2, col: Color, scale: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _tex
	l.texture_scale = scale
	l.color = col
	l.energy = energy
	l.position = pos
	l.set_meta("base", energy)
	add_child(l)
	return l


func _rebuild_rooms() -> void:
	for l in rooms:
		l.queue_free()
	rooms.clear()
	for i in Land.view.size():
		var p: Dictionary = Land.view[i]
		if int(p.level) < 1:
			continue
		var r := Map.interior_rect(i, int(p.level))
		rooms.append(_light(r.get_center(), Color("#fff1d0"), r.size.x / 260.0, 0.5))
		for f in p.get("furniture", []):
			if f.k == "lamp":
				var fr := Homes.furniture_rect(i, int(p.level), f)
				rooms.append(_light(fr.get_center(), Color("#ffd27a"), 1.0, 0.8))


func update(player_pos: Vector2) -> void:
	var d := Env.darkness()
	var inside := Map.interior_at(player_pos) >= 0
	if Map.SEA_BED.has_point(player_pos):
		canvas_mod.color = Color(0.55, 0.8, 1.0).lerp(Color(0.2, 0.3, 0.5), d * 0.7)
		for l in street:
			l.visible = false
		player_light.visible = false
		return
	var c: Color
	if inside:
		c = Color.WHITE.lerp(Color(0.5, 0.47, 0.58), d)       # odalar gece loş, ışıklar açık
	else:
		c = Color.WHITE.lerp(Color(0.14, 0.17, 0.33), d)
		match Env.weather:
			"cloudy":
				c *= Color(0.9, 0.9, 0.95)
			"rain":
				c *= Color(0.76, 0.79, 0.88)
			"storm":
				c *= Color(0.6, 0.62, 0.75)
			"fog":
				c *= Color(0.86, 0.88, 0.9)
	c.a = 1.0
	canvas_mod.color = c
	var lit := d > 0.2 or (Env.weather == "storm" and not inside)
	var strength := clampf(d * 1.3, 0.35, 1.0)
	for l in street:
		l.visible = lit
		l.energy = float(l.get_meta("base")) * strength
	for l in rooms:
		l.visible = d > 0.15
		l.energy = float(l.get_meta("base")) * strength
	player_light.position = player_pos
	player_light.visible = d > 0.5 and not inside
	var t := Time.get_ticks_msec() / 1000.0
	for i in fire_lights.size():
		var fl: PointLight2D = fire_lights[i]
		fl.visible = Camp.fire_left(i) > 0.0
		fl.energy = (0.6 + d * 0.9) * (0.9 + 0.1 * sin(t * 11.0 + i))     # titreşen ateş ışığı
		fl.texture_scale = 1.5 + 0.08 * sin(t * 7.0 + i * 2.0)
	for ml in mountain_lights:
		ml.visible = lit
		ml.energy = float(ml.get_meta("base")) * strength
