extends RefCounted
## Açık Okyanus (1.6) haritası: sabit tohumla üretilen adalar. Sunucu ve istemci aynı adaları üretir.
## Okyanus harita dışında ayrı bir bölgedir (şehirden kendi teknenle ya da uçakla gelinir).

const OCEAN := Rect2(14000, 0, 16000, 10000)
const SEED := 1606
const ISLANDS := 30
const CELL := 500.0                               # keşif sisi hücresi
const COLS := 32
const ROWS := 20
const HOME := Vector2(15400, 1300)                # Liman Adası (başlangıç)
const ARRIVE := Vector2(15400, 1680)              # gelince tekneyle burada (limanın güneyinde su)
const TYPES := {
	"tropik": {"name": "Tropik", "sand": Color("#f0dba5"), "land": Color("#5f9e3c"), "tier": 1},
	"kayalik": {"name": "Kayalık", "sand": Color("#bdb6a8"), "land": Color("#7d8a6a"), "tier": 2},
	"mangrov": {"name": "Mangrov", "sand": Color("#9c8a5c"), "land": Color("#3f6b35"), "tier": 2},
	"volkanik": {"name": "Volkanik", "sand": Color("#4b4540"), "land": Color("#3a2f2a"), "tier": 4},
	"buzul": {"name": "Buzul", "sand": Color("#e2edf3"), "land": Color("#f8fbfd"), "tier": 4},
	"batik": {"name": "Batık Şehir", "sand": Color("#cbbf9a"), "land": Color("#8fa28a"), "tier": 5},
}
const NAME_A := ["Mercan", "Kartal", "Ateş", "Buz", "Bambu", "Fırtına", "Martı", "Yengeç", "Kaplumbağa", "Yunus", "Kehribar",
	"Gümüş", "Altın", "Kızıl", "Sis", "Rüzgâr", "Yıldız", "Ay", "Güneş", "Fener", "Deniz Kızı", "Balina", "Korsan", "Hazine",
	"Kaya", "Lav", "Kristal", "Zümrüt", "Safir", "İnci"]
const NAME_B := {"tropik": ["Adası", "Koyu", "Plajı"], "kayalik": ["Kayalığı", "Burnu", "Adası"], "mangrov": ["Sazlığı", "Koyu", "Bataklığı"],
	"volkanik": ["Dağı", "Adası", "Krateri"], "buzul": ["Buzulu", "Adası", "Kıyısı"], "batik": ["Harabeleri", "Şehri", "Tapınağı"]}

static var _cache: Array = []


## Adalar: [{id, name, type, tier, c (merkez), r (yarıçap), shape (poligon), lighthouse, fuel, dock, chest, shipyard}]
static func islands() -> Array:
	if not _cache.is_empty():
		return _cache
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var out: Array = []
	# 0: Liman Adası (tersane, yakıt, fener)
	out.append(_make(0, "Liman Adası", "tropik", HOME, 300.0, rng))
	out[0]["shipyard"] = true
	out[0]["fuel"] = true
	out[0]["lighthouse"] = true
	var names_used := {}
	var tries := 0
	while out.size() < ISLANDS and tries < 4000:
		tries += 1
		var c := Vector2(rng.randf_range(OCEAN.position.x + 700, OCEAN.end.x - 700), rng.randf_range(OCEAN.position.y + 700, OCEAN.end.y - 700))
		var r := rng.randf_range(170.0, 380.0)
		var ok := true
		for o in out:
			if c.distance_to(o.c) < r + float(o.r) + 650.0:
				ok = false
				break
		if not ok:
			continue
		# uzaklık zorluğu belirler: uzak adalar daha tehlikeli tiplerde
		var far := clampf(c.distance_to(HOME) / 14000.0, 0.0, 1.0)
		var pool: Array = ["tropik", "tropik", "kayalik", "mangrov"]
		if far > 0.3:
			pool += ["kayalik", "mangrov", "volkanik", "buzul", "volkanik"]
		if far > 0.55:
			pool += ["volkanik", "volkanik", "buzul", "buzul", "batik", "batik"]
		var t: String = pool[rng.randi() % pool.size()]
		var nm := ""
		while nm == "" or names_used.has(nm):
			nm = "%s %s" % [NAME_A[rng.randi() % NAME_A.size()], NAME_B[t][rng.randi() % NAME_B[t].size()]]
		names_used[nm] = true
		var isl := _make(out.size(), nm, t, c, r, rng)
		isl["lighthouse"] = rng.randf() < 0.3
		isl["fuel"] = rng.randf() < 0.3 or t == "tropik" and rng.randf() < 0.3
		out.append(isl)
	_cache = out
	return out


static func _make(id: int, nm: String, t: String, c: Vector2, r: float, rng: RandomNumberGenerator) -> Dictionary:
	var shape := PackedVector2Array()
	var n := 28
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var sq := rng.randf_range(0.65, 1.0)
	for k in n:
		var a := TAU * k / n
		var rr := r * (1.0 + 0.16 * sin(a * 3.0 + ph1) + 0.08 * sin(a * 5.0 + ph2))
		shape.append(c + Vector2(cos(a) * rr, sin(a) * rr * sq))
	var deco: Array = []
	for k in int(r / 22.0):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.7)
		deco.append(c + Vector2(cos(a) * r * d, sin(a) * r * d * sq))
	var dock_a := rng.randf() * TAU
	var dock := c + Vector2(cos(dock_a) * r * 0.98, sin(dock_a) * r * 0.98 * sq)
	return {"id": id, "name": nm, "type": t, "tier": int(TYPES[t].tier), "c": c, "r": r, "sq": sq, "shape": shape, "deco": deco,
		"dock": dock, "dock_dir": Vector2(cos(dock_a), sin(dock_a) * sq).normalized(), "chest": c + Vector2(rng.randf_range(-0.3, 0.3) * r, rng.randf_range(-0.25, 0.25) * r * sq),
		"lighthouse": false, "fuel": false, "shipyard": false}


static func in_ocean(p: Vector2) -> bool:
	return OCEAN.has_point(p)


## Kara mı? (adalar). margin > 0: kıyıdan o kadar açıkta da kara say (tekne gövdesi için).
static func island_at(p: Vector2, margin: float = 0.0) -> int:
	for isl in islands():
		var c: Vector2 = isl.c
		var r: float = float(isl.r) * 1.3 + margin
		if absf(p.x - c.x) > r or absf(p.y - c.y) > r:
			continue
		if margin <= 0.0:
			if Geometry2D.is_point_in_polygon(p, isl.shape):
				return int(isl.id)
		else:
			var d := (p - c) / Vector2(1.0, float(isl.sq))
			var a := atan2(d.y, d.x)
			var k := fposmod(a / TAU * 28.0, 28.0)
			var i0 := int(k) % 28
			var i1 := (i0 + 1) % 28
			var edge: float = lerpf((isl.shape[i0] - c).length(), (isl.shape[i1] - c).length(), k - floorf(k))
			if (p - c).length() < edge + margin:
				return int(isl.id)
	return -1


## İskele: kıyıdan denize uzanan tahta (üstünde yürünür, ucundan tekneye binilir).
static func pier_end(isl: Dictionary) -> Vector2:
	return Vector2(isl.dock) + Vector2(isl.dock_dir) * 95.0


static func on_pier(p: Vector2) -> bool:
	for isl in islands():
		var a: Vector2 = Vector2(isl.dock) - Vector2(isl.dock_dir) * 40.0
		var b := pier_end(isl)
		if absf(p.x - a.x) > 160.0 or absf(p.y - a.y) > 160.0:
			continue
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) < 18.0:
			return true
	return false


static func is_land(p: Vector2) -> bool:
	return island_at(p) >= 0


## Okyanusta su mu? (tekne yolu)
static func is_water(p: Vector2) -> bool:
	return in_ocean(p) and island_at(p) < 0


static func cell_of(p: Vector2) -> int:
	var x := clampi(int((p.x - OCEAN.position.x) / CELL), 0, COLS - 1)
	var y := clampi(int((p.y - OCEAN.position.y) / CELL), 0, ROWS - 1)
	return y * COLS + x


static func cell_rect(i: int) -> Rect2:
	return Rect2(OCEAN.position + Vector2(i % COLS, int(i / COLS)) * CELL, Vector2(CELL, CELL))


## Bir noktanın çevresindeki hücreler (görüş yarıçapı r).
static func cells_around(p: Vector2, r: float) -> Array:
	var out: Array = []
	var n := int(ceil(r / CELL))
	var c := cell_of(p)
	var cx := c % COLS
	var cy := int(c / COLS)
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= COLS or y >= ROWS:
				continue
			var i := y * COLS + x
			if cell_rect(i).get_center().distance_to(p) <= r + CELL * 0.7:
				out.append(i)
	return out
