extends Node
## Uzay üssü ve Ay (1.8).
##  Uzay Üssü (havalimanından uçarak gidilir): roket atölyesi — roket (15.000 TL, Sv.10), uzay giysisi, ay matkabı;
##  uzay pazarı — Ay Taşı ve Helyum-3 satılır. Fırlatma rampasından roketle Ay'a gidilir (yakıt 400 TL).
##  Ay: düşük yerçekimi (zıplayarak yürünür). Giysinin oksijeni üs kubbesinin dışında azalır, içinde dolar;
##  biterse kurtarma ekibi seni kubbeye taşır (150 TL). Ay taşlarını matkapla kaz, helyum çıkan bacalardan topla.
##  Ortak Ay üssü projesi: herkes taş/helyum bağışlar; modüller tamamlandıkça üste görünür. Sera bitince
##  her gün Ay Çileği hasadı. Roket rampasından Dünya'ya (uzay üssüne) dönülür.
## Veri: rec["space"] = {rocket, suit, drill, rocks, he, harvest_day, given}; save_data["moon_base"] = {modül: {rocks, he}}

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const ROCKET_PRICE := 15000
const ROCKET_LEVEL := 10
const SUIT_PRICE := 3000
const DRILL_PRICE := 1500
const FUEL_PRICE := 400
const TRIP_TIME := 6.0
const O2_MAX := 240.0
const RESCUE_FEE := 150
const ROCK_PRICE := 120
const HE_PRICE := 350
const ROCKS := 14
const VENTS := 5
const ROCK_HP := 3
const ROCK_RESPAWN := 180.0
const VENT_COOLDOWN := 120.0
const MODULES := {
	"bayrak": {"name": "Bayrak", "rocks": 10, "he": 0},
	"sera": {"name": "Sera", "rocks": 30, "he": 10},
	"rasathane": {"name": "Rasathane", "rocks": 50, "he": 20},
	"anten": {"name": "Uydu Anteni", "rocks": 60, "he": 30},
}
const MODULE_POS := {"bayrak": Vector2(-260, -40), "sera": Vector2(-200, 130), "rasathane": Vector2(240, 120), "anten": Vector2(280, -60)}

signal trip(d: Dictionary)

# --- istemci
var my := {"rocket": false, "suit": false, "drill": false, "rocks": 0, "he": 0}
var o2 := O2_MAX
var base := {}                       # modül -> {rocks, he}
var rocks: Array = []                # [[x, y, can]] (can 0: kazılmış)

# --- sunucu
var _o2 := {}
var _trips := {}                     # id -> [varış, hedef ("ay" | "dunya")]
var _rock_hp: Array = []
var _rock_t: Array = []
var _vent_t := {}                    # "ad:i" -> son toplama
var _acc := 0.0


func reset() -> void:
	my = {"rocket": false, "suit": false, "drill": false, "rocks": 0, "he": 0}
	o2 = O2_MAX
	base = {}
	rocks = []
	_o2.clear()
	_trips.clear()
	_rock_hp.clear()


func on_player_left(id: int) -> void:
	_o2.erase(id)
	_trips.erase(id)


static func rock_positions() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1808
	var out: Array = []
	var m: Rect2 = Map.MOON
	while out.size() < ROCKS:
		var p := Vector2(rng.randf_range(m.position.x + 120, m.end.x - 120), rng.randf_range(m.position.y + 120, m.end.y - 200))
		if Map.MOON_BASE.grow(160).has_point(p):
			continue
		var ok := true
		for q in out:
			if (q as Vector2).distance_to(p) < 220.0:
				ok = false
		if ok:
			out.append(p)
	return out


static func vent_positions() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2808
	var out: Array = []
	var m: Rect2 = Map.MOON
	while out.size() < VENTS:
		var p := Vector2(rng.randf_range(m.position.x + 200, m.end.x - 200), rng.randf_range(m.position.y + 150, m.end.y - 300))
		var ok := not Map.MOON_BASE.grow(200).has_point(p)
		for q in rock_positions() + out:
			if (q as Vector2).distance_to(p) < 160.0:
				ok = false
		if ok:
			out.append(p)
	return out


static func craters() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3808
	var out: Array = []
	for k in 26:
		out.append([Vector2(rng.randf_range(Map.MOON.position.x, Map.MOON.end.x), rng.randf_range(Map.MOON.position.y, Map.MOON.end.y)), rng.randf_range(40, 160)])
	return out


static func in_dome(p: Vector2) -> bool:
	var b: Rect2 = Map.MOON_BASE
	var d := (p - b.get_center()) / (b.size / 2.0)
	return d.length_squared() < 1.0


static func module_done(b: Dictionary, k: String) -> bool:
	var m: Dictionary = b.get(k, {})
	return int(m.get("rocks", 0)) >= int(MODULES[k].rocks) and int(m.get("he", 0)) >= int(MODULES[k].he)


# ------------------------------------------------------------------ istemci API

func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func launch() -> void:
	Net.ask(self, "req_launch")


func mine(i: int) -> void:
	Net.ask(self, "req_mine", {"i": i})


func vent(i: int) -> void:
	Net.ask(self, "req_vent", {"i": i})


func sell() -> void:
	Net.ask(self, "req_sell")


func donate(k: String) -> void:
	Net.ask(self, "req_donate", {"k": k})


func harvest() -> void:
	Net.ask(self, "req_harvest")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d.get("my", my)
	base = d.get("base", base)
	rocks = d.get("rocks", rocks)
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_o2(d: Dictionary) -> void:
	o2 = float(d.o2)


@rpc("authority", "call_local", "reliable")
func on_trip(d: Dictionary) -> void:
	trip.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("space") is Dictionary:
		rec["space"] = {"rocket": false, "suit": false, "drill": false, "rocks": 0, "he": 0, "harvest_day": "", "given": 0}
	return rec.space


func _base() -> Dictionary:
	if not Net.save_data.get("moon_base") is Dictionary:
		Net.save_data["moon_base"] = {}
	return Net.save_data.moon_base


func _rocks_view() -> Array:
	if _rock_hp.is_empty():
		for k in ROCKS:
			_rock_hp.append(ROCK_HP)
			_rock_t.append(0.0)
	var out: Array = []
	var ps := rock_positions()
	for i in ROCKS:
		out.append([ps[i].x, ps[i].y, int(_rock_hp[i])])
	return out


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var s := _data(rec)
	Net.tell(self, id, "on_state", {"my": {"rocket": bool(s.rocket), "suit": bool(s.suit), "drill": bool(s.drill), "rocks": int(s.rocks), "he": int(s.he),
		"harvested": str(s.get("harvest_day", "")) == Time.get_date_string_from_system()}, "base": _base(), "rocks": _rocks_view()})


func _broadcast_moon() -> void:
	for id in Net.players:
		if Map.MOON.has_point(_pos(id)) or Map.SPACEPORT.has_point(_pos(id)):
			send_state(id)


func _at_shop(id: int) -> bool:
	return _pos(id).distance_to(Map.SPACE_SHOP) < 170.0 or in_dome(_pos(id))


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _pos(id).distance_to(Map.SPACE_SHOP) > 170.0:
		return
	var s := _data(rec)
	var item := str(d.get("item", ""))
	var price: int = {"rocket": ROCKET_PRICE, "suit": SUIT_PRICE, "drill": DRILL_PRICE}.get(item, -1)
	if price < 0 or bool(s.get(item, false)):
		return
	if item == "rocket" and Rpg.level(id) < ROCKET_LEVEL:
		Net.notify(id, "Roket için seviye %d gerekli." % ROCKET_LEVEL, false)
		return
	if not Net.try_spend(id, price):
		Net.notify(id, "%s." % U.money(price), false)
		return
	s[item] = true
	if item == "rocket":
		Ach.event(id, "rocket")
		Net.announce("%s kendi roketini yaptı! Ay yolculuğu yakında." % Net.players[id].name)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, {"rocket": "Roketin hazır! Fırlatma rampasına git.", "suit": "Uzay giysisini giydin (oksijen %d sn)." % int(O2_MAX),
		"drill": "Ay matkabı senin: Ay taşlarını kazabilirsin."}[item])


@rpc("any_peer", "call_remote", "reliable")
func req_launch(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _trips.has(id):
		return
	var s := _data(rec)
	var p := _pos(id)
	if p.distance_to(Map.SPACE_PAD) < 150.0:
		if not bool(s.rocket):
			Net.notify(id, "Önce atölyeden bir roket yap.", false)
			return
		if not bool(s.suit):
			Net.notify(id, "Ay'a uzay giysisi olmadan gidilmez.", false)
			return
		if not Net.try_spend(id, FUEL_PRICE):
			Net.notify(id, "Roket yakıtı %s." % U.money(FUEL_PRICE), false)
			return
		_trips[id] = [Time.get_ticks_msec() / 1000.0 + TRIP_TIME, "ay"]
		Garage.set_ride(id, "train")
		Net.tell(self, id, "on_trip", {"to": "ay", "time": TRIP_TIME})
		Ach.event(id, "moon_trips")
	elif p.distance_to(Map.MOON_PAD) < 150.0:
		_trips[id] = [Time.get_ticks_msec() / 1000.0 + TRIP_TIME, "dunya"]
		Garage.set_ride(id, "train")
		Net.tell(self, id, "on_trip", {"to": "dunya", "time": TRIP_TIME})


@rpc("any_peer", "call_remote", "reliable")
func req_mine(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	_rocks_view()
	if rec.is_empty() or i < 0 or i >= ROCKS or int(_rock_hp[i]) <= 0:
		return
	var s := _data(rec)
	if not bool(s.drill):
		Net.notify(id, "Ay taşı kazmak için uzay üssünden Ay matkabı al.", false)
		return
	if _pos(id).distance_to(rock_positions()[i]) > 90.0:
		return
	_rock_hp[i] = int(_rock_hp[i]) - 1
	if int(_rock_hp[i]) <= 0:
		_rock_t[i] = Time.get_ticks_msec() / 1000.0
		var n := randi_range(2, 4)
		s["rocks"] = int(s.rocks) + n
		Ach.event(id, "moon_rocks", n)
		Rpg.add_xp(id, "", 20)
		Net.notify(id, "+%d Ay Taşı (toplam %d)" % [n, int(s.rocks)])
		Net.mark_dirty()
	_broadcast_moon()


@rpc("any_peer", "call_remote", "reliable")
func req_vent(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	if rec.is_empty() or i < 0 or i >= VENTS or _pos(id).distance_to(vent_positions()[i]) > 90.0:
		return
	var key := "%s:%d" % [Net.players[id].name, i]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_vent_t.get(key, -999.0)) < VENT_COOLDOWN:
		Net.notify(id, "Bu bacadan biraz önce topladın; %d sn sonra yine." % int(VENT_COOLDOWN - (now - float(_vent_t[key]))), false)
		return
	_vent_t[key] = now
	var s := _data(rec)
	s["he"] = int(s.he) + 1
	Rpg.add_xp(id, "", 15)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "+1 Helyum-3 (toplam %d)" % int(s.he))


@rpc("any_peer", "call_remote", "reliable")
func req_sell(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_shop(id):
		return
	var s := _data(rec)
	var money := int(s.rocks) * ROCK_PRICE + int(s.he) * HE_PRICE
	if money <= 0:
		return
	Net.add_money(id, money)
	Net.notify(id, "%d Ay Taşı ve %d Helyum-3 satıldı: %s" % [int(s.rocks), int(s.he), U.money(money)])
	s["rocks"] = 0
	s["he"] = 0
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_donate(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("k", ""))
	if rec.is_empty() or not MODULES.has(k) or not in_dome(_pos(id)):
		return
	var b := _base()
	if module_done(b, k):
		return
	if not b.has(k):
		b[k] = {"rocks": 0, "he": 0}
	var s := _data(rec)
	var need_r := maxi(0, int(MODULES[k].rocks) - int(b[k].rocks))
	var need_h := maxi(0, int(MODULES[k].he) - int(b[k].he))
	var gr := mini(need_r, int(s.rocks))
	var gh := mini(need_h, int(s.he))
	if gr + gh <= 0:
		Net.notify(id, "Bağışlayacak Ay Taşı ya da Helyum-3'ün yok.", false)
		return
	s["rocks"] = int(s.rocks) - gr
	s["he"] = int(s.he) - gh
	b[k]["rocks"] = int(b[k].rocks) + gr
	b[k]["he"] = int(b[k].he) + gh
	s["given"] = int(s.get("given", 0)) + gr + gh
	Ach.set_max(id, "moon_given", int(s.given))
	Rpg.add_xp(id, "", 10 * (gr + gh))
	if module_done(b, k):
		Net.announce("Ay üssüne %s eklendi! Katkı veren herkese teşekkürler." % MODULES[k].name)
	Net.mark_dirty()
	_broadcast_moon()
	Net.notify(id, "%s için %d taş, %d helyum bağışladın." % [MODULES[k].name, gr, gh])


@rpc("any_peer", "call_remote", "reliable")
func req_harvest(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not module_done(_base(), "sera") or not in_dome(_pos(id)):
		return
	var s := _data(rec)
	var today := Time.get_date_string_from_system()
	if str(s.get("harvest_day", "")) == today:
		Net.notify(id, "Ay çileklerini bugün topladın.", false)
		return
	s["harvest_day"] = today
	Net.add_money(id, 600)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Seradan Ay Çileği topladın: %s" % U.money(600))


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _trips.keys():
		if now < float(_trips[id][0]):
			continue
		var to: String = _trips[id][1]
		_trips.erase(id)
		if not Net.players.has(id):
			continue
		Garage.set_ride(id, "")
		if to == "ay":
			_o2[id] = O2_MAX
			Homes._teleport(id, Map.MOON_PAD + Vector2(0, -70))
			Net.notify(id, "Ay'a indin! Oksijenine dikkat; üs kubbesinde dolar.")
			send_state(id)
		else:
			Homes._teleport(id, Map.SPACE_PAD + Vector2(0, 110))
			Net.notify(id, "Dünya'ya döndün.")
	# kazılan taşlar yeniden belirir
	if not _rock_hp.is_empty():
		var any := false
		for i in ROCKS:
			if int(_rock_hp[i]) <= 0 and now - float(_rock_t[i]) > ROCK_RESPAWN:
				_rock_hp[i] = ROCK_HP
				any = true
		if any:
			_broadcast_moon()
	# oksijen
	_acc += delta
	var tick := _acc >= 0.5
	if tick:
		_acc = 0.0
	for id in Net.players:
		var p := _pos(id)
		if not Map.MOON.has_point(p) or _trips.has(id):
			continue
		var o := float(_o2.get(id, O2_MAX))
		o = minf(O2_MAX, o + 30.0 * delta) if in_dome(p) else o - delta
		if o <= 0.0:
			o = O2_MAX * 0.5
			Net.try_spend(id, mini(RESCUE_FEE, Net.get_money(id)))
			Homes._teleport(id, Map.MOON_BASE.get_center())
			Net.notify(id, "Oksijenin bitti! Kurtarma ekibi seni kubbeye taşıdı (%s)." % U.money(RESCUE_FEE), false)
		_o2[id] = o
		if tick:
			Net.tell(self, id, "on_o2", {"o2": snappedf(o, 0.1)})
