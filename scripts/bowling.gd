extends Node
## Bowling salonu (1.8, fuarda): bir oyun 50 TL, 10 çerçeve, gerçek bowling puanlaması.
##  Panelde gidip gelen nişan çubuğunda topun çıkış yerini, sonra falso çubuğunda topun dönüşünü seç
##  (Boşluk/E ya da dokun). Top kanalın sonuna doğru falsoyla döner; lobutlar birbirini devirir.
##  Fizik sunucuda: inç ölçüsünde yukarıdan bakışlı çember çarpışmaları (top 7 kg, lobut 1,5 kg).
##  Oyun bitince puanın kadar ×3 TL; 200 üstü ve 300 (mükemmel oyun) ilan edilir. Sunucu rekoru saklanır.
## Veri: rec["bowling"] = {best, games, strikes}; save_data["bowling_best"] = {score, by}

signal changed
signal rolled(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const GAME_PRICE := 50
const LANE_W := 41.5
const LANE_LEN := 720.0
const BALL_R := 4.3
const PIN_R := 2.4
const STEP := 1.0 / 240.0
const SIM_TIME := 3.6
const SAMPLE := 6                    # canlandırma için her 6 adımda bir kare
const PIN_SPACING := 12.0

# --- istemci
var game := {}                       # {rolls, standing, frame, done, score}

# --- sunucu
var _g := {}                         # id -> {rolls: [], standing: [bool x10], busy}


func reset() -> void:
	game = {}
	_g.clear()


func on_player_left(id: int) -> void:
	_g.erase(id)


static func pin_spots() -> Array:
	var out: Array = []
	for r in 4:
		for k in r + 1:
			out.append(Vector2((k - r / 2.0) * PIN_SPACING, r * PIN_SPACING * 0.866))
	return out


static func all_standing() -> Array:
	var a: Array = []
	for k in 10:
		a.append(true)
	return a


## Bir atış: x çıkış yeri (-18..18), curve falso (-1..1), power hız (0..1), seed çarpışma tohumu.
## Döner: {down: [düşen lobut sırası], frames: [[top, [lobut konumları]]...], gutter}
static func simulate(x: float, curve: float, power: float, standing: Array, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bp := Vector2(clampf(x, -18.0, 18.0), -LANE_LEN)
	var bv := Vector2(0, lerpf(260.0, 400.0, clampf(power, 0.0, 1.0)))
	var spots := pin_spots()
	var pp: Array = []
	var pv: Array = []
	var active: Array = []
	var fallen: Array = []
	for k in 10:
		pp.append(spots[k])
		pv.append(Vector2.ZERO)
		active.append(bool(standing[k]))
		fallen.append(false)
	var gutter := false
	var frames: Array = []
	var steps := int(SIM_TIME / STEP)
	for step in steps:
		# falso: kanalın son üçte birinde kanca
		if bp.y > -LANE_LEN * 0.4 and bp.y < 40.0 and not gutter:
			bv.x += clampf(curve, -1.0, 1.0) * 75.0 * STEP
		bp += bv * STEP
		if not gutter and bp.y < -6.0 and absf(bp.x) > LANE_W / 2.0 - BALL_R * 0.5:
			gutter = true
			bp.x = signf(bp.x) * (LANE_W / 2.0 + 3.0)
			bv.x = 0.0
		for k in 10:
			if not active[k]:
				continue
			# top-lobut
			if not gutter:
				var d: Vector2 = pp[k] - bp
				if d.length() < BALL_R + PIN_R:
					var n := d.normalized().rotated(rng.randf_range(-0.08, 0.08))
					var rel: float = (bv - pv[k]).dot(n)
					if rel > 0.0:
						var j: float = 2.0 * rel / (1.0 / 7.0 + 1.0 / 1.5) * 0.85
						bv -= n * j / 7.0
						pv[k] += n * j / 1.5
					pp[k] = bp + n * (BALL_R + PIN_R)
			pp[k] += pv[k] * STEP
			var sp: float = pv[k].length()
			if sp > 0.0:
				pv[k] = pv[k].normalized() * maxf(0.0, sp - 60.0 * STEP)
			if sp > 25.0 or (pp[k] as Vector2).distance_to(spots[k]) > 1.6:
				fallen[k] = true
			if absf(pp[k].x) > LANE_W / 2.0 + 2.0 or pp[k].y > 60.0:
				fallen[k] = true
		# lobut-lobut
		for a in 10:
			if not active[a]:
				continue
			for b in range(a + 1, 10):
				if not active[b]:
					continue
				var d: Vector2 = pp[b] - pp[a]
				if d.length() < PIN_R * 2.0 and d.length() > 0.001:
					var n := d.normalized().rotated(rng.randf_range(-0.12, 0.12))
					var rel: float = (pv[a] - pv[b]).dot(n)
					if rel > 0.0:
						var j: float = rel * 0.8
						pv[a] -= n * j
						pv[b] += n * j
					var mid: Vector2 = (pp[a] + pp[b]) / 2.0
					pp[a] = mid - n * PIN_R
					pp[b] = mid + n * PIN_R
		if step % SAMPLE == 0:
			var snap: Array = []
			for k in 10:
				snap.append([pp[k].x, pp[k].y, active[k], fallen[k]])
			frames.append([bp.x, bp.y, snap])
		if bp.y > 80.0:
			var moving := false
			for k in 10:
				if active[k] and pv[k].length() > 4.0:
					moving = true
			if not moving:
				break
	var down: Array = []
	for k in 10:
		if active[k] and fallen[k]:
			down.append(k)
	return {"down": down, "frames": frames, "gutter": gutter}


## Klasik bowling puanı: atışlardan çerçeve toplamları (birikimli; hesaplanamayan -1).
static func frame_scores(rolls: Array) -> Array:
	var out: Array = []
	var i := 0
	var total := 0
	for f in 10:
		if i >= rolls.size():
			break
		var r1 := int(rolls[i])
		if r1 == 10 and f < 9:
			if i + 2 < rolls.size():
				total += 10 + int(rolls[i + 1]) + int(rolls[i + 2])
				out.append(total)
			else:
				out.append(-1)
			i += 1
			continue
		if i + 1 >= rolls.size():
			out.append(-1)
			break
		var r2 := int(rolls[i + 1])
		if f == 9:
			if r1 + r2 >= 10:
				if i + 2 < rolls.size():
					total += r1 + r2 + int(rolls[i + 2])
					out.append(total)
				else:
					out.append(-1)
			else:
				total += r1 + r2
				out.append(total)
			break
		if r1 + r2 == 10:
			if i + 2 < rolls.size():
				total += 10 + int(rolls[i + 2])
				out.append(total)
			else:
				out.append(-1)
		else:
			total += r1 + r2
			out.append(total)
		i += 2
	return out


## Oyun bitti mi, şu an kaçıncı çerçeve ve atış? -> [frame (0..9), atış (0..2), bitti]
static func position(rolls: Array) -> Array:
	var i := 0
	for f in 10:
		if f == 9:
			var n := rolls.size() - i
			if n >= 3:
				return [9, 3, true]
			if n == 2:
				var a := int(rolls[i]) + int(rolls[i + 1])
				return [9, 2, not (int(rolls[i]) == 10 or a >= 10)]
			return [9, n, false]
		if i >= rolls.size():
			return [f, 0, false]
		if int(rolls[i]) == 10:
			i += 1
			continue
		if i + 1 >= rolls.size():
			return [f, 1, false]
		i += 2
	return [9, 0, false]


static func total(rolls: Array) -> int:
	var fs := frame_scores(rolls)
	for k in range(fs.size() - 1, -1, -1):
		if int(fs[k]) >= 0:
			return int(fs[k])
	return 0


# ------------------------------------------------------------------ istemci API

func start() -> void:
	Net.ask(self, "req_start")


func roll(x: float, curve: float, power: float) -> void:
	Net.ask(self, "req_roll", {"x": x, "c": curve, "p": power})


func quit() -> void:
	Net.ask(self, "req_quit")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	game = d
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_roll(d: Dictionary) -> void:
	rolled.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _near(id: int) -> bool:
	return (Map.BOWLING.rect as Rect2).grow(70).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


func send_state(id: int) -> void:
	if not _g.has(id):
		Net.tell(self, id, "on_state", {})
		return
	var g: Dictionary = _g[id]
	var pos := position(g.rolls)
	Net.tell(self, id, "on_state", {"rolls": g.rolls, "standing": g.standing, "frame": pos[0], "ball": pos[1], "done": pos[2],
		"scores": frame_scores(g.rolls), "score": total(g.rolls)})


@rpc("any_peer", "call_remote", "reliable")
func req_start(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _near(id):
		return
	if _g.has(id) and not position(_g[id].rolls)[2]:
		send_state(id)
		return
	if not Net.try_spend(id, GAME_PRICE):
		Net.notify(id, "Bowling oyunu %s." % U.money(GAME_PRICE), false)
		return
	_g[id] = {"rolls": [], "standing": all_standing(), "busy": 0.0}
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_quit(_d: Dictionary) -> void:
	var id := Net.sender()
	_g.erase(id)
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_roll(d: Dictionary) -> void:
	var id := Net.sender()
	if not _g.has(id) or not _near(id):
		return
	var g: Dictionary = _g[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(g.busy) or position(g.rolls)[2]:
		return
	var x := clampf(float(d.get("x", 0.0)), -18.0, 18.0)
	var c := clampf(float(d.get("c", 0.0)), -1.0, 1.0)
	var p := clampf(float(d.get("p", 0.6)), 0.0, 1.0)
	var seed := randi()
	var pins_before: Array = g.standing.duplicate()
	var res := simulate(x, c, p, pins_before, seed)
	var n: int = res.down.size()
	var before := position(g.rolls)
	g.rolls.append(n)
	for k in res.down:
		g.standing[k] = false
	g["busy"] = now + 2.2
	var after := position(g.rolls)
	var cleared: bool = not g.standing.has(true)
	var mark := ""
	if cleared:
		mark = "STRIKE!" if int(pins_before.count(true)) == 10 and n == 10 else "SPARE!"
	if mark == "STRIKE!":
		Ach.event(id, "bowling_strikes")
	# yeni çerçeve ya da 10. çerçevede temizlenen lobutlar yeniden dizilir
	if int(after[0]) != int(before[0]) or cleared:
		g["standing"] = all_standing()
	Net.tell(self, id, "on_roll", {"x": x, "c": c, "p": p, "seed": seed, "standing": pins_before, "down": n, "mark": mark})
	if bool(after[2]):
		_finish(id)
	send_state(id)


func _finish(id: int) -> void:
	var g: Dictionary = _g[id]
	var score := total(g.rolls)
	var reward := score * 3
	if score == 300:
		reward += 10000
		Net.announce("MÜKEMMEL OYUN! %s bowlingde 300 puan yaptı!" % Net.players[id].name)
	elif score >= 200:
		Net.announce("%s bowlingde %d puan yaptı!" % [Net.players[id].name, score])
	Net.add_money(id, reward)
	Rpg.add_xp(id, "", 40 + score / 5)
	Ach.event(id, "bowling_games")
	Ach.set_max(id, "bowling_best", score)
	var rec := _rec(id)
	if not rec.get("bowling") is Dictionary:
		rec["bowling"] = {"best": 0, "games": 0, "strikes": 0}
	var b: Dictionary = rec.bowling
	b["games"] = int(b.get("games", 0)) + 1
	for r in g.rolls:
		if int(r) == 10:
			b["strikes"] = int(b.get("strikes", 0)) + 1
	b["best"] = maxi(int(b.get("best", 0)), score)
	var best = Net.save_data.get("bowling_best", {})
	if not best is Dictionary or score > int(best.get("score", 0)):
		Net.save_data["bowling_best"] = {"score": score, "by": Net.players[id].name}
	Net.notify(id, "Oyun bitti: %d puan. Ödül %s" % [score, U.money(reward)])
	Net.mark_dirty()
