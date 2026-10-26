extends Node
## Sinema (1.7, fuar bölgesinde akvaryumun güneyi).
##  Seanslar: her 2 dakikada bir 90 saniyelik kısa animasyon filmi (4 film sırayla döner). Herkes aynı anda,
##  aynı sahneyi izler (sunucu saatine bağlı). Bilet o seans içindir. Patlamış mısır enerji verir.
##  Tepkiler (alkış, kahkaha, çığlık) salondaki herkese görünür.
##  Karaoke: perdede sözler akar, her heceyi tam vaktinde Boşluk'la söylersin (notalar çalar). Puanı sunucu
##  vuruş zamanlarından hesaplar; günün en yüksek puanı "Karaoke Yıldızı" olur.
## Veri: rec["cinema"] = {films, best, kara_day, kara_n}; save_data["karaoke"] = {day, best, by}

signal changed
signal reaction(d: Dictionary)
signal karaoke_result(d: Dictionary)

const U = preload("res://scripts/util.gd")
const Map = preload("res://scripts/map.gd")

const TICKET := 40
const POPCORN := 15
const POPCORN_ENERGY := 12
const SESSION := 120.0
const FILM_LEN := 90.0
const FILMS := [
	{"name": "Uzay Kedisi", "desc": "Minik bir kedi roketle Ay'a gidip balık şeklindeki bir yıldız arar."},
	{"name": "Korsanın Altını", "desc": "Tek Göz Rıza'nın gençliği: fırtına, ada ve kayıp sandık."},
	{"name": "Robotun Dostu", "desc": "Hurdalıkta uyanan robot, şehirde bir köpekle arkadaş olur."},
	{"name": "Dev Kaplumbağa", "desc": "Okyanusun dibindeki yaşlı kaplumbağa, Kraken'e yol gösterir."},
]
const REACTIONS := {"alkis": "Alkış!", "kahkaha": "Hahaha!", "ciglik": "Aaaa!", "vay": "Vay be!"}
# Karaoke şarkıları (sözler oyuna özgü). Her satır: [hece/kelime listesi]; her biri bir vuruş.
const SONGS := [
	{"name": "Şehrin Işıkları", "bpm": 100, "lines": [
		["Şeh", "rin", "ı", "şık", "la", "rı", "yan", "dı"],
		["Mar", "tı", "lar", "de", "ni", "ze", "dal", "dı"],
		["Dost", "lar", "la", "çar", "şı", "da", "bu", "luş", "tuk"],
		["Ge", "ce", "bo", "yu", "şar", "kı", "söy", "le", "dik"]],
		"melody": [0, 2, 4, 4, 2, 0, 2, 4, 5, 4, 2, 0, 2, 0, 4, 4, 5, 7, 5, 4, 2, 4, 5, 4, 2, 0, 2, 4, 2, 0, 0, 2, 4, 2, 0]},
	{"name": "Okyanus Türküsü", "bpm": 92, "lines": [
		["Dal", "ga", "lar", "kı", "yı", "ya", "vu", "rur"],
		["Tek", "nem", "rüz", "gâr", "la", "yol", "bu", "lur"],
		["U", "zak", "a", "da", "da", "bir", "san", "dık"],
		["Kra", "ken", "bi", "le", "bize", "dost", "ka", "lır"]],
		"melody": [4, 4, 5, 7, 5, 4, 2, 0, 2, 4, 5, 4, 2, 0, 2, 4, 7, 7, 5, 4, 5, 4, 2, 0, 0, 2, 4, 5, 4, 2, 2, 0]},
]
const LINE_GAP := 2      # satırlar arası boş vuruş
const HIT_PERFECT := 0.09
const HIT_GOOD := 0.18
const KARAOKE_DAILY := 3             # günde ödüllü karaoke sayısı

# --- istemci
var my := {"ticket": -1, "films": 0, "best": 0}
var viewers: Array = []              # salondaki oyuncu adları
var kara_best := {"best": 0, "by": ""}
var karaoke := {}                    # {song, t0 (yerel), beats}

# --- sunucu
var _tickets := {}                   # ad -> seans no
var _watch := {}                     # id -> izlediği seans
var _kara := {}                      # id -> {song, t0 (sunucu sn)}
var _react_t := {}


func reset() -> void:
	my = {"ticket": -1, "films": 0, "best": 0}
	viewers = []
	karaoke = {}
	_tickets.clear()
	_watch.clear()
	_kara.clear()


func on_player_left(id: int) -> void:
	_watch.erase(id)
	_kara.erase(id)
	_react_t.erase(id)
	_send_viewers()


## Seans bilgisi: {n: seans no, film, t: filmin kaçıncı sn'sinde, playing, left: sonraki filme kalan}
static var shift := 0.0              # testler seansı kaydırır (oyunda 0)


static func session_at(t: float) -> Dictionary:
	t += shift
	var n := int(floor(t / SESSION))
	var u := t - n * SESSION
	return {"n": n, "film": n % FILMS.size(), "t": u, "playing": u < FILM_LEN, "left": SESSION - u}


## Bir şarkının vuruş zamanları (sn, başlangıca göre) ve heceleri.
static func beats(song: int) -> Array:
	var s: Dictionary = SONGS[song]
	var step := 60.0 / float(s.bpm)
	var out: Array = []
	var t := 3.0                       # 3 sn geri sayım
	var mi := 0
	for li in s.lines.size():
		for w in s.lines[li]:
			out.append({"t": t, "w": w, "line": li, "note": int(s.melody[mi % s.melody.size()])})
			mi += 1
			t += step
		t += step * LINE_GAP
	return out


static func song_length(song: int) -> float:
	var b := beats(song)
	return float(b[-1].t) + 2.0


## Vuruş zamanlarından puan (sunucu ve istemci aynı hesaplar).
static func score_hits(song: int, hits: Array) -> Dictionary:
	var bs := beats(song)
	var used := {}
	var perfect := 0
	var good := 0
	for h in hits:
		var ht := float(h)
		var best_i := -1
		var best_d := 1e9
		for i in bs.size():
			if used.has(i):
				continue
			var dd := absf(float(bs[i].t) - ht)
			if dd < best_d:
				best_d = dd
				best_i = i
		if best_i < 0 or best_d > HIT_GOOD:
			continue
		used[best_i] = true
		if best_d <= HIT_PERFECT:
			perfect += 1
		else:
			good += 1
	var extra := maxi(0, hits.size() - bs.size())        # rastgele basmanın cezası
	var score := maxi(0, perfect * 100 + good * 50 - extra * 30)
	return {"score": score, "perfect": perfect, "good": good, "miss": bs.size() - perfect - good, "max": bs.size() * 100}


# ------------------------------------------------------------------ istemci API

func buy_ticket() -> void:
	Net.ask(self, "req_ticket")


func buy_popcorn() -> void:
	Net.ask(self, "req_popcorn")


func watch(on: bool) -> void:
	Net.ask(self, "req_watch", {"on": on})


func react(k: String) -> void:
	Net.ask(self, "req_react", {"k": k})


func karaoke_start(song: int) -> void:
	Net.ask(self, "req_karaoke", {"song": song})


func karaoke_finish(hits: Array) -> void:
	karaoke = {}
	Net.ask(self, "req_karaoke_end", {"hits": hits})


func has_ticket(n: int) -> bool:
	return int(my.get("ticket", -1)) == n


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d.get("my", my)
	kara_best = d.get("kara", kara_best)
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_viewers(d: Dictionary) -> void:
	viewers = d.get("v", [])
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_react(d: Dictionary) -> void:
	reaction.emit(d)


@rpc("authority", "call_local", "reliable")
func on_karaoke(d: Dictionary) -> void:
	karaoke = {"song": int(d.song), "t0": Time.get_ticks_msec() / 1000.0, "beats": beats(int(d.song))}
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_karaoke_result(d: Dictionary) -> void:
	karaoke = {}
	karaoke_result.emit(d)
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("cinema") is Dictionary:
		rec["cinema"] = {"films": 0, "best": 0, "kara_day": "", "kara_n": 0}
	return rec.cinema


func _at_cinema(id: int) -> bool:
	return (Map.CINEMA.rect as Rect2).grow(80).has_point(_pos(id))


func _now() -> float:
	return Time.get_unix_time_from_system()


func _kara_board() -> Dictionary:
	var today := Time.get_date_string_from_system()
	var k = Net.save_data.get("karaoke")
	if not k is Dictionary or str(k.get("day", "")) != today:
		k = {"day": today, "best": 0, "by": ""}
		Net.save_data["karaoke"] = k
	return k


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var c := _data(rec)
	var kb := _kara_board()
	Net.tell(self, id, "on_state", {"my": {"ticket": int(_tickets.get(Net.players[id].name, -1)), "films": int(c.films), "best": int(c.best)},
		"kara": {"best": int(kb.best), "by": str(kb.by)}})


func _send_viewers() -> void:
	var names: Array = []
	for id in _watch:
		if Net.players.has(id):
			names.append(Net.players[id].name)
	for id in _watch:
		Net.tell(self, id, "on_viewers", {"v": names})


@rpc("any_peer", "call_remote", "reliable")
func req_ticket(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _at_cinema(id):
		return
	var s := session_at(_now())
	# film başladıysa bilet bir sonraki seans içindir (son 10 sn hariç: hâlâ bu seansa girilebilir)
	var n: int = int(s.n) if float(s.t) < 20.0 else int(s.n) + 1
	var me: String = Net.players[id].name
	if int(_tickets.get(me, -1)) >= n:
		Net.notify(id, "Biletin zaten var.", false)
		return
	if not Net.try_spend(id, TICKET):
		Net.notify(id, "Sinema bileti %s." % U.money(TICKET), false)
		return
	_tickets[me] = n
	send_state(id)
	var film: Dictionary = FILMS[n % FILMS.size()]
	Net.notify(id, "Bilet alındı: \"%s\"%s" % [film.name, "" if n == int(s.n) else " (sonraki seans, %d sn sonra)" % int(s.left)])


@rpc("any_peer", "call_remote", "reliable")
func req_popcorn(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _at_cinema(id):
		return
	if not Net.try_spend(id, POPCORN):
		Net.notify(id, "Patlamış mısır %s." % U.money(POPCORN), false)
		return
	Rpg.add_energy(id, POPCORN_ENERGY)
	Net.notify(id, "Çıtır çıtır patlamış mısır! (+%d enerji)" % POPCORN_ENERGY)


@rpc("any_peer", "call_remote", "reliable")
func req_watch(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if bool(d.get("on", false)) and _at_cinema(id):
		_watch[id] = int(session_at(_now()).n)
	else:
		_watch.erase(id)
		Net.tell(self, id, "on_viewers", {"v": []})
	_send_viewers()


@rpc("any_peer", "call_remote", "reliable")
func req_react(d: Dictionary) -> void:
	var id := Net.sender()
	var k := str(d.get("k", ""))
	if not _watch.has(id) or not REACTIONS.has(k):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_react_t.get(id, 0.0)) < 1.5:
		return
	_react_t[id] = now
	for pid in _watch:
		Net.tell(self, pid, "on_react", {"who": Net.players[id].name, "k": k})


@rpc("any_peer", "call_remote", "reliable")
func req_karaoke(d: Dictionary) -> void:
	var id := Net.sender()
	var song := int(d.get("song", -1))
	if not Net.players.has(id) or not _at_cinema(id) or song < 0 or song >= SONGS.size() or _kara.has(id):
		return
	_kara[id] = {"song": song, "t0": Time.get_ticks_msec() / 1000.0}
	Net.tell(self, id, "on_karaoke", {"song": song})


@rpc("any_peer", "call_remote", "reliable")
func req_karaoke_end(d: Dictionary) -> void:
	var id := Net.sender()
	if not _kara.has(id):
		return
	var k: Dictionary = _kara[id]
	_kara.erase(id)
	var rec := _rec(id)
	var elapsed := Time.get_ticks_msec() / 1000.0 - float(k.t0)
	var hits: Array = []
	for h in d.get("hits", []):
		var ht := float(h)
		if ht >= 0.0 and ht <= elapsed + 0.5:          # gelecekten vuruş olmaz
			hits.append(ht)
	var res := score_hits(int(k.song), hits)
	if elapsed + 1.0 < song_length(int(k.song)) * 0.6:
		res.score = 0                                    # şarkı yarıda kesildi
	var c := _data(rec)
	var today := Time.get_date_string_from_system()
	if str(c.get("kara_day", "")) != today:
		c["kara_day"] = today
		c["kara_n"] = 0
	var money := 0
	if int(c.kara_n) < KARAOKE_DAILY and int(res.score) > 0:
		c["kara_n"] = int(c.kara_n) + 1
		money = int(res.score) / 10
		Net.add_money(id, money)
		Rpg.add_xp(id, "", int(res.score) / 40)
	if int(res.score) > int(c.best):
		c["best"] = int(res.score)
	var kb := _kara_board()
	var star := false
	if int(res.score) > int(kb.best):
		kb["best"] = int(res.score)
		kb["by"] = Net.players[id].name
		star = true
		Net.announce("%s karaokede günün rekorunu kırdı: %d puan! (%s)" % [Net.players[id].name, int(res.score), SONGS[int(k.song)].name])
	Ach.event(id, "karaoke")
	if int(res.score) >= int(res.max) * 0.8:
		Ach.event(id, "karaoke_star")
	Net.mark_dirty()
	res["money"] = money
	res["star"] = star
	Net.tell(self, id, "on_karaoke_result", res)
	send_state(id)


func _process(_delta: float) -> void:
	if not Net.is_server() or _watch.is_empty():
		return
	# film sonunda biletiyle baştan izleyenler ödül alır
	var s := session_at(_now())
	for id in _watch.keys():
		if not Net.players.has(id) or not _at_cinema(id):
			_watch.erase(id)
			_send_viewers()
			continue
		var n := int(_watch[id])
		if n < int(s.n) or (n == int(s.n) and not s.playing):
			var me: String = Net.players[id].name
			if int(_tickets.get(me, -1)) == n and n <= int(s.n):
				_tickets.erase(me)
				var c := _data(_rec(id))
				c["films"] = int(c.films) + 1
				Rpg.add_xp(id, "", 25)
				Ach.event(id, "films")
				Net.mark_dirty()
				Net.notify(id, "Film bitti! \"%s\" güzeldi. (+25 XP)" % FILMS[n % FILMS.size()].name)
				send_state(id)
			_watch[id] = int(s.n) + (0 if s.playing else 1)
