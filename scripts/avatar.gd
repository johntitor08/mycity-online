extends RefCounted
## Karakter görünümü: seçenekler, doğrulama ve katmanlı sprite çizimi.
## Görünüm sözlüğü: {skin, hair, hair_color, shirt, pants, hat, glasses, neck} (hepsi listelerdeki indeksler).
## Aksesuarlar (şapka, gözlük, kolye) ve özel saç renkleri (indeks ≥ FREE_HAIR_COLORS) Çarşı'dan alınır;
## sahip olunmayanları sunucu sıfırlar (bkz. Shops.enforce).

const CELL := Vector2(48, 64)          # oyun birimi; dokular 2x çözünürlükte
const SKIN_TONES := [Color("#fbe0c9"), Color("#f2c39b"), Color("#d9a273"), Color("#a86b45"), Color("#6e4429")]
const HAIR_STYLES := ["short", "long", "bun", "spiky", "bald"]
const HAIR_STYLE_NAMES := ["Kısa", "Uzun", "Topuz", "Kirpi", "Kel"]
const HAIR_COLORS := [Color("#2b2118"), Color("#4a2c17"), Color("#7a4a22"), Color("#c08a3e"),
	Color("#ecc76e"), Color("#b4472c"), Color("#a3a8b0"), Color("#e879f9"),
	# 0.7: Kuaför'den alınan özel renkler
	Color("#f1f5f9"), Color("#22d3ee"), Color("#4ade80"), Color("#dc2626"), Color("#1d4ed8")]
const FREE_HAIR_COLORS := 8
const HAIR_COLOR_NAMES := ["Siyah", "Koyu kahve", "Kahve", "Bal", "Sarı", "Kızıl", "Gri", "Pembe",
	"Platin", "Neon mavi", "Nane", "Ateş kırmızısı", "Lacivert"]
const HATS := ["Yok", "Kasket", "Fötr", "Beyzbol Şapkası", "Bere", "Kovboy Şapkası", "Taç"]
const GLASSES := ["Yok", "Güneş Gözlüğü", "Numaralı Gözlük", "Kalp Gözlük"]
const NECKS := ["Yok", "Altın Kolye", "Kırmızı Atkı", "Papyon"]
const SHIRT_COLORS := [Color("#ef4444"), Color("#f97316"), Color("#facc15"), Color("#84cc16"),
	Color("#22c55e"), Color("#14b8a6"), Color("#38bdf8"), Color("#3b82f6"), Color("#8b5cf6"),
	Color("#ec4899"), Color("#f8fafc"), Color("#475569")]
const PANTS_COLORS := [Color("#334155"), Color("#1e3a8a"), Color("#3f3f46"), Color("#78350f"),
	Color("#166534"), Color("#d6c7a1")]
const OPTIONS := {"skin": SKIN_TONES, "hair": HAIR_STYLES, "hair_color": HAIR_COLORS,
	"shirt": SHIRT_COLORS, "pants": PANTS_COLORS, "hat": HATS, "glasses": GLASSES, "neck": NECKS}
const ACCESSORY_SLOTS := ["hat", "glasses", "neck"]

const TEX := {
	"legs": preload("res://assets/characters/legs.svg"),
	"skin": preload("res://assets/characters/skin.svg"),
	"shirt": preload("res://assets/characters/shirt.svg"),
	"short": preload("res://assets/characters/hair_short.svg"),
	"long": preload("res://assets/characters/hair_long.svg"),
	"bun": preload("res://assets/characters/hair_bun.svg"),
	"spiky": preload("res://assets/characters/hair_spiky.svg"),
}


## İsme göre sabit, rastgele görünen varsayılan görünüm.
static func default_for(player_name: String) -> Dictionary:
	var h := absi(hash(player_name))
	return {
		"skin": h % SKIN_TONES.size(),
		"hair": (h / 7) % 4,
		"hair_color": (h / 31) % 6,
		"shirt": (h / 3) % SHIRT_COLORS.size(),
		"pants": (h / 101) % 3,
		"hat": 0, "glasses": 0, "neck": 0,
	}


static func random() -> Dictionary:
	var d := {}
	for k in OPTIONS:
		d[k] = randi() % OPTIONS[k].size()
	d.hair_color = randi() % FREE_HAIR_COLORS
	# NPC'lerin bir kısmı aksesuarlı
	for k in ACCESSORY_SLOTS:
		d[k] = randi() % OPTIONS[k].size() if randf() < 0.18 else 0
	if d.hat == 6:
		d.hat = 1         # taç sadece oyunculara
	return d


## Ağdan/dosyadan gelen değeri güvenli hale getirir.
static func sanitize(d) -> Dictionary:
	var out := {}
	for k in OPTIONS:
		var v := 0
		if d is Dictionary:
			v = int(d.get(k, 0))
		out[k] = clampi(v, 0, OPTIONS[k].size() - 1)
	return out


static func shirt_color(app: Dictionary) -> Color:
	return SHIRT_COLORS[int(app.get("shirt", 0))]


## Karakteri ayakları `pos` noktasında olacak şekilde çizer.
## facing: down/up/left/right, frame: 0 durma, 1-2 adım. swim: sadece belden yukarısı.
static func draw(ci: CanvasItem, pos: Vector2, app: Dictionary, facing: String, frame: int,
		scale: float = 1.0, swim: bool = false) -> void:
	var row: int = {"down": 0, "up": 1, "right": 2, "left": 2}.get(facing, 0)
	var cell_h := 34.0 if swim else CELL.y
	var src := Rect2(Vector2(frame, row) * CELL * 2.0, Vector2(CELL.x, cell_h) * 2.0)
	var dest := Rect2(-CELL.x / 2.0, -CELL.y + 14 + (22.0 if swim else 0.0), CELL.x, cell_h)
	ci.draw_set_transform(pos, 0, Vector2(-scale if facing == "left" else scale, scale))
	var a := sanitize(app)
	if not swim:
		ci.draw_texture_rect_region(TEX.legs, dest, src, PANTS_COLORS[a.pants])
	ci.draw_texture_rect_region(TEX.skin, dest, src, SKIN_TONES[a.skin])
	ci.draw_texture_rect_region(TEX.shirt, dest, src, SHIRT_COLORS[a.shirt])
	var style: String = HAIR_STYLES[a.hair]
	if style != "bald":
		ci.draw_texture_rect_region(TEX[style], dest, src, HAIR_COLORS[a.hair_color])
	if int(a.hat) > 0 or int(a.glasses) > 0 or int(a.neck) > 0:
		# hücre koordinatı (x, y) → yerel (x - 24, y - 50 [+22 yüzerken])
		_draw_accessories(ci, a, row, Vector2(-24, -50 + (22.0 if swim else 0.0)), swim)
	ci.draw_set_transform(Vector2.ZERO)


## Aksesuarlar basit şekillerle çizilir (dönüşüm draw() içinde ayarlı; sola bakarken ayna).
static func _draw_accessories(ci: CanvasItem, a: Dictionary, row: int, o: Vector2, swim: bool) -> void:
	var side := row == 2
	var hx := 25.0 if side else 24.0           # baş merkezi
	var ol := Color("#232634")
	if int(a.neck) > 0 and not swim and row != 1:
		match int(a.neck):
			1:   # altın kolye
				var pts := PackedVector2Array()
				for k in 9:
					var t := k / 8.0
					pts.append(o + Vector2(lerpf(18.5, 29.5, t) + (2.0 if side else 0.0), 29.5 + sin(t * PI) * 4.5))
				ci.draw_polyline(pts, Color("#facc15"), 1.6)
				ci.draw_circle(o + Vector2(24 + (2.0 if side else 0.0), 34.5), 1.8, Color("#fde047"))
			2:   # atkı
				ci.draw_rect(Rect2(o + Vector2(15.5 if not side else 18, 27.5), Vector2(17 if not side else 14, 4.5)), Color("#dc2626"))
				ci.draw_rect(Rect2(o + Vector2(27 if not side else 19, 30), Vector2(4, 9)), Color("#b91c1c"))
			3:   # papyon
				var c := o + Vector2(24 + (3.0 if side else 0.0), 30.5)
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(-5, -3), c + Vector2(-5, 3)]), Color("#111827"))
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(5, -3), c + Vector2(5, 3)]), Color("#111827"))
				ci.draw_circle(c, 1.4, Color("#374151"))
	if int(a.glasses) > 0 and row != 1:
		var col: Color = [Color.TRANSPARENT, Color("#111827"), Color(0.75, 0.9, 1.0, 0.35), Color("#ec4899")][int(a.glasses)]
		var frame: Color = [Color.TRANSPARENT, Color("#111827"), Color("#374151"), Color("#be185d")][int(a.glasses)]
		var lenses: Array = [Vector2(31.5, 19)] if side else [Vector2(19.5, 19), Vector2(28.5, 19)]
		for l in lenses:
			var c: Vector2 = o + l
			if int(a.glasses) == 3:
				ci.draw_circle(c + Vector2(-1.3, -0.8), 2.0, col)
				ci.draw_circle(c + Vector2(1.3, -0.8), 2.0, col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.2, -0.3), c + Vector2(3.2, -0.3), c + Vector2(0, 3.2)]), col)
			else:
				ci.draw_rect(Rect2(c - Vector2(3.4, 2.6), Vector2(6.8, 5.2)), col)
				ci.draw_rect(Rect2(c - Vector2(3.4, 2.6), Vector2(6.8, 5.2)), frame, false, 1.0)
		if side:
			ci.draw_line(o + Vector2(28, 18.5), o + Vector2(20, 17.5), frame, 1.0)
		else:
			ci.draw_line(o + Vector2(22.9, 18.5), o + Vector2(25.1, 18.5), frame, 1.0)
			ci.draw_line(o + Vector2(16.1, 18), o + Vector2(12.5, 17.5), frame, 1.0)
			ci.draw_line(o + Vector2(31.9, 18), o + Vector2(35.5, 17.5), frame, 1.0)
	if int(a.hat) > 0:
		var top := o + Vector2(hx, 5)
		match int(a.hat):
			1:   # kasket
				ci.draw_colored_polygon(_dome(top + Vector2(0, 5.5), 12.5, 6.5), Color("#57534e"))
				ci.draw_rect(Rect2(top + Vector2(-12.5 if not side else -11, 4), Vector2(25 if not side else 23, 2.5)), Color("#44403c"))
				if side:
					ci.draw_rect(Rect2(top + Vector2(9, 4), Vector2(7, 3)), Color("#292524"))
			2:   # fötr
				ci.draw_rect(Rect2(top + Vector2(-16, 3), Vector2(32, 3.5)), Color("#1c1917"))
				ci.draw_rect(Rect2(top + Vector2(-9, -6), Vector2(18, 10)), Color("#292524"))
				ci.draw_rect(Rect2(top + Vector2(-9, 0.5), Vector2(18, 2.5)), Color("#b91c1c"))
			3:   # beyzbol
				ci.draw_colored_polygon(_dome(top + Vector2(0, 5), 12.5, 8), Color("#2563eb"))
				if side:
					ci.draw_rect(Rect2(top + Vector2(8, 3), Vector2(10, 3)), Color("#1d4ed8"))
				elif row == 0:
					ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-9, 4), top + Vector2(9, 4), top + Vector2(7, 8), top + Vector2(-7, 8)]), Color("#1d4ed8"))
				ci.draw_circle(top + Vector2(0, -2.8), 1.5, Color("#ffffff"))
			4:   # bere
				ci.draw_colored_polygon(_dome(top + Vector2(0, 6), 12.8, 9), Color("#16a34a"))
				ci.draw_rect(Rect2(top + Vector2(-12.8, 3.5), Vector2(25.6, 3.5)), Color("#15803d"))
				ci.draw_circle(top + Vector2(0, -3.5), 2.6, Color("#f0fdf4"))
			5:   # kovboy
				ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-18, 3), top + Vector2(18, 3), top + Vector2(14, 6.5), top + Vector2(-14, 6.5)]), Color("#92400e"))
				ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-9, 3.5), top + Vector2(-8, -6), top + Vector2(0, -3.5), top + Vector2(8, -6), top + Vector2(9, 3.5)]), Color("#a16207"))
				ci.draw_rect(Rect2(top + Vector2(-9, 0.5), Vector2(18, 2)), Color("#451a03"))
			6:   # taç
				var g := Color("#facc15")
				ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-9, 4), top + Vector2(-10, -5), top + Vector2(-5, -1), top + Vector2(0, -7),
					top + Vector2(5, -1), top + Vector2(10, -5), top + Vector2(9, 4)]), g)
				ci.draw_polyline(PackedVector2Array([top + Vector2(-9, 4), top + Vector2(-10, -5), top + Vector2(-5, -1), top + Vector2(0, -7),
					top + Vector2(5, -1), top + Vector2(10, -5), top + Vector2(9, 4), top + Vector2(-9, 4)]), ol, 0.8)
				ci.draw_circle(top + Vector2(0, 0.5), 1.6, Color("#ef4444"))


static func _dome(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
