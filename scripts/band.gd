extends Node
## Konser ve müzik aletleri (1.2). Parktaki sahnede gitar, davul ya da klavye çal: ritim oyunu.
## Notalar dört şeritte akar (D F J K). Sunucu her vuruşun zamanını kendi saatiyle denetler (gecikme payıyla).
## Çalınan notalar yakındaki herkese gider, herkes duyar. Şarkı bitince puana göre kazanç: seyirci arttıkça
## ve sahnede birden çok oyuncu birlikte çalıyorsa (grup) kazanç artar. Seyirciler bahşiş verebilir.
## Veri: rec["instruments"] = ["gitar", ...]

signal changed
signal song_started(d: Dictionary)
signal hit_result(d: Dictionary)
signal song_ended(d: Dictionary)
signal note_heard(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const INSTRUMENTS := {
	"gitar": {"name": "Gitar", "price": 1500},
	"davul": {"name": "Davul", "price": 2500},
	"klavye": {"name": "Klavye", "price": 3000},
}
# ad, bpm, vuruş sayısı, nota yoğunluğu, gereken müzisyenlik seviyesi
const SONGS := [
	{"name": "Park Esintisi", "bpm": 88, "beats": 40, "dense": 0.55, "level": 1},
	{"name": "Yaz Akşamı", "bpm": 104, "beats": 48, "dense": 0.65, "level": 2},
	{"name": "Liman Blues", "bpm": 96, "beats": 56, "dense": 0.75, "level": 3},
	{"name": "Şehir Işıkları", "bpm": 120, "beats": 64, "dense": 0.8, "level": 4},
	{"name": "Kar Fırtınası", "bpm": 140, "beats": 72, "dense": 0.9, "level": 6},
]
const LANE_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const LANE_PITCH := [1.0, 1.1225, 1.335, 1.498]
const LEAD := 2.5                  # şarkı başlamadan önceki geri sayım
const EARLY := 0.30                # sunucu toleransı (sn): erken
const LATE := 0.55                 # geç (ağ gecikmesi dahil)
const ENERGY := 2
const TIP := 50
const TIP_COOLDOWN := 8.0
const HEAR_RANGE := 1100.0
const ANNOUNCE_EVERY := 300.0

# --- istemci
var owned: Array = []
var session := {}                  # {song, inst, notes, t0 (yerel)}

# --- sunucu
var _play := {}                    # id -> {song, inst, notes, t0, done, hits, misses, combo, maxc, score}
var _tip_t := {}
var _announced := {}


func reset() -> void:
	owned = []
	session = {}
	_play.clear()


func on_player_left(id: int) -> void:
	_play.erase(id)


## Şarkının notaları: [[zaman, şerit], ...] (sunucu ve istemci aynı tohumla aynı notaları üretir)
static func chart(song: int) -> Array:
	var s: Dictionary = SONGS[song]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + song * 31
	var beat := 60.0 / float(s.bpm)
	var out: Array = []
	var lane := 0
	for b in int(s.beats):
		if b % 8 == 7:
			continue                        # nefes
		if rng.randf() < float(s.dense) or b % 4 == 0:
			lane = (lane + rng.randi_range(1, 3)) % 4 if rng.randf() < 0.7 else lane
			out.append([b * beat, lane])
		if song >= 2 and rng.randf() < float(s.dense) * 0.35:
			out.append([(b + 0.5) * beat, rng.randi_range(0, 3)])
	return out


static func sample_of(inst: String, lane: int) -> Array:
	if inst == "davul":
		return ["davul_%d" % lane, 1.0]
	return ["piyano" if inst == "klavye" else "gitar", LANE_PITCH[lane]]


func is_playing() -> bool:
	return not session.is_empty()


## İstemci: şu an sahnede çalanlar (kadro bilgisinden).
func performers_seen() -> Array:
	var out: Array = []
	for id in Net.roster:
		if str(Net.roster[id].get("playing", "")) != "":
			out.append(id)
	return out


# ------------------------------------------------------------------ istemci API

func buy(inst: String) -> void:
	Net.ask(self, "req_buy", {"inst": inst})


func play(song: int, inst: String) -> void:
	Net.ask(self, "req_play", {"song": song, "inst": inst})


func hit(i: int, lane: int) -> void:
	Net.ask(self, "req_hit", {"i": i, "lane": lane})


func stop() -> void:
	Net.ask(self, "req_stop")


func tip(to: int) -> void:
	Net.ask(self, "req_tip", {"to": to})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	owned = d.get("owned", [])
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_song(d: Dictionary) -> void:
	session = {"song": int(d.song), "inst": str(d.inst), "notes": chart(int(d.song)),
		"t0": Time.get_ticks_msec() / 1000.0 + float(d.lead)}
	song_started.emit(session)


@rpc("authority", "call_local", "reliable")
func on_hit(d: Dictionary) -> void:
	hit_result.emit(d)


@rpc("authority", "call_local", "reliable")
func on_end(d: Dictionary) -> void:
	session = {}
	song_ended.emit(d)


@rpc("authority", "call_local", "unreliable")
func on_note(d: Dictionary) -> void:
	if int(d.get("id", 0)) == Net.my_id():
		return
	note_heard.emit(d)
	var smp := sample_of(str(d.inst), int(d.lane))
	Sfx.play(smp[0], -8.0, smp[1])


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func on_stage(id: int) -> bool:
	return Map.STAGE.grow(30).has_point(_pos(id))


func send_state(id: int) -> void:
	var rec := _rec(id)
	if not rec.is_empty():
		Net.tell(self, id, "on_state", {"owned": rec.get("instruments", [])})


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var inst := str(d.get("inst", ""))
	if rec.is_empty() or not INSTRUMENTS.has(inst) or not Map.STAGE.grow(220).has_point(_pos(id)):
		return
	if not rec.get("instruments") is Array:
		rec["instruments"] = []
	if inst in rec.instruments:
		return
	if not Net.try_spend(id, int(INSTRUMENTS[inst].price)):
		Net.notify(id, "%s %s." % [INSTRUMENTS[inst].name, U.money(int(INSTRUMENTS[inst].price))], false)
		return
	rec.instruments.append(inst)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s aldın! Sahneye çık ve çal." % INSTRUMENTS[inst].name)


@rpc("any_peer", "call_remote", "reliable")
func req_play(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var song := int(d.get("song", -1))
	var inst := str(d.get("inst", ""))
	if rec.is_empty() or _play.has(id) or song < 0 or song >= SONGS.size():
		return
	if not inst in rec.get("instruments", []):
		Net.notify(id, "Önce bir %s almalısın." % INSTRUMENTS.get(inst, {"name": "çalgı"}).name, false)
		return
	if not on_stage(id):
		Net.notify(id, "Çalmak için parktaki sahneye çık.", false)
		return
	if Rpg.skill(id, "music") < int(SONGS[song].level):
		Net.notify(id, "Bu şarkı için Müzisyenlik seviyesi %d gerekli." % int(SONGS[song].level), false)
		return
	if not Rpg.use_energy(id, ENERGY):
		Net.notify(id, "Çok yorgunsun.", false)
		return
	_play[id] = {"song": song, "inst": inst, "notes": chart(song), "t0": _now() + LEAD, "done": {},
		"hits": 0, "misses": 0, "combo": 0, "maxc": 0, "score": 0, "next": 0}
	Net.players[id]["playing"] = inst
	Net._broadcast_roster()
	Net.tell(self, id, "on_song", {"song": song, "inst": inst, "lead": LEAD})
	var me: String = Net.players[id].name
	if _now() - float(_announced.get(me, -9999.0)) > ANNOUNCE_EVERY:
		_announced[me] = _now()
		Net.announce("%s parktaki sahnede %s çalıyor: «%s». Dinlemeye gel!" % [me, INSTRUMENTS[inst].name, SONGS[song].name])


@rpc("any_peer", "call_remote", "reliable")
func req_stop(_d: Dictionary) -> void:
	_finish(Net.sender(), true)


@rpc("any_peer", "call_remote", "reliable")
func req_hit(d: Dictionary) -> void:
	var id := Net.sender()
	if not _play.has(id):
		return
	var s: Dictionary = _play[id]
	var i := int(d.get("i", -1))
	var lane := int(d.get("lane", -1))
	if i < 0 or i >= s.notes.size() or s.done.has(i):
		return
	var dt := _now() - (float(s.t0) + float(s.notes[i][0]))
	if dt < -EARLY or dt > LATE:
		return                        # çok erken/geç vuruş sayılmaz (nota sonradan "kaçtı" olur)
	s.done[i] = true
	var res := {"i": i}
	if lane != int(s.notes[i][1]):
		s["combo"] = 0
		s["misses"] = int(s.misses) + 1
		res["ok"] = false
	else:
		s["combo"] = int(s.combo) + 1
		s["maxc"] = maxi(int(s.maxc), int(s.combo))
		s["hits"] = int(s.hits) + 1
		var pts := int(round(100.0 * (1.0 + mini(int(s.combo), 30) * 0.03)))
		s["score"] = int(s.score) + pts
		res["ok"] = true
		res["pts"] = pts
		_spread_note(id, str(s.inst), lane)
	res["combo"] = int(s.combo)
	res["score"] = int(s.score)
	Net.tell(self, id, "on_hit", res)


func _spread_note(id: int, inst: String, lane: int) -> void:
	var p := _pos(id)
	for pid in Net.players:
		if pid != id and _pos(pid).distance_to(p) < HEAR_RANGE:
			Net.tell(self, pid, "on_note", {"id": id, "inst": inst, "lane": lane})


## Sahnede birlikte çalanlar ve seyirciler.
func performers() -> Array:
	var out: Array = []
	for id in _play:
		if on_stage(id):
			out.append(id)
	return out


func _audience(exclude: Array) -> int:
	var n := 0
	for pid in Net.players:
		if not pid in exclude and Map.STAGE.grow(260).has_point(_pos(pid)):
			n += 1
	return n


func _finish(id: int, aborted: bool) -> void:
	if not _play.has(id):
		return
	var s: Dictionary = _play[id]
	var band := performers()
	_play.erase(id)
	if Net.players.has(id):
		Net.players[id].erase("playing")
		Net._broadcast_roster()
	if aborted:
		Net.tell(self, id, "on_end", {"ok": false, "text": "Şarkıyı yarıda bıraktın."})
		return
	var total: int = s.notes.size()
	var acc := float(s.hits) / maxf(1.0, float(total))
	var band_mult := 1.5 if band.size() >= 2 and id in band else 1.0
	var crowd := _audience(band)
	var mult := band_mult * (1.0 + 0.15 * mini(crowd, 6)) * Events.pay_mult() * (1.15 if Rpg.buff(id, "work") else 1.0)
	var pay := int(round(float(s.score) / 22.0 * mult))
	Net.add_money(id, pay)
	Rpg.add_xp(id, "music", int(s.hits) * 2 + (40 if acc >= 0.9 else 0))
	Ach.event(id, "songs")
	if band_mult > 1.0:
		Ach.event(id, "band")
	if int(s.hits) == total and total > 0:
		Ach.event(id, "fullcombo")
	Bank.activity("MRKT", 1)
	var grade := "S" if acc >= 0.97 else ("A" if acc >= 0.85 else ("B" if acc >= 0.7 else ("C" if acc >= 0.5 else "D")))
	var text := "«%s» bitti! İsabet %%%d, en uzun seri %d, not: %s.  +%s" % [SONGS[s.song].name, int(acc * 100), int(s.maxc), grade, U.money(pay)]
	if band_mult > 1.0:
		text += "  (grup bonusu)"
	if crowd > 0:
		text += "  (%d seyirci)" % crowd
	Net.tell(self, id, "on_end", {"ok": true, "pay": pay, "acc": acc, "grade": grade, "score": int(s.score), "text": text})
	Net.mark_dirty()


@rpc("any_peer", "call_remote", "reliable")
func req_tip(d: Dictionary) -> void:
	var id := Net.sender()
	var to := int(d.get("to", 0))
	if not Net.players.has(id) or not _play.has(to) or to == id:
		return
	if _pos(id).distance_to(_pos(to)) > 400.0:
		Net.notify(id, "Bahşiş için sahneye yaklaş.", false)
		return
	if _now() - float(_tip_t.get(id, -99.0)) < TIP_COOLDOWN:
		return
	if not Net.try_spend(id, TIP):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	_tip_t[id] = _now()
	Net.add_money(to, TIP)
	Ach.event(to, "tips")
	Net.notify(id, "%s'e %s bahşiş verdin." % [Net.players[to].name, U.money(TIP)])
	Net.notify(to, "%s sana %s bahşiş verdi!" % [Net.players[id].name, U.money(TIP)])


func _process(_delta: float) -> void:
	if not Net.is_server() or _play.is_empty():
		return
	var now := _now()
	for id in _play.keys():
		if not Net.players.has(id):
			_play.erase(id)
			continue
		var s: Dictionary = _play[id]
		# geçen notalar kaçtı sayılır
		while int(s.next) < s.notes.size() and now > float(s.t0) + float(s.notes[int(s.next)][0]) + LATE:
			var i := int(s.next)
			if not s.done.has(i):
				s.done[i] = true
				s["misses"] = int(s.misses) + 1
				s["combo"] = 0
				Net.tell(self, id, "on_hit", {"i": i, "ok": false, "miss": true, "combo": 0, "score": int(s.score)})
			s["next"] = i + 1
		if int(s.next) >= s.notes.size():
			_finish(id, false)
		elif not on_stage(id):
			_finish(id, true)
