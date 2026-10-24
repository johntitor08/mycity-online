extends Node
## Düğün ve aile. Kuyumcu'dan yüzük alan oyuncu (Sv.4+) yakınındaki bir oyuncuya evlenme teklif eder;
## kabul edilirse yüzük harcanır, şehirde düğün töreni yapılır (herkese duyuru, konfeti).
## Evliler: ortak aile kasası (ikisi de yatırır/çeker), birbirlerinin evine her zaman girebilir,
## yakınlarındayken %10 fazla XP kazanır, eşin mutlu evcil hayvanının bonusu iki tarafa da işler.
## Boşanma 5.000 TL; aile kasası ikiye bölünür.
## Veri: rec["spouse"] = ad; save_data["families"] = {"a|b": {a, b, bank, since}}

signal changed
signal proposal(from_name: String)
signal wedding(d: Dictionary)

const U = preload("res://scripts/util.gd")

const LEVEL := 4
const PROPOSE_RANGE := 200.0
const NEAR_XP_RANGE := 400.0
const XP_BONUS := 1.1
const DIVORCE_COST := 5000
const PROPOSAL_TTL := 60.0

var info: Dictionary = {}          # istemci: {spouse, online, bank, since} ya da {}
var weddings: Array = []           # istemci: süren düğün kutlamaları [{pos, a, b, until}]

var _proposals := {}               # sunucu: hedef id -> {from, t}


func reset() -> void:
	info = {}
	weddings = []
	_proposals.clear()


static func key_of(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])


# ------------------------------------------------------------------ istemci API

func propose(target: String) -> void:
	Net.ask(self, "req_propose", {"to": target})


func answer(yes: bool) -> void:
	Net.ask(self, "req_answer", {"yes": yes})


func deposit(amount: int) -> void:
	Net.ask(self, "req_bank", {"amount": amount})


func withdraw(amount: int) -> void:
	Net.ask(self, "req_bank", {"amount": -amount})


func divorce() -> void:
	Net.ask(self, "req_divorce")


@rpc("authority", "call_local", "reliable")
func on_family(d: Dictionary) -> void:
	info = d.get("f", {})
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_proposal(d: Dictionary) -> void:
	proposal.emit(str(d.from))


@rpc("authority", "call_local", "reliable")
func on_wedding(d: Dictionary) -> void:
	weddings.append({"pos": d.pos, "a": d.a, "b": d.b, "until": Time.get_ticks_msec() / 1000.0 + 25.0})
	wedding.emit(d)


# ------------------------------------------------------------------ sunucu

func _store() -> Dictionary:
	if not Net.save_data.get("families") is Dictionary:
		Net.save_data["families"] = {}
	return Net.save_data["families"]


func _rec_name(n: String) -> Dictionary:
	return Net.save_data.players.get(n, {})


func spouse_of_name(n: String) -> String:
	return str(_rec_name(n).get("spouse", ""))


func spouse_of(id: int) -> String:
	return spouse_of_name(Net.players[id].name) if Net.players.has(id) else ""


func _family(n: String) -> Dictionary:
	var s := spouse_of_name(n)
	return _store().get(key_of(n, s), {}) if s != "" else {}


## XP çarpanı: eş çevrimiçi ve yakındaysa.
func xp_mult(id: int) -> float:
	var s := spouse_of(id)
	if s == "":
		return 1.0
	var sid := Net.id_by_name(s)
	if sid == 0:
		return 1.0
	var a: Vector2 = Net.positions.get(id, Vector2(-1e6, 0))
	var b: Vector2 = Net.positions.get(sid, Vector2(1e6, 0))
	return XP_BONUS if a.distance_to(b) <= NEAR_XP_RANGE else 1.0


func send_state(id: int) -> void:
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var f := _family(me)
	var out := {}
	if not f.is_empty():
		var s := spouse_of_name(me)
		out = {"spouse": s, "online": Net.id_by_name(s) != 0, "bank": int(f.bank), "since": str(f.get("since", ""))}
	Net.tell(self, id, "on_family", {"f": out})
	_refresh_roster(id)


func _refresh_roster(id: int) -> void:
	var s := spouse_of(id)
	if str(Net.players[id].get("spouse", "")) != s:
		Net.players[id]["spouse"] = s
		Net._broadcast_roster()


func on_presence(player_name: String) -> void:
	var s := spouse_of_name(player_name)
	var sid := Net.id_by_name(s)
	if sid != 0:
		send_state(sid)


@rpc("any_peer", "call_remote", "reliable")
func req_propose(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var to := str(d.get("to", ""))
	var tid := Net.id_by_name(to)
	var rec := _rec_name(me)
	if tid == 0 or tid == id:
		Net.notify(id, "Teklif için çevrimiçi bir oyuncu seç.", false)
		return
	if spouse_of_name(me) != "" or spouse_of_name(to) != "":
		Net.notify(id, "İkinizden biri zaten evli.", false)
		return
	if Rpg.level(id) < LEVEL or Rpg.level(tid) < LEVEL:
		Net.notify(id, "Evlilik için ikinizin de en az seviye %d olması gerek." % LEVEL, false)
		return
	if int(rec.get("rings", 0)) <= 0:
		Net.notify(id, "Önce Çarşı'daki Kuyumcu'dan bir yüzük al.", false)
		return
	if Net.positions[id].distance_to(Net.positions.get(tid, Vector2(-1e6, 0))) > PROPOSE_RANGE + 80.0:
		Net.notify(id, "Teklif için %s'in yanına git." % to, false)
		return
	_proposals[tid] = {"from": me, "t": Time.get_unix_time_from_system()}
	Net.tell(self, tid, "on_proposal", {"from": me})
	Net.notify(id, "%s'e evlenme teklif ettin... Cevap bekleniyor." % to)


@rpc("any_peer", "call_remote", "reliable")
func req_answer(d: Dictionary) -> void:
	var id := Net.sender()
	if not _proposals.has(id) or not Net.players.has(id):
		return
	var p: Dictionary = _proposals[id]
	_proposals.erase(id)
	var me: String = Net.players[id].name
	var from: String = p.from
	var fid := Net.id_by_name(from)
	if Time.get_unix_time_from_system() - float(p.t) > PROPOSAL_TTL or fid == 0:
		Net.notify(id, "Teklifin süresi geçti.", false)
		return
	if not bool(d.get("yes", false)):
		Net.notify(fid, "%s teklifini kibarca reddetti." % me, false)
		Net.notify(id, "Teklifi reddettin.")
		return
	var frec := _rec_name(from)
	if int(frec.get("rings", 0)) <= 0 or spouse_of_name(from) != "" or spouse_of_name(me) != "":
		Net.notify(id, "Düğün gerçekleşemedi.", false)
		return
	frec["rings"] = int(frec.rings) - 1
	frec["spouse"] = me
	_rec_name(me)["spouse"] = from
	_store()[key_of(from, me)] = {"a": from, "b": me, "bank": 0, "since": Time.get_date_string_from_system()}
	Net.mark_dirty()
	Shops.send_state(fid)
	send_state(id)
	send_state(fid)
	var pos: Vector2 = (Net.positions.get(id, Vector2.ZERO) + Net.positions.get(fid, Vector2.ZERO)) / 2.0
	Net.tell_all(self, "on_wedding", {"pos": pos, "a": from, "b": me})
	Net.announce("DÜĞÜN VAR! %s ve %s evlendi. Mutluluklar!" % [from, me])
	Rpg.add_xp(id, "", 200)
	Rpg.add_xp(fid, "", 200)
	Net.log_line("Düğün: %s & %s" % [from, me])


@rpc("any_peer", "call_remote", "reliable")
func req_bank(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var f := _family(me)
	if f.is_empty():
		return
	var amount := int(d.get("amount", 0))
	if amount > 0:
		if not Net.try_spend(id, amount):
			Net.notify(id, "Yeterli paran yok.", false)
			return
		f["bank"] = int(f.bank) + amount
	elif amount < 0:
		var take := mini(-amount, int(f.bank))
		if take <= 0:
			Net.notify(id, "Aile kasası boş.", false)
			return
		f["bank"] = int(f.bank) - take
		Net.add_money(id, take)
	else:
		return
	Net.mark_dirty()
	send_state(id)
	var sid := Net.id_by_name(spouse_of_name(me))
	if sid != 0:
		send_state(sid)
		Net.notify(sid, "%s aile kasasına %s %s." % [me, U.money(absi(amount)), "yatırdı" if amount > 0 else "çekti"])


@rpc("any_peer", "call_remote", "reliable")
func req_divorce(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var s := spouse_of_name(me)
	if s == "":
		return
	if not Net.try_spend(id, DIVORCE_COST):
		Net.notify(id, "Boşanma masrafı %s." % U.money(DIVORCE_COST), false)
		return
	var f := _family(me)
	var half := int(int(f.get("bank", 0)) / 2.0)
	Net.add_money(id, half)
	Net.add_money_by_name(s, int(f.get("bank", 0)) - half)
	_store().erase(key_of(me, s))
	_rec_name(me).erase("spouse")
	_rec_name(s).erase("spouse")
	Net.mark_dirty()
	send_state(id)
	var sid := Net.id_by_name(s)
	if sid != 0:
		send_state(sid)
		Net.notify(sid, "%s boşanma davası açtı; artık bekârsın. Aile kasasından payın: %s" % [me, U.money(int(f.get("bank", 0)) - half)], false)
	Net.notify(id, "Boşandınız. Aile kasasından payın: %s" % U.money(half))
	Net.log_line("Boşanma: %s & %s" % [me, s])
