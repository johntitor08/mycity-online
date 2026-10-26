extends Node
## Paintball arenası (1.7, fuar bölgesinde havalimanının kuzeyi). Kırmızı ve Mavi takım.
##  Gişeden takım seçilir; "Başlat" ile maç başlar, eksik yerleri botlar doldurur (takım başına 3 kişi).
##  Modlar sırayla: "Vuruş" (ilk 10 vuruşa ulaşan takım kazanır) ve "Bayrak" (rakip bayrağı kendi üssüne
##  3 kez getiren kazanır). Sol tıkla fareye doğru boya topu atılır; vurulan 3 sn oyun dışı kalır, üssünde doğar.
##  Toplar engellerde patlar; vuruşları ve bayrakları sunucu hesaplar. Maç en fazla 3 dakika.
##  Ödül: kazanan takım 250 TL + 60 XP, kaybeden 80 TL + 30 XP. Vuruşlar haftalık Paintball ligine yazılır.

signal changed
signal shot(d: Dictionary)
signal hit(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const Avatar = preload("res://scripts/avatar.gd")
const U = preload("res://scripts/util.gd")

const TEAM_SIZE := 3
const TEAMS := ["kirmizi", "mavi"]
const TEAM_NAME := {"kirmizi": "Kırmızı", "mavi": "Mavi"}
const TEAM_COLOR := {"kirmizi": Color("#ef4444"), "mavi": Color("#3b82f6")}
const BALL_SPEED := 720.0
const BALL_LIFE := 0.9
const BALL_R := 6.0
const BODY_R := 18.0
const FIRE_COOLDOWN := 0.45
const OUT_TIME := 3.0
const MATCH_TIME := 180.0
const WIN_HITS := 10
const WIN_FLAGS := 3
const BOT_SPEED := 165.0
const BOT_NAMES := ["Boyacı Bora", "Lekeli Leyla", "Nişancı Nil", "Sıçrayan Sami", "Fırça Fikret", "Damla Deniz"]

# --- istemci (görünüm)
var st := {"phase": "idle", "mode": "hits", "score": {"kirmizi": 0, "mavi": 0}, "teams": {}, "bots": [], "flags": {}, "out": {}, "left": 0.0}
var balls: Array = []                # [{p, v, team, t0 (yerel)}]
var splats: Array = []               # [{p, team}]

# --- sunucu
var _phase := "idle"                 # idle (lobi) | play | end
var _mode := "hits"
var _next_mode := "hits"
var _teams := {}                     # ad -> takım (lobide ve maçta)
var _bots: Array = []                # [{name, team, p, app, fire_t, out_until, goal}]
var _score := {"kirmizi": 0, "mavi": 0}
var _balls: Array = []               # [{p, v, team, by, t}]
var _flags := {}                     # takım -> {p, carrier ("" | ad)}
var _out := {}                       # ad -> oyuna dönüş zamanı
var _fire_t := {}
var _until := 0.0
var _end_at := 0.0
var _sync := 0.0
var _hits := {}                      # ad -> bu maçtaki vuruş


func reset() -> void:
	st = {"phase": "idle", "mode": "hits", "score": {"kirmizi": 0, "mavi": 0}, "teams": {}, "bots": [], "flags": {}, "out": {}, "left": 0.0}
	balls = []
	splats = []
	_phase = "idle"
	_teams.clear()
	_bots.clear()
	_balls.clear()
	_out.clear()


func on_player_left(id: int) -> void:
	if Net.players.has(id):
		_teams.erase(Net.players[id].name)
		_drop_flag(Net.players[id].name)
	_fire_t.erase(id)


func my_team() -> String:
	return str(st.get("teams", {}).get(Net.my_name, ""))


func in_match() -> bool:
	return st.get("phase", "") == "play" and my_team() != ""


func is_out(who: String) -> bool:
	return st.get("out", {}).has(who)


## Arenada durulabilir mi (engeller ve duvarlar)? İstemci ve botlar kullanır.
static func free_at(p: Vector2, r: float = 14.0) -> bool:
	if not Map.ARENA.grow(-r).has_point(p):
		return false
	for c in Map.ARENA_COVER:
		if (c as Rect2).grow(r).has_point(p):
			return false
	return true


static func ball_blocked(p: Vector2) -> bool:
	if not Map.ARENA.has_point(p):
		return true
	for c in Map.ARENA_COVER:
		if (c as Rect2).has_point(p):
			return true
	return false


static func spawn_pos(team: String, k: int) -> Vector2:
	var b: Vector2 = Map.ARENA_BASE[team]
	return b + Vector2(0, (k % 3 - 1) * 60.0)


# ------------------------------------------------------------------ istemci API

func join(team: String) -> void:
	Net.ask(self, "req_join", {"team": team})


func leave_team() -> void:
	Net.ask(self, "req_leave")


func start() -> void:
	Net.ask(self, "req_start")


func fire(dir: Vector2) -> void:
	Net.ask(self, "req_fire", {"d": dir.normalized()})


@rpc("authority", "call_local", "unreliable_ordered")
func on_state(d: Dictionary) -> void:
	var was: String = st.get("phase", "")
	st = d
	if was == "play" and d.phase != "play":
		balls = []
	if was != "play" and d.phase == "play":
		splats = []
		balls = []
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_lobby(d: Dictionary) -> void:
	on_state(d)


@rpc("authority", "call_local", "unreliable")
func on_ball(d: Dictionary) -> void:
	balls.append({"p": d.p, "v": d.v, "team": d.team, "t0": Time.get_ticks_msec() / 1000.0})
	shot.emit(d)


@rpc("authority", "call_local", "reliable")
func on_hit(d: Dictionary) -> void:
	splats.append({"p": d.p, "team": d.team})
	if splats.size() > 160:
		splats.pop_front()
	# hedefe çarpan topu kaldır
	var best := -1
	var bd := 1e9
	var now := Time.get_ticks_msec() / 1000.0
	for i in balls.size():
		var b: Dictionary = balls[i]
		var bp: Vector2 = b.p + b.v * (now - float(b.t0))
		var dd := bp.distance_to(d.p)
		if b.team == d.team and dd < bd:
			bd = dd
			best = i
	if best >= 0 and bd < 80.0:
		balls.remove_at(best)
	hit.emit(d)


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _near_booth(id: int) -> bool:
	return _pos(id).distance_to(Map.ARENA_BOOTH) < 140.0


func _view() -> Dictionary:
	var bots: Array = []
	for b in _bots:
		bots.append({"name": b.name, "team": b.team, "x": snappedf(b.p.x, 1.0), "y": snappedf(b.p.y, 1.0), "app": b.app, "f": b.get("facing", "down")})
	var fl := {}
	for t in _flags:
		fl[t] = {"x": _flags[t].p.x, "y": _flags[t].p.y, "c": _flags[t].carrier}
	var out := {}
	var now := Time.get_ticks_msec() / 1000.0
	for who in _out:
		out[who] = maxf(0.0, float(_out[who]) - now)
	return {"phase": _phase, "mode": _mode if _phase != "idle" else _next_mode, "score": _score, "teams": _teams, "bots": bots,
		"flags": fl, "out": out, "left": maxf(0.0, _until - now) if _phase == "play" else 0.0}


func _audience() -> Array:
	var out: Array = []
	for id in Net.players:
		if Map.ARENA.grow(500).has_point(_pos(id)) or _teams.has(Net.players[id].name):
			out.append(id)
	return out


func _sync_all(reliable: bool = false) -> void:
	var v := _view()
	for id in _audience():
		Net.tell(self, id, "on_lobby" if reliable else "on_state", v)


func send_state(id: int) -> void:
	Net.tell(self, id, "on_lobby", _view())


@rpc("any_peer", "call_remote", "reliable")
func req_join(d: Dictionary) -> void:
	var id := Net.sender()
	var team := str(d.get("team", ""))
	if not Net.players.has(id) or not team in TEAMS or _phase == "play" or not _near_booth(id):
		return
	var n := 0
	for who in _teams:
		if _teams[who] == team:
			n += 1
	var me: String = Net.players[id].name
	if n >= TEAM_SIZE and _teams.get(me, "") != team:
		Net.notify(id, "%s takım dolu." % TEAM_NAME[team], false)
		return
	_teams[me] = team
	_sync_all(true)


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	_teams.erase(me)
	if _phase == "play":
		_drop_flag(me)
		Homes._teleport(id, Map.ARENA_BOOTH + Vector2(0, 40))
	_sync_all(true)


@rpc("any_peer", "call_remote", "reliable")
func req_start(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _phase == "play" or not _teams.has(Net.players[id].name) or not _near_booth(id):
		return
	start_match()


func start_match() -> void:
	_phase = "play"
	_mode = _next_mode
	_next_mode = "flag" if _mode == "hits" else "hits"
	_score = {"kirmizi": 0, "mavi": 0}
	_balls.clear()
	_out.clear()
	_hits.clear()
	_bots.clear()
	_until = Time.get_ticks_msec() / 1000.0 + MATCH_TIME
	_flags = {}
	for t in TEAMS:
		_flags[t] = {"p": Map.ARENA_BASE[t], "carrier": ""}
	# insanlar üslerine, eksikler bot
	var count := {"kirmizi": 0, "mavi": 0}
	for who in _teams:
		var pid := Net.id_by_name(who)
		if pid == 0:
			continue
		var t: String = _teams[who]
		Garage.set_ride(pid, "")
		Homes._teleport(pid, spawn_pos(t, count[t]))
		count[t] += 1
	var bi := 0
	for t in TEAMS:
		while count[t] < TEAM_SIZE:
			_bots.append({"name": BOT_NAMES[bi % BOT_NAMES.size()], "team": t, "p": spawn_pos(t, count[t]), "app": Avatar.random(),
				"fire_t": 0.0, "goal": Vector2.ZERO, "facing": "right" if t == "kirmizi" else "left", "strafe": randf_range(-1, 1)})
			count[t] += 1
			bi += 1
	_sync_all(true)
	for who in _teams:
		var pid := Net.id_by_name(who)
		if pid != 0:
			Net.notify(pid, "Maç başladı: %s! Sol tık: boya topu at." % ("ilk %d vuruş" % WIN_HITS if _mode == "hits" else "rakip bayrağı %d kez üssüne getir" % WIN_FLAGS))


@rpc("any_peer", "call_remote", "reliable")
func req_fire(d: Dictionary) -> void:
	var id := Net.sender()
	if _phase != "play" or not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	if not _teams.has(me) or _out.has(me):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_fire_t.get(id, 0.0)) < FIRE_COOLDOWN:
		return
	_fire_t[id] = now
	var dir: Vector2 = d.get("d", Vector2.RIGHT)
	if dir.length() < 0.1:
		return
	_spawn_ball(_pos(id), dir.normalized(), _teams[me], me)


func _spawn_ball(from: Vector2, dir: Vector2, team: String, by: String) -> void:
	var p := from + dir * (BODY_R + 4.0) + Vector2(0, -16)
	var b := {"p": p, "v": dir * BALL_SPEED, "team": team, "by": by, "t": 0.0}
	_balls.append(b)
	for id in _audience():
		Net.tell(self, id, "on_ball", {"p": p, "v": b.v, "team": team})


## Oyuncu ve bot konumları: [ad, takım, konum]
func _bodies() -> Array:
	var out: Array = []
	for who in _teams:
		var pid := Net.id_by_name(who)
		if pid != 0 and not _out.has(who):
			out.append([who, _teams[who], _pos(pid)])
	for b in _bots:
		if not _out.has(b.name):
			out.append([b.name, b.team, b.p])
	return out


func _drop_flag(who: String) -> void:
	for t in _flags:
		if _flags[t].carrier == who:
			_flags[t] = {"p": Map.ARENA_BASE[t], "carrier": ""}


func _hit(victim: String, vteam: String, by: String, team: String, p: Vector2) -> void:
	_out[victim] = Time.get_ticks_msec() / 1000.0 + OUT_TIME
	_drop_flag(victim)
	_hits[by] = int(_hits.get(by, 0)) + 1
	if _mode == "hits":
		_score[team] = int(_score[team]) + 1
	var pid := Net.id_by_name(by)
	if pid != 0:
		League.add(pid, "paint", 1.0)
		Ach.event(pid, "paint_hits")
	var vid := Net.id_by_name(victim)
	if vid != 0:
		Net.notify(vid, "%s seni boyadı! 3 sn sonra üssünde doğarsın." % by, false)
	for id in _audience():
		Net.tell(self, id, "on_hit", {"p": p, "team": team, "victim": victim, "by": by, "vteam": vteam})


func _tick(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# toplar
	var bodies := _bodies()
	for i in range(_balls.size() - 1, -1, -1):
		var b: Dictionary = _balls[i]
		var steps := 3
		var gone := false
		for s in steps:
			b.p += b.v * delta / steps
			if ball_blocked(b.p):
				for id in _audience():
					Net.tell(self, id, "on_hit", {"p": b.p, "team": b.team, "victim": "", "by": b.by, "vteam": ""})
				gone = true
				break
			for body in bodies:
				if body[1] != b.team and (body[2] + Vector2(0, -16)).distance_to(b.p) < BODY_R + BALL_R:
					_hit(body[0], body[1], b.by, b.team, b.p)
					gone = true
					break
			if gone:
				break
		b.t = float(b.t) + delta
		if gone or float(b.t) > BALL_LIFE:
			_balls.remove_at(i)
	# oyun dışından dönüş
	for who in _out.keys():
		if now >= float(_out[who]):
			_out.erase(who)
			var t: String = str(_teams.get(who, ""))
			var pid := Net.id_by_name(who)
			if pid != 0 and t != "":
				Homes._teleport(pid, spawn_pos(t, randi() % 3))
			for bt in _bots:
				if bt.name == who:
					bt.p = spawn_pos(bt.team, randi() % 3)
	# bayraklar
	if _mode == "flag":
		for body in _bodies():
			var who: String = body[0]
			var t: String = body[1]
			var p: Vector2 = body[2]
			var enemy := "mavi" if t == "kirmizi" else "kirmizi"
			var ef: Dictionary = _flags[enemy]
			if ef.carrier == "" and p.distance_to(ef.p) < 40.0:
				ef["carrier"] = who
			if ef.carrier == who:
				ef["p"] = p + Vector2(0, -30)
				if p.distance_to(Map.ARENA_BASE[t]) < 55.0 and _flags[t].carrier == "":
					_score[t] = int(_score[t]) + 1
					_flags[enemy] = {"p": Map.ARENA_BASE[enemy], "carrier": ""}
					var pid := Net.id_by_name(who)
					if pid != 0:
						Ach.event(pid, "paint_flags")
	# botlar
	for bt in _bots:
		if _out.has(bt.name):
			continue
		_bot_think(bt, delta, now)
	# bitiş
	var goal := WIN_HITS if _mode == "hits" else WIN_FLAGS
	for t in TEAMS:
		if int(_score[t]) >= goal:
			_finish(t)
			return
	if now > _until:
		_finish("" if _score.kirmizi == _score.mavi else ("kirmizi" if _score.kirmizi > _score.mavi else "mavi"))


func _bot_think(bt: Dictionary, delta: float, now: float) -> void:
	var enemy := "mavi" if bt.team == "kirmizi" else "kirmizi"
	var target := Vector2.ZERO
	var best := 1e9
	for body in _bodies():
		if body[1] == enemy:
			var dd: float = bt.p.distance_to(body[2])
			if dd < best:
				best = dd
				target = body[2]
	var goal: Vector2 = target
	if _mode == "flag":
		var ef: Dictionary = _flags[enemy]
		if ef.carrier == bt.name:
			goal = Map.ARENA_BASE[bt.team]
		elif ef.carrier == "" and randf() < 0.5:
			goal = ef.p
	if goal == Vector2.ZERO:
		return
	var to: Vector2 = goal - bt.p
	var want := to.normalized()
	if best < 260.0 and goal == target:
		want = want.orthogonal() * float(bt.strafe)            # yakındaysa yana kay
		if randf() < delta * 0.7:
			bt.strafe = -float(bt.strafe)
	if to.length() > 8.0 or goal != target:
		for k in 5:
			var dirv := want.rotated([0.0, 0.6, -0.6, 1.2, -1.2][k])
			var np: Vector2 = bt.p + dirv * BOT_SPEED * delta
			if free_at(np):
				bt.p = np
				if absf(dirv.x) > 0.3:
					bt.facing = "right" if dirv.x > 0 else "left"
				break
	if best < 420.0 and now - float(bt.fire_t) > 1.15:
		bt.fire_t = now + randf_range(0.0, 0.4)
		var aim: Vector2 = (target - bt.p).normalized().rotated(randf_range(-0.14, 0.14))
		_spawn_ball(bt.p, aim, bt.team, bt.name)


func _finish(winner: String) -> void:
	_phase = "idle"
	for who in _teams:
		var pid := Net.id_by_name(who)
		if pid == 0:
			continue
		var t: String = _teams[who]
		var won := t == winner
		var money := 250 if won else 80
		Net.add_money(pid, money)
		Rpg.add_xp(pid, "", 60 if won else 30)
		Ach.event(pid, "paint_games")
		if won:
			Ach.event(pid, "paint_wins")
		Homes._teleport(pid, Map.ARENA_BOOTH + Vector2(randf_range(-60, 60), 40))
		var head := "KAZANDINIZ!" if won else ("Berabere." if winner == "" else "Kaybettiniz.")
		var other := "mavi" if t == "kirmizi" else "kirmizi"
		var unit := "vuruş" if _mode == "hits" else "bayrak"
		Net.notify(pid, "%s  %d – %d  (%s). +%s" % [head, int(_score[t]), int(_score[other]), unit, U.money(money)], won)
	_bots.clear()
	_balls.clear()
	_out.clear()
	_flags = {}
	if winner != "":
		Net.announce("Paintball: %s takım kazandı! (%d – %d)" % [TEAM_NAME[winner], int(_score[winner]), int(_score["mavi" if winner == "kirmizi" else "kirmizi"])])
	_sync_all(true)


func _process(delta: float) -> void:
	if not Net.is_server() or _phase != "play":
		return
	_tick(delta)
	if _phase != "play":
		return
	_sync += delta
	if _sync >= 0.1:
		_sync = 0.0
		_sync_all()
