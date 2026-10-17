extends RefCounted
## Şehir haritası sabitleri. Sunucu da istemci de aynı yerleşimi kullanır.

const WORLD := Rect2(0, 0, 2400, 2300)
const SPAWN := Vector2(1200, 445)

const BUILDINGS := [
	{"type": "hospital", "label": "Hastane", "rect": Rect2(100, 100, 380, 260),
		"wall": Color(0.93, 0.94, 0.96), "roof": Color(0.80, 0.18, 0.20)},
	{"type": "market", "label": "Market", "rect": Rect2(560, 100, 340, 260),
		"wall": Color(0.98, 0.90, 0.70), "roof": Color(0.15, 0.55, 0.30)},
	{"type": "casino", "label": "Kumarhane", "rect": Rect2(980, 100, 380, 260),
		"wall": Color(0.35, 0.12, 0.40), "roof": Color(0.85, 0.65, 0.10)},
	{"type": "poker", "label": "Poker Salonu", "rect": Rect2(1440, 100, 360, 260),
		"wall": Color(0.12, 0.30, 0.20), "roof": Color(0.10, 0.10, 0.12)},
	{"type": "realestate", "label": "Emlak Ofisi", "rect": Rect2(1880, 100, 300, 260),
		"wall": Color(0.85, 0.85, 0.80), "roof": Color(0.20, 0.35, 0.70)},
]

# Yollar (çizim ve ağaç yerleşimi için)
const ROADS := [
	Rect2(0, 390, 2400, 110),
	Rect2(960, 500, 90, 1130),
	Rect2(1050, 790, 1350, 70),
]

const LAKE := Rect2(80, 620, 760, 820)
const DOCK := Rect2(760, 990, 200, 80)          # göl iskelesi (tamamı balık tutma alanı)

# Plaj ve deniz
const BEACH := Rect2(0, 1630, 2400, 230)
const SEA := Rect2(0, 1860, 2400, 440)
const PIER := Rect2(1560, 1700, 80, 400)        # denize uzanan iskele
const PIER_END := Rect2(1550, 1960, 100, 140)   # deniz balıkçılığı alanı

const PLOT_COUNT := 12
const PLOT_ORIGIN := Vector2(1080, 890)
const PLOT_SIZE := Vector2(260, 180)
const PLOT_GAP := 30.0
const PLOT_PRICES := [2000, 2000, 2500, 2500, 3500, 3500, 5000, 5000, 8000, 8000, 12000, 20000]


static func plot_rect(i: int) -> Rect2:
	var col := i % 4
	var row := int(i / 4.0)
	return Rect2(PLOT_ORIGIN + Vector2(col * (PLOT_SIZE.x + PLOT_GAP), row * (PLOT_SIZE.y + PLOT_GAP)), PLOT_SIZE)


## Göl: yürünemez.
static func in_water(p: Vector2) -> bool:
	var c := LAKE.get_center()
	var r := LAKE.size / 2.0
	var d := (p - c) / r
	return d.length_squared() < 1.0 and not DOCK.has_point(p)


## Deniz: yüzülebilir (iskele hariç).
static func in_sea(p: Vector2) -> bool:
	return p.y > SEA.position.y + sin(p.x / 60.0) * 6.0 and not PIER.has_point(p)


## Balık tutma noktası: "lake", "sea" ya da "" (iskele ucunda değil).
static func fishing_spot(p: Vector2) -> String:
	if DOCK.grow(30).has_point(p):
		return "lake"
	if PIER_END.grow(30).has_point(p):
		return "sea"
	return ""
