extends Node
## Otoyol ve kasabalar (2.1).
##  Şehrin batı ucundaki rampadan, Yalıkent'in ve Çamlıbel'in rampalarından arabayla otoyola çıkılır (E).
##  Otoyolda gerçek yolculuk: yol boyunca sür, gideceğin kasabanın çıkışında E. Arabadan sadece dinlenme
##  tesisinde inilir. Başka bir kasabaya varınca yolculuk sayılır (başarım).
##  Şehirler arası otobüs: her yerin otogarından bilet al (150 TL), kısa bir yolculukla öbür otogara var.
##  Kasaba hizmetleri: Yalıkent Balık Hali (balıklar %25 fazlasına), Martı Kafe; Çamlıbel Kaplıca (enerji dolar,
##  15 dk iş maaşı bonusu), Yayla Lokantası; otoyolda dinlenme tesisi (çay ve simit).
## Veri: rec["roads"] = {trips, from}

signal trip(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const BUS_PRICE := 150
const BUS_TIME := 8.0
const RAMP_R := 150.0
const SERVICES := {
	"hal": {"name": "Balık Hali", "price": 0},
	"kaplica": {"name": "Kaplıca", "price": 200, "energy": 999.0},
	"lokanta": {"name": "Yayla Lokantası", "price": 60, "energy": 40.0},
	"kafe": {"name": "Martı Kafe", "price": 30, "energy": 20.0},
	"tesis": {"name": "Dinlenme Tesisi", "price": 40, "energy": 30.0},
}
const HAL_BONUS := 1.25

# --- sunucu
var _bus := {}                      # id -> [varış, hedef]


func reset() -> void:
	_bus.clear()


func on_player_left(id: int) -> void:
	_bus.erase(id)


func send_state(_id: int) -> void:
	pass


## Sunucu ve istemci: bu noktadaki hizmet (bina önü) ya da "".
static func service_at(p: Vector2) -> String:
	var inside := Map.inst_at(p)              # 2.3: kurumun içindeyken de
	for b in Map.YK_BUILDINGS + Map.CB_BUILDINGS:
		if inside != "" and str(b.type) == inside:
			return {"balikhali": "hal", "kaplica": "kaplica", "lokanta": "lokanta", "yk_kafe": "kafe"}.get(inside, "")
		if (b.rect as Rect2).grow(40).has_point(p):
			match str(b.type):
				"balikhali":
					return "hal"
				"kaplica":
					return "kaplica"
				"lokanta":
					return "lokanta"
				"yk_kafe":
					return "kafe"
	if Map.HWY_REST.grow(40).has_point(p):
		return "tesis"
	return ""


static func otogar_at(p: Vector2) -> String:
	for k in Map.OTOGARS:
		if p.distance_to(Map.OTOGARS[k]) < 120.0:
			return k
	return ""


static func ramp_at(p: Vector2) -> String:
	for k in Map.TOWN_RAMPS:
		if p.distance_to(Map.TOWN_RAMPS[k]) < RAMP_R:
			return k
	return ""


## Otoyolda: yakındaki çıkış.
static func exit_at(p: Vector2) -> String:
	if not Map.HIGHWAY.has_point(p):
		return ""
	for k in Map.HWY_RAMPS:
		if absf(p.x - float(Map.HWY_RAMPS[k])) < 260.0:
			return k
	return ""


# ------------------------------------------------------------------ istemci API

func enter_highway() -> void:
	Net.ask(self, "req_enter")


func exit_highway(to: String) -> void:
	Net.ask(self, "req_exit", {"to": to})


func take_bus(to: String) -> void:
	Net.ask(self, "req_bus", {"to": to})


func use(k: String) -> void:
	Net.ask(self, "req_service", {"k": k})


@rpc("authority", "call_local", "reliable")
func on_trip(d: Dictionary) -> void:
	trip.emit(d)


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("roads") is Dictionary:
		rec["roads"] = {"trips": 0, "from": ""}
	return rec.roads


@rpc("any_peer", "call_remote", "reliable")
func req_enter(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var town := ramp_at(_pos(id))
	if town == "":
		return
	if str(Net.players[id].get("ride", "")) != "car":
		Net.notify(id, "Otoyola sadece arabayla çıkılır.", false)
		return
	_data(_rec(id))["from"] = town
	var x := float(Map.HWY_RAMPS[town])
	# batı ucundan doğuya, doğu ucundan batıya; ortadan doğuya doğru çıkılır
	var y := Map.HWY_ROAD.position.y + (180.0 if town == "camlibel" else 60.0)
	Homes._teleport(id, Vector2(x + (-120.0 if town == "camlibel" else 120.0), y))
	Net.notify(id, "Otoyoldasın! Gideceğin yerin çıkışında E'ye bas. (Yalıkent ortada, Çamlıbel doğu ucunda)")


@rpc("any_peer", "call_remote", "reliable")
func req_exit(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var to := str(d.get("to", ""))
	if not Map.TOWN_RAMPS.has(to) or exit_at(_pos(id)) != to:
		return
	var r := _data(_rec(id))
	var inward: Vector2 = {"sehir": Vector2(120, 0), "yalikent": Vector2(140, 0), "camlibel": Vector2(-140, 0)}[to]
	Homes._teleport(id, Map.TOWN_RAMPS[to] + inward)
	if str(r.get("from", "")) != "" and str(r.from) != to:
		r["trips"] = int(r.get("trips", 0)) + 1
		Ach.event(id, "road_trips")
		Rpg.add_xp(id, "", 40)
		Net.notify(id, "%s'e vardın! İyi yolculuklar." % Map.TOWN_NAMES[to])
	r["from"] = ""
	Net.mark_dirty()


@rpc("any_peer", "call_remote", "reliable")
func req_bus(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _bus.has(id) or Police.is_jailed(id):
		return
	var here := otogar_at(_pos(id))
	var to := str(d.get("to", ""))
	if here == "" or not Map.OTOGARS.has(to) or to == here:
		return
	if not Net.try_spend(id, BUS_PRICE):
		Net.notify(id, "Otobüs bileti %s." % U.money(BUS_PRICE), false)
		return
	_bus[id] = [Time.get_ticks_msec() / 1000.0 + BUS_TIME, to]
	Garage.set_ride(id, "train")
	Net.tell(self, id, "on_trip", {"to": to, "name": Map.TOWN_NAMES[to], "time": BUS_TIME})
	Ach.event(id, "intercity_bus")


@rpc("any_peer", "call_remote", "reliable")
func req_service(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var k := str(d.get("k", ""))
	if service_at(_pos(id)) != k or not SERVICES.has(k):
		return
	var s: Dictionary = SERVICES[k]
	if k == "hal":
		var rec := _rec(id)
		var names := {}
		for f in Jobs.LAKE_FISH + Jobs.SEA_FISH:
			names[str(f[0])] = true
		var bag: Array = rec.get("fish", [])
		var money := 0
		var n := 0
		for i in range(bag.size() - 1, -1, -1):
			if names.has(str(bag[i].name)):
				money += int(round(int(bag[i].price) * HAL_BONUS))
				bag.remove_at(i)
				n += 1
		if n == 0:
			Net.notify(id, "Kovanda satılacak balık yok.", false)
			return
		Net.add_money(id, money)
		Jobs.send_inventory(id)
		Net.mark_dirty()
		Net.notify(id, "Balık Hali'nde %d balık sattın: %s (%%%d fazlası)" % [n, U.money(money), int((HAL_BONUS - 1.0) * 100)])
		return
	if not Net.try_spend(id, int(s.price)):
		Net.notify(id, "%s %s." % [s.name, U.money(int(s.price))], false)
		return
	Rpg.add_energy(id, float(s.energy))
	if k == "kaplica":
		var r2 := Rpg.ensure(_rec(id))          # bonuslar Rpg kaydında tutulur
		if not r2.get("buffs") is Dictionary:
			r2["buffs"] = {}
		r2.buffs["work"] = maxf(float(r2.buffs.get("work", 0.0)), Time.get_unix_time_from_system()) + 900.0
		Ach.event(id, "spa")
	Rpg.send_sheet(id)
	Net.mark_dirty()
	Net.notify(id, {"kaplica": "Kaplıcada dinlendin: enerjin doldu, 15 dk iş maaşı +%15!", "lokanta": "Gözleme ve ayran: +40 enerji",
		"kafe": "Çay ve poğaça: +20 enerji", "tesis": "Dinlenme tesisinde çay ve simit: +30 enerji"}[k])


func _process(_delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _bus.keys():
		if now < float(_bus[id][0]):
			continue
		var to: String = _bus[id][1]
		_bus.erase(id)
		if not Net.players.has(id):
			continue
		Garage.set_ride(id, "")
		Homes._teleport(id, Map.OTOGARS[to] + Vector2(0, 40))
		Net.notify(id, "%s otogarına vardın." % Map.TOWN_NAMES[to])
