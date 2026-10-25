extends Node
## Langırt (plajdaki masa). İki koltuk: Kırmızı (sol) ve Mavi (sağ); boş koltuğa bot oturabilir.
## Her taraf tek tutamakla kalecisini ve 3 kişilik forvet çubuğunu birlikte yukarı-aşağı oynatır (W/S ya da fare).
## Top fiziği sunucuda; durum 20 kez/sn masadakilere ve yakındaki seyircilere gönderilir. 5 gole ulaşan kazanır.

signal state_changed

const U = preload("res://scripts/util.gd")

const POS := Vector2(1950, 1700)          # masanın plajdaki yeri
const W := 400.0
const H := 220.0
const GOAL_HALF := 32.0
const BALL_R := 6.0
const MAN_R := 10.0
const WIN := 5
const BOT_SPEED := 230.0
const MAX_SPEED := 560.0
# [çubuk x, adam uzaklıkları]: sol taraf; sağ taraf aynalanır
const RODS := [[30.0, [0.0]], [250.0, [-62.0, 0.0, 62.0]]]
const ROD_RANGE := Vector2(40.0, 180.0)   # çubuk merkezinin gidebileceği y aralığı

# --- herkes (son durum)
var state: Dictionary = {}                # {b, r, s, st, n, bot}

# --- sunucu
var _seats := [0, 0]                      # oyuncu id; -1 = bot; 0 = boş
var _rod := [H / 2.0, H / 2.0]
var _ball := Vector2(W / 2.0, H / 2.0)
var _vel := Vector2.ZERO
var _score := [0, 0]
var _phase := "wait"                      # wait, serve, play
var _serve_at := 0.0
var _sync := 0.0


func reset() -> void:
	state = {}
	_seats = [0, 0]
	_score = [0, 0]
	_phase = "wait"


static func man_positions(side: int, rod_y: float) -> Array:
	var out: Array = []
	for r in RODS:
		var x: float = r[0] if side == 0 else W - float(r[0])
		for off in r[1]:
			out.append(Vector2(x, rod_y + float(off)))
	return out


func my_seat() -> int:
	var n: Array = state.get("n", ["", ""])
	for i in 2:
		if str(n[i]) == Net.my_name and Net.my_name != "":
			return i
	return -1


# ------------------------------------------------------------------ istemci API

func sit(seat: int, vs_bot: bool = false) -> void:
	Net.ask(self, "req_sit", {"seat": seat, "bot": vs_bot})


func leave() -> void:
	Net.ask(self, "req_leave")


func move_rod(y: float) -> void:
	if not Net.is_online():
		return
	if multiplayer.is_server():
		req_rod(y)
	else:
		rpc_id(1, "req_rod", y)


@rpc("authority", "call_local", "unreliable_ordered")
func on_table(d: Dictionary) -> void:
	state = d
	state_changed.emit()


# ------------------------------------------------------------------ sunucu

func _near(id: int) -> bool:
	return Net.positions.get(id, Vector2(-9999, -9999)).distance_to(POS) < 160.0


func _names() -> Array:
	var out := ["", ""]
	for i in 2:
		if _seats[i] == -1:
			out[i] = "Bot"
		elif _seats[i] != 0 and Net.players.has(_seats[i]):
			out[i] = Net.players[_seats[i]].name
	return out


@rpc("any_peer", "call_remote", "reliable")
func req_sit(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _near(id):
		Net.notify(id, "Langırt masasına yaklaş.", false)
		return
	if id in _seats:
		return
	var seat := clampi(int(d.get("seat", 0)), 0, 1)
	if _seats[seat] != 0 and _seats[seat] != -1:
		seat = 1 - seat
		if _seats[seat] != 0 and _seats[seat] != -1:
			Net.notify(id, "Masa dolu, sırayı bekle.", false)
			return
	_seats[seat] = id
	if bool(d.get("bot", false)) and _seats[1 - seat] == 0:
		_seats[1 - seat] = -1
	_score = [0, 0]
	_try_start()


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	_free(Net.sender())


func on_player_left(id: int) -> void:
	_free(id)


func _free(id: int) -> void:
	var i := _seats.find(id)
	if i < 0:
		return
	_seats[i] = 0
	if _seats[1 - i] == -1:
		_seats[1 - i] = 0
	_phase = "wait"
	_score = [0, 0]


@rpc("any_peer", "call_remote", "unreliable_ordered")
func req_rod(y: float) -> void:
	var i := _seats.find(Net.sender())
	if i >= 0:
		_rod[i] = clampf(y, ROD_RANGE.x, ROD_RANGE.y)


func _try_start() -> void:
	if _seats[0] != 0 and _seats[1] != 0 and _phase == "wait":
		_serve(randi() % 2)


func _serve(towards: int) -> void:
	_ball = Vector2(W / 2.0, H / 2.0)
	_vel = Vector2.ZERO
	_phase = "serve"
	_serve_at = Time.get_ticks_msec() / 1000.0 + 1.5
	_vel = Vector2(-1.0 if towards == 0 else 1.0, randf_range(-0.6, 0.6)).normalized() * 220.0


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	delta = minf(delta, 0.05)
	for i in 2:
		if _seats[i] > 0 and not Net.players.has(_seats[i]):
			_free(_seats[i])
	if _phase == "serve" and Time.get_ticks_msec() / 1000.0 >= _serve_at:
		_phase = "play"
	if _phase == "play":
		_bots(delta)
		_physics(delta)
	_sync += delta
	if _sync >= 0.05 and (_seats[0] != 0 or _seats[1] != 0):
		_sync = 0.0
		var d := {"b": _ball, "r": _rod.duplicate(), "s": _score.duplicate(), "st": _phase, "n": _names()}
		for id in Net.players:
			if id in _seats or _near(id):
				Net.tell(self, id, "on_table", d)


func _bots(delta: float) -> void:
	for i in 2:
		if _seats[i] == -1:
			var target := _ball.y + randf_range(-6, 6)
			_rod[i] = clampf(move_toward(_rod[i], target, BOT_SPEED * delta), ROD_RANGE.x, ROD_RANGE.y)


func _physics(delta: float) -> void:
	_ball += _vel * delta
	if _ball.y < BALL_R:
		_ball.y = BALL_R
		_vel.y = absf(_vel.y)
	elif _ball.y > H - BALL_R:
		_ball.y = H - BALL_R
		_vel.y = -absf(_vel.y)
	var mouth := absf(_ball.y - H / 2.0) < GOAL_HALF
	if _ball.x < BALL_R:
		if mouth:
			_scored(1)
			return
		_ball.x = BALL_R
		_vel.x = absf(_vel.x)
	elif _ball.x > W - BALL_R:
		if mouth:
			_scored(0)
			return
		_ball.x = W - BALL_R
		_vel.x = -absf(_vel.x)
	for side in 2:
		for m in man_positions(side, _rod[side]):
			var d: Vector2 = _ball - m
			if d.length() < BALL_R + MAN_R:
				var n := d.normalized() if d.length() > 0.01 else Vector2(1 if side == 0 else -1, 0)
				_ball = m + n * (BALL_R + MAN_R + 0.5)
				var sp := minf(MAX_SPEED, maxf(_vel.length() * 1.06, 260.0))
				var dir := Vector2(1.0 if side == 0 else -1.0, clampf(d.y / (BALL_R + MAN_R), -0.9, 0.9))
				_vel = dir.normalized() * sp


func _scored(side: int) -> void:
	_score[side] += 1
	if _score[side] >= WIN:
		var winner: int = _seats[side]
		var loser: int = _seats[1 - side]
		var names := _names()
		if winner > 0 and Net.players.has(winner):
			var prize := 150 if loser > 0 else 50
			Net.add_money(winner, prize)
			Rpg.add_xp(winner, "", 40)
			Ach.event(winner, "langirt_win")
			Net.notify(winner, "Langırtı kazandın! +%s" % U.money(prize))
		if loser > 0 and names[0] != "" and names[1] != "":
			Net.announce("Langırt: %s, %s'i %d-%d yendi!" % [names[side], names[1 - side], _score[side], _score[1 - side]])
		_phase = "wait"
		var d := {"b": _ball, "r": _rod.duplicate(), "s": _score.duplicate(), "st": "over", "n": names, "w": side}
		for id in Net.players:
			if id in _seats or _near(id):
				Net.tell(self, id, "on_table", d)
		_score = [0, 0]
		get_tree().create_timer(3.0).timeout.connect(_try_start)
		return
	_serve(side)
