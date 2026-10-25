extends Node
## Dağ bölgesi (1.2). Şehirdeki teleferik istasyonundan gidilir (harita dışında ayrı bir alan).
##  Maden: Dağ Evi'nden kazma al, maden ocağındaki kayaları kır (E basılı tut). Taş → kömür/demir,
##   maden damarı → gümüş/altın, kristal → elmas/ametist; ara sıra fosil çıkar (müzeye bağışlanır).
##   Madenler ambara girer, Dağ Evi'nde satılır. Madencilik yeteneği değerli maden şansını artırır.
##  Kayak: telesiyejle zirveye çık (kayak kirala ya da al), 12 kapıdan geçerek pisti in. Sunucu kapıları
##   denetler; kaçırılan kapı +3 sn ceza. Süreye göre ödül, pist rekoru ve haftalık Kayak ligi.
## Veri: rec["pickaxe"], rec["skis"], save_data["ski_best"] = {n, t}

signal changed
signal ski_result(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const CABLE_PRICE := 30
const PICKAXE_PRICE := 800
const SKIS_PRICE := 1500
const SKI_RENT := 50
const SKI_SPEED := 1.25          # yokuş aşağı (Garage.speed_of)
const MAX_ROCKS := 18
const ROCK_EVERY := 9.0
const HIT_COOLDOWN := 0.4
const HIT_RANGE := 75.0
const GATE_PENALTY := 3.0
const SKI_TIMEOUT := 90.0

# Madenler ve fosiller (ambar anahtarları): ad, Dağ Evi'nde satış fiyatı, fosil mi
const ORES := {
	"komur": {"name": "Kömür", "price": 12},
	"demir": {"name": "Demir", "price": 25},
	"gumus": {"name": "Gümüş", "price": 70},
	"altin": {"name": "Altın", "price": 180},
	"ametist": {"name": "Ametist", "price": 150},
	"kehribar": {"name": "Kehribar", "price": 120},
	"elmas": {"name": "Elmas", "price": 600},
	"f_ammonit": {"name": "Ammonit Fosili", "price": 90, "fossil": true},
	"f_trilobit": {"name": "Trilobit Fosili", "price": 110, "fossil": true},
	"f_dis": {"name": "Köpekbalığı Dişi Fosili", "price": 160, "fossil": true},
	"f_bocek": {"name": "Kehribarda Böcek", "price": 300, "fossil": true},
	"f_mamut": {"name": "Mamut Dişi", "price": 400, "fossil": true},
	"f_kemik": {"name": "Dinozor Kemiği", "price": 500, "fossil": true},
}
# kaya türü: [ağırlık, can, düşenler {anahtar: ağırlık}]
const ROCKS := {
	"tas": [70, 3, {"komur": 55, "demir": 38, "f_ammonit": 4, "f_trilobit": 3}],
	"maden": [25, 4, {"gumus": 45, "altin": 30, "demir": 15, "f_dis": 5, "kehribar": 5}],
	"kristal": [5, 5, {"elmas": 35, "ametist": 40, "f_kemik": 10, "f_mamut": 8, "f_bocek": 7}],
}
const COMMON := ["komur", "demir"]
const LODGE_FOODS := {
	"sicak_cikolata": {"name": "Sıcak Çikolata", "price": 35, "energy": 20},
	"gozleme": {"name": "Dağ Gözlemesi", "price": 60, "energy": 35},
}

# --- istemci
var rocks: Array = []              # [{id, x, y, k, hp}]
var has_pickaxe := false
var has_skis := false
var best := {}                     # {n, t} pist rekoru
var ski_t0 := 0.0                  # yerel: kayak başladıysa başlangıç
var ski_gate := 0

# --- sunucu
var _rocks: Array = []
var _uid := 1
var _acc := 0.0
var _last_hit := {}                # id -> zaman
var _hits := {}                    # id -> vuruş sayacı (enerji için)
var _ski := {}                     # id -> {t0, gate, pen, prev, missed}


func reset() -> void:
	rocks = []
	ski_t0 = 0.0
	_rocks.clear()
	_ski.clear()
	_last_hit.clear()
	_hits.clear()


func on_player_left(id: int) -> void:
	_ski.erase(id)
	_last_hit.erase(id)
	_hits.erase(id)


static func item_info(k: String) -> Dictionary:
	return ORES.get(k, {})


static func is_fossil(k: String) -> bool:
	return bool(ORES.get(k, {}).get("fossil", false))


func skiing() -> bool:
	return ski_t0 > 0.0


# ------------------------------------------------------------------ istemci API

func go_up() -> void:
	Net.ask(self, "req_cable", {"dir": "up"})


func go_down() -> void:
	Net.ask(self, "req_cable", {"dir": "down"})


func hit(rock_id: int) -> void:
	Net.ask(self, "req_hit", {"id": rock_id})


func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func sell_all(fossils: bool) -> void:
	Net.ask(self, "req_sell", {"fossils": fossils})


func ski_start() -> void:
	Net.ask(self, "req_ski")


func ski_stop() -> void:
	Net.ask(self, "req_ski_stop")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	has_pickaxe = bool(d.get("pickaxe", false))
	has_skis = bool(d.get("skis", false))
	best = d.get("best", {})
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_rocks(d: Dictionary) -> void:
	var new_rocks: Array = d.get("rocks", [])
	var ids := {}
	for r in new_rocks:
		ids[int(r.id)] = true
	for r in rocks if new_rocks.size() < rocks.size() else []:
		if not ids.has(int(r.id)):
			Sfx.play("rock_break", -4.0)       # kırıldı (yakında olan biz olmasak da duyulur)
			break
	rocks = new_rocks
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_ski(d: Dictionary) -> void:
	match str(d.get("state", "")):
		"start":
			ski_t0 = Time.get_ticks_msec() / 1000.0
			ski_gate = 0
		"gate":
			ski_gate = int(d.get("gate", 0))
			Sfx.play("tick" if d.get("ok", false) else "error", -2.0 if d.get("ok", false) else -8.0, 1.6)
		"end":
			ski_t0 = 0.0
			best = d.get("best", best)
			ski_result.emit(d)
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	Net.tell(self, id, "on_state", {"pickaxe": bool(rec.get("pickaxe", false)), "skis": bool(rec.get("skis", false)),
		"best": Net.save_data.get("ski_best", {})})
	Net.tell(self, id, "on_rocks", {"rocks": _rocks})


func _near_building(id: int, type: String, grow := 60.0) -> bool:
	for b in Map.MOUNTAIN_BUILDINGS + Map.BUILDINGS:
		if b.type == type:
			return b.rect.grow(grow).has_point(_pos(id))
	return false


@rpc("any_peer", "call_remote", "reliable")
func req_cable(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Police.is_jailed(id):
		return
	if str(d.get("dir", "")) == "up":
		if not _near_building(id, "teleferik"):
			return
		if Env.weather == "storm":
			Net.notify(id, "Fırtınada teleferik çalışmıyor.", false)
			return
		if not Net.try_spend(id, CABLE_PRICE):
			Net.notify(id, "Teleferik bileti %s." % U.money(CABLE_PRICE), false)
			return
		Garage.set_ride(id, "")
		Homes._teleport(id, Map.MOUNTAIN_SPAWN)
		Net.tell(self, id, "on_rocks", {"rocks": _rocks})
		Camp.send_state(id)
		Ach.event(id, "mountain")
		Net.notify(id, "Dağa hoş geldin! Maden ocağı solda, kayak pisti ve telesiyej sağda, Dağ Evi hemen yanında.")
	else:
		if not _near_building(id, "teleferik_dag"):
			return
		_ski_end(id, false)
		Garage.set_ride(id, "")
		Homes._teleport(id, Map.CITY_CABLE_SPAWN)


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _near_building(id, "dagevi"):
		return
	var item := str(d.get("item", ""))
	match item:
		"pickaxe", "skis":
			var key := item
			if bool(rec.get(key, false)):
				return
			var price := PICKAXE_PRICE if item == "pickaxe" else SKIS_PRICE
			if not Net.try_spend(id, price):
				Net.notify(id, "Yeterli paran yok (%s)." % U.money(price), false)
				return
			rec[key] = true
			Net.notify(id, "Kazma alındı! Maden ocağındaki kayaların yanında E'yi basılı tut." if item == "pickaxe"
				else "Kayak takımı alındı! Artık telesiyejde kiralamana gerek yok.")
		_:
			if not LODGE_FOODS.has(item):
				return
			var r := Rpg.ensure(rec)
			if int(r.items.get(item, 0)) >= Rpg.MAX_FOOD_STACK:
				Net.notify(id, "Çantan dolu.", false)
				return
			if not Net.try_spend(id, int(LODGE_FOODS[item].price)):
				Net.notify(id, "Yeterli paran yok.", false)
				return
			r.items[item] = int(r.items.get(item, 0)) + 1
			Rpg.send_sheet(id)
			Net.notify(id, "%s aldın (çantada)." % LODGE_FOODS[item].name)
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_sell(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _near_building(id, "dagevi"):
		return
	var with_fossils := bool(d.get("fossils", false))
	var store := Farm.barn(rec)
	var total := 0
	var n := 0
	for k in store.keys():
		if not ORES.has(k) or (is_fossil(k) and not with_fossils):
			continue
		total += int(ORES[k].price) * int(store[k])
		n += int(store[k])
		store.erase(k)
	if n == 0:
		Net.notify(id, "Satacak maden yok." if not with_fossils else "Satacak maden ya da fosil yok.", false)
		return
	total = Election.take_tax(total)
	Net.add_money(id, total)
	Bank.activity("MRKT", n)
	Net.mark_dirty()
	Farm.send_state(id)
	Net.notify(id, "%d parça sattın: +%s" % [n, U.money(total)])


# --- maden

func _spawn_rock() -> void:
	var total := 0
	for k in ROCKS:
		total += int(ROCKS[k][0])
	var roll := randi() % total
	var kind := "tas"
	for k in ROCKS:
		roll -= int(ROCKS[k][0])
		if roll < 0:
			kind = k
			break
	for _try in 20:
		var p := Vector2(randf_range(Map.QUARRY.position.x + 50, Map.QUARRY.end.x - 50), randf_range(Map.QUARRY.position.y + 120, Map.QUARRY.end.y - 40))
		var ok := true
		for r in _rocks:
			if Vector2(float(r.x), float(r.y)).distance_to(p) < 80.0:
				ok = false
				break
		if ok:
			_rocks.append({"id": _uid, "x": snappedf(p.x, 1.0), "y": snappedf(p.y, 1.0), "k": kind, "hp": int(ROCKS[kind][1])})
			_uid += 1
			return


func _broadcast_rocks() -> void:
	for id in Net.players:
		if Map.MOUNTAIN.has_point(_pos(id)):
			Net.tell(self, id, "on_rocks", {"rocks": _rocks})


func _drop(id: int, kind: String) -> String:
	var table: Dictionary = ROCKS[kind][2]
	var boost := 1.0 + 0.06 * (Rpg.skill(id, "mining") - 1)
	var weights := {}
	var total := 0.0
	for k in table:
		weights[k] = float(table[k]) * (1.0 if k in COMMON else boost)
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return COMMON[0]


@rpc("any_peer", "call_remote", "reliable")
func req_hit(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	if not bool(rec.get("pickaxe", false)):
		Net.notify(id, "Kaya kırmak için kazma lazım (Dağ Evi'nde %s)." % U.money(PICKAXE_PRICE), false)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_hit.get(id, 0.0)) < HIT_COOLDOWN:
		return
	var rid := int(d.get("id", -1))
	var rock: Dictionary = {}
	for r in _rocks:
		if int(r.id) == rid:
			rock = r
	if rock.is_empty() or Vector2(float(rock.x), float(rock.y)).distance_to(_pos(id)) > HIT_RANGE + 40.0:
		return
	_hits[id] = int(_hits.get(id, 0)) + 1
	if int(_hits[id]) % 2 == 0 and not Rpg.use_energy(id, 1):
		Net.notify(id, "Çok yorgunsun. Dağ Evi'nde sıcak çikolata iç ya da dinlen.", false)
		return
	_last_hit[id] = now
	rock["hp"] = int(rock.hp) - 1
	if int(rock.hp) > 0:
		_broadcast_rocks()
		return
	_rocks.erase(rock)
	var item := _drop(id, str(rock.k))
	var store := Farm.barn(rec)
	store[item] = int(store.get(item, 0)) + 1
	Rpg.add_xp(id, "mining", 8 if rock.k == "tas" else (14 if rock.k == "maden" else 25))
	Ach.event(id, "mined")
	if item == "elmas":
		Ach.event(id, "diamond")
		Net.announce("%s dağda ELMAS buldu!" % Net.players[id].name)
	if is_fossil(item):
		Ach.event(id, "fossil")
	Net.mark_dirty()
	Farm.send_state(id)
	_broadcast_rocks()
	Net.notify(id, ("Fosil buldun: %s! Müzeye bağışlayabilirsin." if is_fossil(item) else "+1 %s") % ORES[item].name)


# --- kayak

@rpc("any_peer", "call_remote", "reliable")
func req_ski(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _ski.has(id):
		return
	if _pos(id).distance_to(Map.LIFT) > 140.0:
		return
	if Env.weather == "storm":
		Net.notify(id, "Fırtınada telesiyej çalışmıyor.", false)
		return
	if not bool(rec.get("skis", false)) and not Net.try_spend(id, SKI_RENT):
		Net.notify(id, "Kayak kirası %s." % U.money(SKI_RENT), false)
		return
	Homes._teleport(id, Map.SKI_TOP)
	Garage.set_ride(id, "ski")
	_ski[id] = {"t0": Time.get_ticks_msec() / 1000.0 + 0.4, "gate": 0, "pen": 0.0, "prev": Map.SKI_TOP, "missed": 0}
	Net.tell(self, id, "on_ski", {"state": "start"})
	Ach.event(id, "summit")


@rpc("any_peer", "call_remote", "reliable")
func req_ski_stop(_d: Dictionary) -> void:
	_ski_end(Net.sender(), false)


func _ski_end(id: int, finished: bool) -> void:
	if not _ski.has(id):
		return
	var s: Dictionary = _ski[id]
	_ski.erase(id)
	if Net.players.has(id) and str(Net.players[id].get("ride", "")) == "ski":
		Garage.set_ride(id, "")
	if not finished:
		Net.tell(self, id, "on_ski", {"state": "end", "ok": false, "text": "Kayak bırakıldı."})
		return
	var t := Time.get_ticks_msec() / 1000.0 - float(s.t0) + float(s.pen)
	var pay := clampi(int(round(700.0 - 30.0 * (t - 10.0))), 60, 700)
	if int(s.missed) == 0:
		pay += 150
		Ach.event(id, "ski_clean")
	pay = int(pay * Events.pay_mult())
	Net.add_money(id, pay)
	Rpg.add_xp(id, "", 30)
	Ach.event(id, "ski")
	League.best(id, "ski", snappedf(t, 0.01))
	var b: Dictionary = Net.save_data.get("ski_best", {})
	var record := b.is_empty() or t < float(b.get("t", 9999.0))
	if record:
		Net.save_data["ski_best"] = {"n": Net.players[id].name, "t": snappedf(t, 0.01)}
		if not b.is_empty():
			Net.announce("%s kayak pistinde yeni rekor kırdı: %.2f sn!" % [Net.players[id].name, t])
	Net.mark_dirty()
	var text := "Pist bitti: %.2f sn (%d kapı kaçtı, +%d sn ceza). +%s" % [t, int(s.missed), int(s.pen), U.money(pay)]
	if record:
		text += "  YENİ PİST REKORU!"
	Net.tell(self, id, "on_ski", {"state": "end", "ok": true, "time": t, "missed": int(s.missed), "pay": pay,
		"record": record, "best": Net.save_data.get("ski_best", {}), "text": text})


func _ski_tick() -> void:
	var gates := Map.ski_gates()
	var now := Time.get_ticks_msec() / 1000.0
	for id in _ski.keys():
		if not Net.players.has(id) or str(Net.players[id].get("ride", "")) != "ski" or now - float(_ski[id].t0) > SKI_TIMEOUT:
			_ski_end(id, false)
			continue
		var s: Dictionary = _ski[id]
		var p := _pos(id)
		var prev: Vector2 = s.prev
		while int(s.gate) < gates.size():
			var g: Vector2 = gates[int(s.gate)]
			if p.y < g.y:
				break
			# kapının hizasında x'i iki konum arasında doğrusal bul
			var k := 1.0 if is_equal_approx(p.y, prev.y) else clampf((g.y - prev.y) / (p.y - prev.y), 0.0, 1.0)
			var x := lerpf(prev.x, p.x, k)
			var ok := absf(x - g.x) <= Map.SKI_GATE_W / 2.0
			if not ok:
				s["pen"] = float(s.pen) + GATE_PENALTY
				s["missed"] = int(s.missed) + 1
			s["gate"] = int(s.gate) + 1
			Net.tell(self, id, "on_ski", {"state": "gate", "gate": int(s.gate), "ok": ok})
		s["prev"] = p
		if int(s.gate) >= gates.size() and p.y >= Map.SKI_FINISH_Y:
			_ski_end(id, true)


func is_skiing(id: int) -> bool:
	return _ski.has(id)


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	if not _ski.is_empty():
		_ski_tick()
	_acc += delta
	if _acc < ROCK_EVERY:
		return
	_acc = 0.0
	if _rocks.size() < MAX_ROCKS:
		_spawn_rock()
		if _rocks.size() < 8:
			_spawn_rock()
		_broadcast_rocks()
