extends Node
## Etkinlikler ve mini oyunlar. Sunucu belli aralıklarla sırayla şehir çapında bir etkinlik başlatır:
##   Yarış Günü (pistte en hızlı tur), Balık Turnuvası (en değerli balık), Hazine Avı (ilk bulan alır),
##   Şehir Festivali (maaşlar ve işletme müşterileri artar). İlk üçe para, XP ve klan puanı verilir.
## Yarış pisti her zaman açıktır (zamana karşı tur, rekor tablosu); etkinlik sırasında turlar yarışmaya sayılır.

signal changed
signal race_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const KINDS := {
	"race": {"name": "Yarış Günü", "dur": 300.0,
		"desc": "Pistte en hızlı turu atan kazanır! Başlangıç: doğudaki damalı bayrak (ana yolun sonu)."},
	"fish": {"name": "Balık Turnuvası", "dur": 420.0,
		"desc": "Turnuva boyunca tutulan en değerli tek balık kazanır. Göl, iskele ya da tekne fark etmez."},
	"treasure": {"name": "Hazine Avı", "dur": 420.0,
		"desc": "Şehirde bir hazine sandığı saklandı! Haritadaki sarı alanda ara; ilk bulan alır."},
	"festival": {"name": "Şehir Festivali", "dur": 360.0,
		"desc": "Festival boyunca tüm işlerde maaş +%25, işletmelere 1,5 kat müşteri. Şehir süslendi!"},
	# 0.8: mevsimlik etkinlikler (sadece kendi mevsiminde sıraya girer)
	"snow": {"name": "Kartopu Savaşı", "dur": 300.0, "season": "winter",
		"desc": "Kışın T tuşuyla kartopu at! En çok isabet ettiren kazanır."},
	"harvest": {"name": "Hasat Festivali", "dur": 420.0, "season": "autumn",
		"desc": "Hal'de ürünler 1,5 kat fiyatına! En çok ürün toplayan kazanır."},
	"beach": {"name": "Plaj Kupası", "dur": 360.0, "season": "summer",
		"desc": "Plajdaki futbol sahasında en çok gol atan kazanır!"},
	"ev": {"name": "En Güzel Ev Yarışması", "dur": 600.0,
		"desc": "Evini mobilyalarla süsle, misafir çağır: dekor puanı + misafirlerin verdiği yıldızlar. En yüksek puan kazanır!"},
}
const GAP := 540.0                 # iki etkinlik arası bekleme
const FIRST_DELAY := 150.0         # sunucu açıldıktan sonra ilk etkinlik
const PRIZES := [3000, 1500, 750]
const PRIZE_XP := [300, 150, 75]
const PRIZE_CLAN := [100, 50, 25]
const TREASURE_PRIZE := 4000
const TREASURE_RADIUS := 45.0
const TREASURE_SHOW := 260.0       # bu kadar yaklaşınca sandık görünür
const FESTIVAL_PAY := 1.25
const FESTIVAL_CUSTOMERS := 1.5

const RACE_TIMEOUT := 180.0
const RACE_COUNTDOWN := 3.0
const LAP_REWARD := 60
const LAP_XP := 40
const LAP_REWARD_COOLDOWN := 120.0
const RECORDS := 10

# --- istemci
var current: Dictionary = {}       # {kind, name, desc, standings, area, area_r} ya da {}
var current_ends := 0.0            # yerel saat (sn)
var next_kind := ""
var next_at := 0.0                 # yerel saat (sn)
var race: Dictionary = {}          # {state, go (yerel sn), next, total, last, best}
var records: Array = []            # [{name, time, ride}]
var treasure_pos = null            # yakındaysa sandığın yeri

# --- sunucu
var _active: Dictionary = {}       # {kind, ends, scores: {ad: [puan, yazı]}, pos, area, area_r, hinted, near}
var _next_at := 0.0
var _next_kind := ""
var _order: Array = []
var _racers := {}                  # id -> {go, next, started, ride}
var _sync := 0.0


static func local_now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _now() -> float:
	return Time.get_unix_time_from_system()


func reset() -> void:
	current = {}
	race = {}
	records = []
	treasure_pos = null
	next_kind = ""
	_active = {}
	_racers.clear()


func is_active(kind: String) -> bool:
	return str(_active.get("kind", current.get("kind", ""))) == kind


## Festival maaş çarpanı (sunucu).
func pay_mult() -> float:
	return FESTIVAL_PAY if _active.get("kind", "") == "festival" else 1.0


func customer_mult() -> float:
	return FESTIVAL_CUSTOMERS if _active.get("kind", "") == "festival" else 1.0


# ------------------------------------------------------------------ istemci API

func race_start() -> void:
	Net.ask(self, "req_race_start")


func race_quit() -> void:
	Net.ask(self, "req_race_quit")


func race_time() -> float:
	if race.get("state", "") != "running":
		return 0.0
	return maxf(0.0, local_now() - float(race.go))


@rpc("authority", "call_local", "reliable")
func on_event(d: Dictionary) -> void:
	current = d.get("cur", {})
	current_ends = local_now() + float(d.get("left", 0.0))
	next_kind = str(d.get("next", ""))
	next_at = local_now() + float(d.get("next_in", 0.0))
	records = d.get("records", records)
	if current.get("kind", "") != "treasure":
		treasure_pos = null
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_treasure_near(d: Dictionary) -> void:
	treasure_pos = d.get("pos")
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_race(d: Dictionary) -> void:
	var st := str(d.get("state", ""))
	match st:
		"countdown":
			race = {"state": "countdown", "go": local_now() + float(d.t), "next": 0, "total": Map.RACE_CPS.size(), "best": d.get("best", 0.0)}
		"go":
			race["state"] = "running"
			race["go"] = local_now()
			Sfx.play("bell", -2.0)
		"cp":
			race["next"] = int(d.next)
			Sfx.play("coin", -4.0, 1.3)
		"finish":
			race = {"state": "finished", "last": float(d.time), "best": float(d.get("best", 0.0)), "record": bool(d.get("record", false))}
			Sfx.play("success", -2.0)
		_:
			race = {}
	race_changed.emit()


# ------------------------------------------------------------------ sunucu: zamanlama

func server_start() -> void:
	_active = {}
	_racers.clear()
	_order = []
	_next_kind = _pick_next()
	_next_at = _now() + FIRST_DELAY


func _pick_next() -> String:
	for _i in 12:
		if _order.is_empty():
			_order = KINDS.keys()
			_order.shuffle()
		var k: String = _order.pop_front()
		var s := str(KINDS[k].get("season", ""))
		if s == "" or s == Env.season:
			return k
	return "festival"


## Toplanan puanlı etkinlikler (kartopu, hasat, gol): oyuncunun puanına ekle.
func add_score(id: int, kind: String, n: int, fmt: String) -> void:
	if _active.get("kind", "") != kind or not Net.players.has(id) or n <= 0:
		return
	var who: String = Net.players[id].name
	var cur := float(_active.scores.get(who, [0.0, ""])[0]) + n
	_active.scores[who] = [cur, fmt % int(cur)]
	_sync = 99.0


func _store_records() -> Array:
	if not Net.save_data.get("race_records") is Array:
		Net.save_data["race_records"] = []
	return Net.save_data["race_records"]


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := _now()
	if _active.is_empty():
		if _next_at > 0.0 and now >= _next_at:
			start_event(_next_kind)
	elif now >= float(_active.ends):
		_finish()
	elif _active.kind == "treasure":
		_treasure_tick(now)
	if not _racers.is_empty():
		_race_tick(now)
	_sync += delta
	if _sync >= 5.0:
		_sync = 0.0
		_broadcast()


## Etkinliği hemen başlat (zamanlayıcı ve testler).
func start_event(kind: String) -> void:
	if not Net.is_server() or not KINDS.has(kind):
		return
	if not _active.is_empty():
		_finish()
	var info: Dictionary = KINDS[kind]
	_active = {"kind": kind, "ends": _now() + float(info.dur), "scores": {}, "near": {}}
	if kind == "treasure":
		var pos: Vector2 = Map.TREASURE_SPOTS.pick_random()
		_active["pos"] = pos
		_active["area_r"] = 320.0
		_active["area"] = pos + Vector2(randf_range(-200, 200), randf_range(-160, 160))
		_active["hinted"] = false
		Net.announce("HAZİNE AVI başladı! Sandık %s civarında saklı. Haritadaki sarı alana bak!" % Map.area_name(pos))
	else:
		Net.announce("%s başladı! %s" % [U.upper_tr(info.name), info.desc])
	if kind == "ev":
		Party.seed_contest.call_deferred()
	Net.log_line("Etkinlik başladı: %s" % info.name)
	_next_kind = _pick_next()
	_next_at = 0.0
	_broadcast()


func _finish() -> void:
	var kind: String = _active.kind
	var info: Dictionary = KINDS[kind]
	var list: Array = []
	for n in _active.scores:
		list.append([n, _active.scores[n][0], _active.scores[n][1]])
	if kind == "race":
		list.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	else:
		list.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	if kind == "festival":
		Net.announce("Şehir Festivali sona erdi. Katılan herkese teşekkürler!")
	elif kind == "treasure":
		if list.is_empty():
			Net.announce("Hazine Avı bitti: sandığı kimse bulamadı! (%s civarındaydı)" % Map.area_name(_active.pos))
	elif list.is_empty():
		Net.announce("%s bitti; katılan olmadı." % info.name)
	else:
		var parts: Array = []
		for k in mini(3, list.size()):
			var who: String = list[k][0]
			parts.append("%d. %s (%s)" % [k + 1, who, list[k][2]])
			_reward(who, PRIZES[k], PRIZE_XP[k], PRIZE_CLAN[k])
		Net.announce("%s bitti! %s" % [info.name, "  ".join(parts)])
	Net.log_line("Etkinlik bitti: %s (%d katılımcı)" % [info.name, list.size()])
	_active = {}
	_next_at = _now() + GAP
	_broadcast()


func _reward(player_name: String, money: int, xp: int, clan_points: int) -> void:
	Net.add_money_by_name(player_name, money)
	var pid := Net.id_by_name(player_name)
	if pid != 0:
		Rpg.add_xp(pid, "", xp)
		Ach.event(pid, "event_win")
		Net.notify(pid, "Etkinlik ödülü: +%s, +%d XP" % [U.money(money), xp])
	var tag := Clans.tag_of_name(player_name)
	if tag != "":
		Clans.add_points(tag, clan_points)


func _score(player_name: String, value: float, text: String, higher_better: bool) -> void:
	var old = _active.scores.get(player_name)
	if old == null or (value > float(old[0]) if higher_better else value < float(old[0])):
		_active.scores[player_name] = [value, text]
		_sync = 99.0      # bir sonraki karede yayınla


func _public() -> Dictionary:
	if _active.is_empty():
		return {}
	var kind: String = _active.kind
	var list: Array = []
	for n in _active.scores:
		list.append({"name": n, "score": float(_active.scores[n][0]), "text": str(_active.scores[n][1])})
	if kind == "race":
		list.sort_custom(func(a, b): return a.score < b.score)
	else:
		list.sort_custom(func(a, b): return a.score > b.score)
	var out := {"kind": kind, "name": KINDS[kind].name, "desc": KINDS[kind].desc, "standings": list.slice(0, 8)}
	if kind == "treasure":
		out["area"] = _active.area
		out["area_r"] = _active.area_r
	return out


func _state() -> Dictionary:
	var now := _now()
	return {"cur": _public(), "left": maxf(0.0, float(_active.get("ends", now)) - now),
		"next": _next_kind, "next_in": maxf(0.0, _next_at - now) if _next_at > 0.0 else 0.0,
		"records": _store_records().slice(0, RECORDS)}


func _broadcast() -> void:
	Net.tell_all(self, "on_event", _state())


func send_state(id: int) -> void:
	Net.tell(self, id, "on_event", _state())


func on_player_left(id: int) -> void:
	_racers.erase(id)


# ------------------------------------------------------------------ olay kancaları

## Jobs: balık yakalanınca.
func on_fish(id: int, fish_name: String, price: int) -> void:
	if _active.get("kind", "") == "fish" and Net.players.has(id):
		_score(Net.players[id].name, price, "%s %s" % [fish_name, U.money(price)], true)


# ------------------------------------------------------------------ hazine avı

func _treasure_tick(now: float) -> void:
	var pos: Vector2 = _active.pos
	if not _active.hinted and now > float(_active.ends) - KINDS.treasure.dur / 2.0:
		_active.hinted = true
		_active.area_r = 160.0
		_active.area = pos + Vector2(randf_range(-90, 90), randf_range(-70, 70))
		Net.announce("Hazine ipucu: arama alanı daraldı! (%s)" % Map.area_name(pos))
		_broadcast()
	for id in Net.players:
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
		var d := p.distance_to(pos)
		if d < TREASURE_SHOW and not _active.near.has(id):
			_active.near[id] = true
			Net.tell(self, id, "on_treasure_near", {"pos": pos})
		if d < TREASURE_RADIUS:
			var who: String = Net.players[id].name
			_active.scores[who] = [1.0, "buldu!"]
			Net.add_money(id, TREASURE_PRIZE)
			Rpg.add_xp(id, "", 250)
			var tag := Clans.tag_of_name(who)
			if tag != "":
				Clans.add_points(tag, 120)
			Ach.event(id, "treasure")
			Net.announce("%s hazine sandığını buldu ve %s kazandı!" % [who, U.money(TREASURE_PRIZE)])
			Net.notify(id, "Hazineyi buldun! +%s" % U.money(TREASURE_PRIZE))
			_active.ends = now      # bir sonraki karede biter
			return


# ------------------------------------------------------------------ yarış pisti

@rpc("any_peer", "call_remote", "reliable")
func req_race_start(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _racers.has(id):
		return
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	if p.distance_to(Map.RACE_START) > 170.0 and p.distance_to(Map.RACE_FLAG) > 170.0:
		Net.notify(id, "Yarışa başlamak için damalı bayrağın yanına git.", false)
		return
	if Police.is_jailed(id):
		return
	_racers[id] = {"go": _now() + RACE_COUNTDOWN, "next": 0, "started": false, "ride": str(Net.players[id].get("ride", ""))}
	var best := float(Net.save_data.players[Net.players[id].name].get("race_best", 0.0))
	Net.tell(self, id, "on_race", {"state": "countdown", "t": RACE_COUNTDOWN, "best": best})


@rpc("any_peer", "call_remote", "reliable")
func req_race_quit(_d: Dictionary) -> void:
	var id := Net.sender()
	if _racers.erase(id):
		Net.tell(self, id, "on_race", {"state": "none"})


func _race_tick(now: float) -> void:
	for id in _racers.keys():
		if not Net.players.has(id):
			_racers.erase(id)
			continue
		var r: Dictionary = _racers[id]
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
		if not r.started:
			if p.distance_to(Map.RACE_START) > 230.0 and p.distance_to(Map.RACE_FLAG) > 230.0:
				_racers.erase(id)
				Net.notify(id, "Erken çıkış! Geri sayım bitmeden başlangıçtan ayrıldın.", false)
				Net.tell(self, id, "on_race", {"state": "none"})
			elif now >= float(r.go):
				r.started = true
				Net.tell(self, id, "on_race", {"state": "go"})
			continue
		var ride := str(Net.players[id].get("ride", ""))
		if ride != "":
			r.ride = ride        # turda kullanılan araç kayda geçer
		if now - float(r.go) > RACE_TIMEOUT:
			_racers.erase(id)
			Net.notify(id, "Süre doldu, tur tamamlanamadı.", false)
			Net.tell(self, id, "on_race", {"state": "none"})
			continue
		var cps: Array = Map.RACE_CPS
		if p.distance_to(cps[int(r.next)]) < Map.RACE_CP_RADIUS:
			r.next = int(r.next) + 1
			if int(r.next) >= cps.size():
				_racers.erase(id)
				_lap_done(id, now - float(r.go), str(r.ride))
			else:
				Net.tell(self, id, "on_race", {"state": "cp", "next": r.next})


func _lap_done(id: int, t: float, ride: String) -> void:
	var who: String = Net.players[id].name
	var rec: Dictionary = Net.save_data.players[who]
	var best := float(rec.get("race_best", 0.0))
	var personal := best <= 0.0 or t < best
	if personal:
		rec["race_best"] = t
		best = t
	# genel rekor tablosu (kişi başı en iyi tur)
	var recs := _store_records()
	var mine := -1
	for k in recs.size():
		if recs[k].name == who:
			mine = k
	var is_record := false
	if mine < 0 or t < float(recs[mine].time):
		if mine >= 0:
			recs.remove_at(mine)
		recs.append({"name": who, "time": snappedf(t, 0.01), "ride": ride})
		recs.sort_custom(func(a, b): return float(a.time) < float(b.time))
		while recs.size() > RECORDS:
			recs.pop_back()
		is_record = not recs.is_empty() and recs[0].name == who and float(recs[0].time) == snappedf(t, 0.01)
	if _active.get("kind", "") == "race":
		_score(who, t, "%.2f sn" % t, false)
	League.best(id, "race", snappedf(t, 0.01))
	var last := float(rec.get("race_paid", 0.0))
	if _now() - last > LAP_REWARD_COOLDOWN:
		rec["race_paid"] = _now()
		Net.add_money(id, LAP_REWARD)
		Rpg.add_xp(id, "", LAP_XP)
	Rpg.quest_event(id, "race")
	Net.mark_dirty()
	Net.tell(self, id, "on_race", {"state": "finish", "time": t, "best": best, "record": is_record})
	if is_record:
		Ach.event(id, "record")
		Net.announce("YENİ PİST REKORU! %s turu %.2f saniyede tamamladı%s." % [who, t, " (%s)" % Garage.VEHICLES[ride].name.to_lower() if Garage.VEHICLES.has(ride) else " (yaya)"])
	_broadcast()
