extends Node
## At çiftliği ve hipodrom (1.3).
##  Hara (Sanayi): at satın al (en fazla 2), besle (yem ya da mısır), antrenmanla hız/dayanıklılık geliştir.
##   Atına F ile bin (karada; dağda olmaz). Tok değilse binilmez.
##  Hipodrom: bir oyuncu atıyla yarışa katılınca 25 sn bekleme başlar; boş kulvarları NPC atlar doldurur.
##   Beklemede herkes bahis oynayabilir (oran atların gücüne göre). Yarışta jokey "kamçı" ile hızlanır ama
##   dayanıklılığı biter; zamanlama önemli. İlk üçe ödül, kazanan ata +1 hız. Sunucu yarışı simüle eder.
## Veri: rec["horses"] = [{n, c, spd, sta, fed, tr, wins}], rec["horse_active"]

signal changed
signal race_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PRICE := 4000
const LEVEL := 4
const MAX_HORSES := 2
const FEED_PRICE := 25
const FEED_TIME := 7200.0
const TRAIN_ENERGY := 4
const TRAIN_COOLDOWN := 300.0
const STAT_MAX := 100
const COLORS := [Color("#8b5a2b"), Color("#1f1f1f"), Color("#f3f4f6"), Color("#9ca3af"), Color("#a0522d"), Color("#d6b48c")]
const COLOR_NAMES := ["Kahverengi", "Yağız", "Beyaz", "Kır", "Doru", "Kula"]
const NAMES := ["Rüzgâr", "Yıldırım", "Karayel", "Bozkurt", "Fırtına", "Sultan", "Gülbahar", "Şimşek", "Tarçın", "Duman",
	"Poyraz", "Kısmet", "Sevda", "Atlas", "Akıncı", "Yaman"]
const LOBBY_TIME := 25.0
const LANES := 4
const PRIZES := [1500, 600, 250]
const BET_MIN := 50
const BET_MAX := 2000
const WHIP_TIME := 0.6

# --- istemci
var my_horses: Array = []
var active_idx := 0
var race := {}                     # {state, left, lanes: [{n, owner, c, x, st, stmax, odds, place}], bets}
var _race_at := 0.0

# --- sunucu
var _race := {}                    # {state, t, lanes, bets: {id: [lane, amount]}, finish: []}
var _acc := 0.0
var _send_acc := 0.0


func reset() -> void:
	my_horses = []
	race = {}
	_race = {}


func on_player_left(id: int) -> void:
	if _race.is_empty():
		return
	for l in _race.lanes:
		if int(l.get("pid", 0)) == id:
			l["pid"] = 0                    # at koşmaya devam eder (NPC gibi)


static func rating(h: Dictionary) -> float:
	return float(h.spd) * 0.7 + float(h.sta) * 0.3


func race_left() -> float:
	return maxf(0.0, float(race.get("left", 0.0)) - (Time.get_ticks_msec() / 1000.0 - _race_at))


func has_horse() -> bool:
	return not my_horses.is_empty()


func active_horse() -> Dictionary:
	if my_horses.is_empty():
		return {}
	return my_horses[clampi(active_idx, 0, my_horses.size() - 1)]


# ------------------------------------------------------------------ istemci API

func buy() -> void:
	Net.ask(self, "req_buy")


func feed(i: int, with_corn: bool) -> void:
	Net.ask(self, "req_feed", {"i": i, "corn": with_corn})


func train(i: int, stat: String) -> void:
	Net.ask(self, "req_train", {"i": i, "stat": stat})


func set_active(i: int) -> void:
	Net.ask(self, "req_active", {"i": i})


func join_race() -> void:
	Net.ask(self, "req_join")


func bet(lane: int, amount: int) -> void:
	Net.ask(self, "req_bet", {"lane": lane, "amount": amount})


func whip() -> void:
	Net.ask(self, "req_whip")


func refresh_race() -> void:
	Net.ask(self, "req_race")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my_horses = d.get("horses", [])
	active_idx = int(d.get("active", 0))
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_race(d: Dictionary) -> void:
	race = d
	_race_at = Time.get_ticks_msec() / 1000.0
	race_changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _list(rec: Dictionary) -> Array:
	if not rec.get("horses") is Array:
		rec["horses"] = []
	return rec.horses


func _at_stable(id: int) -> bool:
	return Map.building("hara").rect.grow(80).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


func _at_track(id: int) -> bool:
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	return p.distance_to(Map.HIPPO_BOOTH) < 140.0 or Map.HIPPO_STANDS.grow(90).has_point(p)


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	Net.tell(self, id, "on_state", {"horses": _list(rec), "active": int(rec.get("horse_active", 0))})


## Garage.req_ride sorar: bu oyuncu ata binebilir mi? (tok bir atı var mı)
func can_ride(id: int) -> String:
	var rec := _rec(id)
	var hs := _list(rec)
	if hs.is_empty():
		return "Atın yok. Sanayi'deki Hara'dan at alabilirsin."
	var h: Dictionary = hs[clampi(int(rec.get("horse_active", 0)), 0, hs.size() - 1)]
	if float(h.get("fed", 0.0)) < Time.get_unix_time_from_system():
		return "%s aç! Önce Hara'da besle." % h.n
	return ""


func ride_color(id: int) -> int:
	var rec := _rec(id)
	var hs := _list(rec)
	if hs.is_empty():
		return 0
	return int(hs[clampi(int(rec.get("horse_active", 0)), 0, hs.size() - 1)].c)


@rpc("any_peer", "call_remote", "reliable")
func req_buy(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_stable(id):
		return
	var hs := _list(rec)
	if hs.size() >= MAX_HORSES:
		Net.notify(id, "Ahırında en fazla %d at olabilir." % MAX_HORSES, false)
		return
	if Rpg.level(id) < LEVEL:
		Net.notify(id, "At almak için seviye %d gerekli." % LEVEL, false)
		return
	if not Net.try_spend(id, PRICE):
		Net.notify(id, "At %s." % U.money(PRICE), false)
		return
	var used: Array = hs.map(func(h): return h.n)
	var free: Array = NAMES.filter(func(n): return not n in used)
	var h := {"n": free.pick_random(), "c": randi() % COLORS.size(), "spd": randi_range(40, 58), "sta": randi_range(40, 58),
		"fed": Time.get_unix_time_from_system() + FEED_TIME, "tr": 0.0, "wins": 0}
	hs.append(h)
	rec["horse_active"] = hs.size() - 1
	Ach.event(id, "horse")
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s adlı %s atın artık senin! F ile bin, Hara'da besle ve antrenman yaptır." % [h.n, COLOR_NAMES[int(h.c)].to_lower()])


@rpc("any_peer", "call_remote", "reliable")
func req_active(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	if rec.is_empty() or i < 0 or i >= _list(rec).size():
		return
	rec["horse_active"] = i
	Net.mark_dirty()
	send_state(id)
	if str(Net.players[id].get("ride", "")) == "horse":
		Net.players[id]["hc"] = ride_color(id)
		Net._broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func req_feed(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	if rec.is_empty() or i < 0 or i >= _list(rec).size() or not _at_stable(id):
		return
	var h: Dictionary = rec.horses[i]
	if bool(d.get("corn", false)):
		var store := Farm.barn(rec)
		if int(store.get("misir", 0)) < 2:
			Net.notify(id, "Ambarında 2 mısır yok.", false)
			return
		store["misir"] = int(store.misir) - 2
		if int(store.misir) <= 0:
			store.erase("misir")
		Farm.send_state(id)
	elif not Net.try_spend(id, FEED_PRICE):
		Net.notify(id, "Yem %s." % U.money(FEED_PRICE), false)
		return
	h["fed"] = maxf(float(h.get("fed", 0.0)), Time.get_unix_time_from_system()) + FEED_TIME
	h["fed"] = minf(float(h.fed), Time.get_unix_time_from_system() + FEED_TIME * 2.0)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s doydu." % h.n)


@rpc("any_peer", "call_remote", "reliable")
func req_train(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	var stat := str(d.get("stat", ""))
	if rec.is_empty() or i < 0 or i >= _list(rec).size() or not stat in ["spd", "sta"] or not _at_stable(id):
		return
	var h: Dictionary = rec.horses[i]
	var now := Time.get_unix_time_from_system()
	if float(h.get("fed", 0.0)) < now:
		Net.notify(id, "Aç atla antrenman olmaz, önce besle.", false)
		return
	if now - float(h.get("tr", 0.0)) < TRAIN_COOLDOWN:
		Net.notify(id, "%s dinleniyor (%d dk sonra)." % [h.n, int(ceil((TRAIN_COOLDOWN - (now - float(h.tr))) / 60.0))], false)
		return
	if int(h[stat]) >= STAT_MAX:
		Net.notify(id, "Bu özellik zaten en üstte.", false)
		return
	if not Rpg.use_energy(id, TRAIN_ENERGY):
		Net.notify(id, "Çok yorgunsun.", false)
		return
	var gain := randi_range(1, 3)
	h[stat] = mini(STAT_MAX, int(h[stat]) + gain)
	h["tr"] = now
	Rpg.add_xp(id, "riding", 20)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s antrenman yaptı: %s +%d" % [h.n, "hız" if stat == "spd" else "dayanıklılık", gain])


# --- yarış

func _npc_horse() -> Dictionary:
	return {"n": NAMES.pick_random() + " (NPC)", "c": randi() % COLORS.size(), "spd": randi_range(45, 72), "sta": randi_range(45, 72)}


func _odds(lanes: Array) -> void:
	var tot := 0.0
	for l in lanes:
		tot += pow(rating(l), 3.0)
	for l in lanes:
		var p := pow(rating(l), 3.0) / maxf(1.0, tot)
		l["odds"] = snappedf(clampf(0.85 / maxf(p, 0.01), 1.2, 12.0), 0.1)


@rpc("any_peer", "call_remote", "reliable")
func req_join(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _at_track(id):
		return
	var hs := _list(rec)
	if hs.is_empty():
		Net.notify(id, "Yarışmak için atın olmalı (Hara).", false)
		return
	var h: Dictionary = hs[clampi(int(rec.get("horse_active", 0)), 0, hs.size() - 1)]
	if float(h.get("fed", 0.0)) < Time.get_unix_time_from_system():
		Net.notify(id, "%s aç, önce besle." % h.n, false)
		return
	if not _race.is_empty() and _race.state != "lobby":
		Net.notify(id, "Yarış sürüyor, bir sonrakine katıl.", false)
		return
	if _race.is_empty():
		_race = {"state": "lobby", "t": LOBBY_TIME, "lanes": [], "bets": {}, "finish": []}
		Net.announce("Hipodromda at yarışı başlıyor! %d sn içinde katıl ya da bahis oyna (Sanayi)." % int(LOBBY_TIME))
	for l in _race.lanes:
		if int(l.get("pid", 0)) == id:
			return
	if _race.lanes.size() >= LANES:
		Net.notify(id, "Kulvarlar dolu.", false)
		return
	_race.lanes.append({"n": h.n, "owner": Net.players[id].name, "pid": id, "c": int(h.c), "spd": int(h.spd), "sta": int(h.sta),
		"hidx": int(rec.get("horse_active", 0))})
	_odds(_race.lanes)
	Net.notify(id, "%s ile yarışa katıldın! Yarışta Boşluk / KAMÇI ile hızlan ama dayanıklılığa dikkat." % h.n)
	_broadcast_race()


@rpc("any_peer", "call_remote", "reliable")
func req_bet(d: Dictionary) -> void:
	var id := Net.sender()
	if _race.is_empty() or _race.state != "lobby" or not Net.players.has(id):
		return
	var lane := int(d.get("lane", -1))
	var amount := clampi(int(d.get("amount", 0)), BET_MIN, BET_MAX)
	if lane < 0 or lane >= LANES:
		return
	if _race.bets.has(id):
		Net.notify(id, "Bu yarışa zaten bahis oynadın.", false)
		return
	if not Net.try_spend(id, amount):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	_race.bets[id] = [lane, amount]
	Net.notify(id, "Kulvar %d'e %s bahis." % [lane + 1, U.money(amount)])
	_broadcast_race()


@rpc("any_peer", "call_remote", "reliable")
func req_whip(_d: Dictionary) -> void:
	var id := Net.sender()
	if _race.is_empty() or _race.state != "run":
		return
	for l in _race.lanes:
		if int(l.get("pid", 0)) == id and float(l.st) > 5.0:
			l["whip"] = WHIP_TIME


@rpc("any_peer", "call_remote", "reliable")
func req_race(_d: Dictionary) -> void:
	_send_race(Net.sender())


func _view() -> Dictionary:
	if _race.is_empty():
		return {"state": "idle"}
	var lanes: Array = []
	for l in _race.lanes:
		lanes.append({"n": l.n, "owner": l.owner, "c": l.c, "x": snappedf(float(l.get("x", Map.HIPPO_START_X)), 0.1),
			"st": snappedf(float(l.get("st", 0.0)), 0.1), "stmax": float(l.get("stmax", 1.0)), "odds": l.get("odds", 2.0),
			"place": int(l.get("place", 0)), "pid": int(l.get("pid", 0)), "whip": float(l.get("whip", 0.0)) > 0.0,
			"spd": int(l.spd), "sta": int(l.sta)})
	var bets := {}
	for bid in _race.bets:
		bets[bid] = _race.bets[bid]
	return {"state": _race.state, "left": float(_race.t), "lanes": lanes, "bets": bets}


func _send_race(id: int) -> void:
	Net.tell(self, id, "on_race", _view())


func _broadcast_race() -> void:
	var v := _view()
	for id in Net.players:
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
		if Map.HIPPODROME.grow(700).has_point(p) or _race.get("bets", {}).has(id):
			Net.tell(self, id, "on_race", v)


func _start_run() -> void:
	while _race.lanes.size() < LANES:
		var h := _npc_horse()
		_race.lanes.append({"n": h.n, "owner": "", "pid": 0, "c": h.c, "spd": h.spd, "sta": h.sta})
	_odds(_race.lanes)
	for l in _race.lanes:
		l["x"] = Map.HIPPO_START_X
		l["stmax"] = 40.0 + float(l.sta)
		l["st"] = float(l.stmax)
		l["whip"] = 0.0
		l["place"] = 0
		l["ai"] = randf_range(0.0, 1.0)
	_race.state = "run"
	_race.t = 0.0
	_race.finish = []


func _tick_run(delta: float) -> void:
	_race.t = float(_race.t) + delta
	if float(_race.t) < 3.0:
		return                                # geri sayım
	for l in _race.lanes:
		if int(l.place) > 0:
			continue
		var x := float(l.x)
		var whip := float(l.whip)
		# NPC jokey: dayanıklılık yeterliyse ara ara, son düzlükte sık kamçılar
		if int(l.pid) == 0 and whip <= 0.0:
			var final_run := x > Map.HIPPO_FINISH_X - 650.0
			if float(l.st) > float(l.stmax) * (0.2 if final_run else 0.55) and randf() < (0.5 if final_run else 0.06) * delta * 10.0:
				whip = WHIP_TIME
		var v := (95.0 + float(l.spd) * 1.25) * randf_range(0.94, 1.06)
		if whip > 0.0 and float(l.st) > 0.0:
			v *= 1.38
			l["st"] = maxf(0.0, float(l.st) - 45.0 * delta)
			whip -= delta
		else:
			whip = 0.0
			l["st"] = minf(float(l.stmax), float(l.st) + 9.0 * delta)
			if float(l.st) < 4.0:
				v *= 0.8                      # yoruldu
		l["whip"] = whip
		var binicilik := 1.0
		if int(l.pid) != 0:
			binicilik += 0.01 * (Rpg.skill(int(l.pid), "riding") - 1) + (0.03 if School.has_by_id(int(l.pid), "binicilik") else 0.0)
		l["x"] = x + v * binicilik * delta
		if float(l.x) >= Map.HIPPO_FINISH_X:
			_race.finish.append(l)
			l["place"] = _race.finish.size()
	if _race.finish.size() >= _race.lanes.size():
		_end_race()


func _end_race() -> void:
	var lines: Array = []
	for i in _race.finish.size():
		var l: Dictionary = _race.finish[i]
		lines.append("%d. %s%s" % [i + 1, l.n, (" (%s)" % l.owner) if str(l.owner) != "" else ""])
		if str(l.owner) == "":
			continue
		var prize: int = PRIZES[i] if i < PRIZES.size() else 0
		if prize > 0:
			Net.add_money_by_name(str(l.owner), prize)
		var rec: Dictionary = Net.save_data.players.get(str(l.owner), {})
		var hs := _list(rec)
		var hi := int(l.get("hidx", 0))
		if i == 0 and hi < hs.size():
			hs[hi]["wins"] = int(hs[hi].get("wins", 0)) + 1
			hs[hi]["spd"] = mini(STAT_MAX, int(hs[hi].spd) + 1)
		var pid := Net.id_by_name(str(l.owner))
		if pid != 0:
			Rpg.add_xp(pid, "riding", 60 if i == 0 else 30)
			if i == 0:
				Ach.event(pid, "horse_win")
			Net.notify(pid, "%s yarışı %d. bitirdi!%s" % [l.n, i + 1, ("  +%s" % U.money(prize)) if prize > 0 else ""])
			send_state(pid)
	# bahisler
	var winner_lane: int = _race.lanes.find(_race.finish[0])
	for bid in _race.bets:
		var b: Array = _race.bets[bid]
		if int(b[0]) == winner_lane:
			var win := int(round(int(b[1]) * float(_race.lanes[winner_lane].odds)))
			if Net.players.has(bid):
				Net.add_money(bid, win)
				Ach.event(bid, "bet_horse")
				Net.notify(bid, "Bahsi kazandın! +%s" % U.money(win))
		elif Net.players.has(bid):
			Net.notify(bid, "Bahsi kaybettin. Kazanan: %s" % _race.finish[0].n, false)
	Net.announce("Hipodrom: " + ", ".join(lines.slice(0, 3)))
	Net.mark_dirty()
	_race.state = "done"
	_race.t = 6.0


func _process(delta: float) -> void:
	if not Net.is_server() or _race.is_empty():
		return
	match str(_race.state):
		"lobby":
			_race.t = float(_race.t) - delta
			if float(_race.t) <= 0.0:
				_start_run()
		"run":
			_tick_run(delta)
		"done":
			_race.t = float(_race.t) - delta
			if float(_race.t) <= 0.0:
				_race = {}
				for id in Net.players:
					Net.tell(self, id, "on_race", {"state": "idle"})
				return
	_send_acc += delta
	if _send_acc >= (0.1 if str(_race.get("state", "")) == "run" else 0.5):
		_send_acc = 0.0
		_broadcast_race()
