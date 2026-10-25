extends RefCounted
## Şehir haritası sabitleri. Sunucu da istemci de aynı yerleşimi kullanır.

const WORLD := Rect2(0, 0, 2800, 4300)       # 0.8: açık deniz ve Martı Adası, 1.0: güneyde Sanayi ve Liman
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
	# 0.6: karakol (alt yolun altında)
	{"type": "karakol", "label": "Karakol", "rect": Rect2(2290, 900, 320, 220), "sign_y": 102},
	# 0.7: banka ve çarşı (karakolun altı)
	{"type": "banka", "label": "Banka", "rect": Rect2(2290, 1160, 320, 220), "sign_y": 102},
	{"type": "carsi", "label": "Çarşı", "rect": Rect2(2290, 1400, 320, 220), "sign_y": 102},
	# 1.0: Sanayi bölgesi
	{"type": "fabrika", "label": "Fabrika", "rect": Rect2(300, 3800, 440, 280), "sign_y": 102},
	# 1.2: müze (Sanayi) ve teleferik istasyonu (arsaların altı)
	{"type": "muze", "label": "Müze", "rect": Rect2(860, 3800, 420, 280), "sign_y": 104},
	{"type": "teleferik", "label": "Teleferik", "rect": Rect2(2050, 1506, 180, 116), "sign_y": 30},
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

# Yarış pisti: şehir yollarında kontrol noktaları (son nokta = başlangıç/bitiş çizgisi)
const RACE_START := Vector2(2700, 445)
const RACE_FLAG := Vector2(2700, 378)          # hakem bayrağı (yarış penceresi burada açılır)
const RACE_CPS := [Vector2(200, 445), Vector2(1005, 1560), Vector2(2700, 825), Vector2(2700, 445)]
const RACE_CP_RADIUS := 110.0

# Hazine avı için olası saklanma yerleri
const TREASURE_SPOTS := [
	Vector2(60, 560), Vector2(880, 600), Vector2(860, 1500), Vector2(120, 1560), Vector2(2760, 980),
	Vector2(2750, 1580), Vector2(2200, 1580), Vector2(1700, 1580), Vector2(40, 60), Vector2(940, 60),
	Vector2(2760, 60), Vector2(2240, 470), Vector2(560, 1620), Vector2(2100, 1700), Vector2(400, 1820),
	Vector2(1300, 2990), Vector2(1650, 3040),       # Martı Adası (tekneyle)
	Vector2(900, 4200), Vector2(2700, 4150),        # Sanayi bölgesi
]

# Hapishane: harita dışında (ev içlerinin altında), tek büyük koğuş
const JAIL := Rect2(3200, 2900, 864, 480)

# Yollar (çizim ve ağaç yerleşimi için)
const ROADS := [
	Rect2(0, 390, 2800, 110),
	Rect2(960, 500, 90, 1130),
	Rect2(1050, 790, 1750, 70),
]

const LAKE := Rect2(80, 620, 760, 820)
# 0.9: Hastane ile Market arasından göle akan nehir; ana yolda köprü
const RIVER := Rect2(500, 0, 46, 640)
const BRIDGE := Rect2(490, 380, 66, 134)
# Park (gölün güneyi): çeşme, saat kulesi, banklar
const PARK := Rect2(60, 1455, 860, 170)
const FOUNTAIN := Vector2(480, 1540)
const FOUNTAIN_R := 44.0
const CLOCK_TOWER := Vector2(790, 1545)
const CHAMPIONS_WALL := Vector2(620, 1600)      # parkta Şampiyonlar Duvarı
const STAGE := Rect2(96, 1462, 250, 64)           # 1.2: park sahnesi (konserler)
# Otobüs: yollarda kapalı güzergâh ve duraklar
const BUS_ROUTE := [Vector2(120, 425), Vector2(2650, 425), Vector2(2650, 465), Vector2(1030, 465),
	Vector2(1030, 1570), Vector2(985, 1570), Vector2(985, 465), Vector2(120, 465)]
const BUS_SPEED := 240.0
const BUS_STOPS := {
	"merkez": ["Merkez", Vector2(1300, 518)], "bati": ["Hastane / Nehir", Vector2(300, 518)],
	"dogu": ["Doğu Mahallesi", Vector2(2480, 518)], "arsalar": ["Arsalar", Vector2(1095, 790)],
	"plaj": ["Plaj / Park", Vector2(1095, 1600)],
}
# Meslek noktaları
const TAXI_STAND := Vector2(1465, 520)
const CARGO_DEPOT := Vector2(1855, 700)
const FIRE_STATION := Rect2(2632, 930, 156, 140)
const RECYCLE := Vector2(935, 1612)
const DOCK := Rect2(760, 990, 200, 80)          # göl iskelesi (tamamı balık tutma alanı)

# Plaj ve deniz
const BEACH := Rect2(0, 1630, 2800, 230)
const SEA := Rect2(0, 1860, 2800, 1700)
const SOUTH_COAST_Y := 3560.0                   # 1.0: güney kıyısı (Sanayi/Liman bölgesi bunun altında)
const PORT_ROAD := Rect2(0, 3690, 2800, 70)
const PORT_PIER := Rect2(1300, 3400, 90, 170)   # liman iskelesi (feribot)
const CONTAINER_YARD := Rect2(1520, 3790, 1180, 300)
const CRANES := [Vector2(1650, 3610), Vector2(2050, 3610), Vector2(2450, 3610)]
# Feribot: şehir (batı plajı) ↔ Martı Adası ↔ Liman
const FERRY_PIER := Rect2(300, 1700, 80, 300)   # şehirdeki feribot iskelesi
const FERRY_STOPS := {
	"sehir": ["Şehir (batı plajı)", Vector2(340, 1985)],
	"ada": ["Martı Adası", Vector2(1500, 2710)],
	"liman": ["Sanayi Limanı", Vector2(1345, 3420)],
}
const FERRY_ROUTE := [Vector2(340, 2060), Vector2(1500, 2620), Vector2(1345, 3330), Vector2(1500, 2620)]
const FERRY_SPEED := 150.0
const DEEP_Y := 2380.0                          # bundan sonrası derin deniz: sadece tekneyle
# Martı Adası (açık denizde): kum + çim elips, deniz feneri, adanın kuzeyinde balık iskelesi
const ISLAND := Rect2(1140, 2780, 720, 340)
const ISLAND_PIER := Rect2(1470, 2690, 60, 110)
const ISLAND_SPOT := Rect2(1460, 2690, 80, 40)  # iskele ucu: ada balıkçılığı
const LIGHTHOUSE := Vector2(1740, 2930)
# 1.1: dalış — deniz tabanı harita dışında ayrı bir alan (yüzeydeki x konumuna göre inilir)
const SEA_BED := Rect2(4300, 2900, 2800, 1000)
# 1.2: dağ bölgesi (harita dışında; teleferikle gidilir). Üstte zirveler, ortada kayak pisti,
# solda maden ocağı, altta teleferik istasyonu ve Dağ Evi.
const MOUNTAIN := Rect2(7900, 0, 2400, 2900)
const MOUNTAIN_TOP_Y := 180.0                    # bunun üstü sarp kayalık (yürünmez)
const MOUNTAIN_BUILDINGS := [
	{"type": "dagevi", "label": "Dağ Evi", "rect": Rect2(8650, 2540, 300, 200), "sign_y": 98},
	{"type": "teleferik_dag", "label": "Teleferik", "rect": Rect2(8150, 2640, 180, 116), "sign_y": 30},
]
const MOUNTAIN_SPAWN := Vector2(8240, 2800)      # teleferikten inince
const CITY_CABLE_SPAWN := Vector2(2140, 1650)    # şehre dönünce (istasyonun önü, plaj)
const QUARRY := Rect2(8000, 900, 1000, 1300)     # maden ocağı
const CAVE := Vector2(8500, 930)
const SLOPE := Rect2(9330, 260, 500, 2460)        # kayak pisti
const SKI_TOP := Vector2(9580, 300)
const SKI_FINISH_Y := 2640.0
const SKI_GATE_W := 120.0
const LIFT := Vector2(9930, 2680)                 # telesiyejin alt istasyonu
const SNOW_LINE := 1300.0                         # bunun üstü her mevsim karlı
const WRECK := Vector2(6300, 3600)
const BOAT_RENT_SPOT := Vector2(1530, 1680)    # deniz iskelesinin başı (Kaptan Rüstem'in solunda)
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


## Göl ve nehir: yürünemez (iskele ve köprü hariç).
static func in_water(p: Vector2) -> bool:
	if RIVER.has_point(p) and not BRIDGE.has_point(p):
		return true
	var c := LAKE.get_center()
	var r := LAKE.size / 2.0
	var d := (p - c) / r
	return d.length_squared() < 1.0 and not DOCK.has_point(p)


## Otobüsün güzergâh üzerindeki konumu (sunucu saatinden; herkeste aynı).
static func bus_route_len() -> float:
	var total := 0.0
	for i in BUS_ROUTE.size():
		total += BUS_ROUTE[i].distance_to(BUS_ROUTE[(i + 1) % BUS_ROUTE.size()])
	return total


static func bus_at(t: float) -> Array:
	var d := fmod(t * BUS_SPEED, bus_route_len())
	for i in BUS_ROUTE.size():
		var a: Vector2 = BUS_ROUTE[i]
		var b: Vector2 = BUS_ROUTE[(i + 1) % BUS_ROUTE.size()]
		var seg := a.distance_to(b)
		if d <= seg:
			return [a.lerp(b, d / seg), (b - a).normalized()]
		d -= seg
	return [BUS_ROUTE[0], Vector2.RIGHT]


## Deniz: yüzülebilir (iskeleler ve ada hariç).
static func in_sea(p: Vector2) -> bool:
	if p.x > WORLD.end.x:
		return false      # harita dışı (ev içleri) deniz değildir
	return p.y > SEA.position.y + sin(p.x / 60.0) * 6.0 and p.y < SOUTH_COAST_Y + sin(p.x / 70.0) * 6.0 \
		and not PIER.has_point(p) and not ISLAND_PIER.has_point(p) and not on_island(p) \
		and not PORT_PIER.has_point(p) and not FERRY_PIER.has_point(p)


## Martı Adası'nın karası (elips).
static func on_island(p: Vector2) -> bool:
	var d := (p - ISLAND.get_center()) / (ISLAND.size / 2.0)
	return d.length_squared() < 1.0


## Derin deniz: yüzerek girilemez, sadece tekneyle.
static func in_deep(p: Vector2) -> bool:
	return p.y > DEEP_Y and p.y < SOUTH_COAST_Y - 140.0 and in_sea(p)


## Güney kıyısının karası (Sanayi/Liman).
static func in_south(p: Vector2) -> bool:
	return p.y >= SOUTH_COAST_Y and WORLD.has_point(p)


## Feribotun güzergâhtaki konumu (sunucu saatinden).
static func ferry_at(t: float) -> Array:
	var total := 0.0
	for i in FERRY_ROUTE.size():
		total += FERRY_ROUTE[i].distance_to(FERRY_ROUTE[(i + 1) % FERRY_ROUTE.size()])
	var d := fmod(t * FERRY_SPEED, total)
	for i in FERRY_ROUTE.size():
		var a: Vector2 = FERRY_ROUTE[i]
		var b: Vector2 = FERRY_ROUTE[(i + 1) % FERRY_ROUTE.size()]
		var seg := a.distance_to(b)
		if d <= seg:
			return [a.lerp(b, d / seg), (b - a).normalized()]
		d -= seg
	return [FERRY_ROUTE[0], Vector2.RIGHT]


## Oltanın şamandırası yakında suya düşebilir mi? (balık tutmak için şart; olta animasyonu da buraya çizilir)
static func water_near(p: Vector2) -> bool:
	for d in [Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
		for dist in [80.0, 110.0, 150.0]:
			var q: Vector2 = p + d * dist
			if in_water(q) or in_sea(q):
				return true
	return false


## Balık tutma noktası: "lake", "sea" ya da "" (iskele ucunda değil).
static func fishing_spot(p: Vector2) -> String:
	if DOCK.grow(30).has_point(p):
		return "lake"
	if PIER_END.grow(30).has_point(p):
		return "sea"
	if ISLAND_SPOT.grow(30).has_point(p):
		return "island"
	return ""


## Noktanın bulunduğu bölgenin adı (hazine ipuçları için).
static func area_name(p: Vector2) -> String:
	if p.y >= SOUTH_COAST_Y - 200:
		return "Sanayi Limanı"
	if on_island(p) or p.y > DEEP_Y:
		return "Martı Adası"
	if p.y > BEACH.position.y - 20:
		return "plaj"
	if LAKE.grow(80).has_point(p):
		return "göl kıyısı"
	if p.y < 390:
		return "kuzey sokakları" if p.x < 1400 else "kuzeydoğu sokakları"
	if p.x > 2240:
		return "doğu mahallesi"
	if p.x < 960:
		return "batı yakası"
	return "arsalar bölgesi"


static func jail_spawn() -> Vector2:
	return JAIL.get_center() + Vector2(randf_range(-200, 200), randf_range(-80, 80))


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
## Kayak pistindeki kapılar (sırayla; sağ-sol değişir).
static func ski_gates() -> Array:
	var out: Array = []
	for k in 12:
		out.append(Vector2(SLOPE.get_center().x + (-130.0 if k % 2 == 0 else 130.0) + (k % 3 - 1) * 25.0, 560.0 + k * 180.0))
	return out


static func in_mountain(p: Vector2) -> bool:
	return MOUNTAIN.has_point(p)


static func plot_front(i: int) -> Vector2:
	var r := plot_rect(i)
	return Vector2(r.get_center().x, r.end.y - 20)
