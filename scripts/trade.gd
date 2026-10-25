extends Node
## Güvenli takas (1.3). Yan yana duran iki oyuncu bir takas penceresi açar; ikisi de para, balık, ambar
## ürünleri (ekin, hayvan ürünü, maden, orman ürünü) ve çanta yiyecekleri koyabilir. İki taraf da onaylayınca
## sunucu her şeyi yeniden denetler ve takası tek seferde yapar. Teklif değişirse onaylar sıfırlanır.
## Uzaklaşınca, oyundan çıkınca ya da iptal edilince takas kapanır.

signal invited(from_id: int, from_name: String)
signal opened(d: Dictionary)
signal updated(d: Dictionary)
signal closed(text: String)

const U = preload("res://scripts/util.gd")

const RANGE := 220.0
const KEEP_RANGE := 420.0
const INVITE_TTL := 20.0
const MAX_MONEY := 1000000

# --- istemci
var view := {}                     # {tid, me: "a"|"b", other, offers: {a, b}, ok: {a, b}}

# --- sunucu
var _trades := {}                  # tid -> {a, b, offers: {a: offer, b: offer}, ok: {a, b}}
var _of := {}                      # oyuncu -> tid
var _invites := {}                 # hedef -> {from, t}
var _uid := 1
var _acc := 0.0


static func empty_offer() -> Dictionary:
	return {"money": 0, "fish": [], "barn": {}, "items": {}}


func reset() -> void:
	view = {}
	_trades.clear()
	_of.clear()
	_invites.clear()


func on_player_left(id: int) -> void:
	_invites.erase(id)
	if _of.has(id):
		_close(int(_of[id]), "%s oyundan çıktı, takas iptal." % _pname(id))


func active() -> bool:
	return not view.is_empty()


# ------------------------------------------------------------------ istemci API

func invite(to_name: String) -> void:
	Net.ask(self, "req_invite", {"to": to_name})


func respond(from_id: int, accept: bool) -> void:
	Net.ask(self, "req_respond", {"from": from_id, "accept": accept})


func offer(o: Dictionary) -> void:
	Net.ask(self, "req_offer", o)


func confirm() -> void:
	Net.ask(self, "req_ok")


func cancel() -> void:
	Net.ask(self, "req_cancel")


@rpc("authority", "call_local", "reliable")
func on_invite(d: Dictionary) -> void:
	invited.emit(int(d.from), str(d.name))


@rpc("authority", "call_local", "reliable")
func on_trade(d: Dictionary) -> void:
	var first := view.is_empty()
	view = d
	if first:
		opened.emit(d)
	else:
		updated.emit(d)


@rpc("authority", "call_local", "reliable")
func on_closed(d: Dictionary) -> void:
	view = {}
	closed.emit(str(d.get("text", "")))


# ------------------------------------------------------------------ sunucu

func _pname(id: int) -> String:
	return str(Net.players[id].name) if Net.players.has(id) else "?"


func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(_pname(id), {})


func _dist(a: int, b: int) -> float:
	return Net.positions.get(a, Vector2(-1e6, 0)).distance_to(Net.positions.get(b, Vector2(1e6, 0)))


@rpc("any_peer", "call_remote", "reliable")
func req_invite(d: Dictionary) -> void:
	invite_from(Net.sender(), str(d.get("to", "")))


## Sohbetteki /takas isim komutu da bunu kullanır.
func invite_from(id: int, to_name: String) -> void:
	if not Net.players.has(id):
		return
	var to := Net.id_by_name(Net._account_key(to_name.strip_edges()))
	if to == 0 or to == id:
		Net.notify(id, "Takas için çevrimiçi bir oyuncu seç.", false)
		return
	if _of.has(id) or _of.has(to):
		Net.notify(id, "Şu an başka bir takas açık.", false)
		return
	if _dist(id, to) > RANGE:
		Net.notify(id, "Takas için %s'in yanına git." % _pname(to), false)
		return
	_invites[to] = {"from": id, "t": Time.get_ticks_msec() / 1000.0}
	Net.tell(self, to, "on_invite", {"from": id, "name": _pname(id)})
	Net.notify(id, "%s'e takas teklifi gönderildi." % _pname(to))


@rpc("any_peer", "call_remote", "reliable")
func req_respond(d: Dictionary) -> void:
	var id := Net.sender()
	var inv: Dictionary = _invites.get(id, {})
	var from := int(d.get("from", 0))
	if inv.is_empty() or int(inv.from) != from:
		return
	_invites.erase(id)
	if Time.get_ticks_msec() / 1000.0 - float(inv.t) > INVITE_TTL or not Net.players.has(from):
		Net.notify(id, "Takas teklifinin süresi doldu.", false)
		return
	if not bool(d.get("accept", false)):
		Net.notify(from, "%s takas teklifini reddetti." % _pname(id), false)
		return
	if _of.has(id) or _of.has(from) or _dist(id, from) > RANGE:
		Net.notify(id, "Takas başlatılamadı (uzaktasınız ya da biriniz meşgul).", false)
		return
	var tid := _uid
	_uid += 1
	_trades[tid] = {"a": from, "b": id, "offers": {"a": empty_offer(), "b": empty_offer()}, "ok": {"a": false, "b": false}}
	_of[from] = tid
	_of[id] = tid
	_send(tid)


func _side(tid: int, id: int) -> String:
	var t: Dictionary = _trades.get(tid, {})
	return "a" if int(t.get("a", 0)) == id else "b"


func _send(tid: int) -> void:
	var t: Dictionary = _trades[tid]
	for side in ["a", "b"]:
		var pid := int(t[side])
		var other := int(t["b" if side == "a" else "a"])
		Net.tell(self, pid, "on_trade", {"tid": tid, "me": side, "other": _pname(other), "offers": t.offers, "ok": t.ok,
			"fish_names": {"a": _fish_labels(int(t.a), t.offers.a.fish), "b": _fish_labels(int(t.b), t.offers.b.fish)}})


func _fish_labels(id: int, idx: Array) -> Array:
	var bag: Array = _rec(id).get("fish", [])
	var out: Array = []
	for i in idx:
		if int(i) >= 0 and int(i) < bag.size():
			out.append("%s (%s)" % [bag[int(i)].name, U.money(int(bag[int(i)].price))])
	return out


## Teklif geçerli mi? (sahibinde gerçekten var mı) — geçersizse açıklama döner.
func _check(id: int, o: Dictionary) -> String:
	var rec := _rec(id)
	if rec.is_empty():
		return "oyuncu yok"
	if int(o.money) < 0 or int(o.money) > int(rec.get("money", 0)):
		return "%s'in yeterli parası yok" % _pname(id)
	var bag: Array = rec.get("fish", [])
	var seen := {}
	for i in o.fish:
		if int(i) < 0 or int(i) >= bag.size() or seen.has(int(i)):
			return "%s'in kovası değişti" % _pname(id)
		seen[int(i)] = true
	var store := Farm.barn(rec)
	for k in o.barn:
		if Farm.item_info(k).is_empty() or int(o.barn[k]) <= 0 or int(store.get(k, 0)) < int(o.barn[k]):
			return "%s'in ambarında yeterli %s yok" % [_pname(id), Farm.item_info(k).get("name", k)]
	var items: Dictionary = Rpg.ensure(rec).items
	for k in o.items:
		if Rpg.food_info(k).is_empty() or int(o.items[k]) <= 0 or int(items.get(k, 0)) < int(o.items[k]):
			return "%s'in çantasında yeterli %s yok" % [_pname(id), Rpg.food_info(k).get("name", k)]
	return ""


func _clean(d: Dictionary) -> Dictionary:
	var o := empty_offer()
	o.money = clampi(int(d.get("money", 0)), 0, MAX_MONEY)
	var fish: Array = []
	for i in d.get("fish", []):
		if not int(i) in fish and fish.size() < 20:
			fish.append(int(i))
	o.fish = fish
	for key in ["barn", "items"]:
		var src = d.get(key, {})
		if src is Dictionary:
			for k in src:
				if int(src[k]) > 0 and o[key].size() < 30:
					o[key][str(k)] = mini(int(src[k]), 999)
	return o


@rpc("any_peer", "call_remote", "reliable")
func req_offer(d: Dictionary) -> void:
	var id := Net.sender()
	if not _of.has(id):
		return
	var tid := int(_of[id])
	var t: Dictionary = _trades[tid]
	var o := _clean(d)
	var why := _check(id, o)
	if why != "":
		Net.notify(id, "Teklif geçersiz: %s." % why, false)
		return
	t.offers[_side(tid, id)] = o
	t.ok = {"a": false, "b": false}       # teklif değişti: iki taraf da yeniden onaylamalı
	_send(tid)


@rpc("any_peer", "call_remote", "reliable")
func req_cancel(_d: Dictionary) -> void:
	var id := Net.sender()
	if _of.has(id):
		_close(int(_of[id]), "%s takası iptal etti." % _pname(id))


@rpc("any_peer", "call_remote", "reliable")
func req_ok(_d: Dictionary) -> void:
	var id := Net.sender()
	if not _of.has(id):
		return
	var tid := int(_of[id])
	var t: Dictionary = _trades[tid]
	t.ok[_side(tid, id)] = true
	if not (t.ok.a and t.ok.b):
		_send(tid)
		return
	_execute(tid)


func _execute(tid: int) -> void:
	var t: Dictionary = _trades[tid]
	var a := int(t.a)
	var b := int(t.b)
	if _dist(a, b) > KEEP_RANGE:
		_close(tid, "Çok uzaklaştınız, takas iptal.")
		return
	for pair in [[a, t.offers.a], [b, t.offers.b]]:
		var why := _check(pair[0], pair[1])
		if why != "":
			_close(tid, "Takas yapılamadı: %s." % why)
			return
	var ra := _rec(a)
	var rb := _rec(b)
	# kova ve çanta sınırları
	if ra.get("fish", []).size() - t.offers.a.fish.size() + t.offers.b.fish.size() > Jobs.BAG_SIZE \
			or rb.get("fish", []).size() - t.offers.b.fish.size() + t.offers.a.fish.size() > Jobs.BAG_SIZE:
		_close(tid, "Takas yapılamadı: kovaya sığmıyor (en fazla %d balık)." % Jobs.BAG_SIZE)
		return
	# hepsi tamam: tek seferde değiştir
	_move(a, b, ra, rb, t.offers.a)
	_move(b, a, rb, ra, t.offers.b)
	Net.mark_dirty()
	for pid in [a, b]:
		Jobs.send_inventory(pid)
		Farm.send_state(pid)
		Rpg.send_sheet(pid)
		Ach.event(pid, "trades")
	Net.log_line("Takas: %s <-> %s  (%s / %s)" % [_pname(a), _pname(b), JSON.stringify(t.offers.a), JSON.stringify(t.offers.b)])
	_close(tid, "Takas tamamlandı!", true)


func _move(from: int, to: int, rf: Dictionary, rt: Dictionary, o: Dictionary) -> void:
	if int(o.money) > 0 and Net.try_spend(from, int(o.money)):
		Net.add_money(to, int(o.money))
	var bag_f: Array = rf.get("fish", [])
	if not rt.get("fish") is Array:
		rt["fish"] = []
	var idx: Array = o.fish.duplicate()
	idx.sort()
	idx.reverse()
	var moved: Array = []
	for i in idx:
		moved.append(bag_f[int(i)])
		bag_f.remove_at(int(i))
	for f in moved:
		rt.fish.append(f)
	var sf := Farm.barn(rf)
	var st := Farm.barn(rt)
	for k in o.barn:
		sf[k] = int(sf[k]) - int(o.barn[k])
		if int(sf[k]) <= 0:
			sf.erase(k)
		st[k] = int(st.get(k, 0)) + int(o.barn[k])
	var itf: Dictionary = Rpg.ensure(rf).items
	var itt: Dictionary = Rpg.ensure(rt).items
	for k in o.items:
		itf[k] = int(itf[k]) - int(o.items[k])
		if int(itf[k]) <= 0:
			itf.erase(k)
		itt[k] = int(itt.get(k, 0)) + int(o.items[k])


func _close(tid: int, text: String, ok := false) -> void:
	var t: Dictionary = _trades.get(tid, {})
	_trades.erase(tid)
	for side in ["a", "b"]:
		var pid := int(t.get(side, 0))
		_of.erase(pid)
		if Net.players.has(pid):
			Net.tell(self, pid, "on_closed", {"text": text, "ok": ok})
			Net.notify(pid, text, ok)


func _process(delta: float) -> void:
	if not Net.is_server() or _trades.is_empty():
		return
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	for tid in _trades.keys():
		var t: Dictionary = _trades[tid]
		if _dist(int(t.a), int(t.b)) > KEEP_RANGE:
			_close(tid, "Çok uzaklaştınız, takas iptal.")
