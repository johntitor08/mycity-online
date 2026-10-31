extends Node
## Okyanus ticareti (1.7). Yakıt iskelesi olan adalar (ve Liman Adası) birer limandır.
##  Her liman kendi ada tipinin malını ucuza satar (tropik → muz, volkanik → kükürt...), başka malları
##  bölgesine göre pahalıya alır. Fiyatlar zamanla dalgalanır (sunucu saatine bağlı, herkes aynı fiyatı görür).
##  Teknenin ambarı sınırlıdır (tersanede "Ambar" yükseltmesi: 10 → 20 → 35 → 50 sandık).
##  Kargo taşırken korsan gemisi peşine düşebilir: kaçarsan kurtulursun, yakalarsa kargonun %40'ını alır,
##  zıpkınla 3 kez vurursan batar (ödül). Tekne batarsa kargo da gider.
## Veri: rec.ocean.cargo = {mal: {q, c (toplam maliyet)}}, rec.ocean.profit (toplam kâr)

signal changed
signal raids_changed

const OM = preload("res://scripts/ocean_map.gd")
const U = preload("res://scripts/util.gd")

const GOODS := {
	"muz": {"name": "Muz", "src": "tropik", "base": 22},
	"tuz": {"name": "Kaya Tuzu", "src": "kayalik", "base": 30},
	"bal": {"name": "Mangrov Balı", "src": "mangrov", "base": 44},
	"kukurt": {"name": "Kükürt", "src": "volkanik", "base": 60},
	"buz": {"name": "Buz Kalıbı", "src": "buzul", "base": 55},
	"antika": {"name": "Antika Vazo", "src": "batik", "base": 110},
}
const HOLD := [10, 20, 35, 50]
const SELL_CUT := 0.92
const RAID_MIN_VALUE := 300
const RAID_CHANCE := 1.0 / 200.0       # saniyede (kargo taşırken)
const RAID_TIME := 45.0
const RAID_SPEED := 330.0
const RAID_CATCH := 110.0
const RAID_ESCAPE := 1150.0
const RAID_HITS := 3
const RAID_REWARD := 400

# --- istemci
var cargo := {}                      # mal -> adet
var profit := 0
var raids := {}                      # sahip adı -> {x, y, hits}

# --- sunucu
var _raids := {}                     # id -> {p, until, hits, cool}
var _raid_cool := {}                 # id -> bir sonraki baskına kadar
var _acc := 0.0
var _harp_t := {}


func reset() -> void:
	cargo = {}
	profit = 0
	raids = {}
	_raids.clear()
	_raid_cool.clear()


func on_player_left(id: int) -> void:
	_raids.erase(id)
	_raid_cool.erase(id)
	_harp_t.erase(id)


static func capacity(up: Dictionary) -> int:
	return HOLD[clampi(int(up.get("hold", 0)), 0, HOLD.size() - 1)]


## Liman adaları: yakıt iskelesi olanlar + Liman Adası.
static func ports() -> Array:
	var out: Array = []
	for isl in OM.islands():
		if isl.fuel or isl.shipyard:
			out.append(int(isl.id))
	return out


static func _h01(a: int, b: String) -> float:
	return float(absi(hash(str(a) + ":" + b)) % 1000) / 1000.0


## Limanda bir malın fiyatı (alış: bu limanın kendi malıysa; satış: diğerleri). t: sunucu saati (sn).
static func price(port: int, good: String, t: float) -> int:
	var isl: Dictionary = OM.islands()[port]
	var g: Dictionary = GOODS[good]
	var wave := 1.0 + 0.18 * sin(t / 1500.0 + _h01(port, good) * TAU)
	if str(isl.type) == str(g.src):
		return maxi(1, int(round(float(g.base) * 0.55 * wave)))
	# uzak limanlar (Liman Adası'na göre) biraz daha iyi öder
	var far := clampf(Vector2(isl.c).distance_to(OM.HOME) / 14000.0, 0.0, 1.0)
	return int(round(float(g.base) * (1.05 + 0.45 * _h01(port, good) + 0.3 * far) * wave))


## Bu limanda satılan mal (limanın kendi tipi). Liman Adası muz satar.
static func local_good(port: int) -> String:
	var t := str(OM.islands()[port].type)
	for k in GOODS:
		if GOODS[k].src == t:
			return k
	return "muz"


static func port_near(p: Vector2) -> int:
	for i in ports():
		var isl: Dictionary = OM.islands()[i]
		if p.distance_to(isl.dock) < 220.0:
			return i
	return -1


func used() -> int:
	var n := 0
	for k in cargo:
		n += int(cargo[k])
	return n


# ------------------------------------------------------------------ istemci API

func buy(good: String, n: int) -> void:
	Net.ask(self, "req_buy", {"g": good, "n": n})


func sell(good: String, n: int) -> void:
	Net.ask(self, "req_sell", {"g": good, "n": n})


func harpoon_raid(owner_name: String) -> void:
	Net.ask(self, "req_harpoon", {"o": owner_name})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	cargo = d.get("cargo", {})
	profit = int(d.get("profit", 0))
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_raids(d: Dictionary) -> void:
	raids = d.get("r", {})
	raids_changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _cargo(o: Dictionary) -> Dictionary:
	if not o.get("cargo") is Dictionary:
		o["cargo"] = {}
	return o.cargo


func _value(o: Dictionary) -> int:
	var v := 0
	for k in _cargo(o):
		v += int(o.cargo[k].q) * int(GOODS[k].base)
	return v


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var o: Dictionary = Ocean._data(rec)
	var c := {}
	for k in _cargo(o):
		c[k] = int(o.cargo[k].q)
	Net.tell(self, id, "on_state", {"cargo": c, "profit": int(o.get("profit", 0))})


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var good := str(d.get("g", ""))
	var n := clampi(int(d.get("n", 0)), 1, 50)
	var port := port_near(_pos(id))
	if rec.is_empty() or port < 0 or not GOODS.has(good) or local_good(port) != good:
		return
	var o: Dictionary = Ocean._data(rec)
	var c := _cargo(o)
	var have := 0
	for k in c:
		have += int(c[k].q)
	n = mini(n, capacity(o.up) - have)
	if n <= 0:
		Net.notify(id, "Ambar dolu (%d sandık). Tersanede Ambar'ı büyütebilirsin." % capacity(o.up), false)
		return
	var p := price(port, good, Time.get_unix_time_from_system())
	var afford := mini(n, int(Net.get_money(id) / p))
	if afford <= 0:
		Net.notify(id, "%s sandığı %s." % [GOODS[good].name, U.money(p)], false)
		return
	Net.try_spend(id, afford * p)
	if not c.has(good):
		c[good] = {"q": 0, "c": 0}
	c[good]["q"] = int(c[good].q) + afford
	c[good]["c"] = int(c[good].c) + afford * p
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%d sandık %s yüklendi (%s)." % [afford, GOODS[good].name, U.money(afford * p)])


@rpc("any_peer", "call_remote", "reliable")
func req_sell(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var good := str(d.get("g", ""))
	var port := port_near(_pos(id))
	if rec.is_empty() or port < 0 or not GOODS.has(good) or local_good(port) == good:
		return
	var o: Dictionary = Ocean._data(rec)
	var c := _cargo(o)
	if not c.has(good):
		return
	var n := clampi(int(d.get("n", 0)), 1, int(c[good].q))
	var p := int(round(price(port, good, Time.get_unix_time_from_system()) * SELL_CUT))
	var cost := int(round(float(c[good].c) * n / float(c[good].q)))
	var earn := n * p
	Net.add_money(id, earn)
	c[good]["q"] = int(c[good].q) - n
	c[good]["c"] = int(c[good].c) - cost
	if int(c[good].q) <= 0:
		c.erase(good)
	o["profit"] = int(o.get("profit", 0)) + (earn - cost)
	Ach.set_max(id, "trade_profit", int(o.profit))
	Ach.event(id, "trades")
	Rpg.add_xp(id, "", maxi(1, (earn - cost) / 50))
	Net.mark_dirty()
	send_state(id)
	var gain := earn - cost
	Net.notify(id, "%d sandık %s satıldı: %s (%s %s)" % [n, GOODS[good].name, U.money(earn), "kâr" if gain >= 0 else "zarar", U.money(absi(gain))])


@rpc("any_peer", "call_remote", "reliable")
func req_harpoon(d: Dictionary) -> void:
	var id := Net.sender()
	var target := Net.id_by_name(str(d.get("o", "")))
	if not _raids.has(target) or not Net.players.has(id) or str(Net.players[id].get("ride", "")) != "boat":
		return
	var r: Dictionary = _raids[target]
	if _pos(id).distance_to(r.p) > Ocean.HARPOON_RANGE + 60.0:
		return
	if not U.rate_ok(_harp_t, id, Ocean.HARPOON_COOLDOWN):
		return
	r["hits"] = int(r.hits) + 1
	if int(r.hits) >= RAID_HITS:
		_raids.erase(target)
		Net.add_money(id, RAID_REWARD)
		Rpg.add_xp(id, "", 60)
		Ach.event(id, "raid_sunk")
		Pirates.maybe_piece(id, 0.3)
		Net.notify(id, "Korsan gemisini batırdın! (+%s)" % U.money(RAID_REWARD))
		if target != id:
			Net.notify(target, "%s korsanları batırdı, kargon kurtuldu!" % Net.players[id].name)
		_broadcast_raids()


func _end_raid(id: int, msg: String, good: bool) -> void:
	_raids.erase(id)
	_raid_cool[id] = Time.get_ticks_msec() / 1000.0 + 240.0
	Net.notify(id, msg, good)
	_broadcast_raids()


func _broadcast_raids() -> void:
	var r := {}
	for id in _raids:
		if Net.players.has(id):
			r[Net.players[id].name] = {"x": snappedf(_raids[id].p.x, 1.0), "y": snappedf(_raids[id].p.y, 1.0), "hits": int(_raids[id].hits)}
	for id in Net.players:
		if OM.in_ocean(_pos(id)):
			Net.tell(self, id, "on_raids", {"r": r})


func start_raid(id: int) -> void:
	var p := _pos(id)
	var sp := p
	for k in 24:
		var q := p + Vector2.RIGHT.rotated(randf() * TAU) * 750.0
		if OM.in_ocean(q) and OM.island_at(q, 60.0) < 0:
			sp = q
			break
	_raids[id] = {"p": sp, "until": Time.get_ticks_msec() / 1000.0 + RAID_TIME, "hits": 0, "near": 0.0}
	Net.notify(id, "KORSANLAR! Kara bayraklı bir gemi kargonun peşinde. Kaç ya da zıpkınla!", false)
	_broadcast_raids()


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _raids.keys():
		if not Net.players.has(id):
			_raids.erase(id)
			continue
		var r: Dictionary = _raids[id]
		var p := _pos(id)
		if not OM.in_ocean(p):
			_end_raid(id, "Korsanlar okyanusta kaldı.", true)
			continue
		var to: Vector2 = p - r.p
		var step: Vector2 = to.normalized() * RAID_SPEED * delta
		if OM.island_at(r.p + step, 40.0) >= 0:
			step = step.rotated(PI / 2.0)              # adanın etrafından dolaş
		r.p += step
		var dist := p.distance_to(r.p)
		if dist < RAID_CATCH:
			r["near"] = float(r.near) + delta
			if float(r.near) > 1.5:
				var o: Dictionary = Ocean._data(_rec(id))
				var lost := 0
				for k in _cargo(o).keys():
					var take := int(ceil(int(o.cargo[k].q) * 0.4))
					lost += take
					o.cargo[k]["c"] = int(o.cargo[k].c) - int(round(float(o.cargo[k].c) * take / float(o.cargo[k].q)))
					o.cargo[k]["q"] = int(o.cargo[k].q) - take
					if int(o.cargo[k].q) <= 0:
						o.cargo.erase(k)
				Net.mark_dirty()
				send_state(id)
				_end_raid(id, "Korsanlar gemine çıktı ve %d sandık kargonu aldı!" % lost, false)
				continue
		else:
			r["near"] = 0.0
		if dist > RAID_ESCAPE or now > float(r.until):
			Ach.event(id, "raid_escape")
			_end_raid(id, "Korsanları atlattın!", true)
	_acc += delta
	if _acc < 0.5:
		return
	var tick := _acc
	_acc = 0.0
	if not _raids.is_empty():
		_broadcast_raids()
	# yeni baskın: kargo taşıyan teknelere ara sıra
	for id in Net.players:
		if _raids.has(id) or now < float(_raid_cool.get(id, 0.0)) or str(Net.players[id].get("ride", "")) != "boat":
			continue
		var p := _pos(id)
		if not OM.in_ocean(p) or p.distance_to(OM.HOME) < 1500.0:
			continue
		var o: Dictionary = Ocean._data(_rec(id))
		if _value(o) >= RAID_MIN_VALUE and randf() < RAID_CHANCE * tick:
			start_raid(id)
