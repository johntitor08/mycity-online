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
	# 1.3: hara (at çiftliği), Sanayi bölgesinde müzenin yanında
	{"type": "hara", "label": "Hara", "rect": Rect2(1316, 3806, 196, 150), "sign_y": 26},
	# 1.4: okul (bankanın doğusu)
	{"type": "okul", "label": "Okul", "rect": Rect2(2626, 1168, 168, 200), "sign_y": 30},
	# 1.5: spor salonu (çarşının doğusu)
	{"type": "spor", "label": "Spor Salonu", "rect": Rect2(2626, 1424, 168, 156), "sign_y": 26},
]
# 1.5: hayvanat bahçesi ve akvaryum (fuarın altı)
const ZOO := Rect2(10700, 1720, 1560, 1080)
const ZOO_GATE := Vector2(11480, 1720)            # giriş turnikesi (üst çit ortası)
const ZOO_PENS := {
	"aslan": Rect2(10760, 1800, 340, 260), "fil": Rect2(11160, 1800, 400, 280), "zurafa": Rect2(11640, 1800, 340, 300),
	"penguen": Rect2(10760, 2160, 340, 240), "maymun": Rect2(11160, 2180, 400, 240), "ayi": Rect2(11640, 2200, 340, 240),
}
const ZOO_KEEPER := Vector2(11480, 2560)          # bakıcı ofisi (yem deposu)
const ZOO_BUILDINGS := [
	{"type": "akvaryum", "label": "Akvaryum", "rect": Rect2(12360, 1800, 560, 340), "sign_y": 40},
]
# 1.5: maraton parkuru (şehir içi, yaya)
const MARATHON := [Vector2(2700, 1620), Vector2(2480, 518), Vector2(1300, 518), Vector2(300, 518),
	Vector2(300, 1590), Vector2(1005, 1660), Vector2(1600, 1690), Vector2(2700, 1620)]
const MARATHON_R := 90.0
# 1.5: Korsan Adası (açık denizde, Martı Adası'nın doğusu; tekneyle)
const KORSAN := Rect2(2050, 2500, 700, 380)
const KORSAN_PIER := Rect2(2378, 2410, 50, 110)
const KORSAN_CAPTAIN := Vector2(2200, 2660)
const KORSAN_SHIP := Vector2(2600, 2720)
# 1.4: Fuar ve Havalimanı bölgesi (harita dışında; şehirden servisle gidilir)
const FAIR := Rect2(10600, 0, 2600, 2900)        # 1.5: aşağıya hayvanat bahçesi eklendi
const SHUTTLE_CITY := Vector2(1640, 518)          # şehirdeki servis durağı (üst caddenin güney kaldırımı)
const SHUTTLE_FAIR := Vector2(11300, 1560)        # fuardaki servis durağı (gelince burada)
const FERRIS := Vector2(10950, 560)               # dönme dolabın merkezi
const FERRIS_R := 230.0
const BUMPER := Rect2(11260, 250, 480, 360)       # çarpışan araba pisti
const GALLERY := Vector2(10860, 1060)             # atış poligonu tezgâhı
const TICKET_BOOTH := Vector2(11230, 1060)        # jeton gişesi ve ödül standı
const CANDY := Vector2(11560, 1080)               # pamuk şeker
const FAIR_BUILDINGS := [
	{"type": "terminal", "label": "Havalimanı", "rect": Rect2(12160, 860, 420, 230), "sign_y": 40},
]
const RUNWAY := Rect2(11900, 1260, 1220, 110)
const BALLOON_FIELD := Vector2(12880, 520)
const DETECTIVE := Vector2(2252, 1046)            # Dedektif Ferhat (karakolun batısı)

## Balon turu güzergâhı (şehrin üstünde, 45 sn).
const BALLOON_ROUTE := [Vector2(320, 1620), Vector2(700, 1000), Vector2(1250, 650), Vector2(1900, 420),
	Vector2(2450, 760), Vector2(2350, 1350), Vector2(1700, 1900), Vector2(1000, 2050), Vector2(450, 1800)]
const BALLOON_TIME := 45.0


static func balloon_at(t: float) -> Vector2:
	var pts: Array = BALLOON_ROUTE
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var d := clampf(t / BALLOON_TIME, 0.0, 1.0) * total
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if d <= seg:
			return pts[i].lerp(pts[i + 1], d / seg)
		d -= seg
	return pts[-1]


## Bölge kimliği: oyuncu bölgeler arasında sadece sunucu ışınlamasıyla geçer.
static var rail_shift := 0.0        # testler tarifeyi kaydırır (oyunda 0)


static func train_state(t: float) -> Dictionary:
	## Tren nerede? {k: 0 giriş → 1 peron → 2 çıkış, stopped: peronda mı, visible, left: kalkışa kalan sn, next: gelişe kalan sn}
	var u := fposmod(t + rail_shift, RAIL_PERIOD)
	if u < 10.0:
		var k := u / 10.0
		return {"k": 1.0 - (1.0 - k) * (1.0 - k), "phase": "in", "stopped": false, "visible": true, "next": 10.0 - u}
	if u < 30.0:
		return {"k": 1.0, "phase": "stop", "stopped": true, "visible": true, "left": 30.0 - u}
	if u < 40.0:
		var k2 := (u - 30.0) / 10.0
		return {"k": 1.0 + k2 * k2, "phase": "out", "stopped": false, "visible": true, "next": RAIL_PERIOD - u + 10.0}
	return {"k": 0.0, "phase": "away", "stopped": false, "visible": false, "next": RAIL_PERIOD - u + 10.0}


## Trenin ortasının x'i (k: 0 girişte, 1 peronda, 2 çıkışta).
static func train_x(st: Dictionary, k: float) -> float:
	if k <= 1.0:
		return lerpf(float(st.x0), float(st.stop), k)
	return lerpf(float(st.stop), float(st.x1), k - 1.0)


static func rail_region(key: String) -> String:
	return {"sehir": "sehir", "dag": "dag", "fuar": "fuar", "mahalle": "mahalle"}[key]


static func region_of(p: Vector2) -> String:
	if OCEAN.has_point(p):
		return "okyanus"
	if DUNGEON.has_point(p):
		return "zindan"
	if MOON.has_point(p):
		return "ay"
	if SPACEPORT.has_point(p):
		return "uzay"
	if GOLF.has_point(p):
		return "golf"
	if TOWN.has_point(p):
		return "mahalle"
	if DEEP.has_point(p):
		return "derin"
	if HIGHWAY.has_point(p):
		return "otoyol"
	if YALIKENT.has_point(p):
		return "yalikent"
	if CAMLIBEL.has_point(p):
		return "camlibel"
	if INST_AREA.has_point(p):
		return "ic"
	if MOUNTAIN.has_point(p):
		return "dag"
	if FAIR.has_point(p):
		return "fuar"
	return "sehir"


# 1.7: tren hattı. Her bölgenin kenarında bir istasyon; tren hepsinde aynı tarifeyle peronlara girer.
#  y: ray yüksekliği, x0/x1: trenin girip çıktığı uçlar, stop: durduğu yer (trenin ortası), booth: bilet gişesi
const RAIL := {
	"sehir": {"name": "Şehir Garı", "y": 36.0, "x0": -500.0, "x1": 3300.0, "stop": 2230.0, "booth": Vector2(2230, 84), "arrive": Vector2(2230, 140)},
	"dag": {"name": "Dağ İstasyonu", "y": 2866.0, "x0": 7400.0, "x1": 10800.0, "stop": 8560.0, "booth": Vector2(8560, 2826), "arrive": Vector2(8620, 2790)},
	"fuar": {"name": "Lunapark İstasyonu", "y": 36.0, "x0": 10100.0, "x1": 13700.0, "stop": 11560.0, "booth": Vector2(11560, 84), "arrive": Vector2(11640, 150)},
	"mahalle": {"name": "Yeni Mahalle İstasyonu", "y": 36.0, "x0": 39000.0, "x1": 43900.0, "stop": 40800.0, "booth": Vector2(40800, 84), "arrive": Vector2(40880, 150)},
}
const RAIL_PERIOD := 80.0          # tarife: 0-10 sn giriş, 10-30 peronda, 30-40 çıkış
const TRAIN_LEN := 480.0

# 1.7: sinema (fuar bölgesi, akvaryumun güneyi) ve paintball arenası (havalimanının kuzeyi)
const CINEMA := {"type": "sinema", "label": "Sinema", "rect": Rect2(12440, 2330, 400, 280), "sign_y": 78}
const ARENA := Rect2(11940, 110, 680, 430)
const ARENA_BOOTH := Vector2(12280, 610)
const ARENA_COVER := [Rect2(12120, 190, 30, 110), Rect2(12410, 350, 30, 110), Rect2(12240, 160, 90, 26),
	Rect2(12230, 460, 90, 26), Rect2(12030, 400, 70, 26), Rect2(12460, 210, 70, 26), Rect2(12260, 300, 50, 50)]
const ARENA_BASE := {"kirmizi": Vector2(11990, 325), "mavi": Vector2(12570, 325)}

# 1.8: harita dışı bölgeler: zindan katları (4 sefer yuvası alt alta), Ay, uzay üssü, mini golf sahası
const DUNGEON := Rect2(31000, 0, 2000, 4800)
const DUNGEON_SLOT_H := 1200.0
const DUNGEON_DOOR := Vector2(8260, 520)          # dağda mağara girişi (karlı ormanın içinde)
const DUNGEON_SHOP := Vector2(8420, 600)           # silahçı çadırı (mağaranın yanında)
const MOON := Rect2(33500, 0, 3000, 2400)
const MOON_BASE := Rect2(34700, 1660, 600, 360)   # Ay üssü kubbesi (oksijen, sera, dönüş rampası)
const MOON_PAD := Vector2(35000, 2320)            # roket iniş/kalkış
const SPACEPORT := Rect2(33500, 2700, 1800, 1000)
const SPACE_PAD := Vector2(34500, 3050)            # fırlatma rampası
const SPACE_SHOP := Vector2(33900, 3350)           # roket atölyesi ve uzay pazarı
const SPACE_STRIP := Vector2(34900, 3560)          # uzay üssünün uçak pisti (havalimanına dönüş)
const GOLF := Rect2(37000, 0, 1800, 1200)
const GOLF_BOOTH := Vector2(12880, 1120)           # fuarda mini golf gişesi
# 1.9: Yeni Mahalle (trenle gidilir): pazar meydanı ve tezgâhlar, tuning garajı ve drift alanı, evcil hayvan parkı
const TOWN := Rect2(39500, 0, 3900, 1800)           # 2.0: doğuya genişledi (akademi, mahalle muhtarlığı)
const TOWN_ROAD := Rect2(39500, 196, 3900, 74)
const TOWN_AVE := Rect2(40556, 270, 74, 1530)
const MARKET_SQ := Rect2(39620, 320, 880, 720)
const STALL_COUNT := 8
const WANTED_BOARD := Vector2(40060, 1000)          # alım ilanları panosu
const TUNING := {"type": "tuning", "label": "Tuning Garajı", "rect": Rect2(39660, 1110, 420, 230), "sign_y": 60}
const DRIFT := Rect2(39620, 1420, 880, 340)          # drift alanı (puanlar burada sayılır)
const PET_PARK := Rect2(40700, 320, 1340, 1440)
const PET_TRACK := [Vector2(40820, 520), Vector2(41900, 520), Vector2(41900, 800), Vector2(40820, 800), Vector2(40820, 1060), Vector2(41900, 1060)]
const PET_BOOTH := Vector2(40780, 430)               # parkur yarışı gişesi
const PET_STAGE := Rect2(41260, 1250, 440, 170)      # güzellik şovu sahnesi
const PET_SPOTS := {"kosu": Vector2(40830, 1280), "slalom": Vector2(40830, 1520), "bakim": Vector2(41060, 1640)}
const PET_KIOSK := Vector2(41880, 1330)              # aksesuar dükkânı
# 2.0: Aşçılık Akademisi ve mahalle muhtarlığı (Yeni Mahalle'nin doğusu)
const ACADEMY := {"type": "akademi", "label": "Aşçılık Akademisi", "rect": Rect2(42250, 360, 560, 300), "sign_y": 60}
const MAHALLE_OFFICE := {"type": "mahalle_muhtar", "label": "Mahalle Muhtarlığı", "rect": Rect2(42320, 860, 400, 200), "sign_y": 50}
const TOWN_AVE2 := Rect2(42140, 270, 74, 1530)
# 2.0: denizaltı tersanesi (Sanayi Limanı) ve Batık Şehir (harita dışında)
const SUB_DOCK := Vector2(900, 3640)
const DEEP := Rect2(45000, 0, 3200, 2600)
const DEEP_GATE := Vector2(45300, 300)             # Batık Şehir'e iniş / yüzeye çıkış
# 2.0: plaj festivali
const FEST_STAGE := Rect2(800, 1650, 340, 96)
const DANCE_FLOOR := Rect2(790, 1752, 360, 92)
const DJ_BOOTH := Vector2(970, 1730)
const FEST_GATE := Vector2(700, 1700)               # bilet gişesi
# 2.0: belediye projelerinin yerleri ve proje panosu
const PROJECT_BOARD := Vector2(2245, 700)
const PROJECT_SITES := {
	"heykel": Vector2(880, 1545), "cicek": Vector2(480, 1600), "fiskiye": Vector2(460, 1030), "led": Vector2(1200, 445),
	"bisiklet": Vector2(1005, 900), "plaj": Vector2(1850, 1730), "kule": Vector2(560, 1700),
}

# 1.9: afetlerde yardım çadırı (şehirde, sahil yolunun başında)
const AID_TENT := Vector2(1260, 1585)

const BOWLING := {"type": "bowling", "label": "Bowling", "rect": Rect2(12660, 700, 440, 260), "sign_y": 70}

# 1.6: Açık Okyanus (harita dışında; adalar ocean_map.gd'de)
const OCEAN := Rect2(14000, 0, 16000, 10000)

# 1.3: hipodrom (güney şeridi): 4 kulvar, soldan sağa
const HIPPODROME := Rect2(260, 4116, 2440, 172)
const HIPPO_START_X := 330.0
const HIPPO_FINISH_X := 2600.0
const HIPPO_BOOTH := Vector2(190, 4196)
const HIPPO_STANDS := Rect2(1560, 4094, 700, 22)
static func hippo_lane_y(i: int) -> float:
	return HIPPODROME.position.y + 24.0 + i * 41.0

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
	# 2.1: kasabaların şehir içi durakları (otobüs sadece aynı kasabanın durakları arasında gider)
	"yk_merkez": ["Yalıkent Çarşı", Vector2(50900, 1410)], "yk_liman": ["Yalıkent Liman", Vector2(51650, 2880)],
	"yk_otogar": ["Yalıkent Otogar", Vector2(52790, 1410)],
	"cb_merkez": ["Çamlıbel Meydan", Vector2(55500, 1710)], "cb_kaplica": ["Çamlıbel Kaplıca", Vector2(57500, 3110)],
	"cb_otogar": ["Çamlıbel Otogar", Vector2(57250, 1710)],
}
# Meslek noktaları
const TAXI_STAND := Vector2(1465, 520)
const CARGO_DEPOT := Vector2(1855, 700)
const FIRE_STATION := Rect2(2632, 930, 156, 140)
const RECYCLE := Vector2(935, 1612)
const DOCK := Rect2(760, 990, 200, 80)          # göl iskelesi (tamamı balık tutma alanı)
const KAYIK_SPOT := Vector2(712, 1036)          # 1.7: iskelenin ucunda bağlı bedava kayık (suda)
const LAKE_DEEP_K := 0.62                       # gölün ortası (bu oranın içi) derin: yüzülmez, kayıkla gidilir

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
# ada ile liman arasında adanın batısından dolaşır (adanın içinden geçmesin)
const FERRY_ROUTE := [Vector2(340, 2060), Vector2(1500, 2620), Vector2(1060, 2700), Vector2(1040, 3200), Vector2(1345, 3330),
	Vector2(1040, 3200), Vector2(1060, 2700), Vector2(1500, 2620)]
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
# 1.3: kamp alanı (dağ köyünün kuzeybatısı): ateş çukurları, teleskop; çadırlar buraya kurulur
const CAMP := Rect2(7960, 2230, 500, 360)
const CAMPFIRES := [Vector2(8090, 2380), Vector2(8300, 2450), Vector2(8150, 2530)]
const TELESCOPE := Vector2(8400, 2290)
const WRECK := Vector2(6300, 3600)
const BOAT_RENT_SPOT := Vector2(1530, 1680)    # deniz iskelesinin başı (Kaptan Rüstem'in solunda)
const MOORED_BOATS := [Vector2(1712, 1920), Vector2(1712, 2010)]   # 1.5: iskeleye bağlı kiralık tekneler
const PIER := Rect2(1560, 1700, 80, 400)        # denize uzanan iskele
const PIER_END := Rect2(1550, 1960, 100, 140)   # deniz balıkçılığı alanı

const PLOT_COUNT := 20               # 2.1: 12 şehirde, 4 Yalıkent'te (12–15), 4 Çamlıbel'de (16–19)
const CITY_PLOTS := 12
const PLOT_ORIGIN := Vector2(1080, 890)
const PLOT_SIZE := Vector2(260, 180)
const PLOT_GAP := 30.0
const PLOT_PRICES := [2000, 2000, 2500, 2500, 3500, 3500, 5000, 5000, 8000, 8000, 12000, 20000,
	3000, 3000, 4500, 4500, 3000, 3000, 4500, 4500]


static func plot_rect(i: int) -> Rect2:
	if i >= CITY_PLOTS:
		var k := (i - CITY_PLOTS) % 4
		var o: Vector2 = YALIKENT.position + Vector2(250, 480) if i < CITY_PLOTS + 4 else CAMLIBEL.position + Vector2(1400, 770)
		return Rect2(o + Vector2(k * (PLOT_SIZE.x + 40), 0), PLOT_SIZE)
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
## Gölün suyu (nehir hariç, iskele hariç).
static func in_lake(p: Vector2) -> bool:
	var d := (p - LAKE.get_center()) / (LAKE.size / 2.0)
	return d.length_squared() < 1.0 and not DOCK.has_point(p)


## Gölün derin ortası (yüzerek girilmez).
static func lake_deep(p: Vector2) -> bool:
	var d := (p - LAKE.get_center()) / (LAKE.size / 2.0 * LAKE_DEEP_K)
	return d.length_squared() < 1.0


static func in_sea(p: Vector2) -> bool:
	if p.x > WORLD.end.x:
		return false      # harita dışı (ev içleri) deniz değildir
	return p.y > SEA.position.y + sin(p.x / 60.0) * 6.0 and p.y < SOUTH_COAST_Y + sin(p.x / 70.0) * 6.0 \
		and not PIER.has_point(p) and not ISLAND_PIER.has_point(p) and not on_island(p) and not on_korsan(p) and not KORSAN_PIER.has_point(p) \
		and not PORT_PIER.has_point(p) and not FERRY_PIER.has_point(p)


## Tekne gövdesi için şişirilmiş ada (kumsal dahil) ve iskeleler: tekne merkezi buraya giremez.
static func boat_blocked(p: Vector2) -> bool:
	var d := (p - ISLAND.get_center()) / (ISLAND.size / 2.0 + Vector2(46, 34))
	if d.length_squared() < 1.0:
		return true
	var dk := (p - KORSAN.get_center()) / (KORSAN.size / 2.0 + Vector2(46, 34))
	if dk.length_squared() < 1.0:
		return true
	for r in [PIER, ISLAND_PIER, PORT_PIER, FERRY_PIER, KORSAN_PIER]:
		if r.grow(24).has_point(p):
			return true
	return false


## Korsan Adası'nın karası (elips).
static func on_korsan(p: Vector2) -> bool:
	var d := (p - KORSAN.get_center()) / (KORSAN.size / 2.0)
	return d.length_squared() < 1.0


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
	if YK_PIER_END.grow(30).has_point(p):
		return "sea"                     # 2.1: Yalıkent iskelesi
	if PIER_END.grow(30).has_point(p):
		return "sea"
	if ISLAND_SPOT.grow(30).has_point(p):
		return "island"
	return ""


## Noktanın bulunduğu bölgenin adı (hazine ipuçları için).
static func area_name(p: Vector2) -> String:
	if p.y >= SOUTH_COAST_Y - 200:
		return "Sanayi Limanı"
	if on_korsan(p):
		return "Korsan Adası"
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
const INTERIOR2_ORIGIN := Vector2(90200, 200)
const INTERIOR2_AREA := Rect2(90000, 0, 4700, 1800)
const TILE := 48.0
const ROOM_TILES := {1: Vector2i(12, 8), 2: Vector2i(16, 10), 3: Vector2i(18, 12)}


static func room_tiles(level: int) -> Vector2i:
	return ROOM_TILES.get(clampi(level, 1, 3), Vector2i(12, 8))


## Arsanın ev içi odası (dünya koordinatı).
static func interior_rect(i: int, level: int) -> Rect2:
	var cell := INTERIOR_ORIGIN + Vector2((i % 4) * INTERIOR_CELL.x, int(i / 4.0) * INTERIOR_CELL.y)
	if i >= CITY_PLOTS:                  # 2.1: kasaba evleri ikinci ev içi alanında
		var j := i - CITY_PLOTS
		cell = INTERIOR2_ORIGIN + Vector2((j % 4) * INTERIOR_CELL.x, int(j / 4.0) * INTERIOR_CELL.y)
	var t := room_tiles(level)
	return Rect2(cell, Vector2(t.x, t.y) * TILE)


## Noktanın bulunduğu ev içi (arsa indeksi) ya da -1.
static func interior_at(p: Vector2) -> int:
	if INTERIOR2_AREA.has_point(p):
		var rel2 := p - INTERIOR2_ORIGIN
		var c2 := int(floor(rel2.x / INTERIOR_CELL.x))
		var r2 := int(floor(rel2.y / INTERIOR_CELL.y))
		if c2 < 0 or c2 > 3 or r2 < 0 or r2 > 1:
			return -1
		return CITY_PLOTS + r2 * 4 + c2
	if not INTERIOR_AREA.has_point(p):
		return -1
	var rel := p - INTERIOR_ORIGIN
	var col := int(floor(rel.x / INTERIOR_CELL.x))
	var row := int(floor(rel.y / INTERIOR_CELL.y))
	if col < 0 or col > 3 or row < 0 or row > 2:
		return -1
	return row * 4 + col


# ------------------------------------------------------------------ 2.3: kurum iç mekanları
# Hastane, karakol, banka, kaplıca... Her kurumun içi harita dışında kendi hücresinde; kapıda E ile girilir,
# içeride tezgâhta binanın penceresi açılır. Odalar herkese açıktır.
const INST_ORIGIN := Vector2(100200, 200)
const INST_CELL := Vector2(1400, 1000)
const INST_COLS := 5
const INST_AREA := Rect2(100000, 0, 7200, 4200)
const INST_SIZE := Vector2(1056, 624)             # 22 x 13 karo
const INST_TYPES := ["hospital", "market", "casino", "poker", "realestate", "galeri", "mobilya", "petshop",
	"muhtarlik", "karakol", "banka", "carsi", "muze", "okul", "spor", "kaplica", "lokanta", "yk_kafe", "balikhali"]


static func inst_rect(type: String) -> Rect2:
	var i := INST_TYPES.find(type)
	if i < 0:
		return Rect2()
	return Rect2(INST_ORIGIN + Vector2((i % INST_COLS) * INST_CELL.x, int(i / float(INST_COLS)) * INST_CELL.y), INST_SIZE)


## Noktanın bulunduğu kurum odası ("" = değil).
static func inst_at(p: Vector2) -> String:
	if not INST_AREA.has_point(p):
		return ""
	var rel := p - INST_ORIGIN
	var col := int(floor(rel.x / INST_CELL.x))
	var row := int(floor(rel.y / INST_CELL.y))
	var i := row * INST_COLS + col
	if col < 0 or col >= INST_COLS or row < 0 or i >= INST_TYPES.size():
		return ""
	var t: String = INST_TYPES[i]
	return t if inst_rect(t).grow(60).has_point(p) else ""


static func inst_door(type: String) -> Rect2:
	var r := inst_rect(type)
	return Rect2(r.get_center().x - TILE, r.end.y - TILE, TILE * 2, TILE)


static func inst_spawn(type: String) -> Vector2:
	var r := inst_rect(type)
	return Vector2(r.get_center().x, r.end.y - TILE * 1.6)


## Tezgâh (görevlinin önü): burada E ile binanın penceresi açılır.
static func inst_counter(type: String) -> Rect2:
	var r := inst_rect(type)
	return Rect2(r.get_center().x - 170, r.position.y + 104, 340, 56)


## Şehir, Yalıkent ya da Çamlıbel'deki bina.
static func any_building(type: String) -> Dictionary:
	for list in [BUILDINGS, YK_BUILDINGS, CB_BUILDINGS]:
		for b in list:
			if b.type == type:
				return b
	return {}


## Kurumdan çıkınca binanın kapısının önü.
static func inst_exit(type: String) -> Vector2:
	var b := any_building(type)
	if b.is_empty():
		return SPAWN
	var r: Rect2 = b.rect
	return Vector2(r.get_center().x, r.end.y + 40)


## Binanın önünde ya da içinde mi (sunucu denetimleri için).
static func at_building(type: String, p: Vector2, grow := 60.0) -> bool:
	var b := any_building(type)
	if not b.is_empty() and (b.rect as Rect2).grow(grow).has_point(p):
		return true
	return inst_at(p) == type


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


## 1.9: tezgâh i'nin dikdörtgeni (pazar meydanında iki sıra).
static func stall_rect(i: int) -> Rect2:
	return Rect2(MARKET_SQ.position + Vector2(40 + (i % 4) * 210, 60 + (i / 4) * 320), Vector2(180, 110))


## Tezgâhın önü (alışveriş buradan yapılır).
static func stall_front(i: int) -> Vector2:
	var r := stall_rect(i)
	return Vector2(r.get_center().x, r.end.y + 40)


# ================================================================== 2.1: otoyol ve kasabalar
# Otoyol (ayrı bölge): şehir, Yalıkent ve Çamlıbel rampaları; arabayla yolculuk ~30 sn.
const HIGHWAY := Rect2(50000, 4000, 20000, 700)
const HWY_ROAD := Rect2(50000, 4200, 20000, 240)          # 4 şerit (üst ikisi doğu, alt ikisi batı yönü)
const HWY_REST := Rect2(63200, 4440, 640, 200)            # dinlenme tesisi (otopark dahil)
const HWY_RAMPS := {"sehir": 50300.0, "yalikent": 58500.0, "camlibel": 69700.0}
const TOWN_NAMES := {"sehir": "Şehir", "yalikent": "Yalıkent", "camlibel": "Çamlıbel"}
# Yalıkent: sahil kasabası (güneyi deniz)
const YALIKENT := Rect2(50000, 1000, 3600, 2400)
const YK_ROADS := [Rect2(50000, 1300, 3600, 90), Rect2(51700, 1390, 90, 1500), Rect2(50000, 2890, 3600, 80)]
const YK_SEA_Y := 3050.0
const YK_PIER := Rect2(52400, 2970, 80, 330)
const YK_PIER_END := Rect2(52390, 3200, 100, 100)
const YK_BUILDINGS := [
	{"type": "balikhali", "label": "Balık Hali", "rect": Rect2(52000, 1450, 420, 240), "sign_y": 40},
	{"type": "otogar_yk", "label": "Yalıkent Otogarı", "rect": Rect2(52600, 1450, 380, 220), "sign_y": 40},
	{"type": "yk_kafe", "label": "Martı Kafe", "rect": Rect2(50300, 2620, 320, 200), "sign_y": 34},
]
const YK_LIGHTHOUSE := Vector2(53300, 3200)
# Çamlıbel: dağ kenti (çam ormanları, kaplıca)
const CAMLIBEL := Rect2(54500, 1000, 3600, 2400)
const CB_ROADS := [Rect2(54500, 1600, 3600, 90), Rect2(55700, 1690, 90, 1310), Rect2(55700, 3000, 2400, 90)]
const CB_BUILDINGS := [
	{"type": "kaplica", "label": "Kaplıca", "rect": Rect2(57300, 2700, 500, 240), "sign_y": 40},
	{"type": "lokanta", "label": "Yayla Lokantası", "rect": Rect2(54800, 1750, 380, 220), "sign_y": 40},
	{"type": "otogar_cb", "label": "Çamlıbel Otogarı", "rect": Rect2(57400, 1360, 380, 220), "sign_y": 40},
]
# rampalar (kasabada otoyola çıkış) ve otogarlar (şehirler arası otobüs)
const TOWN_RAMPS := {"sehir": Vector2(60, 445), "yalikent": Vector2(50080, 1345), "camlibel": Vector2(58020, 1645)}
const OTOGARS := {"sehir": Vector2(170, 575), "yalikent": Vector2(52790, 1700), "camlibel": Vector2(57590, 1610)}


## Arabanın gidebildiği yollar (bütün bölgeler).
static func road_rects() -> Array:
	var out: Array = ROADS.duplicate()
	out.append(PORT_ROAD)
	out.append_array([TOWN_ROAD, TOWN_AVE, TOWN_AVE2, DRIFT])
	out.append_array(YK_ROADS)
	out.append_array(CB_ROADS)
	out.append(HWY_ROAD)
	out.append(HWY_REST)
	return out


static func on_road(p: Vector2, margin: float = 0.0) -> bool:
	for r: Rect2 in road_rects():
		if r.grow(margin).has_point(p):
			return true
	return false


## Bir yol üstündeki en yakın nokta (arabayı yola koymak için).
static func nearest_road(p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	for r: Rect2 in road_rects():
		var q := p.clamp(r.position + Vector2(20, 20), r.end - Vector2(20, 20))
		var d := q.distance_to(p)
		if d < bd:
			bd = d
			best = q
	return best


static func town_of(p: Vector2) -> String:
	if YALIKENT.has_point(p):
		return "yalikent"
	if CAMLIBEL.has_point(p):
		return "camlibel"
	if WORLD.has_point(p):
		return "sehir"
	return ""
