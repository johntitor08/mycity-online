extends Node
## Belediye seçimi. 90 dakikalık döngü (sunucu saatine göre):
##   0-30 dk aday başvurusu, 30-60 dk oylama, 60. dakikada sonuç; kazanan bir sonraki sonuca kadar başkandır.
## Başkan: vergi oranını belirler (kira ve işletme satışlarından belediye kasasına), dönemde bir kez kasayı
## çevrimiçi oyunculara hibe olarak dağıtır, 30 dakikada bir şehir etkinliği başlatır, kasadan maaş alır.
## Başkan yoksa Muhtar Rıza vekâlet eder (vergi %5).
## Veri: save_data["election"] = {cycle, candidates: {ad: {slogan, votes}}, voters, mayor, tax, treasury,
##                                event_at, grant_cycle}

signal changed

const U = preload("res://scripts/util.gd")
const Map = preload("res://scripts/map.gd")

const CYCLE := 5400.0              # 90 dk
const APPLY_END := 1800.0
const VOTE_END := 3600.0
const CANDIDATE_LEVEL := 5
const CANDIDATE_FEE := 2000
const VOTE_LEVEL := 2
const MAX_CANDIDATES := 6
const DEFAULT_TAX := 5
const MAX_TAX := 15
const MAYOR_SALARY := 30           # dakikalık, kasadan
const EVENT_COOLDOWN := 1800.0
const ACTING := "Muhtar Rıza"

var debug_offset := 0.0           # testler için saati kaydır
var state: Dictionary = {}         # istemci: {phase, left, candidates, mayor, tax, treasury, voted, cycle, ...}
var _state_at := 0.0
var _acc := 0.0


static func phase_of(t: float) -> String:
	var k := fmod(t, CYCLE)
	if k < APPLY_END:
		return "apply"
	if k < VOTE_END:
		return "vote"
	return "term"


static func cycle_of(t: float) -> int:
	# Sonuç anı 60. dakika: o andan sonraki dönem aynı döngüye aittir.
	return int(floor(t / CYCLE))


func reset() -> void:
	state = {}


# ------------------------------------------------------------------ istemci API

func apply(slogan: String) -> void:
	Net.ask(self, "req_apply", {"slogan": slogan})


func vote(candidate: String) -> void:
	Net.ask(self, "req_vote", {"name": candidate})


func set_tax(rate: int) -> void:
	Net.ask(self, "req_mayor", {"op": "tax", "rate": rate})


func give_grant() -> void:
	Net.ask(self, "req_mayor", {"op": "grant"})


func start_event(kind: String) -> void:
	Net.ask(self, "req_mayor", {"op": "event", "kind": kind})


func time_left() -> float:
	return maxf(0.0, float(state.get("left", 0.0)) - (Time.get_ticks_msec() / 1000.0 - _state_at))


func is_mayor() -> bool:
	return state.get("mayor", "") == Net.my_name and Net.my_name != ""


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	state = d
	_state_at = Time.get_ticks_msec() / 1000.0
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _now() -> float:
	return Time.get_unix_time_from_system() + debug_offset


func _data() -> Dictionary:
	if not Net.save_data.get("election") is Dictionary:
		Net.save_data["election"] = {"cycle": cycle_of(_now()), "candidates": {}, "voters": [], "mayor": "",
			"tax": DEFAULT_TAX, "treasury": 0, "event_at": 0.0, "grant_cycle": -1}
	return Net.save_data["election"]


func tax_rate() -> float:
	return float(_data().get("tax", DEFAULT_TAX)) / 100.0


func mayor() -> String:
	return str(_data().get("mayor", ""))


## Vergiyi kes, kasaya koy; vergi sonrası tutarı döndür.
func take_tax(amount: int) -> int:
	if amount <= 0:
		return amount
	var t := int(floor(amount * tax_rate()))
	if t > 0:
		var e := _data()
		e["treasury"] = int(e.treasury) + t
	return amount - t


func _public(for_name: String) -> Dictionary:
	var e := _data()
	var now := _now()
	var ph := phase_of(now)
	var k := fmod(now, CYCLE)
	var left := (APPLY_END - k) if ph == "apply" else ((VOTE_END - k) if ph == "vote" else (CYCLE - k))
	var cands: Array = []
	for n in e.candidates:
		var c: Dictionary = e.candidates[n]
		cands.append({"name": n, "slogan": str(c.slogan), "votes": int(c.votes) if ph != "vote" else -1})
	cands.sort_custom(func(a, b): return int(a.votes) > int(b.votes))
	return {"phase": ph, "left": left, "candidates": cands, "mayor": str(e.mayor), "tax": int(e.tax),
		"treasury": int(e.treasury), "voted": e.voters.has(for_name), "candidate": e.candidates.has(for_name),
		"grant_used": int(e.grant_cycle) == int(e.cycle), "event_in": maxf(0.0, float(e.event_at) + EVENT_COOLDOWN - now)}


func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_state", _public(Net.players[id].name))


func _broadcast() -> void:
	for id in Net.players:
		send_state(id)


## Oyuncu listesindeki "mayor" rozeti.
func _refresh_roster() -> void:
	var m := mayor()
	var changed_any := false
	for id in Net.players:
		var is_m: bool = Net.players[id].name == m
		if bool(Net.players[id].get("mayor", false)) != is_m:
			Net.players[id]["mayor"] = is_m
			changed_any = true
	if changed_any:
		Net._broadcast_roster()


func on_join(id: int) -> void:
	send_state(id)
	_refresh_roster()


@rpc("any_peer", "call_remote", "reliable")
func req_apply(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var e := _data()
	if phase_of(_now()) != "apply":
		Net.notify(id, "Aday başvuruları kapalı. Yeni dönemin başında başvurabilirsin.", false)
		return
	if e.candidates.has(me):
		Net.notify(id, "Zaten adaysın.", false)
		return
	if e.candidates.size() >= MAX_CANDIDATES:
		Net.notify(id, "Aday listesi dolu.", false)
		return
	if Rpg.level(id) < CANDIDATE_LEVEL:
		Net.notify(id, "Aday olmak için seviye %d gerekli." % CANDIDATE_LEVEL, false)
		return
	if not Net.try_spend(id, CANDIDATE_FEE):
		Net.notify(id, "Aday olma ücreti %s." % U.money(CANDIDATE_FEE), false)
		return
	var slogan := str(d.get("slogan", "")).strip_edges().replace("[", "").replace("]", "").left(60)
	if slogan == "":
		slogan = "Daha güzel bir şehir için!"
	e.candidates[me] = {"slogan": slogan, "votes": 0}
	e["treasury"] = int(e.treasury) + CANDIDATE_FEE
	Net.mark_dirty()
	Net.announce("%s belediye başkanlığına aday oldu: \"%s\"" % [me, slogan])
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_vote(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var e := _data()
	var who := str(d.get("name", ""))
	if phase_of(_now()) != "vote":
		Net.notify(id, "Şu an oylama yok.", false)
		return
	if not e.candidates.has(who):
		return
	if e.voters.has(me):
		Net.notify(id, "Bu seçimde oyunu zaten kullandın.", false)
		return
	if Rpg.level(id) < VOTE_LEVEL:
		Net.notify(id, "Oy vermek için seviye %d gerekli." % VOTE_LEVEL, false)
		return
	e.voters.append(me)
	e.candidates[who]["votes"] = int(e.candidates[who].votes) + 1
	Net.mark_dirty()
	Net.notify(id, "Oyun %s için sandığa atıldı. Teşekkürler!" % who)
	Ach.event(id, "vote")
	Rpg.add_xp(id, "", 20)
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_mayor(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Net.players[id].name != mayor() or mayor() == "":
		Net.notify(id, "Bunu sadece belediye başkanı yapabilir.", false)
		return
	var e := _data()
	match str(d.get("op", "")):
		"tax":
			var r := clampi(int(d.get("rate", DEFAULT_TAX)), 0, MAX_TAX)
			if r == int(e.tax):
				return
			e["tax"] = r
			Net.announce("Belediye Başkanı %s vergi oranını %%%d yaptı." % [mayor(), r])
		"grant":
			if int(e.grant_cycle) == int(e.cycle):
				Net.notify(id, "Bu dönemin hibesi dağıtıldı.", false)
				return
			var n := Net.players.size()
			var share := int(int(e.treasury) / float(maxi(1, n)))
			if share <= 0:
				Net.notify(id, "Belediye kasası boş.", false)
				return
			for pid in Net.players:
				Net.add_money(pid, share)
			e["treasury"] = int(e.treasury) - share * n
			e["grant_cycle"] = int(e.cycle)
			Net.announce("Belediye hibesi! Başkan %s şehirdeki herkese %s dağıttı." % [mayor(), U.money(share)])
		"event":
			var kind := str(d.get("kind", ""))
			if not Events.KINDS.has(kind):
				return
			if _now() < float(e.event_at) + EVENT_COOLDOWN:
				Net.notify(id, "Yeni etkinlik için biraz bekle.", false)
				return
			e["event_at"] = _now()
			Events.start_event(kind)
			Net.announce("Belediye Başkanı %s bir etkinlik başlattı!" % mayor())
		_:
			return
	Net.mark_dirty()
	_broadcast()


## Döngü geçişleri (sonuç ilanı, yeni dönem) ve başkan maaşı.
func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 5.0:
		return
	_acc = 0.0
	var e := _data()
	var now := _now()
	var cyc := cycle_of(now)
	var ph := phase_of(now)
	if int(e.cycle) != cyc:
		# yeni döngü: önceki seçim sonuçlanmadıysa (sunucu kapalıydı) sonuçlandır, listeyi temizle
		if not e.candidates.is_empty():
			_conclude(e)
		e["cycle"] = cyc
		e["candidates"] = {}
		e["voters"] = []
		Net.mark_dirty()
		Net.announce("Belediye seçimi başladı! Aday olmak için Muhtarlık'a git (Sv.%d, %s)." % [CANDIDATE_LEVEL, U.money(CANDIDATE_FEE)])
		_broadcast()
	elif ph == "vote" and not bool(e.get("vote_announced", false)):
		e["vote_announced"] = true
		Net.announce("Oylama başladı! Muhtarlık'ta oyunu kullan (%d aday)." % e.candidates.size())
		_broadcast()
	elif ph == "term" and not e.candidates.is_empty():
		_conclude(e)
		_broadcast()
	if ph == "apply":
		e["vote_announced"] = false
	var _salary_acc: float = float(e.get("salary_acc", 0.0)) + 5.0
	if _salary_acc >= 60.0:
		_salary_acc = 0.0
		var mid := Net.id_by_name(mayor())
		if mid != 0 and int(e.treasury) >= MAYOR_SALARY:
			e["treasury"] = int(e.treasury) - MAYOR_SALARY
			Net.add_money(mid, MAYOR_SALARY)
	e["salary_acc"] = _salary_acc


func _conclude(e: Dictionary) -> void:
	var best := -1
	var winners: Array = []
	for n in e.candidates:
		var v := int(e.candidates[n].votes)
		if v > best:
			best = v
			winners = [n]
		elif v == best:
			winners.append(n)
	e["candidates"] = {}
	e["voters"] = []
	if winners.is_empty():
		return
	var w: String = winners.pick_random()
	e["mayor"] = w
	e["grant_cycle"] = -1
	Net.mark_dirty()
	Net.announce("SEÇİM SONUCU: Yeni belediye başkanı %s! (%d oy)%s" % [w, best, " — eşitlik kura ile bozuldu" if winners.size() > 1 else ""])
	Net.log_line("Seçim: başkan %s (%d oy)" % [w, best])
	var wid := Net.id_by_name(w)
	if wid != 0:
		Rpg.add_xp(wid, "", 500)
		Ach.event(wid, "mayor")
	_refresh_roster()
