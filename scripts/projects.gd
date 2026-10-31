extends Node
## Belediye projeleri ve mahalle muhtarlığı (2.0).
##  Proje panosu Muhtarlık'ın yanında. Başkan bir projeyi oylamaya sunar (başkan yoksa Muhtar Rıza 20 dk'da bir
##  sırayla önerir). 8 dk oylama: evet çoksa proje kabul edilir; belediye kasası (vergiler) bütçenin yarısına kadar
##  öder, gerisi vatandaş bağışıyla toplanır. Bütçe dolunca 4 dk inşaat, sonra yapı şehre kalıcı olarak eklenir.
##  En çok bağış yapanın adı yapıya yazılır (heykel onun görünüşünde olur).
##  Mahalle muhtarlığı: Yeni Mahalle'nin seçimi. 2 saatlik dönem: ilk 40 dk aday başvurusu, sonraki 40 dk oylama;
##  kazanan dönem sonuna kadar muhtardır: tezgâh kirasını (300–600 TL) belirler, kira gelirinin %10'unu alır ve
##  dönemde bir kez "Pazar Günü" ilan eder (10 dk boyunca meydana iki kat müşteri gelir).
## Veri: save_data["projects"] = {done: {k: {by, at}}, cur: {k, phase, ends, yes, no, voters, funds, donors}, idle_at}
##       save_data["mahalle"] = {cycle, candidates: {ad: oy}, voters, muhtar, rent, market_day_until, used_day}

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PROJECTS := {
	"cicek": {"name": "Çiçek Parkı", "cost": 12000, "desc": "Parka çiçek tarhları ve banklar."},
	"led": {"name": "LED Sokak Lambaları", "cost": 15000, "desc": "Geceleri sokaklar daha aydınlık."},
	"bisiklet": {"name": "Bisiklet Yolu", "cost": 18000, "desc": "Yollara bisiklet şeridi: bisikletle %15 daha hızlı."},
	"fiskiye": {"name": "Göl Fıskiyesi", "cost": 20000, "desc": "Gölün ortasında ışıklı fıskiye."},
	"plaj": {"name": "Plaj Düzenlemesi", "cost": 22000, "desc": "Plaja duşlar, voleybol filesi ve palmiyeler."},
	"kule": {"name": "Gözlem Kulesi", "cost": 25000, "desc": "Plajda dürbünlü kule: E ile bütün şehri seyret."},
	"heykel": {"name": "Kahraman Heykeli", "cost": 30000, "desc": "Parka en çok bağış yapanın heykeli dikilir."},
}
const VOTE_TIME := 480.0
const BUILD_TIME := 240.0
const IDLE_GAP := 1200.0
const TREASURY_SHARE := 0.5
const VOTE_LEVEL := 2
const M_CYCLE := 7200.0
const M_APPLY := 2400.0
const M_VOTE := 4800.0
const M_LEVEL := 4
const M_FEE := 1000
const MARKET_DAY := 600.0

# --- istemci
var state := {}                      # {done: {k: {by}}, cur: {...}, voted, treasury, mayor}
var mahalle := {}                    # {phase, left, candidates, muhtar, rent, market_day, voted, can_day}

# --- sunucu
var _acc := 0.0


func reset() -> void:
	state = {}
	mahalle = {}


func on_player_left(_id: int) -> void:
	pass


## Bu proje şehirde yapılmış mı? (istemci ve sunucu)
func done(k: String) -> bool:
	if Net.is_server():
		return _data().done.has(k)
	return state.get("done", {}).has(k)


func market_day() -> bool:
	if Net.is_server():
		return Time.get_unix_time_from_system() < float(_mdata().get("market_day_until", 0.0))
	return float(mahalle.get("market_day", 0.0)) > 0.0


# ------------------------------------------------------------------ istemci API

func propose(k: String) -> void:
	Net.ask(self, "req_propose", {"k": k})


func vote(yes: bool) -> void:
	Net.ask(self, "req_vote", {"yes": yes})


func donate(amount: int) -> void:
	Net.ask(self, "req_donate", {"amount": amount})


func m_apply() -> void:
	Net.ask(self, "req_m_apply")


func m_vote(who: String) -> void:
	Net.ask(self, "req_m_vote", {"who": who})


func m_set_rent(rent: int) -> void:
	Net.ask(self, "req_m_rent", {"rent": rent})


func m_market_day() -> void:
	Net.ask(self, "req_m_day")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	state = d.get("p", state)
	mahalle = d.get("m", mahalle)
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data() -> Dictionary:
	if not Net.save_data.get("projects") is Dictionary:
		Net.save_data["projects"] = {"done": {}, "cur": {}, "idle_at": 0.0}
	return Net.save_data.projects


func _mdata() -> Dictionary:
	if not Net.save_data.get("mahalle") is Dictionary:
		Net.save_data["mahalle"] = {"cycle": int(Time.get_unix_time_from_system() / M_CYCLE), "candidates": {}, "voters": [], "muhtar": "", "rent": 400,
			"market_day_until": 0.0, "used_day": -1}
	return Net.save_data.mahalle


func _view(for_name: String) -> Dictionary:
	var d := _data()
	var cur: Dictionary = d.cur.duplicate()
	if not cur.is_empty():
		cur["left"] = float(cur.ends) - Time.get_unix_time_from_system()
		cur.erase("voters")
		cur["donors"] = d.cur.get("donors", {}).duplicate()
	var m := _mdata()
	var now := Time.get_unix_time_from_system()
	var u := fmod(now, M_CYCLE)
	var phase := "basvuru" if u < M_APPLY else ("oylama" if u < M_VOTE else "sonuc")
	var mv := {"phase": phase, "left": (M_APPLY - u) if phase == "basvuru" else ((M_VOTE - u) if phase == "oylama" else (M_CYCLE - u)),
		"candidates": m.candidates.duplicate(), "muhtar": m.muhtar, "rent": int(m.rent), "market_day": maxf(0.0, float(m.market_day_until) - now),
		"voted": for_name in m.voters, "can_day": int(m.get("used_day", -1)) != int(m.cycle)}
	return {"p": {"done": d.done, "cur": cur, "voted": for_name in d.cur.get("voters", []), "treasury": int(Election._data().get("treasury", 0)),
		"mayor": Election.mayor()}, "m": mv}


func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_state", _view(Net.players[id].name))


func _broadcast() -> void:
	for id in Net.players:
		send_state(id)


func _near_board(id: int) -> bool:
	return _pos(id).distance_to(Map.PROJECT_BOARD) < 140.0 or Map.building("muhtarlik").rect.grow(60).has_point(_pos(id))


func _near_office(id: int) -> bool:
	return (Map.MAHALLE_OFFICE.rect as Rect2).grow(80).has_point(_pos(id))


func _start_vote(k: String, by: String) -> void:
	var d := _data()
	d["cur"] = {"k": k, "phase": "oylama", "ends": Time.get_unix_time_from_system() + VOTE_TIME, "yes": 0, "no": 0, "voters": [], "funds": 0, "donors": {}, "by": by}
	Net.announce("Belediye projesi oylamada: %s (%s). Proje panosundan oy ver!" % [PROJECTS[k].name, U.money(int(PROJECTS[k].cost))])
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_propose(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _near_board(id):
		return
	var me: String = Net.players[id].name
	if Election.mayor() != me:
		Net.notify(id, "Projeyi ancak belediye başkanı oylamaya sunar.", false)
		return
	var k := str(d.get("k", ""))
	var data := _data()
	if not PROJECTS.has(k) or data.done.has(k) or not data.cur.is_empty():
		return
	_start_vote(k, me)


@rpc("any_peer", "call_remote", "reliable")
func req_vote(d: Dictionary) -> void:
	var id := Net.sender()
	var cur: Dictionary = _data().cur
	if not Net.players.has(id) or cur.is_empty() or cur.phase != "oylama" or not _near_board(id):
		return
	var me: String = Net.players[id].name
	if me in cur.voters:
		return
	if Rpg.level(id) < VOTE_LEVEL:
		Net.notify(id, "Oy vermek için seviye %d gerekli." % VOTE_LEVEL, false)
		return
	cur.voters.append(me)
	if bool(d.get("yes", true)):
		cur["yes"] = int(cur.yes) + 1
	else:
		cur["no"] = int(cur.no) + 1
	Ach.event(id, "project_votes")
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_donate(d: Dictionary) -> void:
	var id := Net.sender()
	var cur: Dictionary = _data().cur
	if not Net.players.has(id) or cur.is_empty() or cur.phase != "butce" or not _near_board(id):
		return
	var need := int(PROJECTS[cur.k].cost) - int(cur.funds)
	var amount := mini(int(d.get("amount", 0)), need)
	if amount <= 0:
		return
	if not Net.try_spend(id, amount):
		Net.notify(id, "%s gerekli." % U.money(amount), false)
		return
	var me: String = Net.players[id].name
	cur["funds"] = int(cur.funds) + amount
	cur.donors[me] = int(cur.donors.get(me, 0)) + amount
	Ach.event(id, "project_donated", amount)
	Rpg.add_xp(id, "", mini(100, amount / 100))
	Net.notify(id, "%s projesine %s bağışladın. Teşekkürler!" % [PROJECTS[cur.k].name, U.money(amount)])
	_check_funded()
	Net.mark_dirty()
	_broadcast()


func _check_funded() -> void:
	var cur: Dictionary = _data().cur
	if cur.phase == "butce" and int(cur.funds) >= int(PROJECTS[cur.k].cost):
		cur["phase"] = "insaat"
		cur["ends"] = Time.get_unix_time_from_system() + BUILD_TIME
		Net.announce("%s için bütçe tamamlandı! İnşaat başladı (%d dk)." % [PROJECTS[cur.k].name, int(BUILD_TIME / 60.0)])


func _top_donor(cur: Dictionary) -> String:
	var best := ""
	var bn := 0
	for k in cur.get("donors", {}):
		if int(cur.donors[k]) > bn:
			bn = int(cur.donors[k])
			best = k
	return best


## Heykel için: en çok bağış yapanın görünüşü (kayıttan).
func statue_look() -> Dictionary:
	var info: Dictionary = state.get("done", {}).get("heykel", {})
	return info.get("look", {})


func _tick_projects() -> void:
	var d := _data()
	var now := Time.get_unix_time_from_system()
	var cur: Dictionary = d.cur
	if cur.is_empty():
		# başkan yoksa Muhtar Rıza sıradaki projeyi önerir
		if Election.mayor() == "" and now - float(d.get("idle_at", 0.0)) > IDLE_GAP and not Net.players.is_empty():
			for k in PROJECTS:
				if not d.done.has(k):
					_start_vote(k, Election.ACTING)
					break
		return
	if now < float(cur.ends):
		return
	match str(cur.phase):
		"oylama":
			if int(cur.yes) > int(cur.no) and int(cur.yes) >= 1:
				var cost := int(PROJECTS[cur.k].cost)
				var e: Dictionary = Election._data()
				var from_treasury := mini(int(e.get("treasury", 0)), int(cost * TREASURY_SHARE))
				e["treasury"] = int(e.get("treasury", 0)) - from_treasury
				cur["funds"] = from_treasury
				cur["phase"] = "butce"
				cur["ends"] = now + 86400.0 * 3.0
				Net.announce("%s kabul edildi (%d evet, %d hayır)! Belediye %s koydu; kalan %s bağışla toplanacak." % [PROJECTS[cur.k].name, int(cur.yes), int(cur.no),
					U.money(from_treasury), U.money(cost - from_treasury)])
				_check_funded()
			else:
				Net.announce("%s reddedildi (%d evet, %d hayır)." % [PROJECTS[cur.k].name, int(cur.yes), int(cur.no)])
				d["cur"] = {}
				d["idle_at"] = now
		"butce":
			# 3 günde toplanamadı: bağışlar iade
			for who in cur.donors:
				var pid := Net.id_by_name(who)
				if pid != 0:
					Net.add_money(pid, int(cur.donors[who]))
				else:
					Net.add_money_by_name(who, int(cur.donors[who]))
			Net.announce("%s için bütçe toplanamadı; bağışlar iade edildi." % PROJECTS[cur.k].name)
			d["cur"] = {}
			d["idle_at"] = now
		"insaat":
			var top := _top_donor(cur)
			var info := {"by": top, "at": now}
			if cur.k == "heykel" and top != "":
				var rec: Dictionary = Net.save_data.players.get(top, {})
				info["look"] = rec.get("appearance", {})
			d.done[cur.k] = info
			for who in cur.donors:
				var pid := Net.id_by_name(who)
				if pid != 0:
					Ach.event(pid, "projects_built")
			Net.announce("%s şehre kazandırıldı!%s" % [PROJECTS[cur.k].name, (" En büyük destekçi: %s." % top) if top != "" else ""])
			d["cur"] = {}
			d["idle_at"] = now
	Net.mark_dirty()
	_broadcast()


# --- mahalle muhtarlığı

func _tick_mahalle() -> void:
	var m := _mdata()
	var now := Time.get_unix_time_from_system()
	var cyc := int(now / M_CYCLE)
	var u := fmod(now, M_CYCLE)
	if cyc != int(m.cycle):
		m["cycle"] = cyc
		m["candidates"] = {}
		m["voters"] = []
		Net.mark_dirty()
		_broadcast()
		return
	if u >= M_VOTE and not m.get("concluded", false):
		m["concluded"] = true
		var best := ""
		var bv := -1
		for k in m.candidates:
			if int(m.candidates[k]) > bv:
				bv = int(m.candidates[k])
				best = k
		if best != "":
			m["muhtar"] = best
			Net.announce("Yeni Mahalle'nin muhtarı: %s (%d oy)!" % [best, bv])
			var pid := Net.id_by_name(best)
			if pid != 0:
				Ach.event(pid, "muhtar")
		Net.mark_dirty()
		_broadcast()
	elif u < M_VOTE and m.get("concluded", false):
		m["concluded"] = false


func _phase() -> String:
	var u := fmod(Time.get_unix_time_from_system(), M_CYCLE)
	return "basvuru" if u < M_APPLY else ("oylama" if u < M_VOTE else "sonuc")


@rpc("any_peer", "call_remote", "reliable")
func req_m_apply(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _near_office(id) or _phase() != "basvuru":
		return
	var m := _mdata()
	var me: String = Net.players[id].name
	if m.candidates.has(me):
		return
	if Rpg.level(id) < M_LEVEL:
		Net.notify(id, "Muhtar adayı olmak için seviye %d gerekli." % M_LEVEL, false)
		return
	if not Net.try_spend(id, M_FEE):
		Net.notify(id, "Adaylık ücreti %s." % U.money(M_FEE), false)
		return
	m.candidates[me] = 0
	Net.announce("%s Yeni Mahalle muhtarlığına aday oldu!" % me)
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_m_vote(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _near_office(id) or _phase() != "oylama":
		return
	var m := _mdata()
	var me: String = Net.players[id].name
	var who := str(d.get("who", ""))
	if me in m.voters or not m.candidates.has(who) or Rpg.level(id) < VOTE_LEVEL:
		return
	m.voters.append(me)
	m.candidates[who] = int(m.candidates[who]) + 1
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_m_rent(d: Dictionary) -> void:
	var id := Net.sender()
	var m := _mdata()
	if not Net.players.has(id) or Net.players[id].name != m.muhtar or not _near_office(id):
		return
	m["rent"] = clampi(int(d.get("rent", 400)), 300, 600)
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "Tezgâh kirası %s olarak belirlendi." % U.money(int(m.rent)))


@rpc("any_peer", "call_remote", "reliable")
func req_m_day(_d: Dictionary) -> void:
	var id := Net.sender()
	var m := _mdata()
	if not Net.players.has(id) or Net.players[id].name != m.muhtar or not _near_office(id):
		return
	if int(m.get("used_day", -1)) == int(m.cycle):
		Net.notify(id, "Bu dönem Pazar Günü zaten ilan edildi.", false)
		return
	m["used_day"] = int(m.cycle)
	m["market_day_until"] = Time.get_unix_time_from_system() + MARKET_DAY
	Net.announce("PAZAR GÜNÜ! Muhtar %s ilan etti: 10 dakika boyunca Yeni Mahalle pazarına iki kat müşteri geliyor!" % m.muhtar)
	Net.mark_dirty()
	_broadcast()


## Tezgâh kirası (muhtar belirler).
func stall_rent() -> int:
	return int(_mdata().get("rent", 400))


## Kira gelirinin %10'u muhtara.
func rent_paid(amount: int) -> void:
	var m := _mdata()
	if str(m.muhtar) == "":
		return
	var cut := int(amount * 0.1)
	var pid := Net.id_by_name(str(m.muhtar))
	if pid != 0:                         # 2.1: çevrimdışıyken para kazanılmaz
		Net.add_money(pid, cut)


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	_tick_projects()
	_tick_mahalle()
