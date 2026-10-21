extends RefCounted
## Şehir haritası sabitleri. Sunucu da istemci de aynı yerleşimi kullanır.

const WORLD := Rect2(0, 0, 2800, 2300)
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
	# 0.4: ana yolun altındaki yeni sıra (tabela yazısı y=102'de)
	{"type": "galeri", "label": "Galeri", "rect": Rect2(1110, 540, 320, 220), "sign_y": 102},
	{"type": "pazar", "label": "Pazar Yeri", "rect": Rect2(1500, 540, 320, 220), "sign_y": 100},
	{"type": "mobilya", "label": "Mobilyacı", "rect": Rect2(1890, 540, 320, 220), "sign_y": 102},
	# 0.5: doğu mahallesi
	{"type": "petshop", "label": "Pet Shop", "rect": Rect2(2280, 100, 320, 260)},
	{"type": "muhtarlik", "label": "Muhtarlık", "rect": Rect2(2280, 540, 320, 220), "sign_y": 102},
]

# Görev veren NPC'ler (sabit duranlar): kimlik -> ad, konum, görünüm
const NPCS := {
	"muhtar": {"name": "Muhtar Rıza", "pos": Vector2(2440, 770), "app": {"skin": 2, "hair": 4, "hair_color": 6, "shirt": 11, "pants": 0}},
	"hasan": {"name": "Balıkçı Hasan Amca", "pos": Vector2(900, 1100), "app": {"skin": 3, "hair": 0, "hair_color": 6, "shirt": 7, "pants": 3}},
	"selma": {"name": "Dr. Selma", "pos": Vector2(330, 385), "app": {"skin": 1, "hair": 2, "hair_color": 1, "shirt": 10, "pants": 2}},
	"ayten": {"name": "Ayten Abla", "pos": Vector2(800, 385), "app": {"skin": 1, "hair": 1, "hair_color": 2, "shirt": 9, "pants": 1}},
	"rustem": {"name": "Kaptan Rüstem", "pos": Vector2(1660, 1720), "app": {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 1, "pants": 1}},
}
const NPC_TALK_RANGE := 70.0

# Yürüyen vatandaşlar için kaldırım rotaları (kapalı döngüler)
const WALK_ROUTES := [
	[Vector2(40, 383), Vector2(2760, 383), Vector2(2760, 507), Vector2(40, 507)],
	[Vector2(945, 520), Vector2(945, 1620), Vector2(1058, 1620), Vector2(1058, 520)],
	[Vector2(1070, 783), Vector2(2780, 783), Vector2(2780, 867), Vector2(1070, 867)],
	[Vector2(60, 1700), Vector2(1500, 1700), Vector2(2700, 1720), Vector2(1500, 1790), Vector2(60, 1780)],
]
# NPC arabaların şeritleri (y, yön)
const TRAFFIC_LANES := [[425.0, 1.0], [465.0, -1.0], [810.0, 1.0], [840.0, -1.0]]

# Yollar (çizim ve ağaç yerleşimi için)
const ROADS := [
	Rect2(0, 390, 2800, 110),
	Rect2(960, 500, 90, 1130),
	Rect2(1050, 790, 1750, 70),
]

const LAKE := Rect2(80, 620, 760, 820)
const DOCK := Rect2(760, 990, 200, 80)          # göl iskelesi (tamamı balık tutma alanı)

# Plaj ve deniz
const BEACH := Rect2(0, 1630, 2800, 230)
const SEA := Rect2(0, 1860, 2800, 440)
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
	if p.x > WORLD.end.x:
		return false      # harita dışı (ev içleri) deniz değildir
	return p.y > SEA.position.y + sin(p.x / 60.0) * 6.0 and not PIER.has_point(p)


## Balık tutma noktası: "lake", "sea" ya da "" (iskele ucunda değil).
static func fishing_spot(p: Vector2) -> String:
	if DOCK.grow(30).has_point(p):
		return "lake"
	if PIER_END.grow(30).has_point(p):
		return "sea"
	return ""


## Sokak lambaları (yol kenarları).
static func lamp_positions() -> Array:
	var out: Array = []
	for x in range(80, 2800, 240):
		out.append(Vector2(x, 384))
	for y in range(560, 1600, 220):
		out.append(Vector2(952, y))
	for x in range(1160, 2800, 240):
		out.append(Vector2(x, 868))
	return out


## Bina tipine göre konum (ör. "market").
static func building(type: String) -> Dictionary:
	for b in BUILDINGS:
		if b.type == type:
			return b
	return {}


# ------------------------------------------------------------------ ev içleri
# Her arsanın içi harita dışında kendi hücresinde durur; eve girmek oraya ışınlanmaktır.
const INTERIOR_ORIGIN := Vector2(3200, 200)
const INTERIOR_CELL := Vector2(1100, 800)
const INTERIOR_AREA := Rect2(3000, 0, 4700, 2700)
const TILE := 48.0
const ROOM_TILES := {1: Vector2i(12, 8), 2: Vector2i(16, 10), 3: Vector2i(18, 12)}


static func room_tiles(level: int) -> Vector2i:
	return ROOM_TILES.get(clampi(level, 1, 3), Vector2i(12, 8))


## Arsanın ev içi odası (dünya koordinatı).
static func interior_rect(i: int, level: int) -> Rect2:
	var cell := INTERIOR_ORIGIN + Vector2((i % 4) * INTERIOR_CELL.x, int(i / 4.0) * INTERIOR_CELL.y)
	var t := room_tiles(level)
	return Rect2(cell, Vector2(t.x, t.y) * TILE)


## Noktanın bulunduğu ev içi (arsa indeksi) ya da -1.
static func interior_at(p: Vector2) -> int:
	if not INTERIOR_AREA.has_point(p):
		return -1
	var rel := p - INTERIOR_ORIGIN
	var col := int(floor(rel.x / INTERIOR_CELL.x))
	var row := int(floor(rel.y / INTERIOR_CELL.y))
	if col < 0 or col > 3 or row < 0 or row > 2:
		return -1
	return row * 4 + col


## Odanın kapısı (alt orta) ve girişte durulacak nokta.
static func interior_door(i: int, level: int) -> Rect2:
	var r := interior_rect(i, level)
	return Rect2(r.get_center().x - TILE, r.end.y - TILE, TILE * 2, TILE)


static func interior_spawn(i: int, level: int) -> Vector2:
	var r := interior_rect(i, level)
	return Vector2(r.get_center().x, r.end.y - TILE * 1.6)


## Evden çıkınca arsanın önü.
static func plot_front(i: int) -> Vector2:
	var r := plot_rect(i)
	return Vector2(r.get_center().x, r.end.y - 20)
