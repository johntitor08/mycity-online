extends Node
## Plaj futbolu. Sahada topa yürüyen oyuncu onu iter (sunucuda basit fizik: sürtünme, kenardan sekme).
## İki takım: Kırmızı (soldaki kaleyi korur) ve Mavi (sağdakini). Takım seçmeden de topa vurulabilir.
## Gol: topu son ellenen oyuncuya yazılır (kendi kalesine atarsa rakip takıma). 5 gole ulaşan ya da
## 6 dakika dolunca önde olan takım kazanır; kazanan takımdaki çevrimiçi oyunculara ödül.

signal ball_moved
signal match_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const FIELD := Rect2(2230, 1672, 540, 170)
const GOAL_HALF := 38.0                   # kale ağzının yarı yüksekliği
const BALL_R := 9.0
const KICK_DIST := 26.0
const KICK_SPEED := 430.0
const FRICTION := 0.45                    # saniyede kalan hız oranı
const WIN_GOALS := 5
const MATCH_TIME := 360.0
const WIN_PRIZE := 400
const TEAMS := {"red": "Kırmızı", "blue": "Mavi"}

# --- herkes
var ball := FIELD.get_center()
var vel := Vector2.ZERO
var _ball_at := 0.0                       # son güncellemenin yerel zamanı
var score := {"red": 0, "blue": 0}
var time_left := MATCH_TIME
var last_goal := ""                       # son golü atan (gösterim için)

# --- sunucu
var _last_touch := 0
var _kick_cd := {}
var _sync := 0.0
var _match_sync := 0.0
var _started := false


static func goal_center(side: String) -> Vector2:
	return Vector2(FIELD.position.x if side == "left" else FIELD.end.x, FIELD.get_center().y)


func reset() -> void:
	ball = FIELD.get_center()
	vel = Vector2.ZERO
	score = {"red": 0, "blue": 0}
	_started = false


## İstemci: topun tahmini şu anki yeri (son paketten beri ilerlemiş haliyle).
func ball_now() -> Vector2:
	var dt := clampf(Time.get_ticks_msec() / 1000.0 - _ball_at, 0.0, 0.3)
	return (ball + vel * dt).clamp(FIELD.position - Vector2(30, 0), FIELD.end + Vector2(30, 0))


# ------------------------------------------------------------------ istemci API

func join(team: String) -> void:
	Net.ask(self, "req_team", {"team": team})


@rpc("authority", "call_local", "unreliable_ordered")
func on_ball(p: Vector2, v: Vector2) -> void:
	ball = p
	vel = v
	_ball_at = Time.get_ticks_msec() / 1000.0
	ball_moved.emit()


@rpc("authority", "call_local", "reliable")
func on_match(d: Dictionary) -> void:
	score = d.score
	time_left = float(d.left)
	last_goal = str(d.get("goal", ""))
	match_changed.emit()


# ------------------------------------------------------------------ sunucu

func send_state(id: int) -> void:
	Net.tell(self, id, "on_match", {"score": score, "left": time_left, "goal": ""})


func _broadcast_match(goal_text: String = "") -> void:
	Net.tell_all(self, "on_match", {"score": score, "left": time_left, "goal": goal_text})


@rpc("any_peer", "call_remote", "reliable")
func req_team(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var team := str(d.get("team", ""))
	if team != "" and not TEAMS.has(team):
		return
	if team != "" and not FIELD.grow(120).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Takım seçmek için plajdaki sahaya git.", false)
		return
	Net.players[id]["team"] = team
	Net._broadcast_roster()
	Net.notify(id, ("%s takıma katıldın! Topa doğru yürüyerek vur." % TEAMS[team]) if team != "" else "Takımdan ayrıldın.")


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	delta = minf(delta, 0.1)
	# vuruşlar
	var now := Time.get_ticks_msec() / 1000.0
	for id in Net.players:
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
		if not FIELD.grow(40).has_point(p):
			continue
		var d := ball - p
		if d.length() < KICK_DIST and now > float(_kick_cd.get(id, 0.0)):
			_kick_cd[id] = now + 0.18
			var dir := d.normalized() if d.length() > 0.1 else Vector2.RIGHT
			var boost := 1.25 if str(Net.players[id].get("ride", "")) == "" else 0.8
			vel = dir * maxf(vel.length() * 0.6, KICK_SPEED * boost)
			_last_touch = id
			_started = true
	if vel.length_squared() > 1.0:
		ball += vel * delta
		vel *= pow(FRICTION, delta)
		if vel.length() < 8.0:
			vel = Vector2.ZERO
		_walls()
	# maç saati
	if _started:
		time_left -= delta
		if time_left <= 0.0:
			_end_match()
	_sync += delta
	if _sync >= (0.066 if vel != Vector2.ZERO else 1.0):
		_sync = 0.0
		rpc("on_ball", ball, vel)
	_match_sync += delta
	if _started and _match_sync >= 5.0:
		_match_sync = 0.0
		_broadcast_match()


func _walls() -> void:
	var cy := FIELD.get_center().y
	var in_mouth := absf(ball.y - cy) < GOAL_HALF
	if ball.x < FIELD.position.x + BALL_R:
		if in_mouth and ball.x < FIELD.position.x - 4.0:
			_goal("left")
			return
		elif not in_mouth:
			ball.x = FIELD.position.x + BALL_R
			vel.x = absf(vel.x) * 0.7
	if ball.x > FIELD.end.x - BALL_R:
		if in_mouth and ball.x > FIELD.end.x + 4.0:
			_goal("right")
			return
		elif not in_mouth:
			ball.x = FIELD.end.x - BALL_R
			vel.x = -absf(vel.x) * 0.7
	if ball.y < FIELD.position.y + BALL_R:
		ball.y = FIELD.position.y + BALL_R
		vel.y = absf(vel.y) * 0.7
	if ball.y > FIELD.end.y - BALL_R:
		ball.y = FIELD.end.y - BALL_R
		vel.y = -absf(vel.y) * 0.7


## side: topun girdiği kale ("left" Kırmızı'nın kalesi → Mavi atmış olur).
func _goal(side: String) -> void:
	var team := "blue" if side == "left" else "red"
	score[team] = int(score[team]) + 1
	var text := "%s takım" % TEAMS[team]
	if Net.players.has(_last_touch):
		var who: String = Net.players[_last_touch].name
		var own := str(Net.players[_last_touch].get("team", "")) != "" and str(Net.players[_last_touch].team) != team
		text = "%s%s" % [who, " (kendi kalesine!)" if own else ""]
		if not own:
			Ach.event(_last_touch, "goal")
			League.add(_last_touch, "goals", 1.0)
			Events.add_score(_last_touch, "beach", 1, "%d gol")
			Rpg.add_xp(_last_touch, "", 25)
	Net.announce("GOOOL! %s — Kırmızı %d : %d Mavi" % [text, score.red, score.blue])
	ball = FIELD.get_center()
	vel = Vector2.ZERO
	_broadcast_match(text)
	if int(score[team]) >= WIN_GOALS:
		_end_match()


func _end_match() -> void:
	var winner := ""
	if int(score.red) > int(score.blue):
		winner = "red"
	elif int(score.blue) > int(score.red):
		winner = "blue"
	if winner != "":
		Net.announce("Plaj maçı bitti: %s takım kazandı! (%d - %d)" % [TEAMS[winner], score.red, score.blue])
		for id in Net.players:
			if str(Net.players[id].get("team", "")) == winner:
				Net.add_money(id, WIN_PRIZE)
				Rpg.add_xp(id, "", 80)
				Net.notify(id, "Maçı kazandınız! +%s" % U.money(WIN_PRIZE))
	elif int(score.red) + int(score.blue) > 0:
		Net.announce("Plaj maçı berabere bitti (%d - %d)." % [score.red, score.blue])
	score = {"red": 0, "blue": 0}
	time_left = MATCH_TIME
	_started = false
	ball = FIELD.get_center()
	vel = Vector2.ZERO
	_broadcast_match()
