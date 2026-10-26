extends Node
## Spor salonu ve maraton (1.5).
##  Günlük giriş (50 TL). Koşu bandı: 15 sn boyunca A/D'ye sırayla bas, hızı yeşil bölgede tut → kondisyon.
##   Ağırlık: çubuk yeşil bölgedeyken Boşluk → 8 tekrar → kuvvet. Zamanlamayı sunucu kendi saatiyle denetler.
##  Kondisyon: en fazla +20 maksimum enerji ve yürürken (yaya) hız. Kuvvet: kaya kırarken çift darbe şansı.
##  Günde en fazla 4 antrenman (her biri 5 enerji).
##  Maraton: salonun önünden başlayan şehir parkuru (8 nokta), sadece yaya. Süre rekoru ve haftalık Maraton ligi.
## Veri: rec.rpg["fitness"] = {cardio, strength}, rec["gym"] = {day, sessions}

signal changed
signal session(d: Dictionary)
signal session_ended(d: Dictionary)
signal marathon(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PASS_PRICE := 50
const DAILY := 4
const ENERGY := 5
const CARDIO_TIME := 15.0
const CARDIO_ZONE := [4.0, 7.5]      # adım/sn
const LIFT_REPS := 8
const LIFT_PERIOD := 1.6             # çubuğun bir gidiş-geliş süresi
const LIFT_ZONE := 0.16              # yeşil bölge (0..1 aralığının ortası ± bu)
const LIFT_SLACK := 0.15             # gecikme payı (sn)
const STAT_MAX := 100
const MARATHON_TIMEOUT := 420.0

# --- istemci
var fitness := {"cardio": 0, "strength": 0}
var has_pass := false
var sessions_left := DAILY
var current := {}                    # {kind, t0 (yerel), ...}
var run := {}                        # maraton: {t0 (yerel), cp}
var best := {}                       # {n, t}

# --- sunucu
var _sess := {}                      # id -> {kind, t0, steps: [], last_k, reps, ok}
var _runs := {}                      # id -> {t0, cp}


func reset() -> void:
	fitness = {"cardio": 0, "strength": 0}
	current = {}
	run = {}
	_sess.clear()
	_runs.clear()


func on_player_left(id: int) -> void:
	_sess.erase(id)
	_runs.erase(id)


## Yürüyüş hızı çarpanı (kondisyon).
func walk_mult() -> float:
	return 1.0 + float(fitness.get("cardio", 0)) / 400.0


static func lift_pos(t: float) -> float:
	## çubuğun konumu 0..1 (üçgen dalga)
	var k := fposmod(t / LIFT_PERIOD, 1.0)
	return k * 2.0 if k < 0.5 else 2.0 - k * 2.0


# ------------------------------------------------------------------ istemci API

func buy_pass() -> void:
	Net.ask(self, "req_pass")


func train(kind: String) -> void:
	Net.ask(self, "req_train", {"kind": kind})


func step(k: int) -> void:
	Net.ask(self, "req_step", {"k": k})


func lift() -> void:
	Net.ask(self, "req_lift")


func start_marathon() -> void:
	Net.ask(self, "req_marathon")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	fitness = d.get("fitness", fitness)
	has_pass = bool(d.get("pass", false))
	sessions_left = int(d.get("left", DAILY))
	best = d.get("best", best)
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_session(d: Dictionary) -> void:
	if d.get("end", false):
		current = {}
		session_ended.emit(d)
		return
	current = {"kind": str(d.kind), "t0": Time.get_ticks_msec() / 1000.0 + float(d.get("lead", 0.0)), "reps": 0, "ok": 0}
	session.emit(current)


@rpc("authority", "call_local", "reliable")
func on_rep(d: Dictionary) -> void:
	current["reps"] = int(d.reps)
	current["ok"] = int(d.ok)
	session.emit(current)


@rpc("authority", "call_local", "reliable")
func on_marathon(d: Dictionary) -> void:
	match str(d.get("state", "")):
		"start":
			run = {"t0": Time.get_ticks_msec() / 1000.0, "cp": 1}
		"cp":
			run["cp"] = int(d.cp)
		"end":
			run = {}
	if d.has("best"):
		best = d.best
	marathon.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _fit(rec: Dictionary) -> Dictionary:
	var r := Rpg.ensure(rec)
	if not r.get("fitness") is Dictionary:
		r["fitness"] = {"cardio": 0, "strength": 0}
	return r.fitness


func _gym(rec: Dictionary) -> Dictionary:
	var today := Time.get_date_string_from_system()
	if not rec.get("gym") is Dictionary or str(rec.gym.get("day", "")) != today:
		rec["gym"] = {"day": today, "pass": false, "sessions": 0}
	return rec.gym


func _at_gym(id: int) -> bool:
	return Map.building("spor").rect.grow(70).has_point(_pos(id))


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var g := _gym(rec)
	Net.tell(self, id, "on_state", {"fitness": _fit(rec), "pass": bool(g.pass), "left": DAILY - int(g.sessions),
		"best": Net.save_data.get("marathon_best", {})})


## Kuvvetle kaya kırarken çift darbe şansı (Mountain.req_hit sorar).
func double_hit(id: int) -> bool:
	var rec := _rec(id)
	return not rec.is_empty() and randf() < float(_fit(rec).get("strength", 0)) / 200.0


@rpc("any_peer", "call_remote", "reliable")
func req_pass(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_gym(id):
		return
	var g := _gym(rec)
	if bool(g.pass):
		return
	if not Net.try_spend(id, PASS_PRICE):
		Net.notify(id, "Günlük giriş %s." % U.money(PASS_PRICE), false)
		return
	g["pass"] = true
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Günlük giriş alındı! Bugün %d antrenman yapabilirsin." % DAILY)


@rpc("any_peer", "call_remote", "reliable")
func req_train(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var kind := str(d.get("kind", ""))
	if rec.is_empty() or not kind in ["cardio", "strength"] or _sess.has(id) or not _at_gym(id):
		return
	var g := _gym(rec)
	if not bool(g.pass):
		Net.notify(id, "Önce günlük giriş al (%s)." % U.money(PASS_PRICE), false)
		return
	if int(g.sessions) >= DAILY:
		Net.notify(id, "Bugünlük yeter, kasların dinlensin! Yarın yine gel.", false)
		return
	if not Rpg.use_energy(id, ENERGY):
		Net.notify(id, "Antrenman için enerjin yok.", false)
		return
	g["sessions"] = int(g.sessions) + 1
	var lead := 1.0
	_sess[id] = {"kind": kind, "t0": _now() + lead, "steps": [], "last_k": -1, "reps": 0, "ok": 0}
	Net.mark_dirty()
	send_state(id)
	Net.tell(self, id, "on_session", {"kind": kind, "lead": lead})


@rpc("any_peer", "call_remote", "reliable")
func req_step(d: Dictionary) -> void:
	var id := Net.sender()
	var s: Dictionary = _sess.get(id, {})
	if s.is_empty() or s.kind != "cardio":
		return
	var t := _now() - float(s.t0)
	var k := int(d.get("k", -1))
	if t < 0.0 or t > CARDIO_TIME or k == int(s.last_k) or not k in [0, 1]:
		return                                   # sırayla A, D, A, D...
	s["last_k"] = k
	s.steps.append(t)


@rpc("any_peer", "call_remote", "reliable")
func req_lift(_d: Dictionary) -> void:
	var id := Net.sender()
	var s: Dictionary = _sess.get(id, {})
	if s.is_empty() or s.kind != "strength" or int(s.reps) >= LIFT_REPS:
		return
	var t := _now() - float(s.t0)
	if t < 0.0:
		return
	# gecikme payıyla: basıldığı an (biraz önce) yeşil bölgedeyse sayılır
	var ok := false
	for dt in [0.0, -LIFT_SLACK * 0.5, -LIFT_SLACK]:
		if absf(lift_pos(t + dt) - 0.5) <= LIFT_ZONE:
			ok = true
	s["reps"] = int(s.reps) + 1
	if ok:
		s["ok"] = int(s.ok) + 1
	Net.tell(self, id, "on_rep", {"reps": int(s.reps), "ok": int(s.ok), "good": ok})
	if int(s.reps) >= LIFT_REPS:
		_finish(id)


func _finish(id: int) -> void:
	var s: Dictionary = _sess.get(id, {})
	_sess.erase(id)
	var rec := _rec(id)
	if s.is_empty() or rec.is_empty():
		return
	var f := _fit(rec)
	var gain := 0
	var text := ""
	if s.kind == "cardio":
		# her yarım saniyede adım hızı yeşil bölgede mi?
		var good := 0
		var slots := int(CARDIO_TIME / 0.5)
		for k in slots:
			var n := 0
			for t in s.steps:
				if float(t) >= k * 0.5 - 0.5 and float(t) < k * 0.5 + 0.5:
					n += 1
			if n >= CARDIO_ZONE[0] and n <= CARDIO_ZONE[1]:
				good += 1
		var frac := float(good) / slots
		gain = int(round(frac * 4.0))
		text = "Koşu bitti: sürenin %%%d'i ideal tempoda. Kondisyon +%d" % [int(frac * 100), gain]
		f["cardio"] = mini(STAT_MAX, int(f.cardio) + gain)
	else:
		gain = int(round(int(s.ok) / 2.0))
		text = "Set bitti: %d/%d temiz tekrar. Kuvvet +%d" % [int(s.ok), LIFT_REPS, gain]
		f["strength"] = mini(STAT_MAX, int(f.strength) + gain)
	Rpg.add_xp(id, "", 15 + gain * 5)
	Ach.event(id, "workouts")
	Ach.set_max(id, "fitness", int(f.cardio) + int(f.strength))
	Net.mark_dirty()
	send_state(id)
	Rpg.send_sheet(id)
	Net.tell(self, id, "on_session", {"end": true, "text": text, "gain": gain})


@rpc("any_peer", "call_remote", "reliable")
func req_marathon(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _runs.has(id) or _pos(id).distance_to(Map.MARATHON[0]) > Map.MARATHON_R + 40.0:
		return
	if str(Net.players[id].get("ride", "")) != "":
		Net.notify(id, "Maraton yaya koşulur, araçtan in.", false)
		return
	_runs[id] = {"t0": _now(), "cp": 1}
	Net.tell(self, id, "on_marathon", {"state": "start"})
	Net.notify(id, "Maraton başladı! %d noktadan geçip buraya dön. Araç kullanma!" % (Map.MARATHON.size() - 1))


func _run_tick() -> void:
	for id in _runs.keys():
		var r: Dictionary = _runs[id]
		if not Net.players.has(id):
			_runs.erase(id)
			continue
		if str(Net.players[id].get("ride", "")) != "" or _now() - float(r.t0) > MARATHON_TIMEOUT:
			_runs.erase(id)
			Net.tell(self, id, "on_marathon", {"state": "end", "ok": false})
			Net.notify(id, "Maraton iptal (araç ya da süre aşımı).", false)
			continue
		var target: Vector2 = Map.MARATHON[int(r.cp)]
		if _pos(id).distance_to(target) <= Map.MARATHON_R:
			r["cp"] = int(r.cp) + 1
			if int(r.cp) >= Map.MARATHON.size():
				_finish_run(id)
			else:
				Net.tell(self, id, "on_marathon", {"state": "cp", "cp": int(r.cp)})


func _finish_run(id: int) -> void:
	var r: Dictionary = _runs[id]
	_runs.erase(id)
	var t := _now() - float(r.t0)
	var pay := clampi(int(round(900.0 - 6.0 * (t - 40.0))), 150, 900)
	Net.add_money(id, pay)
	Rpg.add_xp(id, "", 60)
	Ach.event(id, "marathon")
	League.best(id, "marathon", snappedf(t, 0.01))
	var b: Dictionary = Net.save_data.get("marathon_best", {})
	var record := b.is_empty() or t < float(b.get("t", 9999.0))
	if record:
		Net.save_data["marathon_best"] = {"n": Net.players[id].name, "t": snappedf(t, 0.01)}
		if not b.is_empty():
			Net.announce("%s maraton rekorunu kırdı: %.1f sn!" % [Net.players[id].name, t])
	Net.mark_dirty()
	Net.tell(self, id, "on_marathon", {"state": "end", "ok": true, "time": t, "pay": pay, "record": record,
		"best": Net.save_data.get("marathon_best", {})})
	Net.notify(id, "Maraton bitti: %.1f sn. +%s%s" % [t, U.money(pay), "  YENİ REKOR!" if record else ""])


func _process(_delta: float) -> void:
	if not Net.is_server():
		return
	for id in _sess.keys():
		var s: Dictionary = _sess[id]
		if s.kind == "cardio" and _now() - float(s.t0) > CARDIO_TIME:
			_finish(id)
		elif s.kind == "strength" and _now() - float(s.t0) > 40.0:
			_finish(id)
	if not _runs.is_empty():
		_run_tick()
