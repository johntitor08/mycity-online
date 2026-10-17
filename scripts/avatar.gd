extends RefCounted
## Karakter görünümü: seçenekler, doğrulama ve katmanlı sprite çizimi.
## Görünüm sözlüğü: {skin, hair, hair_color, shirt, pants} (hepsi listelerdeki indeksler).

const CELL := Vector2(48, 64)          # oyun birimi; dokular 2x çözünürlükte
const SKIN_TONES := [Color("#fbe0c9"), Color("#f2c39b"), Color("#d9a273"), Color("#a86b45"), Color("#6e4429")]
const HAIR_STYLES := ["short", "long", "bun", "spiky", "bald"]
const HAIR_STYLE_NAMES := ["Kısa", "Uzun", "Topuz", "Kirpi", "Kel"]
const HAIR_COLORS := [Color("#2b2118"), Color("#4a2c17"), Color("#7a4a22"), Color("#c08a3e"),
	Color("#ecc76e"), Color("#b4472c"), Color("#a3a8b0"), Color("#e879f9")]
const SHIRT_COLORS := [Color("#ef4444"), Color("#f97316"), Color("#facc15"), Color("#84cc16"),
	Color("#22c55e"), Color("#14b8a6"), Color("#38bdf8"), Color("#3b82f6"), Color("#8b5cf6"),
	Color("#ec4899"), Color("#f8fafc"), Color("#475569")]
const PANTS_COLORS := [Color("#334155"), Color("#1e3a8a"), Color("#3f3f46"), Color("#78350f"),
	Color("#166534"), Color("#d6c7a1")]
const OPTIONS := {"skin": SKIN_TONES, "hair": HAIR_STYLES, "hair_color": HAIR_COLORS,
	"shirt": SHIRT_COLORS, "pants": PANTS_COLORS}

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
	}


static func random() -> Dictionary:
	var d := {}
	for k in OPTIONS:
		d[k] = randi() % OPTIONS[k].size()
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
	ci.draw_set_transform(Vector2.ZERO)
