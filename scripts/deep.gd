extends Node
## Batık Şehir ve denizaltı (2.0). Sanayi Limanı'ndaki tersaneden denizaltı alınır (Sv.12), oradan dalınır.
##  Batık Şehir karanlıktır: denizaltının farı çevreni aydınlatır. Akü denizaltıdayken azalır, hava kubbelerinde dolar;
##  biterse acil yüzeye çıkış (300 TL). Denizanası tarlaları aküyü üç kat hızlı tüketir.
##  Hava kubbelerinde denizaltıdan inip (F) yürünür: tapınak, şarj istasyonu, deniz pazarı (eserler burada satılır).
##  Deniz canlıları: yanlarına git, E ile tara; ansiklopediye girer (yeni her tür ödül, hepsi büyük ödül).
##  Harabelerdeki sandıklardan antik eserler çıkar (kovaya girer; satılır ya da müzeye bağışlanır). Sandıklar dolar.
##  Tersanede akü, far ve motor yükseltilir.
## Veri: rec["deep"] = {sub, battery_lv, light_lv, motor_lv, found: [tür], loots}

signal changed
signal battery(v: float)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const SUB_PRICE := 25000
const SUB_LEVEL := 12
const BATTERY := [120.0, 200.0, 300.0]
const LIGHT := [260.0, 380.0, 520.0]
const MOTOR := [1.6, 2.0, 2.4]
const UP_PRICES := [6000, 14000]
const RESCUE_FEE := 300
const SCAN_RANGE := 130.0
const SCAN_REWARD := 200
const ALL_REWARD := 10000
const LOOT_RESPAWN := 600.0
const DOMES := [
	{"name": "Tapınak Kubbesi", "c": Vector2(46200, 900), "r": 260.0, "kind": "tapinak"},
	{"name": "Şarj Kubbesi", "c": Vector2(45500, 1900), "r": 200.0, "kind": "sarj"},
	{"name": "Deniz Pazarı", "c": Vector2(47400, 1700), "r": 240.0, "kind": "pazar"},
]
const JELLY := [[Vector2(46900, 600), 260.0], [Vector2(45900, 2250), 220.0], [Vector2(47700, 900), 240.0]]
## [ad, renk, boyut, hız, ödül çarpanı]
const CREATURES := {
	"fener": ["Fener Balığı", "#facc15", 18.0, 40.0, 1],
	"kalamar": ["Dev Kalamar", "#be123c", 60.0, 30.0, 3],
	"denizanasi": ["Denizanası", "#c084fc", 20.0, 15.0, 1],
	"ahtapot": ["Ahtapot", "#ea580c", 30.0, 25.0, 1],
	"murekkep": ["Mürekkep Balığı", "#a8a29e", 22.0, 45.0, 1],
	"kaplumbaga": ["Deniz Kaplumbağası", "#16a34a", 32.0, 30.0, 1],
	"vatoz": ["Vatoz", "#64748b", 40.0, 50.0, 1],
	"cekic": ["Çekiç Başlı Köpekbalığı", "#475569", 50.0, 70.0, 2],
	"balina_kopek": ["Balina Köpekbalığı", "#1e3a8a", 80.0, 35.0, 3],
	"denizati": ["Deniz Atı", "#f59e0b", 14.0, 10.0, 1],
	"nautilus": ["Nautilus", "#fde68a", 18.0, 20.0, 2],
	"kilic": ["Kılıç Balığı", "#0ea5e9", 34.0, 90.0, 2],
	"yengec": ["Dev Yengeç", "#dc2626", 30.0, 12.0, 1],
	"yilan": ["Deniz Yılanı", "#14b8a6", 36.0, 55.0, 2],
	"hayalet": ["Hayalet Balık", "#e0f2fe", 20.0, 35.0, 2],
	"mavi_balina": ["Mavi Balina", "#3b82f6", 160.0, 25.0, 5],
}
const ARTIFACTS := [["Antik Amfora", 400, 900], ["Mozaik Parçası", 300, 700], ["Bronz Kalkan", 700, 1400], ["Mermer Büst", 900, 1800],
	["Deniz Tanrısı Heykelciği", 1200, 2400], ["Altın Maske", 2000, 4000], ["Kristal Taç", 2500, 5000], ["Kayıp Şehir Haritası", 1500, 3000]]
const RUINS := 12

# --- istemci
var my := {"sub": false, "battery_lv": 0, "light_lv": 0, "motor_lv": 0, "found": []}
var bat := 0.0
var loot_ready: Array = []           # her harabe sandığı dolu mu

# --- sunucu
var _bat := {}                       # id -> akü (sn)
var _loot_t: Array = []              # sandık boşaldığı an
var _acc := 0.0


func reset() -> void:
	my = {"sub": false, "battery_lv": 0, "light_lv": 0, "motor_lv": 0, "found": []}
	bat = 0.0
	loot_ready = []
	_bat.clear()
	_loot_t.clear()


func on_player_left(id: int) -> void:
	_bat.erase(id)


static func in_dome(p: Vector2) -> int:
	for i in DOMES.size():
		if p.distance_to(DOMES[i].c) < float(DOMES[i].r):
			return i
	return -1


static func in_jelly(p: Vector2) -> bool:
	for j in JELLY:
		if p.distance_to(j[0]) < float(j[1]):
			return true
	return false


## Canlının t anındaki yeri (sunucu ve istemci aynı formülle hesaplar).
static func creature_pos(k: String, t: float) -> Vector2:
	var h := absi(hash(k))
	var home := Map.DEEP.position + Vector2(300 + h % 2600, 300 + (h / 7) % 2000)
	var spd: float = CREATURES[k][3]
	var rad := 140.0 + float(h % 160)
	var a := t * spd / rad + float(h % 100)
	return home + Vector2(cos(a), sin(a * 0.7)) * rad


static func ruin_positions() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2020
	var out: Array = []
	while out.size() < RUINS:
		var p := Map.DEEP.position + Vector2(rng.randf_range(250, Map.DEEP.size.x - 250), rng.randf_range(250, Map.DEEP.size.y - 250))
		if in_dome(p) >= 0 or p.distance_to(Map.DEEP_GATE) < 300.0:
			continue
		var ok := true
		for q in out:
			if (q as Vector2).distance_to(p) < 300.0:
				ok = false
		if ok:
			out.append(p)
	return out


func light_r() -> float:
	return LIGHT[int(my.get("light_lv", 0))]


# ------------------------------------------------------------------ istemci API

func buy(what: String) -> void:
	Net.ask(self, "req_buy", {"what": what})


func dive() -> void:
	Net.ask(self, "req_dive")


func surface() -> void:
	Net.ask(self, "req_surface")


func toggle_sub() -> void:
	Net.ask(self, "req_toggle")


func scan(k: String) -> void:
	Net.ask(self, "req_scan", {"k": k})


func loot(i: int) -> void:
	Net.ask(self, "req_loot", {"i": i})


func sell() -> void:
	Net.ask(self, "req_sell")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d.get("my", my)
	loot_ready = d.get("loot", loot_ready)
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_battery(d: Dictionary) -> void:
	bat = float(d.b)
	battery.emit(bat)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("deep") is Dictionary:
		rec["deep"] = {"sub": false, "battery_lv": 0, "light_lv": 0, "motor_lv": 0, "found": [], "loots": 0}
	return rec.deep


func _loot_view() -> Array:
	if _loot_t.is_empty():
		for i in RUINS:
			_loot_t.append(-9999.0)
	var now := Time.get_unix_time_from_system()
	var out: Array = []
	for i in RUINS:
		out.append(now - float(_loot_t[i]) >= LOOT_RESPAWN)
	return out


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var d := _data(rec)
	Net.tell(self, id, "on_state", {"my": {"sub": bool(d.sub), "battery_lv": int(d.battery_lv), "light_lv": int(d.light_lv), "motor_lv": int(d.motor_lv), "found": d.found},
		"loot": _loot_view()})


func _at_dock(id: int) -> bool:
	return _pos(id).distance_to(Map.SUB_DOCK) < 150.0


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_dock(id):
		return
	var s := _data(rec)
	var what := str(d.get("what", ""))
	if what == "sub":
		if bool(s.sub):
			return
		if Rpg.level(id) < SUB_LEVEL:
			Net.notify(id, "Denizaltı için seviye %d gerekli." % SUB_LEVEL, false)
			return
		if not Net.try_spend(id, SUB_PRICE):
			Net.notify(id, "Denizaltı %s." % U.money(SUB_PRICE), false)
			return
		s["sub"] = true
		Ach.event(id, "submarine")
		Net.announce("%s denizaltı aldı! Batık Şehir'in kapıları açılıyor." % Net.players[id].name)
	elif what in ["battery_lv", "light_lv", "motor_lv"]:
		var lvl := int(s[what])
		if not bool(s.sub) or lvl >= UP_PRICES.size():
			return
		if not Net.try_spend(id, UP_PRICES[lvl]):
			Net.notify(id, "Yükseltme %s." % U.money(UP_PRICES[lvl]), false)
			return
		s[what] = lvl + 1
	else:
		return
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_dive(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_dock(id):
		return
	var s := _data(rec)
	if not bool(s.sub):
		Net.notify(id, "Önce tersaneden bir denizaltı al.", false)
		return
	_bat[id] = BATTERY[int(s.battery_lv)]
	Garage.set_ride(id, "sub")
	Homes._teleport(id, Map.DEEP_GATE + Vector2(120, 80))
	Ach.event(id, "deep_dives")
	Net.notify(id, "Batık Şehir'e indin! Akün sınırlı; hava kubbelerinde dolar.")
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_surface(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not Map.DEEP.has_point(_pos(id)) or _pos(id).distance_to(Map.DEEP_GATE) > 200.0:
		return
	_up(id)


func _up(id: int) -> void:
	_bat.erase(id)
	Garage.set_ride(id, "")
	Homes._teleport(id, Map.SUB_DOCK + Vector2(0, 50))


@rpc("any_peer", "call_remote", "reliable")
func req_toggle(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or in_dome(_pos(id)) < 0:
		Net.notify(id, "Denizaltıdan ancak hava kubbesinde inilir.", false)
		return
	var ride := str(Net.players[id].get("ride", ""))
	Garage.set_ride(id, "" if ride == "sub" else "sub")


@rpc("any_peer", "call_remote", "reliable")
func req_scan(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("k", ""))
	if rec.is_empty() or not CREATURES.has(k) or not Map.DEEP.has_point(_pos(id)):
		return
	var cp := creature_pos(k, Land.server_now())
	if _pos(id).distance_to(cp) > SCAN_RANGE + 60.0:
		return
	var s := _data(rec)
	if k in s.found:
		Net.notify(id, "%s zaten ansiklopedinde." % CREATURES[k][0], false)
		return
	s.found.append(k)
	var reward := SCAN_REWARD * int(CREATURES[k][4])
	Net.add_money(id, reward)
	Rpg.add_xp(id, "", 30)
	Ach.event(id, "deep_species")
	Net.notify(id, "Yeni tür: %s! Ansiklopediye eklendi (+%s) — %d/%d" % [CREATURES[k][0], U.money(reward), s.found.size(), CREATURES.size()])
	if s.found.size() == CREATURES.size():
		Net.add_money(id, ALL_REWARD)
		Net.announce("%s Batık Şehir'deki bütün canlıları keşfetti! (+%s)" % [Net.players[id].name, U.money(ALL_REWARD)])
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_loot(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	_loot_view()
	if rec.is_empty() or i < 0 or i >= RUINS or _pos(id).distance_to(ruin_positions()[i]) > 110.0:
		return
	if Time.get_unix_time_from_system() - float(_loot_t[i]) < LOOT_RESPAWN:
		Net.notify(id, "Bu sandık boş; sonra yeniden bak.", false)
		return
	var bag: Array = rec.get("fish", [])
	if bag.size() >= Jobs.BAG_SIZE:
		Net.notify(id, "Kovan dolu; önce bir şeyler sat.", false)
		return
	if not rec.get("fish") is Array:
		rec["fish"] = bag
	_loot_t[i] = Time.get_unix_time_from_system()
	var a: Array = ARTIFACTS[randi() % ARTIFACTS.size()] if randf() < 0.85 else ARTIFACTS[5 + randi() % 3]
	var got := {"name": str(a[0]), "price": randi_range(int(a[1]), int(a[2]))}
	bag.append(got)
	var s := _data(rec)
	s["loots"] = int(s.get("loots", 0)) + 1
	Ach.event(id, "artifacts")
	Rpg.add_xp(id, "", 25)
	Jobs.send_inventory(id)
	Net.notify(id, "%s buldun! (%s) — kovaya kondu" % [got.name, U.money(int(got.price))])
	Net.mark_dirty()
	for pid in Net.players:
		if Map.DEEP.has_point(_pos(pid)):
			send_state(pid)


@rpc("any_peer", "call_remote", "reliable")
func req_sell(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var di := in_dome(_pos(id))
	if rec.is_empty() or di < 0 or DOMES[di].kind != "pazar":
		return
	var names: Array = []
	for a in ARTIFACTS:
		names.append(a[0])
	var bag: Array = rec.get("fish", [])
	var money := 0
	for i in range(bag.size() - 1, -1, -1):
		if str(bag[i].name) in names:
			money += int(bag[i].price)
			bag.remove_at(i)
	if money <= 0:
		Net.notify(id, "Satacak antik eserin yok.", false)
		return
	Net.add_money(id, money)
	Jobs.send_inventory(id)
	Net.mark_dirty()
	Net.notify(id, "Eserler satıldı: %s" % U.money(money))


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	var tick := _acc >= 0.5
	if tick:
		_acc = 0.0
	for id in _bat.keys():
		if not Net.players.has(id) or not Map.DEEP.has_point(_pos(id)):
			_bat.erase(id)
			continue
		var p := _pos(id)
		var s := _data(_rec(id))
		var mx: float = BATTERY[int(s.battery_lv)]
		var b := float(_bat[id])
		if in_dome(p) >= 0:
			b = minf(mx, b + 25.0 * delta)
		elif str(Net.players[id].get("ride", "")) == "sub":
			b -= delta * (3.0 if in_jelly(p) else 1.0)
		if b <= 0.0:
			Net.try_spend(id, mini(RESCUE_FEE, Net.get_money(id)))
			_up(id)
			Net.notify(id, "Akü bitti! Acil yüzeye çıkış yapıldı (%s)." % U.money(RESCUE_FEE), false)
			continue
		_bat[id] = b
		if tick:
			Net.tell(self, id, "on_battery", {"b": snappedf(b, 0.1)})
