extends Node
## Mini golf (1.8): fuardaki gişeden (100 TL) 9 delikli sahaya geçilir.
##  Topa yakın dur, fareyi/parmağı topun tersine sürükleyip bırak: ne kadar uzun çekersen o kadar sert vurursun.
##  Fizik sunucuda: duvarlarda seker, kumda yavaşlar, suya düşen top bir vuruş cezasıyla geri gelir,
##  yel değirmeninin dönen kanatları topu çeler. Deliğe yavaş giren top düşer. Delik başına en fazla 8 vuruş.
##  9 delik bitince skor kartı: par altına inersen ikramiye; sunucu rekoru ilan edilir.
## Veri: rec["golf"] = {best, rounds, aces}; save_data["golf_best"] = {strokes, by}

signal changed
signal shot(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const ENTRY_PRICE := 100
const MAX_STROKES := 8
const BALL_R := 7.0
const CUP_R := 12.0
const MAX_SPEED := 900.0
const STEP := 1.0 / 60.0
const CELL := Vector2(600, 400)
const ROUND_REWARD := 300
const UNDER_PAR_BONUS := 250        # par altındaki her vuruş için

## Delikler hücreye göre (hücre 600x400; saha kenarı 40 px içeride). w: duvar, s: kum, x: su, m: yel değirmeni
const HOLES := [
	{"par": 2, "tee": Vector2(110, 200), "cup": Vector2(490, 200), "w": [], "s": [], "x": [], "m": []},
	{"par": 2, "tee": Vector2(110, 300), "cup": Vector2(490, 110), "w": [Rect2(280, 120, 30, 240)], "s": [], "x": [], "m": []},
	{"par": 3, "tee": Vector2(100, 110), "cup": Vector2(500, 290), "w": [Rect2(200, 40, 26, 210), Rect2(380, 150, 26, 210)], "s": [], "x": [], "m": []},
	{"par": 3, "tee": Vector2(100, 200), "cup": Vector2(500, 200), "w": [], "s": [Rect2(250, 120, 110, 160)], "x": [], "m": [Vector2(305, 200)]},
	{"par": 3, "tee": Vector2(100, 300), "cup": Vector2(500, 100), "w": [Rect2(200, 200, 200, 26)], "s": [], "x": [Rect2(260, 60, 120, 120)], "m": []},
	{"par": 2, "tee": Vector2(300, 320), "cup": Vector2(300, 90), "w": [Rect2(160, 190, 110, 22), Rect2(330, 190, 110, 22)], "s": [Rect2(250, 120, 100, 50)], "x": [], "m": []},
	{"par": 3, "tee": Vector2(100, 100), "cup": Vector2(500, 300), "w": [Rect2(40, 180, 380, 26)], "s": [Rect2(440, 60, 120, 100)], "x": [Rect2(170, 250, 150, 110)], "m": []},
	{"par": 4, "tee": Vector2(90, 200), "cup": Vector2(520, 200), "w": [Rect2(170, 40, 24, 200), Rect2(300, 160, 24, 200), Rect2(430, 40, 24, 200)], "s": [], "x": [], "m": []},
	{"par": 3, "tee": Vector2(300, 330), "cup": Vector2(300, 80), "w": [], "s": [Rect2(90, 120, 110, 110), Rect2(400, 120, 110, 110)], "x": [], "m": [Vector2(300, 200)]},
]

# --- istemci
var my := {}                         # {hole, ball: [x, y], cards: [vuruş...], strokes} ya da {}
var balls := {}                      # ad -> [delik, x, y]  (sahadaki herkesin topu)
var flying := {}                     # ad -> {path, t0} (canlandırılan vuruşlar)

# --- sunucu
var _p := {}                         # id -> {hole, ball, cards, strokes, busy_until}


func reset() -> void:
	my = {}
	balls = {}
	flying = {}
	_p.clear()


func on_player_left(id: int) -> void:
	if _p.has(id):
		_p.erase(id)
		_broadcast_balls()


static func hole_origin(i: int) -> Vector2:
	return Map.GOLF.position + Vector2(i % 3, i / 3) * CELL


static func field(i: int) -> Rect2:
	return Rect2(hole_origin(i) + Vector2(40, 40), CELL - Vector2(80, 80))


static func par_total() -> int:
	var n := 0
	for h in HOLES:
		n += int(h.par)
	return n


static func tee(i: int) -> Vector2:
	return hole_origin(i) + HOLES[i].tee


static func cup(i: int) -> Vector2:
	return hole_origin(i) + HOLES[i].cup


static func rects(i: int, key: String) -> Array:
	var out: Array = []
	for r in HOLES[i][key]:
		out.append(Rect2(hole_origin(i) + (r as Rect2).position, (r as Rect2).size))
	return out


## Yel değirmeni kanatları (t anında, dünya koordinatında doğru parçaları).
static func blades(i: int, t: float) -> Array:
	var out: Array = []
	for m in HOLES[i].m:
		var c: Vector2 = hole_origin(i) + m
		var a := fmod(t * 1.6, TAU)
		for k in 2:
			var d := Vector2.from_angle(a + k * PI / 2.0) * 70.0
			out.append([c - d, c + d])
	return out


static func _reflect_rect(p: Vector2, v: Vector2, r: Rect2) -> Array:
	var g := r.grow(BALL_R)
	if not g.has_point(p):
		return [p, v, false]
	var dl := p.x - g.position.x
	var dr := g.end.x - p.x
	var dt := p.y - g.position.y
	var db := g.end.y - p.y
	var m := minf(minf(dl, dr), minf(dt, db))
	if m == dl:
		p.x = g.position.x
		v.x = -absf(v.x)
	elif m == dr:
		p.x = g.end.x
		v.x = absf(v.x)
	elif m == dt:
		p.y = g.position.y
		v.y = -absf(v.y)
	else:
		p.y = g.end.y
		v.y = absf(v.y)
	return [p, v * 0.8, true]


## Vuruşun benzetimi (sunucu da istemci de aynı sonucu bulur; t0: değirmen zamanı).
## Döner: {path: [Vector2...] (her 3 adımda bir), end, result: "stop"|"cup"|"water", start}
static func simulate(i: int, start: Vector2, vel: Vector2, t0: float) -> Dictionary:
	var p := start
	var v := vel.limit_length(MAX_SPEED)
	var path: Array = [p]
	var f := field(i).grow(-BALL_R)
	var walls := rects(i, "w")
	var sand := rects(i, "s")
	var water := rects(i, "x")
	var c := cup(i)
	var t := t0
	var result := "stop"
	for step in 1200:
		t += STEP
		var drag := 220.0
		for s in sand:
			if (s as Rect2).has_point(p):
				drag = 900.0
		var sp := v.length()
		sp = maxf(0.0, sp - drag * STEP) * pow(0.55, STEP)
		v = v.normalized() * sp if sp > 0.0 else Vector2.ZERO
		p += v * STEP
		if p.x < f.position.x:
			p.x = f.position.x
			v.x = absf(v.x) * 0.85
		elif p.x > f.end.x:
			p.x = f.end.x
			v.x = -absf(v.x) * 0.85
		if p.y < f.position.y:
			p.y = f.position.y
			v.y = absf(v.y) * 0.85
		elif p.y > f.end.y:
			p.y = f.end.y
			v.y = -absf(v.y) * 0.85
		for w in walls:
			var res := _reflect_rect(p, v, w)
			p = res[0]
			v = res[1]
		for b in blades(i, t):
			var q := Geometry2D.get_closest_point_to_segment(p, b[0], b[1])
			var d := p - q
			if d.length() < BALL_R + 4.0:
				var n := d.normalized() if d.length() > 0.01 else Vector2.UP
				p = q + n * (BALL_R + 4.0)
				v = v.bounce(n) * 0.9 + n * 120.0
		if step % 3 == 0:
			path.append(p)
		if p.distance_to(c) < CUP_R:
			if v.length() < 520.0:
				result = "cup"
				p = c
				break
			v = v.rotated(0.25) * 0.85         # hızlı top deliğin ağzından seker
		var wet := false
		for x in water:
			if (x as Rect2).has_point(p):
				wet = true
		if wet:
			result = "water"
			break
		if v.length() < 6.0:
			break
	path.append(p)
	return {"path": path, "end": p, "result": result, "start": start}


# ------------------------------------------------------------------ istemci API

func playing() -> bool:
	return my.has("hole")


func enter() -> void:
	Net.ask(self, "req_enter")


func leave() -> void:
	Net.ask(self, "req_leave")


func hit(vel: Vector2) -> void:
	Net.ask(self, "req_shot", {"v": vel})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_balls(d: Dictionary) -> void:
	balls = d.get("b", {})
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_shot(d: Dictionary) -> void:
	var res := simulate(int(d.hole), d.start, d.v, float(d.t0))
	flying[str(d.who)] = {"path": res.path, "t0": Time.get_ticks_msec() / 1000.0, "hole": int(d.hole)}
	shot.emit(d)


## Uçan topun şu anki yeri (yoksa durduğu yer).
func ball_pos(who: String) -> Vector2:
	if flying.has(who):
		var f: Dictionary = flying[who]
		var k := int((Time.get_ticks_msec() / 1000.0 - float(f.t0)) / (STEP * 3.0))
		if k < f.path.size():
			return f.path[k]
		flying.erase(who)
	if balls.has(who):
		return Vector2(balls[who][1], balls[who][2])
	return Vector2(-9999, -9999)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func send_state(id: int) -> void:
	if _p.has(id):
		var s: Dictionary = _p[id]
		Net.tell(self, id, "on_state", {"hole": int(s.hole), "ball": s.ball, "cards": s.cards, "strokes": int(s.strokes)})
	else:
		Net.tell(self, id, "on_state", {})
	Net.tell(self, id, "on_balls", {"b": _balls_view()})


func _balls_view() -> Dictionary:
	var b := {}
	for id in _p:
		if Net.players.has(id):
			b[Net.players[id].name] = [int(_p[id].hole), _p[id].ball.x, _p[id].ball.y]
	return b


func _broadcast_balls() -> void:
	var v := _balls_view()
	for id in Net.players:
		if Map.GOLF.has_point(_pos(id)):
			Net.tell(self, id, "on_balls", {"b": v})


@rpc("any_peer", "call_remote", "reliable")
func req_enter(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _p.has(id) or _pos(id).distance_to(Map.GOLF_BOOTH) > 140.0:
		return
	if not Net.try_spend(id, ENTRY_PRICE):
		Net.notify(id, "Mini golf %s." % U.money(ENTRY_PRICE), false)
		return
	_p[id] = {"hole": 0, "ball": tee(0), "cards": [], "strokes": 0, "busy_until": 0.0}
	Homes._teleport(id, tee(0) + Vector2(-40, 30))
	Net.notify(id, "Mini golfa hoş geldin! Topa yakın dur, tersine sürükleyip bırak.")
	send_state(id)
	_broadcast_balls()


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	var id := Net.sender()
	if not _p.has(id) and not Map.GOLF.has_point(_pos(id)):
		return
	_p.erase(id)
	Homes._teleport(id, Map.GOLF_BOOTH + Vector2(0, 60))
	send_state(id)
	_broadcast_balls()


@rpc("any_peer", "call_remote", "reliable")
func req_shot(d: Dictionary) -> void:
	var id := Net.sender()
	if not _p.has(id):
		return
	var s: Dictionary = _p[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(s.busy_until) or _pos(id).distance_to(s.ball) > 120.0:
		return
	var vel: Vector2 = d.get("v", Vector2.ZERO)
	if vel.length() < 30.0:
		return
	vel = vel.limit_length(MAX_SPEED)
	var hole := int(s.hole)
	var t0 := fmod(Land.server_now(), 1000.0)
	var res := simulate(hole, s.ball, vel, t0)
	s["strokes"] = int(s.strokes) + 1
	var flight: float = res.path.size() * STEP * 3.0
	s["busy_until"] = now + flight
	var me: String = Net.players[id].name
	for pid in Net.players:
		if Map.GOLF.has_point(_pos(pid)):
			Net.tell(self, pid, "on_shot", {"who": me, "hole": hole, "start": s.ball, "v": vel, "t0": t0})
	match str(res.result):
		"cup":
			_finish_hole(id, hole, int(s.strokes), flight)
			return
		"water":
			s["strokes"] = int(s.strokes) + 1
			Net.notify(id, "Top suya düştü! +1 ceza vuruşu.", false)
		_:
			s["ball"] = res.end
	if int(s.strokes) >= MAX_STROKES:
		Net.notify(id, "Bu delikte %d vuruşa ulaştın; sonraki deliğe geçiliyor." % MAX_STROKES, false)
		_finish_hole(id, hole, MAX_STROKES, flight)
		return
	send_state(id)
	_broadcast_balls()


func _finish_hole(id: int, hole: int, strokes: int, delay: float) -> void:
	var s: Dictionary = _p[id]
	s.cards.append(strokes)
	var par := int(HOLES[hole].par)
	if strokes == 1:
		Ach.event(id, "golf_aces")
		Net.announce("%s mini golfta %d. delikte TEK VURUŞ yaptı!" % [Net.players[id].name, hole + 1])
	Ach.event(id, "golf_holes")
	var word: String = {-2: "Kartal!", -1: "Birdie!", 0: "Par.", 1: "Bogey."}.get(strokes - par, "%+d" % (strokes - par))
	Net.notify(id, "%d. delik: %d vuruş (par %d) %s" % [hole + 1, strokes, par, word])
	if hole + 1 >= HOLES.size():
		_finish_round(id)
		return
	s["hole"] = hole + 1
	s["strokes"] = 0
	s["ball"] = tee(hole + 1)
	s["busy_until"] = Time.get_ticks_msec() / 1000.0 + delay
	get_tree().create_timer(delay + 0.4).timeout.connect(func() -> void:
		if _p.has(id) and int(_p[id].hole) == hole + 1:
			Homes._teleport(id, tee(hole + 1) + Vector2(-40, 30)))
	send_state(id)
	_broadcast_balls()


func _finish_round(id: int) -> void:
	var s: Dictionary = _p[id]
	var total := 0
	for n in s.cards:
		total += int(n)
	var under := maxi(0, par_total() - total)
	var reward := ROUND_REWARD + UNDER_PAR_BONUS * under
	Net.add_money(id, reward)
	Rpg.add_xp(id, "", 80)
	var me: String = Net.players[id].name
	var rec := _rec(id)
	if not rec.get("golf") is Dictionary:
		rec["golf"] = {"best": 0, "rounds": 0}
	var g: Dictionary = rec.golf
	g["rounds"] = int(g.get("rounds", 0)) + 1
	if int(g.get("best", 0)) == 0 or total < int(g.best):
		g["best"] = total
	Ach.event(id, "golf_rounds")
	var best = Net.save_data.get("golf_best", {})
	if not best is Dictionary or best.is_empty() or total < int(best.get("strokes", 999)):
		Net.save_data["golf_best"] = {"strokes": total, "by": me}
		Net.announce("Yeni mini golf rekoru: %s, 9 delik %d vuruş!" % [me, total])
	Net.notify(id, "Tur bitti: %d vuruş (par %d). Ödül %s" % [total, par_total(), U.money(reward)])
	Net.tell(self, id, "on_state", {"done": true, "cards": s.cards, "total": total, "reward": reward})
	_p.erase(id)
	Net.mark_dirty()
	_broadcast_balls()
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if Net.players.has(id) and Map.GOLF.has_point(_pos(id)):
			Homes._teleport(id, Map.GOLF_BOOTH + Vector2(0, 60)))
