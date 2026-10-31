extends Node
## Sokak yarışı (1.9): yarış pistinin damalı bayrağında arabayla katılınır (200 TL giriş).
##  İlk katılımdan sonra 20 sn bekleme salonu; az kişi varsa bot sürücüler eklenir (en az 3 araba).
##  Geri sayımdan sonra pist kontrol noktalarından 3 tur. Sıralama canlı; para havuzu ilk üçe dağıtılır.
##  Arabadan inen ya da 150 sn'de bitiremeyen elenir.

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const FEE := 200
const HOUSE := 300
const LOBBY_TIME := 20.0
const COUNTDOWN := 4.0
const LAPS := 3
const TIMEOUT := 150.0
const MAX_RACERS := 6
const MIN_CARS := 3
const SHARES := [0.6, 0.3, 0.1]
const BOT_NAMES := ["Hızlı Hakan", "Drift Defne", "Turbo Tarık", "Nitro Nur"]
## Botların sokak güzergâhı (kontrol noktalarından geçer; bir tur)
const BOT_PATH := [Vector2(2700, 445), Vector2(1005, 445), Vector2(200, 445), Vector2(1005, 445), Vector2(1005, 1560),
	Vector2(1005, 822), Vector2(2700, 822), Vector2(2700, 445)]
const BOT_CP := [2, 4, 6, 7]         # her kontrol noktasının BOT_PATH'teki yeri

# --- istemci
var st := {}                          # {state, left, racers: [[ad, ilerleme, bitiş sn, x, y, bot]], laps, cps}

# --- sunucu
var _state := "idle"
var _t := 0.0                         # durum değişim anı
var _racers := {}                     # ad -> {id, bot, next, prog, done, speed, d}
var _pot := 0
var _sync := 0.0


func reset() -> void:
	st = {}
	_state = "idle"
	_racers.clear()
	_pot = 0


func on_player_left(id: int) -> void:
	for k in _racers.keys():
		if int(_racers[k].id) == id:
			_racers.erase(k)


func total_cps() -> int:
	return Map.RACE_CPS.size() * LAPS


## Geri sayımda arabalar kıpırdamaz.
func frozen() -> bool:
	return str(st.get("state", "")) == "countdown" and in_race(Net.my_name)


func in_race(who: String) -> bool:
	for r in st.get("racers", []):
		if str(r[0]) == who:
			return true
	return false


func next_cp() -> Vector2:
	for r in st.get("racers", []):
		if str(r[0]) == Net.my_name:
			var n := int(r[6]) if r.size() > 6 else 0
			return Map.RACE_CPS[n % Map.RACE_CPS.size()]
	return Vector2.ZERO


# ------------------------------------------------------------------ istemci API

func join() -> void:
	Net.ask(self, "req_join")


func leave() -> void:
	Net.ask(self, "req_leave")


@rpc("authority", "call_local", "unreliable_ordered")
func on_state(d: Dictionary) -> void:
	var was := str(st.get("state", ""))
	st = d
	if was != str(d.get("state", "")):
		changed.emit()


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func send_state(id: int) -> void:
	Net.tell(self, id, "on_state", _view())


func _view() -> Dictionary:
	if _state == "idle":
		return {"state": "idle"}
	var now := Time.get_ticks_msec() / 1000.0
	var list: Array = []
	for k in _racers:
		var r: Dictionary = _racers[k]
		var p: Vector2 = r.p if r.bot else _pos(int(r.id))
		list.append([k, snappedf(float(r.prog), 0.01), snappedf(float(r.done), 0.01), snappedf(p.x, 1.0), snappedf(p.y, 1.0), r.bot, int(r.next)])
	list.sort_custom(func(a, b):
		if float(a[2]) >= 0.0 and float(b[2]) >= 0.0:
			return float(a[2]) < float(b[2])
		if float(a[2]) >= 0.0 or float(b[2]) >= 0.0:
			return float(a[2]) >= 0.0
		return float(a[1]) > float(b[1]))
	var left := 0.0
	match _state:
		"lobby":
			left = LOBBY_TIME - (now - _t)
		"countdown":
			left = COUNTDOWN - (now - _t)
		"run":
			left = now - _t
	return {"state": _state, "left": snappedf(left, 0.1), "racers": list, "pot": _pot, "laps": LAPS, "cps": total_cps()}


func _broadcast() -> void:
	var v := _view()
	for id in Net.players:
		if Map.region_of(_pos(id)) == "sehir":
			Net.tell(self, id, "on_state", v)


@rpc("any_peer", "call_remote", "reliable")
func req_join(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	if _state in ["countdown", "run"]:
		Net.notify(id, "Yarış başladı; bir sonrakine katıl.", false)
		return
	if _racers.has(me):
		return
	if _pos(id).distance_to(Map.RACE_FLAG) > 160.0 and _pos(id).distance_to(Map.RACE_START) > 160.0:
		Net.notify(id, "Sokak yarışına damalı bayraktan katılınır.", false)
		return
	if str(Net.players[id].get("ride", "")) != "car":
		Net.notify(id, "Sokak yarışına arabayla katılınır (F ile bin).", false)
		return
	if _racers.size() >= MAX_RACERS:
		Net.notify(id, "Yarış dolu.", false)
		return
	if not Net.try_spend(id, FEE):
		Net.notify(id, "Giriş ücreti %s." % U.money(FEE), false)
		return
	_pot += FEE
	_racers[me] = {"id": id, "bot": false, "next": 0, "prog": 0.0, "done": -1.0, "p": Vector2.ZERO}
	if _state == "idle":
		_state = "lobby"
		_t = Time.get_ticks_msec() / 1000.0
		_pot += HOUSE
		Net.announce("%s sokak yarışı başlatıyor! 20 sn içinde arabayla damalı bayrağa gel (giriş %s)." % [me, U.money(FEE)])
	Net.notify(id, "Sokak yarışına katıldın. Havuz: %s" % U.money(_pot))
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	if _racers.has(me) and _state == "lobby":
		_racers.erase(me)
		_pot -= FEE
		Net.add_money(id, FEE)
		if _racers.is_empty():
			_state = "idle"
			_pot = 0
		_broadcast()


func _start_countdown() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var names: Array = BOT_NAMES.duplicate()
	names.shuffle()
	var k := 0
	while _racers.size() < MIN_CARS and k < names.size():
		_racers[names[k]] = {"id": 0, "bot": true, "next": 0, "prog": 0.0, "done": -1.0, "p": Map.RACE_START,
			"d": 0.0, "speed": 300.0 * 2.4 * rng.randf_range(0.78, 0.93)}
		k += 1
	var slot := 0
	for n in _racers:
		var r: Dictionary = _racers[n]
		var gp := Map.RACE_START + Vector2(60 + (slot / 2) * 90, -36 + (slot % 2) * 72)
		if r.bot:
			r["p"] = gp
		else:
			Homes._teleport(int(r.id), gp)
		slot += 1
	_state = "countdown"
	_t = Time.get_ticks_msec() / 1000.0
	_broadcast()


static func _path_len() -> float:
	var n := 0.0
	for i in BOT_PATH.size() - 1:
		n += BOT_PATH[i].distance_to(BOT_PATH[i + 1])
	return n


static func bot_pos(d: float) -> Vector2:
	var lap := _path_len()
	d = fposmod(d, lap)
	for i in BOT_PATH.size() - 1:
		var seg: float = BOT_PATH[i].distance_to(BOT_PATH[i + 1])
		if d <= seg:
			return BOT_PATH[i].lerp(BOT_PATH[i + 1], d / seg)
		d -= seg
	return BOT_PATH[-1]


## Bot ilerlemesi: yol boyunca geçtiği kontrol noktası sayısı (+ kesir).
static func _bot_progress(d: float) -> float:
	var lap := _path_len()
	var laps := floorf(d / lap)
	var in_lap := fposmod(d, lap)
	var acc := 0.0
	var marks: Array = []
	for i in BOT_PATH.size() - 1:
		acc += BOT_PATH[i].distance_to(BOT_PATH[i + 1])
		marks.append(acc)
	var cps := 0.0
	var prev := 0.0
	for c in BOT_CP.size():
		var m: float = marks[int(BOT_CP[c]) - 1]
		if in_lap >= m:
			cps += 1.0
			prev = m
		else:
			cps += (in_lap - prev) / maxf(1.0, m - prev)
			break
	return laps * BOT_CP.size() + cps


func _finish() -> void:
	var order: Array = _view().racers
	var place := 0
	var lines: Array = []
	for r in order:
		var who := str(r[0])
		var done := float(r[2])
		if done < 0.0:
			continue
		lines.append("%d. %s (%.1f sn)" % [place + 1, who, done])
		var info: Dictionary = _racers.get(who, {})
		if not info.is_empty() and not info.bot and place < SHARES.size():
			var pid := int(info.id)
			var prize := int(_pot * float(SHARES[place]))
			if Net.players.has(pid):
				Net.add_money(pid, prize)
				Rpg.add_xp(pid, "", 120 - place * 40)
				Net.notify(pid, "Sokak yarışında %d. oldun! Ödül %s" % [place + 1, U.money(prize)])
				if place == 0:
					Ach.event(pid, "street_wins")
			Ach.event(pid, "street_races")
		place += 1
	if not lines.is_empty():
		Net.announce("Sokak yarışı bitti: " + ", ".join(lines.slice(0, 3)))
	_state = "done"
	_t = Time.get_ticks_msec() / 1000.0
	_broadcast()
	Net.mark_dirty()


func _process(delta: float) -> void:
	if not Net.is_server() or _state == "idle":
		return
	var now := Time.get_ticks_msec() / 1000.0
	match _state:
		"lobby":
			for k in _racers.keys():
				var pid := int(_racers[k].id)
				if not Net.players.has(pid):
					_racers.erase(k)
			if _racers.is_empty():
				_state = "idle"
				_pot = 0
			elif now - _t >= LOBBY_TIME:
				_start_countdown()
		"countdown":
			if now - _t >= COUNTDOWN:
				_state = "run"
				_t = now
				_broadcast()
		"run":
			var el := now - _t
			var cps: Array = Map.RACE_CPS
			for k in _racers:
				var r: Dictionary = _racers[k]
				if float(r.done) >= 0.0:
					continue
				if r.bot:
					r["d"] = float(r.d) + float(r.speed) * delta
					r["p"] = bot_pos(float(r.d))
					r["prog"] = _bot_progress(float(r.d))
					r["next"] = int(r.prog) % cps.size()
					if float(r.prog) >= total_cps():
						r["done"] = el
					continue
				var pid := int(r.id)
				if not Net.players.has(pid) or str(Net.players[pid].get("ride", "")) != "car":
					r["done"] = -2.0             # elendi
					continue
				var p := _pos(pid)
				var target: Vector2 = cps[int(r.next) % cps.size()]
				if p.distance_to(target) < Map.RACE_CP_RADIUS:
					r["next"] = int(r.next) + 1
					if int(r.next) >= total_cps():
						r["done"] = el
						r["prog"] = float(total_cps())
						continue
				var prev: Vector2 = cps[(int(r.next) - 1 + cps.size()) % cps.size()] if int(r.next) > 0 else Map.RACE_START
				var nxt: Vector2 = cps[int(r.next) % cps.size()]
				var seg := maxf(1.0, prev.distance_to(nxt))
				r["prog"] = float(r.next) + clampf(1.0 - p.distance_to(nxt) / seg, 0.0, 0.99)
			# bütün oyuncular bitirdiyse (botları beklemeden) ya da süre dolduysa
			var humans_done := true
			for k in _racers:
				if not _racers[k].bot and float(_racers[k].done) == -1.0:
					humans_done = false
			if humans_done or el > TIMEOUT:
				_finish()
				return
		"done":
			if now - _t > 8.0:
				_state = "idle"
				_racers.clear()
				_pot = 0
				_broadcast()
				return
	_sync += delta
	if _sync >= 0.2:
		_sync = 0.0
		_broadcast()
