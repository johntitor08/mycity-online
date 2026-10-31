extends Node
## Plaj müzik festivali (2.0): her 2 saatte bir 15 dakika (yönetici: /festival). Plajda dev sahne, dans pisti, havai fişek.
##  DJ: kabinde sıraya gir; sıran gelince 60 sn'lik set çalarsın. Vuruşa (Boşluk) tam zamanında bas: kalabalığın
##  coşkusu (hype) artar; 8 vuruşta bir gelen "DROP" anında E'ye bas. Coşku 100 olunca havai fişekler patlar.
##  Kimse çalmıyorsa festivalin DJ'i Selin çalar.
##  Dans: gişeden bileklik al (100 TL), pistte ok tuşlarıyla beliren adımları vuruşta bas; seri yaptıkça puan artar.
##  Set bitince DJ coşkuya ve dansçı sayısına göre bahşiş, dansçılar puanlarına göre ödül alır.
##  Sunucu her vuruşu kendi saatiyle denetler (gecikme payıyla).
## Veri: rec["festival"] = {dj_sets, best_hype, dance_best}

signal changed
signal beat_hit(d: Dictionary)
signal fireworks(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PERIOD := 7200.0
const LENGTH := 900.0
const TICKET := 100
const SET_TIME := 60.0
const TRACKS := [
	{"name": "Kumsal Dalgası", "bpm": 110, "key": 0},
	{"name": "Gece Yarısı Güneşi", "bpm": 124, "key": 3},
	{"name": "Martı Ritmi", "bpm": 118, "key": 5},
	{"name": "Neon Dalgalar", "bpm": 128, "key": 7},
	{"name": "Yakamoz", "bpm": 100, "key": 2},
]
const GOOD := 0.13
const PERFECT := 0.06
const NPC_DJ := "Selin"
const MAX_QUEUE := 6
const ARROWS := ["left", "down", "up", "right"]

# --- istemci
var st := {}                         # {on, left, dj, track, t0 (sunucu saati), hype, queue, dancers, ticket}
var my_combo := 0
var my_points := 0

# --- sunucu
var _forced_until := -1.0
var _dj := ""                        # şu an çalan (NPC_DJ ya da oyuncu adı)
var _dj_id := 0
var _track := 0
var _t0 := 0.0                       # set başlangıcı (sunucu unix)
var _hype := 0.0
var _queue: Array = []               # oyuncu adları
var _tickets := {}                   # ad -> true (bu festival)
var _dancers := {}                   # ad -> {pts, combo, last_beat}
var _dj_hits := {}                   # vuruş indisi -> true
var _drop_done := {}
var _fw_at := 0.0
var _sync := 0.0
var _was_on := false
var natural := true                  # testler takvimli festivali kapatır (force yine çalışır)


func reset() -> void:
	st = {}
	_dj = ""
	_queue.clear()
	_tickets.clear()
	_dancers.clear()


func on_player_left(id: int) -> void:
	if Net.players.has(id):
		_queue.erase(Net.players[id].name)


func active() -> bool:
	return bool(st.get("on", false))


static func beat_len(track: int) -> float:
	return 60.0 / float(TRACKS[track % TRACKS.size()].bpm)


## k. vuruşta dans adımı var mı, hangi ok? ("" = dinlen)
static func step_at(seed_v: int, k: int) -> String:
	var h := absi(hash(seed_v * 131 + k))
	if k % 8 == 7 or h % 5 == 0:
		return ""
	return ARROWS[h % 4]


static func is_drop(k: int) -> bool:
	return k > 0 and k % 8 == 0


# ------------------------------------------------------------------ istemci API

func buy_ticket() -> void:
	Net.ask(self, "req_ticket")


func dj_join() -> void:
	Net.ask(self, "req_dj_join")


func dj_hit(drop: bool) -> void:
	Net.ask(self, "req_dj_hit", {"drop": drop})


func dance(arrow: String) -> void:
	Net.ask(self, "req_dance", {"a": arrow})


## İstemci: şu anki vuruş konumu (kaçıncı vuruş, kesir).
func beat_pos() -> float:
	if not active() or str(st.get("dj", "")) == "":
		return -1.0
	return (Land.server_now() - float(st.t0)) / beat_len(int(st.track))


@rpc("authority", "call_local", "unreliable_ordered")
func on_state(d: Dictionary) -> void:
	var was := active()
	var old_dj := str(st.get("dj", ""))
	st = d
	if was != active() or old_dj != str(d.get("dj", "")):
		changed.emit()


@rpc("authority", "call_local", "reliable")
func on_hit(d: Dictionary) -> void:
	if str(d.get("who", "")) == Net.my_name and d.has("combo"):
		my_combo = int(d.combo)
		my_points = int(d.pts)
	beat_hit.emit(d)


@rpc("authority", "call_local", "reliable")
func on_fireworks(d: Dictionary) -> void:
	fireworks.emit(d)


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("festival") is Dictionary:
		rec["festival"] = {"dj_sets": 0, "best_hype": 0, "dance_best": 0}
	return rec.festival


func _now() -> float:
	return Land.server_now()


func is_on() -> bool:
	var now := _now()
	return natural and fmod(now, PERIOD) < LENGTH or Time.get_ticks_msec() / 1000.0 < _forced_until


func force(minutes: float) -> void:
	_forced_until = Time.get_ticks_msec() / 1000.0 + minutes * 60.0


func force_stop() -> void:
	_forced_until = -1.0
	if _was_on:
		_end_festival()


func _view(for_name: String) -> Dictionary:
	if not _was_on:
		return {"on": false}
	var left := 0.0
	if Time.get_ticks_msec() / 1000.0 < _forced_until:
		left = _forced_until - Time.get_ticks_msec() / 1000.0
	else:
		left = LENGTH - fmod(_now(), PERIOD)
	var dancers: Array = []
	for k in _dancers:
		dancers.append([k, int(_dancers[k].pts)])
	dancers.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return {"on": true, "left": snappedf(left, 1.0), "dj": _dj, "track": _track, "t0": _t0, "hype": snappedf(_hype, 0.1), "queue": _queue.duplicate(),
		"dancers": dancers.slice(0, 8), "ticket": _tickets.has(for_name), "set_left": snappedf(SET_TIME - (_now() - _t0), 0.1)}


func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_state", _view(Net.players[id].name))


func _broadcast() -> void:
	for id in Net.players:
		send_state(id)


func _start_set(who: String, id: int) -> void:
	_dj = who
	_dj_id = id
	_track = randi() % TRACKS.size()
	# vuruşlar tam saniyeye otursun diye kısa bir giriş
	_t0 = _now() + 2.0
	_hype = 20.0 if who == NPC_DJ else 10.0
	_dj_hits.clear()
	_drop_done.clear()
	for k in _dancers:
		_dancers[k]["combo"] = 0
	if who != NPC_DJ:
		Net.announce("Festival sahnesinde DJ %s! Şarkı: %s" % [who, TRACKS[_track].name])
	_broadcast()


func _end_set() -> void:
	if _dj != NPC_DJ and _dj_id != 0 and Net.players.has(_dj_id):
		var n := _dancers.size()
		var tip := int(40 + _hype * 6.0 + n * 60)
		Net.add_money(_dj_id, tip)
		Rpg.add_xp(_dj_id, "music", 40)
		var f := _data(_rec(_dj_id))
		f["dj_sets"] = int(f.dj_sets) + 1
		f["best_hype"] = maxi(int(f.best_hype), int(_hype))
		Ach.event(_dj_id, "dj_sets")
		Ach.set_max(_dj_id, "dj_hype", int(_hype))
		Net.notify(_dj_id, "Setin bitti! Coşku %d, %d dansçı. Bahşiş %s" % [int(_hype), n, U.money(tip)])
	for k in _dancers:
		var pid := Net.id_by_name(k)
		var pts := int(_dancers[k].pts)
		if pid != 0 and pts > 0:
			var pay := mini(800, pts * 2)
			Net.add_money(pid, pay)
			var f := _data(_rec(pid))
			f["dance_best"] = maxi(int(f.dance_best), pts)
			Ach.set_max(pid, "dance_points", pts)
			Net.notify(pid, "Dans puanın %d: %s" % [pts, U.money(pay)])
		_dancers[k]["pts"] = 0
	Net.mark_dirty()
	_dj = ""
	_dj_id = 0


func _end_festival() -> void:
	if _dj != "":
		_end_set()
	_was_on = false
	_queue.clear()
	_tickets.clear()
	_dancers.clear()
	Net.tell_all(self, "on_fireworks", {"big": true})
	Net.announce("Festival havai fişeklerle sona erdi! 2 saat sonra yine plajda.")
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_ticket(_d: Dictionary) -> void:
	var id := Net.sender()
	if not _was_on or not Net.players.has(id) or _pos(id).distance_to(Map.FEST_GATE) > 140.0:
		return
	var me: String = Net.players[id].name
	if _tickets.has(me):
		return
	if not Net.try_spend(id, TICKET):
		Net.notify(id, "Festival bilekliği %s." % U.money(TICKET), false)
		return
	_tickets[me] = true
	Ach.event(id, "festivals")
	Net.notify(id, "Bilekliğini taktın! Dans pistinde ok tuşlarıyla vuruşta dans et.")
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_dj_join(_d: Dictionary) -> void:
	var id := Net.sender()
	if not _was_on or not Net.players.has(id) or _pos(id).distance_to(Map.DJ_BOOTH) > 160.0:
		return
	var me: String = Net.players[id].name
	if me in _queue or _dj == me:
		return
	if _queue.size() >= MAX_QUEUE:
		Net.notify(id, "DJ sırası dolu.", false)
		return
	_queue.append(me)
	Net.notify(id, "DJ sırasına girdin (%d. sıradasın)." % _queue.size())
	if _dj == NPC_DJ:
		_end_set()                # sıradaki oyuncu hemen çıksın
	_broadcast()


func _nearest(t: float, track: int) -> Array:
	var bl := beat_len(track)
	var k := int(round((t - _t0) / bl))
	return [k, absf((t - _t0) - k * bl)]


@rpc("any_peer", "call_remote", "reliable")
func req_dj_hit(d: Dictionary) -> void:
	var id := Net.sender()
	if id != _dj_id or _dj == "" or _dj == NPC_DJ:
		return
	var nb := _nearest(_now(), _track)
	var k: int = nb[0]
	var err: float = nb[1]
	if k < 0 or _dj_hits.has(k):
		return
	_dj_hits[k] = true
	var drop := bool(d.get("drop", false))
	var grade := "miss"
	if err <= PERFECT * 1.6:
		grade = "perfect"
	elif err <= GOOD * 1.6:
		grade = "good"
	if drop:
		if is_drop(k) and grade != "miss":
			_hype += 8.0
			grade = "drop"
		else:
			_hype -= 4.0
	else:
		_hype += {"perfect": 2.5, "good": 1.5, "miss": -3.0}[grade]
	_hype = clampf(_hype, 0.0, 100.0)
	if _hype >= 100.0 and _now() - _fw_at > 20.0:
		_fw_at = _now()
		Net.tell_all(self, "on_fireworks", {"big": false})
		Net.announce("%s kalabalığı coştu! Havai fişekler!" % _dj)
	Net.tell(self, id, "on_hit", {"who": _dj, "grade": grade, "k": k})


@rpc("any_peer", "call_remote", "reliable")
func req_dance(d: Dictionary) -> void:
	var id := Net.sender()
	if not _was_on or _dj == "" or not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	if not _tickets.has(me) or not Map.DANCE_FLOOR.grow(20).has_point(_pos(id)):
		return
	if not _dancers.has(me):
		_dancers[me] = {"pts": 0, "combo": 0, "last": -1}
	var dn: Dictionary = _dancers[me]
	var nb := _nearest(_now(), _track)
	var k: int = nb[0]
	var err: float = nb[1]
	if k <= int(dn.last):
		return
	dn["last"] = k
	var want := step_at(int(_t0), k)
	var a := str(d.get("a", ""))
	var grade := "miss"
	if want != "" and a == want and err <= GOOD * 1.6:
		grade = "perfect" if err <= PERFECT * 1.6 else "good"
	if grade == "miss":
		dn["combo"] = 0
	else:
		dn["combo"] = int(dn.combo) + 1
		dn["pts"] = int(dn.pts) + (10 if grade == "perfect" else 6) * (1 + mini(int(dn.combo), 20) / 5)
		_hype = clampf(_hype + 0.4, 0.0, 100.0)
	Net.tell(self, id, "on_hit", {"who": me, "grade": grade, "k": k, "combo": int(dn.combo), "pts": int(dn.pts)})


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var on := is_on()
	if on and not _was_on:
		_was_on = true
		Net.announce("PLAJ FESTİVALİ BAŞLADI! Sahne, DJ kabini ve dans pisti plajda (bileklik %s)." % U.money(TICKET))
		_broadcast()
	elif not on and _was_on:
		_end_festival()
		return
	if not _was_on:
		return
	var now := _now()
	if _dj == "":
		while not _queue.is_empty():
			var who: String = _queue.pop_front()
			var pid := Net.id_by_name(who)
			if pid != 0 and _pos(pid).distance_to(Map.DJ_BOOTH) < 260.0:
				_start_set(who, pid)
				break
		if _dj == "":
			_start_set(NPC_DJ, 0)
	elif now - _t0 >= SET_TIME:
		_end_set()
	elif _dj != NPC_DJ and (_dj_id == 0 or not Net.players.has(_dj_id)):
		_end_set()
	# coşku yavaşça söner
	_hype = maxf(0.0, _hype - delta * 0.6)
	_sync += delta
	if _sync >= 0.5:
		_sync = 0.0
		_broadcast()
