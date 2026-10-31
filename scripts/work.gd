extends Node
## Yeni meslekler ve şehir hizmetleri (sunucu yetkili; konumlar sunucuda doğrulanır).
##  Taksi: arabanla duraktan iş al, yolcuyu al, gideceği yere bırak (mesai sen bırakana kadar sürer).
##  Kargo: depodan 3 paket al, adreslere teslim et (hızlıysan ikramiye). Her araç olur.
##  İtfaiye: göreve başla; şehirde yangın çıkınca git, yanında E'ye basılı tutarak söndür.
##  Çöpçülük: sokaktaki çöp torbalarını topla (E), geri dönüşüm noktasına götür.
##  Otobüs: duraktan biletle başka durağa git. Çeşme: bozuk para at, dilek tut.

signal job_changed
signal world_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const TAXI_POINTS := [
	Vector2(150, 515), Vector2(700, 515), Vector2(1250, 375), Vector2(1900, 375), Vector2(2500, 375),
	Vector2(2400, 875), Vector2(1700, 875), Vector2(1080, 1200), Vector2(1080, 1580), Vector2(2200, 515),
	Vector2(800, 375), Vector2(1600, 515),
]
const TAXI_BASE := 70
const CARGO_PAY := 40
const CARGO_BONUS := 80
const CARGO_TIME := 150.0
const FIRE_PAY := 180
const FIRE_HP := 100.0
const FIRE_GROW := 1.5            # sn başına büyüme
const FIRE_SPRAY := 6.0           # bir sıkış
const FIRE_EVERY := Vector2(150.0, 300.0)
const FIRE_BURNOUT := 240.0
const TRASH_MAX := 22
const TRASH_EVERY := 15.0
const TRASH_CARRY := 10
const TRASH_PAY := 9
const BUS_FARE := 15
const FERRY_FARE := 20
const WISH_PRICE := 1
const WISHES := ["Bugün şanslı günündesin!", "Yakında güzel bir sürpriz seni bekliyor.", "Sabreden derviş muradına ermiş.",
	"Denizde nadir bir balık seni bekliyor olabilir...", "Bir dost seni düşünüyor.", "Para gelir, para gider; dostluk kalır.",
	"Bu akşam yıldızlar senden yana.", "Bir arsa almanın tam zamanı olabilir."]

# --- istemci
var job: Dictionary = {}          # {kind, stage, target, text, n, left}
var fires: Array = []             # [{id, x, y, hp}]
var trash: Array = []             # [{id, x, y}]
var carrying := 0                 # elimdeki çöp torbası

# --- sunucu
var _jobs := {}                   # id -> {kind, stage, pickup, dest, t0, targets, done}
var _fires: Array = []            # [{id, x, y, hp, t, plot}]
var _trash: Array = []
var _carry := {}                  # id -> çöp sayısı
var _firemen := {}                # id -> true (görevde)
var _next_fire := 0.0
var _trash_acc := 0.0
var _sync := 0.0
var _uid := 1


func reset() -> void:
	job = {}
	fires = []
	trash = []
	carrying = 0
	_jobs.clear()
	_fires.clear()
	_trash.clear()
	_carry.clear()
	_firemen.clear()


func on_player_left(id: int) -> void:
	_jobs.erase(id)
	_carry.erase(id)
	_firemen.erase(id)


func _now() -> float:
	return Time.get_unix_time_from_system()


# ------------------------------------------------------------------ istemci API

func taxi_start() -> void:
	Net.ask(self, "req_taxi")


func cargo_start() -> void:
	Net.ask(self, "req_cargo")


func quit_job() -> void:
	Net.ask(self, "req_quit")


func fire_duty(on: bool) -> void:
	Net.ask(self, "req_fire_duty", {"on": on})


func spray(fire_id: int) -> void:
	Net.ask(self, "req_spray", {"id": fire_id})


func pick_trash(trash_id: int) -> void:
	Net.ask(self, "req_trash", {"id": trash_id})


func recycle() -> void:
	Net.ask(self, "req_recycle")


func ride_bus(to: String) -> void:
	Net.ask(self, "req_bus", {"to": to})


func ride_ferry(to: String) -> void:
	Net.ask(self, "req_ferry", {"to": to})


func wish() -> void:
	Net.ask(self, "req_wish")


func on_duty_fire() -> bool:
	return bool(job.get("fireman", false))


@rpc("authority", "call_local", "reliable")
func on_job(d: Dictionary) -> void:
	job = d
	carrying = int(d.get("carry", carrying))
	job_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_world(d: Dictionary) -> void:
	fires = d.get("fires", fires)
	trash = d.get("trash", trash)
	world_changed.emit()


# ------------------------------------------------------------------ sunucu: ortak

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _ride(id: int) -> String:
	return str(Net.players[id].get("ride", ""))


func send_state(id: int) -> void:
	_send_job(id)
	Net.tell(self, id, "on_world", {"fires": _public_fires(), "trash": _trash})


func _send_job(id: int) -> void:
	if not Net.players.has(id):
		return
	var j: Dictionary = _jobs.get(id, {})
	var d := {"carry": int(_carry.get(id, 0)), "fireman": _firemen.has(id)}
	if not j.is_empty():
		d["kind"] = j.kind
		d["stage"] = j.stage
		match str(j.kind):
			"taxi":
				d["target"] = j.pickup if j.stage == "pickup" else j.dest
				d["text"] = "Taksi: yolcuyu al" if j.stage == "pickup" else "Taksi: yolcuyu %s bırak" % Map.area_name(j.dest)
				d["passenger"] = j.pickup if j.stage == "pickup" else null
			"cargo":
				d["target"] = j.targets[0] if not j.targets.is_empty() else Map.CARGO_DEPOT
				d["text"] = "Kargo: %d paket kaldı" % j.targets.size() if not j.targets.is_empty() else "Kargo: depoya dön"
				d["left"] = maxf(0.0, CARGO_TIME - (_now() - float(j.t0)))
	Net.tell(self, id, "on_job", d)


@rpc("any_peer", "call_remote", "reliable")
func req_quit(_d: Dictionary) -> void:
	var id := Net.sender()
	if _jobs.erase(id):
		Net.notify(id, "Mesaiyi bitirdin.")
	_send_job(id)


# ------------------------------------------------------------------ taksi

@rpc("any_peer", "call_remote", "reliable")
func req_taxi(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if _pos(id).distance_to(Map.TAXI_STAND) > 160.0:
		Net.notify(id, "Taksi durağına git.", false)
		return
	if _ride(id) != "car":
		Net.notify(id, "Taksicilik için arabana bin (F). Araba Galeri'de satılır.", false)
		return
	_new_fare(id)
	Net.notify(id, "Taksi mesaisi başladı! Yön okunu takip et, yolcuyu al.")


func _new_fare(id: int) -> void:
	var here := _pos(id)
	var pts: Array = TAXI_POINTS.duplicate()
	pts.shuffle()
	var pickup: Vector2 = pts[0]
	for p in pts:
		if p.distance_to(here) > 400.0:
			pickup = p
			break
	var dest: Vector2 = pickup
	for p in pts:
		if p.distance_to(pickup) > 900.0:
			dest = p
			break
	_jobs[id] = {"kind": "taxi", "stage": "pickup", "pickup": pickup, "dest": dest, "t0": _now()}
	_send_job(id)


func _taxi_tick(id: int, j: Dictionary) -> void:
	if _ride(id) != "car":
		return
	var p := _pos(id)
	if j.stage == "pickup" and p.distance_to(j.pickup) < 90.0:
		j.stage = "drop"
		j.t0 = _now()
		Net.notify(id, "Yolcu bindi: \"%s, lütfen.\"" % Map.area_name(j.dest))
		_send_job(id)
	elif j.stage == "drop" and p.distance_to(j.dest) < 100.0:
		var dist: float = Vector2(j.pickup).distance_to(j.dest)
		var t := _now() - float(j.t0)
		var fare := TAXI_BASE + int(dist / 18.0)
		var tip := 0
		if t < dist / 380.0 + 6.0:
			tip = int(fare * 0.3)
		Net.add_money(id, fare + tip)
		Rpg.add_xp(id, "", 25)
		Ach.event(id, "taxi")
		Bank.activity("OTO", 1)
		Net.notify(id, "Yolcu indi: +%s%s" % [U.money(fare), "  (bahşiş +%s)" % U.money(tip) if tip > 0 else ""])
		_new_fare(id)


# ------------------------------------------------------------------ kargo

static func _cargo_targets() -> Array:
	var pts: Array = []
	for i in Map.PLOT_COUNT:
		pts.append(Map.plot_front(i) + Vector2(0, 30))
	for b in Map.BUILDINGS:
		pts.append(Vector2(b.rect.get_center().x, b.rect.end.y + 16))
	pts.shuffle()
	return pts.slice(0, 3)


@rpc("any_peer", "call_remote", "reliable")
func req_cargo(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if _pos(id).distance_to(Map.CARGO_DEPOT) > 140.0:
		Net.notify(id, "Kargo deposuna git (Pazar Yeri ile Mobilyacı arası).", false)
		return
	var j: Dictionary = _jobs.get(id, {})
	if j.get("kind", "") == "cargo" and not j.targets.is_empty():
		Net.notify(id, "Önce elindeki paketleri teslim et.", false)
		return
	_jobs[id] = {"kind": "cargo", "stage": "deliver", "targets": _cargo_targets(), "t0": _now(), "done": 0}
	_send_job(id)
	Net.notify(id, "3 paket aldın! %d saniyede bitirirsen ikramiye var." % int(CARGO_TIME))


func _cargo_tick(id: int, j: Dictionary) -> void:
	if _ride(id) == "boat" or j.targets.is_empty():
		return
	if _pos(id).distance_to(j.targets[0]) < 70.0:
		j.targets.pop_front()
		j.done = int(j.done) + 1
		Net.add_money(id, CARGO_PAY)
		Rpg.add_xp(id, "", 15)
		Ach.event(id, "cargo")
		if j.targets.is_empty():
			var fast := _now() - float(j.t0) <= CARGO_TIME
			if fast:
				Net.add_money(id, CARGO_BONUS)
			Net.notify(id, "Tüm paketler teslim edildi!%s Yenisi için depoya dön." % (" Hız ikramiyesi +%s." % U.money(CARGO_BONUS) if fast else ""))
			_jobs.erase(id)
		else:
			Net.notify(id, "Paket teslim edildi: +%s" % U.money(CARGO_PAY))
		_send_job(id)


# ------------------------------------------------------------------ itfaiye

func _public_fires() -> Array:
	var out: Array = []
	for f in _fires:
		out.append({"id": f.id, "x": f.x, "y": f.y, "hp": int(f.hp)})
	return out


@rpc("any_peer", "call_remote", "reliable")
func req_fire_duty(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var on := bool(d.get("on", false))
	if on and not Map.FIRE_STATION.grow(80).has_point(_pos(id)):
		Net.notify(id, "Göreve başlamak için itfaiyeye git.", false)
		return
	if on:
		_firemen[id] = true
		if _next_fire <= 0.0 or _next_fire - _now() > 60.0:
			_next_fire = _now() + randf_range(20.0, 50.0)      # görevli varken yangın tez çıkar
	else:
		_firemen.erase(id)
	_send_job(id)
	Net.notify(id, "İtfaiye görevindesin: yangın çıkınca haritada ve ekranda görürsün. Yanına git, E'yi basılı tut." if on else "İtfaiye görevi bitti.")


@rpc("any_peer", "call_remote", "reliable")
func req_spray(d: Dictionary) -> void:
	var id := Net.sender()
	if not _firemen.has(id):
		return
	var fid := int(d.get("id", -1))
	for f in _fires:
		if int(f.id) == fid and _pos(id).distance_to(Vector2(f.x, f.y)) < 110.0:
			f.hp = float(f.hp) - FIRE_SPRAY
			if not f.has("crew"):
				f["crew"] = {}
			f.crew[id] = true
			if float(f.hp) <= 0.0:
				_extinguish(f)
			return


func _start_fire() -> void:
	var spots: Array = []
	for i in mini(Land.plots.size(), Map.PLOT_COUNT):
		var p: Dictionary = Land.plots[i]
		if p.owner != "" and int(p.level) >= 1:
			spots.append([Map.plot_rect(i).get_center() + Vector2(0, 10), i])
	for b in Map.BUILDINGS:
		spots.append([Vector2(b.rect.get_center().x, b.rect.end.y - 40), -1])
	var s: Array = spots.pick_random()
	_fires.append({"id": _uid, "x": s[0].x, "y": s[0].y, "hp": FIRE_HP, "t": _now(), "plot": s[1]})
	_uid += 1
	var where := ("arsa #%d" % (int(s[1]) + 1)) if int(s[1]) >= 0 else Map.area_name(s[0])
	Net.announce("YANGIN! %s alev aldı. İtfaiye nerede?" % where)
	for fid in _firemen:
		Net.notify(fid, "Telsiz: yangın — %s! Haritaya bak." % where, false)
	_broadcast_world()


func _extinguish(f: Dictionary) -> void:
	_fires.erase(f)
	var crew: Dictionary = f.get("crew", {})
	for cid in crew:
		if Net.players.has(cid):
			var pay := int(FIRE_PAY / float(crew.size())) + 40
			Net.add_money(cid, pay)
			Rpg.add_xp(cid, "", 60)
			Ach.event(cid, "fire")
			Net.notify(cid, "Yangın söndürüldü! +%s" % U.money(pay))
	Net.announce("Yangın söndürüldü. Kahraman itfaiyecilere teşekkürler!")
	_broadcast_world()


func _burn_out(f: Dictionary) -> void:
	_fires.erase(f)
	var i := int(f.get("plot", -1))
	if i >= 0 and i < Land.plots.size() and Land.plots[i].owner != "":
		var owner: String = Land.plots[i].owner
		var rec: Dictionary = Net.save_data.players.get(owner, {})
		var loss := mini(300, int(int(rec.get("money", 0)) * 0.02))
		if loss > 0:
			Net.add_money_by_name(owner, -loss)
			var oid := Net.id_by_name(owner)
			if oid != 0:
				Net.notify(oid, "Arsa #%d'deki yangın kendiliğinden söndü ama hasar bıraktı: -%s" % [i + 1, U.money(loss)], false)
	Net.announce("Yangın kendi kendine söndü; bu sefer itfaiye yetişemedi.")
	_broadcast_world()


# ------------------------------------------------------------------ çöpçülük

func _spawn_trash() -> void:
	if _trash.size() >= TRASH_MAX:
		return
	var pts: Array = [Vector2(randf_range(60, 2740), randf_range(372, 384)), Vector2(randf_range(60, 2740), randf_range(510, 520)),
		Vector2(randf_range(1080, 2740), randf_range(870, 880)), Vector2(randf_range(80, 900), randf_range(1470, 1610)),
		Vector2(randf_range(40, 2760), randf_range(1650, 1840))]
	var p: Vector2 = pts.pick_random()
	if Map.in_water(p):
		return
	_trash.append({"id": _uid, "x": p.x, "y": p.y})
	_uid += 1
	_broadcast_world()


@rpc("any_peer", "call_remote", "reliable")
func req_trash(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if int(_carry.get(id, 0)) >= TRASH_CARRY:
		Net.notify(id, "Ellerin dolu (%d torba). Geri dönüşüm noktasına götür." % TRASH_CARRY, false)
		return
	var tid := int(d.get("id", -1))
	for t in _trash:
		if int(t.id) == tid and _pos(id).distance_to(Vector2(t.x, t.y)) < 90.0:
			_trash.erase(t)
			_carry[id] = int(_carry.get(id, 0)) + 1
			_send_job(id)
			_broadcast_world()
			return


@rpc("any_peer", "call_remote", "reliable")
func req_recycle(_d: Dictionary) -> void:
	var id := Net.sender()
	var n := int(_carry.get(id, 0))
	if n <= 0 or _pos(id).distance_to(Map.RECYCLE) > 120.0:
		return
	_carry[id] = 0
	Net.add_money(id, n * TRASH_PAY)
	Rpg.add_xp(id, "", 6 * n)
	Ach.event(id, "trash", n)
	Net.notify(id, "%d torba geri dönüşüme gitti: +%s. Şehir tertemiz!" % [n, U.money(n * TRASH_PAY)])
	_send_job(id)


# ------------------------------------------------------------------ otobüs ve çeşme

static func stop_near(p: Vector2) -> String:
	for k in Map.BUS_STOPS:
		if p.distance_to(Map.BUS_STOPS[k][1]) < 90.0:
			return k
	return ""


@rpc("any_peer", "call_remote", "reliable")
func req_bus(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Police.is_jailed(id):
		return
	var from := stop_near(_pos(id))
	var to := str(d.get("to", ""))
	if from == "" or not Map.BUS_STOPS.has(to) or to == from:
		return
	if Map.town_of(Map.BUS_STOPS[from][1]) != Map.town_of(Map.BUS_STOPS[to][1]):
		return                  # 2.1: şehir içi otobüs kasabalar arasında gitmez (otogar var)
	if not Net.try_spend(id, BUS_FARE):
		Net.notify(id, "Otobüs bileti %s." % U.money(BUS_FARE), false)
		return
	Garage.set_ride(id, "")
	Homes._teleport(id, Map.BUS_STOPS[to][1] + Vector2(randf_range(-20, 20), 10))
	Ach.event(id, "bus")
	Net.notify(id, "Otobüsle %s durağına geldin. İyi yolculuklar!" % Map.BUS_STOPS[to][0])


static func ferry_stop_near(p: Vector2) -> String:
	for k in Map.FERRY_STOPS:
		if p.distance_to(Map.FERRY_STOPS[k][1]) < 90.0:
			return k
	return ""


@rpc("any_peer", "call_remote", "reliable")
func req_ferry(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Police.is_jailed(id):
		return
	var from := ferry_stop_near(_pos(id))
	var to := str(d.get("to", ""))
	if from == "" or not Map.FERRY_STOPS.has(to) or to == from:
		return
	if Env.weather == "storm":
		Net.notify(id, "Fırtınada feribot seferleri iptal!", false)
		return
	if not Net.try_spend(id, FERRY_FARE):
		Net.notify(id, "Feribot bileti %s." % U.money(FERRY_FARE), false)
		return
	Garage.set_ride(id, "")
	Homes._teleport(id, Map.FERRY_STOPS[to][1] + Vector2(randf_range(-15, 15), 0))
	Ach.event(id, "ferry")
	Net.notify(id, "Feribotla %s'na vardın. İyi yolculuklar!" % Map.FERRY_STOPS[to][0])


@rpc("any_peer", "call_remote", "reliable")
func req_wish(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _pos(id).distance_to(Map.FOUNTAIN) > Map.FOUNTAIN_R + 70.0:
		return
	if not Net.try_spend(id, WISH_PRICE):
		return
	Ach.event(id, "wish")
	if randf() < 0.08:
		Net.add_money(id, 100)
		Net.notify(id, "Çeşmenin dibinde parlayan bir şey... 100 TL buldun!")
	else:
		Net.notify(id, "Dilek tuttun: %s" % WISHES.pick_random())


# ------------------------------------------------------------------ zamanlayıcı

func _process(delta: float) -> void:
	if not Net.is_server():
		return
	for id in _jobs.keys():
		if not Net.players.has(id):
			_jobs.erase(id)
			continue
		var j: Dictionary = _jobs[id]
		match str(j.kind):
			"taxi":
				_taxi_tick(id, j)
			"cargo":
				_cargo_tick(id, j)
	var now := _now()
	# yangınlar: görevde itfaiyeci varken çıkar, zamanla büyür; söndürülmezse kendiliğinden söner
	if not _firemen.is_empty() and _fires.size() < 2 and now >= _next_fire:
		_next_fire = now + randf_range(FIRE_EVERY.x, FIRE_EVERY.y)
		_start_fire()
	for f in _fires.duplicate():
		f.hp = minf(FIRE_HP * 1.6, float(f.hp) + FIRE_GROW * delta)
		if now - float(f.t) > FIRE_BURNOUT:
			_burn_out(f)
	_trash_acc += delta
	if _trash_acc >= TRASH_EVERY:
		_trash_acc = 0.0
		_spawn_trash()
	_sync += delta
	if _sync >= 1.0:
		_sync = 0.0
		if not _fires.is_empty():
			_broadcast_world()


func _broadcast_world() -> void:
	Net.tell_all(self, "on_world", {"fires": _public_fires(), "trash": _trash})
