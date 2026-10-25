extends Node
## Lunapark (1.4, Fuar ve Havalimanı bölgesi). Şehirden servisle gidilir (20 TL).
##  Jeton gişesi: 5 jeton 40 TL. Oyunlardan bilet kazanılır, biletler ödül standında peluş/eşyaya döner.
##  Dönme dolap (2 jeton): bir tur (30 sn) gökyüzünden fuarı izle.
##  Çarpışan arabalar (2 jeton, 60 sn): diğer oyunculara ve NPC arabalara çarptıkça puan → bilet.
##   Çarpışmayı istemci bildirir, sunucu iki aracın gerçekten yan yana olduğunu denetler.
##  Atış poligonu (2 jeton, 25 sn): ördekleri vur. Hedefleri sunucu üretir, vuruşları zamanla denetler.
##  Pamuk şeker standı (yiyecek).
## Veri: rec["fair"] = {jeton, bilet}

signal changed
signal gallery_started(d: Dictionary)
signal gallery_hit(d: Dictionary)
signal gallery_ended(d: Dictionary)
signal bumper_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const SHUTTLE_PRICE := 20
const JETON_PACK := [5, 40]
const RIDE_COST := 2
const FERRIS_SEATS := 8
const FERRIS_PERIOD := 30.0
const BUMPER_TIME := 60.0
const BUMPER_NPCS := 3
const BUMP_COOLDOWN := 0.8
const GALLERY_TIME := 25.0
const GALLERY_AMMO := 30
const FAIR_FOODS := {
	"pamuk_seker": {"name": "Pamuk Şeker", "price": 15, "energy": 12},
	"lolipop": {"name": "Dev Lolipop", "price": 0, "energy": 20},
}
# ödül standı: anahtar -> [ad, bilet, tür]  (tür: furniture = eve konur, food = çantaya)
const PRIZES := {
	"lolipop": ["Dev Lolipop", 10, "food"],
	"pelus_ayi": ["Peluş Ayı", 25, "furniture"],
	"pelus_zurafa": ["Dev Peluş Zürafa", 50, "furniture"],
	"lunapark_feneri": ["Lunapark Feneri", 80, "furniture"],
}

# --- istemci
var jeton := 0
var bilet := 0
var npcs: Array = []               # çarpışan NPC arabalar [{x, y}]
var bumper_end := 0.0              # yerel: çarpışan araba turunun bitişi
var bumper_pts := 0
var gallery := {}                  # {targets, t0 (yerel), ammo}

# --- sunucu
var _ferris := {}                  # id -> bitiş zamanı
var _bumper := {}                  # id -> {end, pts}
var _bump_t := {}                  # "id:hedef" -> zaman
var _npcs: Array = []              # [{p, v}]
var _gallery := {}                 # id -> {targets, t0, hit: {}, shots, pts}
var _acc := 0.0


func reset() -> void:
	jeton = 0
	bilet = 0
	npcs = []
	gallery = {}
	_ferris.clear()
	_bumper.clear()
	_gallery.clear()
	_npcs.clear()


func on_player_left(id: int) -> void:
	_ferris.erase(id)
	_bumper.erase(id)
	_gallery.erase(id)


## Dönme dolabın açısı (herkeste aynı: sunucu saatinden).
static func ferris_angle(t: float) -> float:
	return fmod(t, FERRIS_PERIOD) / FERRIS_PERIOD * TAU


static func seat_pos(seat: int, t: float) -> Vector2:
	var a := ferris_angle(t) + seat * TAU / FERRIS_SEATS
	return Map.FERRIS + Vector2(cos(a), sin(a)) * Map.FERRIS_R


## Atış poligonu hedefleri (tohumdan): [{id, lane, t, dur, dir, gold}]
static func gallery_targets(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array = []
	var t := 0.6
	var id := 0
	while t < GALLERY_TIME - 2.0:
		var lane := rng.randi_range(0, 2)
		out.append({"id": id, "lane": lane, "t": snappedf(t, 0.01), "dur": [3.2, 2.6, 2.0][lane], "dir": 1 if rng.randf() < 0.5 else -1,
			"gold": rng.randf() < 0.08})
		id += 1
		t += rng.randf_range(0.45, 0.95)
	return out


static func target_points(tg: Dictionary) -> int:
	return 5 if tg.get("gold", false) else [1, 2, 3][int(tg.lane)]


# ------------------------------------------------------------------ istemci API

func shuttle(to_fair: bool) -> void:
	Net.ask(self, "req_shuttle", {"fair": to_fair})


func buy_jeton() -> void:
	Net.ask(self, "req_jeton")


func ride_ferris() -> void:
	Net.ask(self, "req_ferris")


func ride_bumper() -> void:
	Net.ask(self, "req_bumper")


func bump(target: String) -> void:
	Net.ask(self, "req_bump", {"t": target})


func start_gallery() -> void:
	Net.ask(self, "req_gallery")


func shoot(target_id: int) -> void:
	Net.ask(self, "req_shot", {"id": target_id})


func prize(k: String) -> void:
	Net.ask(self, "req_prize", {"k": k})


func buy_candy() -> void:
	Net.ask(self, "req_candy")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	jeton = int(d.get("jeton", jeton))
	bilet = int(d.get("bilet", bilet))
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_npcs(d: Dictionary) -> void:
	npcs = d.get("n", [])


@rpc("authority", "call_local", "reliable")
func on_bumper(d: Dictionary) -> void:
	if d.has("left"):
		bumper_end = Time.get_ticks_msec() / 1000.0 + float(d.left)
	bumper_pts = int(d.get("pts", bumper_pts))
	if d.get("end", false):
		bumper_end = 0.0
	bumper_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_gallery(d: Dictionary) -> void:
	match str(d.get("state", "")):
		"start":
			gallery = {"targets": gallery_targets(int(d.seed)), "t0": Time.get_ticks_msec() / 1000.0 + float(d.lead), "ammo": GALLERY_AMMO, "pts": 0}
			gallery_started.emit(gallery)
		"hit":
			gallery["pts"] = int(d.pts)
			gallery_hit.emit(d)
		"end":
			gallery = {}
			gallery_ended.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("fair") is Dictionary:
		rec["fair"] = {"jeton": 0, "bilet": 0}
	return rec.fair


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var f := _data(rec)
	Net.tell(self, id, "on_state", {"jeton": int(f.jeton), "bilet": int(f.bilet)})


func _spend_jeton(id: int, n: int) -> bool:
	var f := _data(_rec(id))
	if int(f.jeton) < n:
		Net.notify(id, "%d jeton lazım (gişeden 5 jeton %s)." % [n, U.money(JETON_PACK[1])], false)
		return false
	f["jeton"] = int(f.jeton) - n
	Net.mark_dirty()
	send_state(id)
	return true


func _add_bilet(id: int, n: int) -> void:
	if n <= 0:
		return
	var f := _data(_rec(id))
	f["bilet"] = int(f.bilet) + n
	Ach.event(id, "bilet", n)
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_shuttle(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Police.is_jailed(id):
		return
	var to_fair := bool(d.get("fair", true))
	var from: Vector2 = Map.SHUTTLE_CITY if to_fair else Map.SHUTTLE_FAIR
	if _pos(id).distance_to(from) > 110.0:
		return
	if not Net.try_spend(id, SHUTTLE_PRICE):
		Net.notify(id, "Servis bileti %s." % U.money(SHUTTLE_PRICE), false)
		return
	Garage.set_ride(id, "")
	Homes._teleport(id, (Map.SHUTTLE_FAIR if to_fair else Map.SHUTTLE_CITY) + Vector2(randf_range(-20, 20), -40))
	if to_fair:
		send_state(id)
		Ach.event(id, "fair")
		Net.notify(id, "Fuar ve Havalimanı'na hoş geldin! Solda lunapark, sağda havalimanı ve balon alanı.")


@rpc("any_peer", "call_remote", "reliable")
func req_jeton(_d: Dictionary) -> void:
	var id := Net.sender()
	if _pos(id).distance_to(Map.TICKET_BOOTH) > 130.0:
		return
	if not Net.try_spend(id, int(JETON_PACK[1])):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	var f := _data(_rec(id))
	f["jeton"] = int(f.jeton) + int(JETON_PACK[0])
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_candy(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _pos(id).distance_to(Map.CANDY) > 120.0:
		return
	var items: Dictionary = Rpg.ensure(rec).items
	if int(items.get("pamuk_seker", 0)) >= Rpg.MAX_FOOD_STACK or not Net.try_spend(id, int(FAIR_FOODS.pamuk_seker.price)):
		return
	items["pamuk_seker"] = int(items.get("pamuk_seker", 0)) + 1
	Rpg.send_sheet(id)
	Net.mark_dirty()
	Net.notify(id, "Pamuk şeker aldın (çantada).")


@rpc("any_peer", "call_remote", "reliable")
func req_prize(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("k", ""))
	if rec.is_empty() or not PRIZES.has(k) or _pos(id).distance_to(Map.TICKET_BOOTH) > 130.0:
		return
	var p: Array = PRIZES[k]
	var f := _data(rec)
	if int(f.bilet) < int(p[1]):
		Net.notify(id, "%d bilet lazım." % int(p[1]), false)
		return
	f["bilet"] = int(f.bilet) - int(p[1])
	if p[2] == "food":
		var items: Dictionary = Rpg.ensure(rec).items
		items[k] = int(items.get(k, 0)) + 1
		Rpg.send_sheet(id)
	else:
		Homes.give(id, k)
	Ach.event(id, "prize")
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s kazandın!%s" % [p[0], " Mobilya deponda, evine yerleştirebilirsin." if p[2] == "furniture" else ""])


# --- dönme dolap

@rpc("any_peer", "call_remote", "reliable")
func req_ferris(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _ferris.has(id):
		return
	if _pos(id).distance_to(Map.FERRIS + Vector2(0, Map.FERRIS_R + 60)) > 130.0:
		return
	if not _spend_jeton(id, RIDE_COST):
		return
	# en alttaki koltuk (açı π/2)
	var now := Land.server_now()
	var best := 0
	var bd := 99.0
	for s in FERRIS_SEATS:
		var a := fposmod(ferris_angle(now) + s * TAU / FERRIS_SEATS - PI / 2.0, TAU)
		var dd := minf(a, TAU - a)
		if dd < bd:
			bd = dd
			best = s
	_ferris[id] = Time.get_ticks_msec() / 1000.0 + FERRIS_PERIOD
	Net.players[id]["seat"] = best
	Garage.set_ride(id, "ferris")
	Homes._teleport(id, seat_pos(best, now))
	Ach.event(id, "ferris")


func _end_ferris(id: int) -> void:
	_ferris.erase(id)
	if not Net.players.has(id):
		return
	Net.players[id].erase("seat")
	Garage.set_ride(id, "")
	Homes._teleport(id, Map.FERRIS + Vector2(40, Map.FERRIS_R + 70))


# --- çarpışan arabalar

@rpc("any_peer", "call_remote", "reliable")
func req_bumper(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _bumper.has(id):
		return
	var gate := Vector2(Map.BUMPER.get_center().x, Map.BUMPER.end.y + 40)
	if _pos(id).distance_to(gate) > 130.0:
		return
	if not _spend_jeton(id, RIDE_COST):
		return
	_bumper[id] = {"end": Time.get_ticks_msec() / 1000.0 + BUMPER_TIME, "pts": 0}
	if _npcs.is_empty():
		for k in BUMPER_NPCS:
			_npcs.append({"p": Map.BUMPER.get_center() + Vector2(-140 + k * 140, -80 + (k % 2) * 160), "v": Vector2(1, 0).rotated(randf() * TAU) * 120.0})
	Garage.set_ride(id, "bumper")
	Homes._teleport(id, Vector2(Map.BUMPER.get_center().x, Map.BUMPER.end.y - 60))
	Net.tell(self, id, "on_bumper", {"left": BUMPER_TIME, "pts": 0})


@rpc("any_peer", "call_remote", "reliable")
func req_bump(d: Dictionary) -> void:
	var id := Net.sender()
	if not _bumper.has(id):
		return
	var t := str(d.get("t", ""))
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%d:%s" % [id, t]
	if now - float(_bump_t.get(key, 0.0)) < BUMP_COOLDOWN:
		return
	var other := Vector2(-1e6, -1e6)
	if t.begins_with("npc:"):
		var k := int(t.substr(4))
		if k >= 0 and k < _npcs.size():
			other = _npcs[k].p
	else:
		var oid := int(t)
		if _bumper.has(oid):
			other = _pos(oid)
	if _pos(id).distance_to(other) > 70.0:
		return
	_bump_t[key] = now
	_bumper[id].pts = int(_bumper[id].pts) + 1
	if t.begins_with("npc:"):
		var k := int(t.substr(4))
		_npcs[k].v = (other - _pos(id)).normalized() * 170.0
	Net.tell(self, id, "on_bumper", {"pts": int(_bumper[id].pts)})


func _end_bumper(id: int) -> void:
	var s: Dictionary = _bumper.get(id, {})
	_bumper.erase(id)
	if not Net.players.has(id):
		return
	var pts := int(s.get("pts", 0))
	var tickets := pts * 2 + (5 if pts >= 10 else 0)
	_add_bilet(id, tickets)
	Garage.set_ride(id, "")
	Homes._teleport(id, Vector2(Map.BUMPER.get_center().x, Map.BUMPER.end.y + 50))
	Net.tell(self, id, "on_bumper", {"end": true, "pts": pts})
	Net.notify(id, "Çarpışan arabalar bitti: %d çarpışma, +%d bilet." % [pts, tickets])
	if pts >= 15:
		Ach.event(id, "bumper_king")


func _tick_npcs(delta: float) -> void:
	var r: Rect2 = Map.BUMPER.grow(-30)
	for n in _npcs:
		var p: Vector2 = n.p + n.v * delta
		var v: Vector2 = n.v
		if p.x < r.position.x or p.x > r.end.x:
			v.x = -v.x
		if p.y < r.position.y or p.y > r.end.y:
			v.y = -v.y
		# oyuncu arabalarından sek
		for id in _bumper:
			var q := _pos(id)
			if q.distance_to(p) < 50.0:
				v = (p - q).normalized() * maxf(120.0, v.length())
		if randf() < delta * 0.4:
			v = v.rotated(randf_range(-0.8, 0.8))
		n["v"] = v
		n["p"] = p.clamp(r.position, r.end)
	for i in _npcs.size():
		for j in range(i + 1, _npcs.size()):
			if _npcs[i].p.distance_to(_npcs[j].p) < 50.0:
				var dv: Vector2 = (_npcs[i].p - _npcs[j].p).normalized()
				_npcs[i].v = dv * _npcs[i].v.length()
				_npcs[j].v = -dv * _npcs[j].v.length()


# --- atış poligonu

@rpc("any_peer", "call_remote", "reliable")
func req_gallery(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _gallery.has(id) or _pos(id).distance_to(Map.GALLERY) > 140.0:
		return
	if not _spend_jeton(id, RIDE_COST):
		return
	var seed_v := randi()
	var lead := 1.5
	_gallery[id] = {"targets": gallery_targets(seed_v), "t0": Time.get_ticks_msec() / 1000.0 + lead, "hit": {}, "shots": 0, "pts": 0}
	Net.tell(self, id, "on_gallery", {"state": "start", "seed": seed_v, "lead": lead})


@rpc("any_peer", "call_remote", "reliable")
func req_shot(d: Dictionary) -> void:
	var id := Net.sender()
	if not _gallery.has(id):
		return
	var g: Dictionary = _gallery[id]
	g["shots"] = int(g.shots) + 1
	if int(g.shots) > GALLERY_AMMO:
		return
	var tid := int(d.get("id", -1))
	if tid < 0 or tid >= g.targets.size() or g.hit.has(tid):
		return
	var tg: Dictionary = g.targets[tid]
	var t := Time.get_ticks_msec() / 1000.0 - float(g.t0)
	# hedef ekranda mı? (gecikme payıyla)
	if t < float(tg.t) - 0.2 or t > float(tg.t) + float(tg.dur) + 0.5:
		return
	g.hit[tid] = true
	g["pts"] = int(g.pts) + target_points(tg)
	Net.tell(self, id, "on_gallery", {"state": "hit", "id": tid, "pts": int(g.pts)})


func _end_gallery(id: int) -> void:
	var g: Dictionary = _gallery.get(id, {})
	_gallery.erase(id)
	if g.is_empty() or not Net.players.has(id):
		return
	var pts := int(g.pts)
	_add_bilet(id, pts)
	if pts >= 30:
		Ach.event(id, "sharpshooter")
	Net.tell(self, id, "on_gallery", {"state": "end", "pts": pts, "text": "Atış bitti: %d puan → +%d bilet" % [pts, pts]})


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _ferris.keys():
		if now >= float(_ferris[id]) or not Net.players.has(id):
			_end_ferris(id)
	for id in _bumper.keys():
		if now >= float(_bumper[id].end) or not Net.players.has(id):
			_end_bumper(id)
	for id in _gallery.keys():
		if now - float(_gallery[id].t0) > GALLERY_TIME + 0.6:
			_end_gallery(id)
	if _bumper.is_empty():
		_npcs.clear()
		return
	_tick_npcs(delta)
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	var view: Array = _npcs.map(func(n): return {"x": snappedf(n.p.x, 0.1), "y": snappedf(n.p.y, 0.1)})
	for id in Net.players:
		if Map.BUMPER.grow(500).has_point(_pos(id)):
			Net.tell(self, id, "on_npcs", {"n": view})
