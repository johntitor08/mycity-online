extends Node
## Havalimanı ve balon (1.4, Fuar ve Havalimanı bölgesi).
##  Uçuşlar: terminalden şehre, Martı Adası'na, dağ köyüne ya da Sanayi Limanı'na hızlı uçuş (kısa uçuş animasyonu).
##  Sıcak hava balonu: balon alanından 45 sn'lik şehir turu. Balon şehrin üstünde süzülür, herkes görür;
##   turda kamera uzaklaşır (kuşbakışı), fotoğraf modu da kullanılabilir. Tur bitince balon alanına inilir.

signal flight(d: Dictionary)
signal balloon_changed
signal takeoff

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const FLIGHT_TIME := 3.0
const BALLOON_PRICE := 150

# varış: [ad, konum, fiyat]
static func destinations() -> Dictionary:
	return {
		"sehir": ["Şehir Merkezi", Map.SPAWN + Vector2(0, 75), 80],
		"ada": ["Martı Adası", Map.ISLAND.get_center() + Vector2(-140, 30), 80],
		"dag": ["Dağ Köyü", Map.MOUNTAIN_SPAWN, 120],
		"liman": ["Sanayi Limanı", Map.FERRY_STOPS.liman[1] + Vector2(0, 260), 60],
		"okyanus": ["Liman Adası (Açık Okyanus)", AIRSTRIP + Vector2(0, 60), 250],
	}

## 1.6: Liman Adası'ndaki küçük pist (okyanustan şehre dönüş uçuşu da buradan)
const AIRSTRIP := Vector2(15260, 1180)

# --- istemci
var balloon_t0 := 0.0              # yerel: balon turu başladıysa

# --- sunucu
var _flights := {}                 # id -> [varış zamanı, hedef]
var _balloon := {}                 # id -> bitiş zamanı


func reset() -> void:
	balloon_t0 = 0.0
	_flights.clear()
	_balloon.clear()


func on_player_left(id: int) -> void:
	_flights.erase(id)
	_balloon.erase(id)


func in_balloon() -> bool:
	return balloon_t0 > 0.0


func balloon_elapsed() -> float:
	return Time.get_ticks_msec() / 1000.0 - balloon_t0


# ------------------------------------------------------------------ istemci API

func fly(to: String) -> void:
	Net.ask(self, "req_fly", {"to": to})


func ride_balloon() -> void:
	Net.ask(self, "req_balloon")


@rpc("authority", "call_local", "reliable")
func on_flight(d: Dictionary) -> void:
	flight.emit(d)


@rpc("authority", "call_local", "reliable")
func on_takeoff(_d: Dictionary) -> void:
	takeoff.emit()


@rpc("authority", "call_local", "reliable")
func on_balloon(d: Dictionary) -> void:
	balloon_t0 = Time.get_ticks_msec() / 1000.0 - float(d.get("elapsed", 0.0)) if d.get("on", false) else 0.0
	balloon_changed.emit()


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _at_terminal(id: int) -> bool:
	return Map.FAIR_BUILDINGS[0].rect.grow(70).has_point(_pos(id)) or _pos(id).distance_to(AIRSTRIP) < 110.0


@rpc("any_peer", "call_remote", "reliable")
func req_fly(d: Dictionary) -> void:
	var id := Net.sender()
	var to := str(d.get("to", ""))
	var dest := destinations()
	if not Net.players.has(id) or not dest.has(to) or _flights.has(id) or not _at_terminal(id):
		return
	if Env.weather == "storm":
		Net.notify(id, "Fırtına yüzünden uçuşlar iptal.", false)
		return
	if not Net.try_spend(id, int(dest[to][2])):
		Net.notify(id, "Bilet %s." % U.money(int(dest[to][2])), false)
		return
	_flights[id] = [Time.get_ticks_msec() / 1000.0 + FLIGHT_TIME, to]
	Garage.set_ride(id, "")
	Net.tell(self, id, "on_flight", {"to": to, "name": dest[to][0], "time": FLIGHT_TIME})
	for pid in Net.players:
		if Map.FAIR.has_point(_pos(pid)):
			Net.tell(self, pid, "on_takeoff", {})
	Ach.event(id, "flights")


@rpc("any_peer", "call_remote", "reliable")
func req_balloon(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _balloon.has(id) or _pos(id).distance_to(Map.BALLOON_FIELD) > 150.0:
		return
	if Env.weather in ["storm", "rain"]:
		Net.notify(id, "Bu havada balon kalkmaz.", false)
		return
	if not Net.try_spend(id, BALLOON_PRICE):
		Net.notify(id, "Balon turu %s." % U.money(BALLOON_PRICE), false)
		return
	_balloon[id] = Time.get_ticks_msec() / 1000.0 + Map.BALLOON_TIME
	Garage.set_ride(id, "balloon")
	Homes._teleport(id, Map.balloon_at(0.0))
	Net.tell(self, id, "on_balloon", {"on": true, "elapsed": 0.0})
	Net.announce("%s sıcak hava balonuyla şehrin üstünde süzülüyor! Yukarı bak." % Net.players[id].name)


func _end_balloon(id: int) -> void:
	_balloon.erase(id)
	if not Net.players.has(id):
		return
	Garage.set_ride(id, "")
	Homes._teleport(id, Map.BALLOON_FIELD + Vector2(0, 90))
	Net.tell(self, id, "on_balloon", {"on": false})
	Ach.event(id, "balloon")
	Rpg.add_xp(id, "", 40)


func _process(_delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _flights.keys():
		if now >= float(_flights[id][0]):
			var to: String = _flights[id][1]
			_flights.erase(id)
			if Net.players.has(id):
				Homes._teleport(id, destinations()[to][1])
				Net.notify(id, "İndin: %s. İyi yolculuklar!" % destinations()[to][0])
	for id in _balloon.keys():
		if now >= float(_balloon[id]) or not Net.players.has(id):
			_end_balloon(id)
