extends Node
## Lig ve sezonlar. Her takvim haftası bir sezondur (ör. "2026-H44"). Kategoriler:
##  Zenginlik (cep + banka), Balık (sezonda tutulan balıkların toplam değeri), Yarış (sezonun en iyi turu),
##  Futbol (sezonda atılan gol), Tecrübe (sezonda kazanılan XP).
## Sezon bitince her kategoride ilk üçe ödül ve kalıcı rozet verilir; Şampiyonlar Duvarı'na yazılır.
## Veri: save_data["league"] = {season, scores: {kategori: {ad: değer}}, history: [{season, winners}]}
##       rec["badges"] = ["2026-H43 Balık 1."]

signal changed

const U = preload("res://scripts/util.gd")

const CATS := {
	"wealth": ["Zenginlik", "TL"], "fish": ["Balık", "TL"], "race": ["Yarış", "sn"],
	"goals": ["Futbol", "gol"], "xp": ["Tecrübe", "XP"], "ski": ["Kayak", "sn"], "marathon": ["Maraton", "sn"],
	"paint": ["Paintball", "vuruş"], "zindan": ["Zindan", "kat"],
}
const PRIZES := [5000, 2500, 1000]
const HISTORY := 20

var view: Dictionary = {}          # istemci: {season, ends_in, boards: {cat: [[ad, değer]]}, history, badges}
var _view_at := 0.0
var _acc := 0.0
var _dirty := false


static func season_of(unix: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(unix))
	# ISO hafta numarası
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1})
	var jan1_wd := (int(Time.get_datetime_dict_from_unix_time(jan1).weekday) + 6) % 7      # pazartesi = 0
	var doy := int((unix - jan1) / 86400.0)
	var week := int((doy + jan1_wd) / 7.0) + 1
	return "%d-H%02d" % [d.year, week]


## Sezonun bitmesine kalan süre (pazartesi 00:00'a kadar, sunucu yerel saati yerine UTC).
static func seconds_left(unix: float) -> float:
	var wd := (int(Time.get_datetime_dict_from_unix_time(int(unix)).weekday) + 6) % 7
	var day_start := floorf(unix / 86400.0) * 86400.0
	return day_start + (7 - wd) * 86400.0 - unix


func reset() -> void:
	view = {}


func time_left() -> float:
	return maxf(0.0, float(view.get("ends_in", 0.0)) - (Time.get_ticks_msec() / 1000.0 - _view_at))


# ------------------------------------------------------------------ istemci API

func refresh() -> void:
	Net.ask(self, "req_view")


@rpc("authority", "call_local", "reliable")
func on_view(d: Dictionary) -> void:
	view = d
	_view_at = Time.get_ticks_msec() / 1000.0
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _data() -> Dictionary:
	if not Net.save_data.get("league") is Dictionary:
		Net.save_data["league"] = {"season": season_of(Time.get_unix_time_from_system()), "scores": {}, "history": []}
	var l: Dictionary = Net.save_data["league"]
	for c in CATS:
		if not l.scores.get(c) is Dictionary:
			l.scores[c] = {}
	return l


func _name(id: int) -> String:
	return Net.players[id].name if Net.players.has(id) else ""


## Toplanan kategoriler (balık, gol, XP).
func add(id: int, cat: String, n: float) -> void:
	var who := _name(id)
	if who == "" or n <= 0.0:
		return
	var s: Dictionary = _data().scores[cat]
	s[who] = float(s.get(who, 0.0)) + n
	_dirty = true


## En iyi değer kategorileri (yarış: düşük daha iyi).
func best(id: int, cat: String, value: float) -> void:
	var who := _name(id)
	if who == "":
		return
	var s: Dictionary = _data().scores[cat]
	if not s.has(who) or value < float(s[who]):
		s[who] = value
		_dirty = true


func _wealth() -> Dictionary:
	var out := {}
	for n in Net.save_data.players:
		var rec: Dictionary = Net.save_data.players[n]
		var bank := 0.0
		if rec.get("bank_acc") is Dictionary:
			bank = float(rec.bank_acc.get("bal", 0.0))
		out[n] = float(rec.get("money", 0)) + bank
	return out


func _board(cat: String) -> Array:
	var src: Dictionary = _wealth() if cat == "wealth" else _data().scores[cat]
	var list: Array = []
	for n in src:
		if float(src[n]) > 0.0:
			list.append([n, float(src[n])])
	if cat in ["race", "ski", "marathon"]:
		list.sort_custom(func(a, b): return a[1] < b[1])
	else:
		list.sort_custom(func(a, b): return a[1] > b[1])
	return list


func send_state(id: int) -> void:
	if not Net.players.has(id):
		return
	var l := _data()
	var boards := {}
	for c in CATS:
		boards[c] = _board(c).slice(0, 10)
	var rec: Dictionary = Net.save_data.players.get(_name(id), {})
	Net.tell(self, id, "on_view", {"season": l.season, "ends_in": seconds_left(Time.get_unix_time_from_system()),
		"boards": boards, "history": l.history.duplicate(), "badges": rec.get("badges", [])})


@rpc("any_peer", "call_remote", "reliable")
func req_view(_d: Dictionary) -> void:
	send_state(Net.sender())


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 5.0:
		return
	_acc = 0.0
	var now_season := season_of(Time.get_unix_time_from_system())
	var l := _data()
	if str(l.season) != now_season:
		_end_season(l, now_season)
	if _dirty:
		_dirty = false
		Net.mark_dirty()


## Sezon bitti: ödüller, rozetler, Şampiyonlar Duvarı, yeni sezon.
func _end_season(l: Dictionary, new_season: String) -> void:
	var winners := {}
	var lines: Array = []
	for c in CATS:
		var board := _board(c)
		var top: Array = []
		for k in mini(3, board.size()):
			var who: String = board[k][0]
			top.append([who, board[k][1]])
			Net.add_money_by_name(who, PRIZES[k])
			var rec: Dictionary = Net.save_data.players.get(who, {})
			if not rec.get("badges") is Array:
				rec["badges"] = []
			rec.badges.append("%s %s %d." % [l.season, CATS[c][0], k + 1])
			var pid := Net.id_by_name(who)
			if pid != 0:
				Net.notify(pid, "Sezon bitti: %s liginde %d. oldun! +%s ve rozet" % [CATS[c][0], k + 1, U.money(PRIZES[k])])
				Ach.event(pid, "league_top")
				if k == 0:
					Ach.event(pid, "league_win")
		winners[c] = top
		if not top.is_empty():
			lines.append("%s: %s" % [CATS[c][0], top[0][0]])
	l.history.push_front({"season": l.season, "winners": winners})
	while l.history.size() > HISTORY:
		l.history.pop_back()
	Net.announce("%s sezonu bitti! Şampiyonlar — %s" % [l.season, ", ".join(lines) if not lines.is_empty() else "yok"])
	Net.log_line("Lig sezonu bitti: %s" % l.season)
	l["season"] = new_season
	l["scores"] = {}
	_data()
	Net.mark_dirty()
	for id in Net.players:
		send_state(id)


## Testler ve yöneticiler için: sezonu hemen bitir.
func force_end() -> void:
	if Net.is_server():
		_end_season(_data(), season_of(Time.get_unix_time_from_system()))
