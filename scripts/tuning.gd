extends Node
## Araba tuning (1.9): Yeni Mahalle'deki Tuning Garajı.
##  Motor (3 kademe, her biri +%6 hız), lastik (2 kademe: yol tutuşu; araba daha az kayar), nitro (N: kısa süreli
##  1,5 kat hız; kademe başına 1 şarj, 25 sn'de bir dolar), spoyler (+%2 hız, görünüm), neon (altta renkli ışık).
##  Araba artık kayarak döner: hızlı dönüşlerde drift yapılır; Drift Alanı'nda kesintisiz drift puanı toplanır
##  ve en iyi skor kaydedilir (sunucu hız ve süreyi denetler).
## Veri: rec["tuning"] = {engine, tires, nitro, spoiler, drift_best}; neon/spoyler görünümü rec["vstyle"]'da.

signal changed
signal nitro_fired(who: String)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const ENGINE := [6000, 12000, 20000]
const TIRES := [4000, 9000]
const NITRO := [5000, 11000]
const SPOILER_PRICE := 3000
const NEON_PRICE := 2500
const NEONS := [Color("#22d3ee"), Color("#a855f7"), Color("#f43f5e"), Color("#22c55e"), Color("#facc15"), Color("#f8fafc")]
const NEON_NAMES := ["Turkuaz", "Mor", "Kırmızı", "Yeşil", "Sarı", "Beyaz"]
const NITRO_TIME := 2.5
const NITRO_MULT := 1.5
const NITRO_RECHARGE := 25.0
const DRIFT_MAX_RATE := 400.0       # saniyede kazanılabilecek en çok drift puanı (sunucu denetimi)
const DRIFT_REWARD_STEP := 1000     # her 1000 puana 100 TL (ilk kez geçilen rekorlarda)

# --- istemci
var my := {"engine": 0, "tires": 0, "nitro": 0, "spoiler": false, "drift_best": 0, "charges": 0}
var nitro_until := 0.0               # yerel saat
var flames := {}                     # oyuncu adı -> yerel bitiş (herkesin nitro alevi)

# --- sunucu
var _charges := {}                   # id -> [şarj, son dolum zamanı]
var _nitro := {}                     # id -> bitiş (sunucu saati)
var _drift := {}                     # id -> {t0, pts}


func reset() -> void:
	my = {"engine": 0, "tires": 0, "nitro": 0, "spoiler": false, "drift_best": 0, "charges": 0}
	nitro_until = 0.0
	flames.clear()
	_charges.clear()
	_nitro.clear()
	_drift.clear()


func on_player_left(id: int) -> void:
	_charges.erase(id)
	_nitro.erase(id)
	_drift.erase(id)


static func speed_mult(t: Dictionary) -> float:
	return 1.0 + 0.06 * int(t.get("engine", 0)) + (0.02 if bool(t.get("spoiler", false)) else 0.0)


## Lastik kademesine göre yol tutuşu (araba hızı ne çabuk istenen yöne döner).
static func grip(t: Dictionary) -> float:
	return 3.2 + 1.6 * int(t.get("tires", 0))


func nitro_on() -> bool:
	return Time.get_ticks_msec() / 1000.0 < nitro_until


## Sunucu hız denetimi için: bu oyuncunun arabası en fazla kaç kat hızlanabilir?
func max_mult(id: int) -> float:
	var rec := _rec(id)
	if rec.is_empty():
		return 1.0
	var t := _data(rec)
	return speed_mult(t) * (NITRO_MULT if int(t.nitro) > 0 else 1.0)


# ------------------------------------------------------------------ istemci API

func buy(part: String, arg: int = 0) -> void:
	Net.ask(self, "req_buy", {"part": part, "arg": arg})


func fire_nitro() -> void:
	Net.ask(self, "req_nitro")


func drift_start() -> void:
	Net.ask(self, "req_drift", {"s": "start"})


func drift_end(points: int) -> void:
	Net.ask(self, "req_drift", {"s": "end", "pts": points})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_nitro(d: Dictionary) -> void:
	var until := Time.get_ticks_msec() / 1000.0 + float(d.dur)
	flames[str(d.who)] = until
	if str(d.who) == Net.my_name:
		nitro_until = until
		my["charges"] = int(d.get("left", 0))
		changed.emit()
	nitro_fired.emit(str(d.who))


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("tuning") is Dictionary:
		rec["tuning"] = {"engine": 0, "tires": 0, "nitro": 0, "spoiler": false, "drift_best": 0}
	return rec.tuning


func _charges_of(id: int) -> int:
	var t := _data(_rec(id))
	var now := Time.get_ticks_msec() / 1000.0
	var c: Array = _charges.get(id, [int(t.nitro), now])
	while int(c[0]) < int(t.nitro) and now - float(c[1]) >= NITRO_RECHARGE:
		c[0] = int(c[0]) + 1
		c[1] = float(c[1]) + NITRO_RECHARGE
	if int(c[0]) >= int(t.nitro):
		c[1] = now
	_charges[id] = c
	return int(c[0])


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var t := _data(rec)
	Net.tell(self, id, "on_state", {"engine": int(t.engine), "tires": int(t.tires), "nitro": int(t.nitro), "spoiler": bool(t.spoiler),
		"drift_best": int(t.get("drift_best", 0)), "charges": _charges_of(id), "neon": int(Garage._style(id).get("neon", -1))})


func _at_garage(id: int) -> bool:
	return (Map.TUNING.rect as Rect2).grow(90).has_point(_pos(id))


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_garage(id):
		return
	if not "car" in Garage._list(id):
		Net.notify(id, "Önce Galeri'den bir araba al.", false)
		return
	var t := _data(rec)
	var part := str(d.get("part", ""))
	var price := -1
	var msg := ""
	match part:
		"engine", "tires", "nitro":
			var table: Array = {"engine": ENGINE, "tires": TIRES, "nitro": NITRO}[part]
			var lvl := int(t[part])
			if lvl >= table.size():
				return
			price = int(table[lvl])
			msg = {"engine": "Motor %d. kademe: hız +%%%d" % [lvl + 1, (lvl + 1) * 6], "tires": "Spor lastik %d. kademe: araba daha az kayar" % [lvl + 1],
				"nitro": "Nitro %d. kademe: %d şarj (N tuşu)" % [lvl + 1, lvl + 1]}[part]
		"spoiler":
			if bool(t.spoiler):
				return
			price = SPOILER_PRICE
			msg = "Spoyler takıldı (+%2 hız)"
		"neon":
			var c := int(d.get("arg", 0))
			if c < 0 or c >= NEONS.size() or int(Garage._style(id).get("neon", -1)) == c:
				return
			price = NEON_PRICE
			msg = "%s neon takıldı" % NEON_NAMES[c]
		_:
			return
	if not Net.try_spend(id, price):
		Net.notify(id, "%s gerekli." % U.money(price), false)
		return
	match part:
		"engine", "tires", "nitro":
			t[part] = int(t[part]) + 1
			if part == "nitro":
				_charges[id] = [int(t.nitro), Time.get_ticks_msec() / 1000.0]
		"spoiler":
			t["spoiler"] = true
			Garage._style(id)["spoiler"] = true
		"neon":
			Garage._style(id)["neon"] = int(d.get("arg", 0))
	var full := int(t.engine) == ENGINE.size() and int(t.tires) == TIRES.size() and int(t.nitro) == NITRO.size() and bool(t.spoiler)
	if full:
		Ach.event(id, "full_tune")
	Net.mark_dirty()
	Garage.send_state(id)
	send_state(id)
	Net.notify(id, msg)


@rpc("any_peer", "call_remote", "reliable")
func req_nitro(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or str(Net.players[id].get("ride", "")) != "car":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_nitro.get(id, 0.0)):
		return
	var c := _charges_of(id)
	if c <= 0:
		return
	_charges[id][0] = c - 1
	if c == int(_data(_rec(id)).nitro):
		_charges[id][1] = now
	_nitro[id] = now + NITRO_TIME
	var who: String = Net.players[id].name
	for pid in Net.players:
		if Map.region_of(_pos(pid)) == Map.region_of(_pos(id)):
			Net.tell(self, pid, "on_nitro", {"who": who, "dur": NITRO_TIME, "left": c - 1})


@rpc("any_peer", "call_remote", "reliable")
func req_drift(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or str(Net.players[id].get("ride", "")) != "car":
		_drift.erase(id)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if str(d.get("s", "")) == "start":
		_drift[id] = {"t0": now}
		return
	if not _drift.has(id):
		return
	var dur := now - float(_drift[id].t0)
	_drift.erase(id)
	if not Map.DRIFT.grow(80).has_point(_pos(id)):
		return
	# sunucu denetimi: süreye göre en çok bu kadar puan olabilir
	var pts := clampi(int(d.get("pts", 0)), 0, int((dur + 0.5) * DRIFT_MAX_RATE))
	if pts < 50:
		return
	var t := _data(_rec(id))
	Ach.set_max(id, "drift", pts)
	Rpg.add_xp(id, "", mini(60, pts / 50))
	if pts > int(t.get("drift_best", 0)):
		var old := int(t.get("drift_best", 0))
		t["drift_best"] = pts
		var reward := (pts / DRIFT_REWARD_STEP - old / DRIFT_REWARD_STEP) * 100
		if reward > 0:
			Net.add_money(id, reward)
		Net.notify(id, "Yeni drift rekorun: %d puan!%s" % [pts, (" +%s" % U.money(reward)) if reward > 0 else ""])
		var best = Net.save_data.get("drift_best", {})
		if not best is Dictionary or pts > int(best.get("pts", 0)):
			Net.save_data["drift_best"] = {"pts": pts, "by": Net.players[id].name}
			if pts >= 1500:
				Net.announce("Drift Alanı rekoru: %s, %d puan!" % [Net.players[id].name, pts])
		Net.mark_dirty()
		send_state(id)
