extends Node
## Açık Okyanus (1.6) sunucu ve istemci durumu.
##  Giriş: kendi teknenle şehrin doğusundaki açık denizden (şamandıralar) ya da havalimanından uçarak.
##  Yakıt: okyanusta tekne yol aldıkça yakıt harcar; biterse kürek hızında gidersin. Yakıt iskelesi olan adalarda dolar.
##  Tersane (Liman Adası): motor (hız), depo (menzil), gövde (fırtına/Kraken dayanımı) yükseltmeleri, tamir.
##  Sandıklar: her adada bir sandık; her oyuncu her adanın sandığını 20 dk'da bir açabilir (uzak ada = zengin ganimet).
##  Fenerler: yakınca geniş bir alan haritada açılır. Keşif sisi: gezdikçe harita açılır, adalar keşfedilir.
##  Fırtınalar: sürüklenen fırtına bölgeleri tekneyi yavaşlatır, gövdeye hasar verir. Gövde biterse tekne batar.
##  Kraken: arada bir ortaya çıkar; oyuncular zıpkınla birlikte saldırır, ganimet verilen hasara göre bölünür.
## Veri: rec["ocean"] = {seen: base64, fuel, hp, up: {motor, tank, hull}, lit: [], found: [], visited: [], chest: {ada: unix}}

signal changed
signal kraken_changed
signal seen_changed
signal sank

const Map = preload("res://scripts/map.gd")
const OM = preload("res://scripts/ocean_map.gd")
const U = preload("res://scripts/util.gd")

const GATE := Rect2(2620, 2930, 180, 560)         # şehirde: okyanusa açılma şeridi (doğu açık deniz, Korsan Adası'nın güneyi)
const CITY_RETURN := Vector2(2690, 3200)          # şehre dönünce (tekneyle)
const BASE_FUEL := 100.0
const TANK_STEP := 60.0
const FUEL_PER_PX := 1.0 / 220.0
const FUEL_PRICE := 2
const CHEST_COOLDOWN := 1200.0
const UPGRADES := {
	"motor": {"name": "Motor", "desc": "Tekne hızı +%12", "price": [3000, 7000, 15000]},
	"tank": {"name": "Yakıt Deposu", "desc": "Menzil +60 L", "price": [2000, 5000, 11000]},
	"hull": {"name": "Gövde", "desc": "Fırtına ve Kraken hasarı -%20", "price": [2500, 6000, 13000]},
	"hold": {"name": "Ambar", "desc": "Kargo kapasitesi 10 → 20 → 35 → 50 sandık", "price": [4000, 9000, 18000]},
}
const REPAIR_PRICE := 5            # can başına
const TOW_FEE := 200
const STORMS := 3
const KRAKEN_EVERY := [1200.0, 2100.0]
const KRAKEN_TIME := 360.0
const HARPOON_RANGE := 460.0
const HARPOON_DMG := 12
const HARPOON_COOLDOWN := 0.9
const KRAKEN_REACH := 380.0
const ITEMS := {"tropik": "Okyanus İncisi", "kayalik": "Kayalık Akiği", "mangrov": "Mangrov Kehribarı", "volkanik": "Volkan Taşı",
	"buzul": "Buzul Kristali", "batik": "Antik Sikke"}

# --- istemci
var my := {"fuel": BASE_FUEL, "hp": 100.0, "up": {"motor": 0, "tank": 0, "hull": 0}, "lit": [], "found": [], "chest": {}}
var seen := PackedByteArray()
var storms: Array = []             # [{x, y, vx, vy, r}]
var _storms_at := 0.0
var kraken := {}                   # {x, y, hp, max, left}
var _pending_cells: Array = []

# --- sunucu
var _storms: Array = []
var _kraken := {}
var _kraken_next := 0.0
var _last_pos := {}
var _acc := 0.0
var _harp_t := {}
var _dmg_acc := {}


func reset() -> void:
	my = {"fuel": BASE_FUEL, "hp": 100.0, "up": {"motor": 0, "tank": 0, "hull": 0}, "lit": [], "found": [], "chest": {}}
	seen = PackedByteArray()
	storms = []
	kraken = {}
	_storms.clear()
	_kraken.clear()
	_last_pos.clear()


func on_player_left(id: int) -> void:
	_last_pos.erase(id)
	_harp_t.erase(id)


static func max_fuel(up: Dictionary) -> float:
	return BASE_FUEL + TANK_STEP * int(up.get("tank", 0))


static func speed_mult(up: Dictionary, fuel: float) -> float:
	return 0.75 * (1.0 + 0.12 * int(up.get("motor", 0))) * (0.25 if fuel <= 0.0 else 1.0)


func is_seen(cell: int) -> bool:
	return cell >= 0 and cell < seen.size() and seen[cell] != 0


func storm_at(p: Vector2) -> bool:
	var dt := Time.get_ticks_msec() / 1000.0 - _storms_at
	for s in storms:
		var sp := Vector2(float(s.x), float(s.y)) + Vector2(float(s.vx), float(s.vy)) * dt
		if sp.distance_to(p) < float(s.r):
			return true
	return false


func storm_positions() -> Array:
	var dt := Time.get_ticks_msec() / 1000.0 - _storms_at
	return storms.map(func(s): return [Vector2(float(s.x), float(s.y)) + Vector2(float(s.vx), float(s.vy)) * dt, float(s.r)])


## Keşif: gördüğün hücreleri işaretle (istemci), toplu olarak sunucuya gönder.
func reveal_around(p: Vector2, r: float) -> void:
	if seen.size() != OM.COLS * OM.ROWS:
		seen.resize(OM.COLS * OM.ROWS)
	var changed_any := false
	for c in OM.cells_around(p, r):
		if seen[c] == 0:
			seen[c] = 1
			_pending_cells.append(c)
			changed_any = true
	if changed_any:
		seen_changed.emit()


func flush_seen() -> void:
	if _pending_cells.is_empty():
		return
	Net.ask(self, "req_seen", {"c": _pending_cells})
	_pending_cells = []


# ------------------------------------------------------------------ istemci API

func enter() -> void:
	Net.ask(self, "req_enter")


func leave() -> void:
	Net.ask(self, "req_leave")


func refuel() -> void:
	Net.ask(self, "req_refuel")


func upgrade(k: String) -> void:
	Net.ask(self, "req_upgrade", {"k": k})


func repair() -> void:
	Net.ask(self, "req_repair")


func open_chest(island: int) -> void:
	Net.ask(self, "req_chest", {"i": island})


func light(island: int) -> void:
	Net.ask(self, "req_light", {"i": island})


func harpoon() -> void:
	Net.ask(self, "req_harpoon")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d.get("my", my)
	if d.has("seen"):
		seen = Marshalls.base64_to_raw(str(d.seen))
		if seen.size() != OM.COLS * OM.ROWS:
			seen.resize(OM.COLS * OM.ROWS)
		seen_changed.emit()
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_fuel(d: Dictionary) -> void:
	my["fuel"] = float(d.fuel)
	my["hp"] = float(d.hp)
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_world(d: Dictionary) -> void:
	storms = d.get("storms", storms)
	_storms_at = Time.get_ticks_msec() / 1000.0
	if d.has("kraken"):
		var had := not kraken.is_empty()
		kraken = d.kraken
		if had != not kraken.is_empty():
			kraken_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_sank(_d: Dictionary) -> void:
	sank.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("ocean") is Dictionary:
		rec["ocean"] = {}
	var o: Dictionary = rec.ocean
	for k in ["lit", "found", "visited"]:
		if not o.get(k) is Array:
			o[k] = []
		elif o[k].any(func(v): return v is float):
			o[k] = o[k].map(func(v): return int(v))      # JSON'dan float gelir; `in` kontrolü int ister
	if not o.get("chest") is Dictionary:
		o["chest"] = {}
	if not o.get("up") is Dictionary:
		o["up"] = {"motor": 0, "tank": 0, "hull": 0, "hold": 0}
	if not o.has("fuel"):
		o["fuel"] = BASE_FUEL
	if not o.has("hp"):
		o["hp"] = 100.0
	if not o.get("seen") is String:
		var b := PackedByteArray()
		b.resize(OM.COLS * OM.ROWS)
		o["seen"] = Marshalls.raw_to_base64(b)
	return o


func send_state(id: int, with_seen: bool = true) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var o := _data(rec)
	var mine := {"fuel": float(o.fuel), "hp": float(o.hp), "up": o.up, "lit": o.lit, "found": o.found, "chest": o.chest}
	var d := {"my": mine}
	if with_seen:
		d["seen"] = o.seen
	Net.tell(self, id, "on_state", d)


func _send_world(id: int) -> void:
	var d := {"storms": _storms_view()}
	d["kraken"] = _kraken_view()
	Net.tell(self, id, "on_world", d)


func _storms_view() -> Array:
	return _storms.map(func(s): return {"x": snappedf(s.p.x, 1.0), "y": snappedf(s.p.y, 1.0), "vx": s.v.x, "vy": s.v.y, "r": s.r})


func _kraken_view() -> Dictionary:
	if _kraken.is_empty():
		return {}
	return {"x": _kraken.p.x, "y": _kraken.p.y, "hp": int(_kraken.hp), "max": int(_kraken.max),
		"left": maxf(0.0, float(_kraken.until) - Time.get_ticks_msec() / 1000.0)}


func _in_ocean(id: int) -> bool:
	return OM.in_ocean(_pos(id))


func _own_boat(id: int) -> bool:
	return "boat" in Net.save_data.players.get(Net.players[id].name, {}).get("vehicles", [])


@rpc("any_peer", "call_remote", "reliable")
func req_enter(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Police.is_jailed(id):
		return
	var p := _pos(id)
	if not GATE.has_point(p) or str(Net.players[id].get("ride", "")) != "boat":
		return
	if not _own_boat(id):
		Net.notify(id, "Açık okyanusa kiralık tekneyle çıkılmaz. Galeri'den kendi tekneni al.", false)
		return
	if Env.weather == "storm":
		Net.notify(id, "Fırtınada okyanusa açılınmaz!", false)
		return
	var o := _data(_rec(id))
	if float(o.hp) <= 0.0:
		o["hp"] = 40.0
	Homes._teleport(id, OM.ARRIVE)
	_last_pos[id] = OM.ARRIVE
	send_state(id)
	_send_world(id)
	Ach.event(id, "ocean")
	Net.notify(id, "Açık Okyanus'a açıldın! Liman Adası'nda tersane ve yakıt var. M: okyanus haritası.")


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _pos(id).distance_to(OM.ARRIVE) > 260.0:
		return
	Garage.set_ride(id, "boat")
	Homes._teleport(id, CITY_RETURN)
	_last_pos.erase(id)
	Net.notify(id, "Şehrin açıklarına döndün.")


func _near_island_feature(id: int, key: String) -> int:
	var p := _pos(id)
	for isl in OM.islands():
		match key:
			"fuel":
				if isl.fuel and p.distance_to(isl.dock) < 220.0:
					return int(isl.id)
			"shipyard":
				if isl.shipyard and p.distance_to(isl.c) < float(isl.r) + 200.0:
					return int(isl.id)
	return -1


@rpc("any_peer", "call_remote", "reliable")
func req_refuel(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _near_island_feature(id, "fuel") < 0 and not Isles.has_pump_near(_pos(id)):
		return
	var o := _data(rec)
	var need := max_fuel(o.up) - float(o.fuel)
	if need < 1.0:
		Net.notify(id, "Depo zaten dolu.", false)
		return
	var cost := int(ceil(need * FUEL_PRICE))
	if not Net.try_spend(id, cost):
		var afford := int(Net.players[id].money / FUEL_PRICE)
		if afford <= 0:
			Net.notify(id, "Yakıt için paran yok.", false)
			return
		Net.try_spend(id, afford * FUEL_PRICE)
		need = float(afford)
		cost = afford * FUEL_PRICE
	o["fuel"] = minf(max_fuel(o.up), float(o.fuel) + need)
	Net.mark_dirty()
	send_state(id, false)
	Net.notify(id, "%d L yakıt alındı (%s)." % [int(need), U.money(cost)])


@rpc("any_peer", "call_remote", "reliable")
func req_upgrade(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("k", ""))
	if rec.is_empty() or not UPGRADES.has(k) or _near_island_feature(id, "shipyard") < 0:
		return
	var o := _data(rec)
	var lvl := int(o.up.get(k, 0))
	if lvl >= UPGRADES[k].price.size():
		Net.notify(id, "Bu yükseltme en üst seviyede.", false)
		return
	var price: int = UPGRADES[k].price[lvl]
	if not Net.try_spend(id, price):
		Net.notify(id, "%s yükseltmesi %s." % [UPGRADES[k].name, U.money(price)], false)
		return
	o.up[k] = lvl + 1
	Ach.event(id, "boat_up")
	Net.mark_dirty()
	send_state(id, false)
	Net.notify(id, "%s %d. seviye! (%s)" % [UPGRADES[k].name, lvl + 1, UPGRADES[k].desc])


@rpc("any_peer", "call_remote", "reliable")
func req_repair(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _near_island_feature(id, "shipyard") < 0:
		return
	var o := _data(rec)
	var need := 100.0 - float(o.hp)
	if need < 1.0:
		return
	var cost := int(ceil(need)) * REPAIR_PRICE
	if not Net.try_spend(id, cost):
		Net.notify(id, "Tamir %s." % U.money(cost), false)
		return
	o["hp"] = 100.0
	Net.mark_dirty()
	send_state(id, false)
	Net.notify(id, "Teknen tamir edildi (%s)." % U.money(cost))


@rpc("any_peer", "call_remote", "reliable")
func req_seen(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _in_ocean(id):
		return
	var o := _data(rec)
	var b := Marshalls.base64_to_raw(str(o.seen))
	if b.size() != OM.COLS * OM.ROWS:
		b.resize(OM.COLS * OM.ROWS)
	var p := _pos(id)
	var n := 0
	for c in d.get("c", []):
		var ci := int(c)
		# hile koruması: sadece oyuncunun yakınındaki hücreler
		if ci >= 0 and ci < b.size() and OM.cell_rect(ci).get_center().distance_to(p) < 2200.0 and b[ci] == 0:
			b[ci] = 1
			n += 1
	if n == 0:
		return
	o["seen"] = Marshalls.raw_to_base64(b)
	_check_found(id, o, b)
	Net.mark_dirty()


func _check_found(id: int, o: Dictionary, b: PackedByteArray) -> void:
	var newly: Array = []
	for isl in OM.islands():
		if int(isl.id) in o.found:
			continue
		if b[OM.cell_of(isl.c)] != 0:
			o.found.append(int(isl.id))
			newly.append(isl.name)
	if newly.is_empty():
		return
	Ach.set_max(id, "isles", o.found.size())
	Rpg.add_xp(id, "", 15 * newly.size())
	send_state(id, false)
	Net.notify(id, "Haritaya eklendi: %s (%d/%d ada)" % [", ".join(newly), o.found.size(), OM.ISLANDS])


@rpc("any_peer", "call_remote", "reliable")
func req_chest(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	var isl_list := OM.islands()
	if rec.is_empty() or i < 0 or i >= isl_list.size():
		return
	var isl: Dictionary = isl_list[i]
	if _pos(id).distance_to(isl.chest) > 110.0:
		return
	var o := _data(rec)
	var now := Time.get_unix_time_from_system()
	var last := float(o.chest.get(str(i), 0.0))
	var cool := CHEST_COOLDOWN
	var rule := Isles.chest_rule(id, i)
	if rule == -1.0:
		Net.notify(id, "Bu özel bir ada; sandığını sadece sahibi açabilir.", false)
		return
	if rule > 0.0:
		cool = rule                          # kendi adanın sandığı daha sık dolar
	if now - last < cool:
		Net.notify(id, "Bu sandık boş; %d dk sonra yine dolu olur." % int(ceil((cool - (now - last)) / 60.0)), false)
		return
	o.chest[str(i)] = now
	var tier := int(isl.tier)
	var money := randi_range(120, 300) * tier
	Net.add_money(id, money)
	var extra := ""
	if randf() < 0.25 + 0.08 * tier:
		var bag: Array = rec.get("fish", [])
		if bag.size() < Jobs.BAG_SIZE:
			var item: String = ITEMS[isl.type]
			bag.append({"name": item, "price": randi_range(150, 300) * tier})
			Jobs.send_inventory(id)
			extra = " ve %s" % item
	Pirates.maybe_piece(id, 0.08)
	if not int(isl.id) in o.visited:
		o.visited.append(int(isl.id))
		Ach.set_max(id, "isles_visited", o.visited.size())
	Ach.event(id, "ocean_chests")
	Rpg.add_xp(id, "", 10 * tier)
	Net.mark_dirty()
	send_state(id, false)
	Net.notify(id, "%s sandığından %s%s çıktı!" % [isl.name, U.money(money), extra])


@rpc("any_peer", "call_remote", "reliable")
func req_light(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	var isl_list := OM.islands()
	if rec.is_empty() or i < 0 or i >= isl_list.size() or not isl_list[i].lighthouse:
		return
	var isl: Dictionary = isl_list[i]
	if _pos(id).distance_to(lighthouse_pos(isl)) > 120.0:
		return
	var o := _data(rec)
	if i in o.lit:
		return
	o.lit.append(i)
	var b := Marshalls.base64_to_raw(str(o.seen))
	if b.size() != OM.COLS * OM.ROWS:
		b.resize(OM.COLS * OM.ROWS)
	for c in OM.cells_around(isl.c, 2600.0):
		b[c] = 1
	o["seen"] = Marshalls.raw_to_base64(b)
	_check_found(id, o, b)
	Ach.event(id, "lighthouses")
	Rpg.add_xp(id, "", 40)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s feneri yandı! Çevredeki deniz haritanda açıldı." % isl.name)


static func lighthouse_pos(isl: Dictionary) -> Vector2:
	var c: Vector2 = isl.c
	var r := float(isl.r)
	if isl.shipyard:
		return c + Vector2(r * 0.55, r * 0.25 * float(isl.sq))
	var d: Vector2 = Vector2(isl.chest) - c
	if d.length() < 1.0:
		d = Vector2.RIGHT
	return c - d.normalized() * Vector2(r * 0.45, r * 0.45 * float(isl.sq))      # sandığın karşı yakası


# --- Kraken

func spawn_kraken() -> void:
	var tries := 0
	var p := Vector2.ZERO
	while tries < 60:
		tries += 1
		p = Vector2(randf_range(OM.OCEAN.position.x + 1500, OM.OCEAN.end.x - 800), randf_range(OM.OCEAN.position.y + 800, OM.OCEAN.end.y - 800))
		if OM.island_at(p, 500.0) < 0 and p.distance_to(OM.HOME) > 2500.0:
			break
	var n := 0
	for id in Net.players:
		if _in_ocean(id):
			n += 1
	var hp := 400 + 200 * maxi(1, n)
	_kraken = {"p": p, "hp": hp, "max": hp, "until": Time.get_ticks_msec() / 1000.0 + KRAKEN_TIME, "dmg": {}, "hit_acc": 0.0}
	var near := ""
	var bd := 1e9
	for isl in OM.islands():
		var dd: float = p.distance_to(isl.c)
		if dd < bd:
			bd = dd
			near = isl.name
	Net.announce("KRAKEN görüldü: %s açıklarında! Teknesi olan herkes zıpkınını kapsın!" % near)
	_broadcast_world()


@rpc("any_peer", "call_remote", "reliable")
func req_harpoon(_d: Dictionary) -> void:
	var id := Net.sender()
	if _kraken.is_empty() or not Net.players.has(id) or str(Net.players[id].get("ride", "")) != "boat":
		return
	if _pos(id).distance_to(_kraken.p) > HARPOON_RANGE + 60.0:
		return
	if not U.rate_ok(_harp_t, id, HARPOON_COOLDOWN):
		return
	var dmg := HARPOON_DMG + randi_range(0, 6)
	_kraken["hp"] = int(_kraken.hp) - dmg
	var who: String = Net.players[id].name
	_kraken.dmg[who] = int(_kraken.dmg.get(who, 0)) + dmg
	if int(_kraken.hp) <= 0:
		_kraken_dead()
	else:
		_broadcast_world()


func _kraken_dead() -> void:
	var dmg: Dictionary = _kraken.dmg
	var total := 0
	for k in dmg:
		total += int(dmg[k])
	var pool := 4000 + 1000 * dmg.size()
	var best := ""
	var best_d := -1
	for who in dmg:
		var share := int(round(pool * float(dmg[who]) / maxf(1.0, float(total))))
		Net.add_money_by_name(who, share)
		if int(dmg[who]) > best_d:
			best_d = int(dmg[who])
			best = who
		var pid := Net.id_by_name(who)
		if pid != 0:
			Ach.event(pid, "kraken")
			Rpg.add_xp(pid, "", 150)
			Net.notify(pid, "KRAKEN YENİLDİ! Payın: %s" % U.money(share))
	var bid := Net.id_by_name(best)
	if bid != 0:
		var bag: Array = _rec(bid).get("fish", [])
		if bag.size() < Jobs.BAG_SIZE:
			bag.append({"name": "Kraken Dişi", "price": 2500})
			Jobs.send_inventory(bid)
	Net.announce("Kraken yenildi! En çok vuran: %s." % best)
	_kraken = {}
	_kraken_next = Time.get_ticks_msec() / 1000.0 + randf_range(KRAKEN_EVERY[0], KRAKEN_EVERY[1])
	Net.mark_dirty()
	_broadcast_world()


func _broadcast_world() -> void:
	for id in Net.players:
		if _in_ocean(id):
			_send_world(id)


func _sink(id: int, o: Dictionary) -> void:
	o["hp"] = 40.0
	if o.get("cargo") is Dictionary and not o.cargo.is_empty():
		o["cargo"] = {}
		Cargo.send_state(id)
		Net.notify(id, "Kargon denizin dibini boyladı!", false)
	o["fuel"] = maxf(float(o.fuel), max_fuel(o.up) * 0.5)
	Net.try_spend(id, mini(TOW_FEE, int(Net.players[id].money)))
	Garage.set_ride(id, "boat")
	Homes._teleport(id, OM.ARRIVE)
	_last_pos[id] = OM.ARRIVE
	Net.tell(self, id, "on_sank", {})
	Net.notify(id, "Teknen battı! Römorkör seni Liman Adası'na çekti (%s). Tersanede tamir et." % U.money(TOW_FEE), false)
	send_state(id, false)


func _tick(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# fırtınalar sürüklenir
	if _storms.is_empty():
		for k in STORMS:
			_storms.append({"p": Vector2(randf_range(OM.OCEAN.position.x + 2500, OM.OCEAN.end.x - 1000), randf_range(OM.OCEAN.position.y + 1500, OM.OCEAN.end.y - 1000)),
				"v": Vector2(1, 0).rotated(randf() * TAU) * randf_range(40.0, 80.0), "r": randf_range(500.0, 850.0)})
	for s in _storms:
		s.p += s.v * delta
		if s.p.x < OM.OCEAN.position.x + 800 or s.p.x > OM.OCEAN.end.x - 800:
			s.v.x = -s.v.x
		if s.p.y < OM.OCEAN.position.y + 800 or s.p.y > OM.OCEAN.end.y - 800:
			s.v.y = -s.v.y
	# Kraken
	if _kraken_next == 0.0:
		_kraken_next = now + randf_range(KRAKEN_EVERY[0], KRAKEN_EVERY[1])
	if _kraken.is_empty() and now > _kraken_next:
		var anyone := false
		for id in Net.players:
			if _in_ocean(id):
				anyone = true
		if anyone:
			spawn_kraken()
		else:
			_kraken_next = now + 120.0
	elif not _kraken.is_empty() and now > float(_kraken.until):
		Net.announce("Kraken derinlere daldı... Bir dahaki sefere!")
		_kraken = {}
		_kraken_next = now + randf_range(KRAKEN_EVERY[0], KRAKEN_EVERY[1])
		_broadcast_world()
	# oyuncular: yakıt, fırtına ve Kraken hasarı
	for id in Net.players:
		var p := _pos(id)
		if not OM.in_ocean(p):
			_last_pos.erase(id)
			continue
		var rec := _rec(id)
		var o := _data(rec)
		var boat := str(Net.players[id].get("ride", "")) == "boat"
		var last: Vector2 = _last_pos.get(id, p)
		_last_pos[id] = p
		if not boat:
			continue
		var moved := minf(last.distance_to(p), 2000.0)
		var fuel0 := float(o.fuel)
		o["fuel"] = maxf(0.0, float(o.fuel) - moved * FUEL_PER_PX)
		if fuel0 > 0.0 and float(o.fuel) <= 0.0:
			Net.notify(id, "Yakıt bitti! Kürek çekerek en yakın yakıt iskelesine git.", false)
		var hull := 1.0 - 0.2 * int(o.up.get("hull", 0))
		var hp0 := float(o.hp)
		for s in _storms:
			if s.p.distance_to(p) < s.r:
				o["hp"] = float(o.hp) - 3.0 * hull * delta
		if not _kraken.is_empty() and p.distance_to(_kraken.p) < KRAKEN_REACH:
			_kraken["hit_acc"] = float(_kraken.get("hit_acc", 0.0))
			if randf() < delta / 2.0:
				o["hp"] = float(o.hp) - 12.0 * hull
				Net.notify(id, "Kraken'in dokunacağı tekneni sarstı!", false)
		if float(o.hp) <= 0.0:
			_sink(id, o)
		elif absf(hp0 - float(o.hp)) > 0.0 or moved > 0.0:
			_dmg_acc[id] = true


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_tick(delta)
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	for id in Net.players:
		if not _in_ocean(id):
			continue
		var o := _data(_rec(id))
		Net.tell(self, id, "on_fuel", {"fuel": snappedf(float(o.fuel), 0.1), "hp": snappedf(float(o.hp), 0.1)})
		_send_world(id)
	if not _dmg_acc.is_empty():
		_dmg_acc.clear()
		Net.mark_dirty()
