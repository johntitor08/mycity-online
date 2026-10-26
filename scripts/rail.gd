extends Node
## Tren hattı (1.7): Şehir Garı, Dağ İstasyonu ve Lunapark İstasyonu.
##  Tren her bölgede aynı tarifeyle (80 sn) perona girer, 20 sn bekler, çıkar. Herkes treni görür.
##  Tren perondayken gişeden bilet alıp binilir; kısa bir yolculuktan (pencereden manzara) sonra
##  hedef istasyonun peronuna inilir. Yolculukta oyuncu görünmez (trenin içindedir).

signal trip(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PRICE := 60
const TRIP_TIME := 6.0
const BOOTH_R := 120.0

# --- sunucu
var _trips := {}                   # id -> [varış zamanı, hedef]


func reset() -> void:
	_trips.clear()


func on_player_left(id: int) -> void:
	_trips.erase(id)


func send_state(_id: int) -> void:
	pass


## Şu an (sunucu saatiyle) tren nerede?
static func now_state(t: float) -> Dictionary:
	return Map.train_state(t)


## Bu noktaya en yakın istasyon (gişe menzilinde), yoksa "".
static func station_at(p: Vector2) -> String:
	for k in Map.RAIL:
		if p.distance_to(Map.RAIL[k].booth) < BOOTH_R:
			return k
	return ""


static func arrive_pos(k: String) -> Vector2:
	return Map.RAIL[k].arrive


# ------------------------------------------------------------------ istemci API

func board(to: String) -> void:
	Net.ask(self, "req_board", {"to": to})


@rpc("authority", "call_local", "reliable")
func on_trip(d: Dictionary) -> void:
	trip.emit(d)


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


@rpc("any_peer", "call_remote", "reliable")
func req_board(d: Dictionary) -> void:
	var id := Net.sender()
	var to := str(d.get("to", ""))
	if not Net.players.has(id) or not Map.RAIL.has(to) or _trips.has(id) or Police.is_jailed(id):
		return
	var here := station_at(_pos(id))
	if here == "" or here == to:
		return
	var st := Map.train_state(Time.get_unix_time_from_system())
	if not st.stopped:
		Net.notify(id, "Tren perona girmedi; %d sn sonra gelir." % int(ceil(float(st.get("next", 0.0)))), false)
		return
	if not Net.try_spend(id, PRICE):
		Net.notify(id, "Tren bileti %s." % U.money(PRICE), false)
		return
	_trips[id] = [Time.get_ticks_msec() / 1000.0 + TRIP_TIME, to]
	Garage.set_ride(id, "train")
	Net.tell(self, id, "on_trip", {"to": to, "name": Map.RAIL[to].name, "time": TRIP_TIME})
	Ach.event(id, "train")
	Bank.activity("OTO", 1)


func _process(_delta: float) -> void:
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
		Homes._teleport(id, arrive_pos(to))
		Net.notify(id, "%s'na vardın. İyi yolculuklar!" % Map.RAIL[to].name)
