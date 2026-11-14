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
var _last_key := Vector4(-1, -1, -1, -1)
var _rooms_dirty := true


func _ready() -> void:
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_tex = _make_texture()
	# 2.5.1: sabit ışıklar bölge bölge tek bir "ışık haritası" dokusuna pişirilir (bkz. _bake_groups).
	var fixed: Array = []                    # [konum, renk, ölçek, enerji]
	for p in Map.lamp_positions():
		fixed.append([p + Vector2(0, -20), Color("#ffd58a"), 0.85, 0.75])
	for b in Map.BUILDINGS:
		fixed.append([Vector2(b.rect.get_center().x, b.rect.end.y - 6), Color("#ffcf8a"), 1.1, 0.65])
	for p in [Map.DOCK.get_center(), Map.PIER_END.get_center()]:
		fixed.append([p, Color("#ffe2a8"), 0.9, 0.7])
	street = _bake_groups(fixed)
	player_light = _light(Vector2.ZERO, Color("#fff4dc"), 0.7, 0.45)
	for f in Map.CAMPFIRES:
		fire_lights.append(_light(f + Vector2(0, -10), Color("#ff9a3c"), 1.6, 1.2))
	var fair: Array = []
	for p in [Map.FERRIS, Map.GALLERY, Map.TICKET_BOOTH, Map.CANDY, Map.BUMPER.get_center(), Map.SHUTTLE_FAIR, Map.BALLOON_FIELD]:
		fair.append([p, Color("#ffd1f0"), 1.6, 0.8])
	for b in Map.FAIR_BUILDINGS:
		fair.append([Vector2(b.rect.get_center().x, b.rect.end.y - 6), Color("#ffcf8a"), 1.3, 0.7])
	for b in Map.MOUNTAIN_BUILDINGS:
		fair.append([Vector2(b.rect.get_center().x, b.rect.end.y - 6), Color("#ffcf8a"), 1.1, 0.7])
	mountain_lights = _bake_groups(fair)
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


## 2.5.1: Aynı bölgedeki sabit ışıkları (lambalar, bina kapıları) tek bir PointLight2D'de toplar.
## Her ışık ekrandaki her piksele ayrı ayrı hesaplandığından gece 20 ışık yerine 1 ışık ≈ çok daha hafif ekran kartı yükü.
## Görünüm aynı: ışık dokusu = her lambanın renkli, yumuşak dairesi (1/4 çözünürlükte), enerji = taban enerji.
const BAKE_K := 4.0

func _bake_groups(list: Array) -> Array:
	var regions := [Map.WORLD, Map.TOWN, Map.YALIKENT, Map.CAMLIBEL, Map.HIGHWAY, Map.FAIR, Map.MOUNTAIN]
	var groups := {}
	var out: Array = []
	for e in list:
		var gi := -1
		for k in regions.size():
			if (regions[k] as Rect2).has_point(e[0]):
				gi = k
				break
		if gi < 0:
			out.append(_light(e[0], e[1], e[2], e[3]))
			continue
		if not groups.has(gi):
			groups[gi] = []
		groups[gi].append(e)
	for gi in groups:
		out.append(_bake(groups[gi]))
	return out


func _bake(entries: Array) -> PointLight2D:
	var bb := Rect2()
	for k in entries.size():
		var r: float = 128.0 * float(entries[k][2])
		var er := Rect2(entries[k][0] - Vector2(r, r), Vector2(r, r) * 2.0) as Rect2
		bb = er if k == 0 else bb.merge(er)
	var w := int(ceil(bb.size.x / BAKE_K)) + 2
	var h := int(ceil(bb.size.y / BAKE_K)) + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var stamps := {}
	for e in entries:
		var key := "%s|%.2f|%.2f" % [(e[1] as Color).to_html(), float(e[2]), float(e[3])]
		if not stamps.has(key):
			stamps[key] = _stamp(e[1], float(e[2]), float(e[3]))
		var st: Image = stamps[key]
		var at: Vector2 = ((e[0] - bb.position) / BAKE_K - Vector2(st.get_size()) / 2.0).round()
		img.blend_rect(st, Rect2i(Vector2i.ZERO, st.get_size()), Vector2i(at))
	var l := PointLight2D.new()
	l.texture = ImageTexture.create_from_image(img)
	l.texture_scale = BAKE_K
	l.color = Color.WHITE
	l.energy = 1.0
	l.position = bb.position + Vector2(w, h) * BAKE_K / 2.0
	l.set_meta("base", 1.0)
	add_child(l)
	return l


## Tek bir ışığın dokudaki izi: renk sabit, alfa = ışık dokusunun radyal düşüşü × enerji.
func _stamp(col: Color, scale: float, energy: float) -> Image:
	var g: Gradient = (_tex as GradientTexture2D).gradient
	var d := maxi(2, int(round(256.0 * scale / BAKE_K)))
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := d / 2.0
	for y in d:
		for x in d:
			var t := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			var a := g.sample(minf(t, 1.0)).a * energy if t < 1.0 else 0.0
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	return img


func _rebuild_rooms() -> void:
	_rooms_dirty = true
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
	if Map.DEEP.has_point(player_pos):
		# 2.0: Batık Şehir karanlık; denizaltının farı çevreyi aydınlatır
		canvas_mod.color = Color(0.1, 0.14, 0.26)
		for l in street:
			l.visible = false
		_last_key = Vector4(-1, -1, -1, -1)
		player_light.visible = true
		player_light.position = player_pos
		player_light.texture_scale = Deep.light_r() / 110.0
		player_light.energy = 1.5
		player_light.color = Color("#d9f4ff")
		return
	player_light.texture_scale = 0.7
	player_light.color = Color("#fff4dc")
	player_light.energy = 0.45
	if Map.SEA_BED.has_point(player_pos):
		canvas_mod.color = Color(0.55, 0.8, 1.0).lerp(Color(0.2, 0.3, 0.5), d * 0.7)
		for l in street:
			l.visible = false
		_last_key = Vector4(-1, -1, -1, -1)
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
	var led := 1.5 if Projects.done("led") else 1.0           # 2.0: LED sokak lambaları
	# 2.5.1: yüzlerce ışığı her karede değil, yalnız durum değişince güncelle
	var key := Vector4(1.0 if lit else 0.0, snappedf(strength, 0.01), led, 1.0 if d > 0.15 else 0.0)
	if key != _last_key or _rooms_dirty:
		_last_key = key
		_rooms_dirty = false
		for l in street:
			l.visible = lit
			l.energy = float(l.get_meta("base")) * strength * led
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
