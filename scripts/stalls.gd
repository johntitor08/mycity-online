extends Node
## Pazar meydanı (1.9, Yeni Mahalle): 8 kiralık tezgâh ve alım ilanları panosu.
##  Tezgâh günlüğü 400 TL (en fazla 3 gün peşin). Tezgâha balık, yiyecek ve çiftlik ürünü dizip fiyatını
##  sen belirlersin; adını ve tente rengini seçersin. Oyuncular tezgâhın önünden alır; sen çevrimdışıyken de
##  meydana gelen müşteriler (NPC) uygun fiyatlı malları satın alır. Fiyat değerinin çok üstündeyse kimse almaz.
##  Satışlar kasada birikir (%5 pazar payı); tezgâhın önünde kasayı boşaltırsın. Kira bitince mallar sana döner.
##  Alım ilanı: "şu üründen şu kadar, tanesi şu fiyattan alırım" — para emanete alınır, satıcı ilanı doldurur.
## Veri: save_data["stalls"] = [ {owner, name, color, until, items: [{kind, item, label, price, base, qty}], till, sold} ... ]
##       save_data["wanted"] = [{id, buyer, kind, key, label, qty, price}]

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const RENT := 400
const MAX_DAYS := 3
const DAY := 86400.0
const MAX_ITEMS := 8
const COMMISSION := 0.05
const NPC_EVERY := 15.0
const MAX_WANTED := 5
const COLORS := [Color("#ef4444"), Color("#f97316"), Color("#eab308"), Color("#22c55e"), Color("#0ea5e9"), Color("#8b5cf6"), Color("#ec4899"), Color("#14b8a6")]

# --- istemci
var view: Array = []                 # her tezgâh: {owner, name, color, open, items: [{label, price, qty, kind}], till (sahibine)}
var wanted: Array = []

# --- sunucu
var _npc_acc := 0.0
var _visitors: Array = []            # meydanı dolaşan NPC müşteriler (görsel)


func reset() -> void:
	view = []
	wanted = []


func on_player_left(_id: int) -> void:
	pass


static func stall_near(p: Vector2) -> int:
	for i in Map.STALL_COUNT:
		if p.distance_to(Map.stall_front(i)) < 90.0:
			return i
	return -1


func my_stall() -> int:
	for i in view.size():
		if str(view[i].get("owner", "")) == Net.my_name:
			return i
	return -1


# ------------------------------------------------------------------ istemci API

func rent(i: int) -> void:
	Net.ask(self, "req_rent", {"i": i})


func stock(kind: String, ref, qty: int, price: int) -> void:
	Net.ask(self, "req_stock", {"kind": kind, "ref": ref, "qty": qty, "price": price})


func unstock(idx: int) -> void:
	Net.ask(self, "req_unstock", {"idx": idx})


func set_look(stall_name: String, color: int) -> void:
	Net.ask(self, "req_look", {"name": stall_name, "color": color})


func collect() -> void:
	Net.ask(self, "req_collect")


func release() -> void:
	Net.ask(self, "req_release")


func buy(i: int, idx: int) -> void:
	Net.ask(self, "req_buy", {"i": i, "idx": idx})


func post_wanted(kind: String, key: String, qty: int, price: int) -> void:
	Net.ask(self, "req_want", {"kind": kind, "key": key, "qty": qty, "price": price})


func fulfill(wid: int, qty: int) -> void:
	Net.ask(self, "req_fulfill", {"wid": wid, "qty": qty})


func cancel_wanted(wid: int) -> void:
	Net.ask(self, "req_unwant", {"wid": wid})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	view = d.get("stalls", [])
	wanted = d.get("wanted", [])
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec_by(player_name: String) -> Dictionary:
	return Net.save_data.players.get(player_name, {})


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _store() -> Array:
	if not Net.save_data.get("stalls") is Array:
		Net.save_data["stalls"] = []
	var s: Array = Net.save_data.stalls
	while s.size() < Map.STALL_COUNT:
		s.append({})
	return s


func _wanted() -> Array:
	if not Net.save_data.get("wanted") is Array:
		Net.save_data["wanted"] = []
	return Net.save_data.wanted


func _open(st: Dictionary) -> bool:
	return not st.is_empty() and float(st.get("until", 0.0)) > Time.get_unix_time_from_system()


func _view_for(player_name: String) -> Dictionary:
	var out: Array = []
	for st in _store():
		if st.is_empty():
			out.append({})
			continue
		var items: Array = []
		for it in st.items:
			items.append({"label": it.label, "price": int(it.price), "qty": int(it.qty), "kind": it.kind, "base": int(it.base)})
		var v := {"owner": st.owner, "name": st.name, "color": int(st.color), "open": _open(st), "items": items, "sold": int(st.get("sold", 0))}
		if st.owner == player_name:
			v["till"] = int(st.till)
			v["left"] = float(st.until) - Time.get_unix_time_from_system()
		out.append(v)
	return {"stalls": out, "wanted": _wanted()}


func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_state", _view_for(Net.players[id].name))


func _broadcast() -> void:
	for id in Net.players:
		send_state(id)


func _mine(player_name: String) -> int:
	var s := _store()
	for i in s.size():
		if not s[i].is_empty() and s[i].owner == player_name:
			return i
	return -1


## Bir malın piyasa değeri (NPC müşteriler buna göre karar verir).
static func base_value(kind: String, item) -> int:
	match kind:
		"fish":
			return int(item.price)
		"food":
			return int(Rpg.food_info(str(item)).get("price", 10))
		"crop":
			return int(Farm.item_info(str(item)).get("price", 5))
	return 1


func _take(id: int, rec: Dictionary, kind: String, ref, qty: int) -> Dictionary:
	match kind:
		"fish":
			var bag: Array = rec.get("fish", [])
			var idx := int(ref)
			if idx < 0 or idx >= bag.size():
				return {}
			var f: Dictionary = bag.pop_at(idx)
			Jobs.send_inventory(id)
			return {"kind": "fish", "item": f, "label": str(f.name), "qty": 1}
		"food":
			var k := str(ref)
			var items: Dictionary = Rpg.ensure(rec).items
			var n := mini(qty, int(items.get(k, 0)))
			if Rpg.food_info(k).is_empty() or n <= 0:
				return {}
			items[k] = int(items[k]) - n
			if int(items[k]) <= 0:
				items.erase(k)
			Rpg.send_sheet(id)
			return {"kind": "food", "item": k, "label": Rpg.food_info(k).name, "qty": n}
		"crop":
			var k := str(ref)
			var store := Farm.barn(rec)
			var n := mini(qty, int(store.get(k, 0)))
			if Farm.item_info(k).is_empty() or n <= 0:
				return {}
			store[k] = int(store[k]) - n
			if int(store[k]) <= 0:
				store.erase(k)
			Farm.send_state(id)
			return {"kind": "crop", "item": k, "label": Farm.item_info(k).name, "qty": n}
	return {}


## Malı oyuncuya ver (n tane). Yer yoksa hata metni döner.
func _give(player_name: String, kind: String, item, n: int, check_only: bool = false) -> String:
	var rec := _rec_by(player_name)
	if rec.is_empty():
		return "Oyuncu yok."
	match kind:
		"fish":
			var bag: Array = rec.get("fish", [])
			if bag.size() + n > Jobs.BAG_SIZE:
				return "Balık kovası dolu."
			if not check_only:
				if not rec.get("fish") is Array:
					rec["fish"] = bag
				for k in n:
					bag.append(item)
		"food":
			var items: Dictionary = Rpg.ensure(rec).items
			if int(items.get(item, 0)) + n > Rpg.MAX_FOOD_STACK:
				return "Çantada yer yok."
			if not check_only:
				items[item] = int(items.get(item, 0)) + n
		"crop":
			var store := Farm.barn(rec)
			if int(store.get(item, 0)) + n > Farm.MAX_STACK:
				return "Ambarda yer yok."
			if not check_only:
				store[item] = int(store.get(item, 0)) + n
	return ""


func _refresh_inv(player_name: String) -> void:
	var pid := Net.id_by_name(player_name)
	if pid != 0:
		Jobs.send_inventory(pid)
		Rpg.send_sheet(pid)
		Farm.send_state(pid)


@rpc("any_peer", "call_remote", "reliable")
func req_rent(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var i := int(d.get("i", -1))
	if i < 0 or i >= Map.STALL_COUNT or _pos(id).distance_to(Map.stall_front(i)) > 120.0:
		return
	var s := _store()
	var st: Dictionary = s[i]
	var now := Time.get_unix_time_from_system()
	if not st.is_empty() and st.owner != me and _open(st):
		Net.notify(id, "Bu tezgâh %s'in." % st.owner, false)
		return
	var mine := _mine(me)
	if mine >= 0 and mine != i:
		Net.notify(id, "Zaten %d numaralı tezgâhın var." % (mine + 1), false)
		return
	if not st.is_empty() and st.owner == me and float(st.until) - now > (MAX_DAYS - 1) * DAY:
		Net.notify(id, "En fazla %d gün peşin ödenir." % MAX_DAYS, false)
		return
	var rent := Projects.stall_rent()          # 2.0: mahalle muhtarı belirler
	if not Net.try_spend(id, rent):
		Net.notify(id, "Günlük kira %s." % U.money(rent), false)
		return
	Projects.rent_paid(rent)
	if st.is_empty() or st.owner != me:
		if not st.is_empty():
			_return_goods(st)
		s[i] = {"owner": me, "name": "%s'in Tezgâhı" % me, "color": i % COLORS.size(), "until": now + DAY, "items": [], "till": 0, "sold": 0}
		Net.notify(id, "%d numaralı tezgâh 1 günlüğüne senin! Mallarını diz, fiyatı sen belirle." % (i + 1))
	else:
		st["until"] = maxf(float(st.until), now) + DAY
		Net.notify(id, "Kira 1 gün uzatıldı.")
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_stock(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var i := _mine(me)
	if i < 0 or not _open(_store()[i]) or _pos(id).distance_to(Map.stall_front(i)) > 120.0:
		return
	var st: Dictionary = _store()[i]
	var price := clampi(int(d.get("price", 0)), 1, 100000)
	var kind := str(d.get("kind", ""))
	# aynı mal aynı fiyatla zaten varsa üstüne eklenir
	var e := _take(id, _rec_by(me), kind, d.get("ref"), clampi(int(d.get("qty", 1)), 1, 99))
	if e.is_empty():
		return
	for it in st.items:
		if it.kind == kind and kind != "fish" and str(it.item) == str(e.item) and int(it.price) == price:
			it["qty"] = int(it.qty) + int(e.qty)
			Net.mark_dirty()
			_broadcast()
			return
	if st.items.size() >= MAX_ITEMS:
		_give(me, kind, e.item, int(e.qty))
		_refresh_inv(me)
		Net.notify(id, "Tezgâhta en fazla %d çeşit mal olur." % MAX_ITEMS, false)
		return
	e["price"] = price
	e["base"] = base_value(kind, e.item)
	st.items.append(e)
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "Tezgâha dizildi: %d %s, tanesi %s" % [int(e.qty), e.label, U.money(price)])


@rpc("any_peer", "call_remote", "reliable")
func req_unstock(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var i := _mine(me)
	var idx := int(d.get("idx", -1))
	if i < 0 or idx < 0 or idx >= _store()[i].items.size():
		return
	var it: Dictionary = _store()[i].items[idx]
	var err := _give(me, it.kind, it.item, int(it.qty))
	if err != "":
		Net.notify(id, err, false)
		return
	_store()[i].items.remove_at(idx)
	_refresh_inv(me)
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_look(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var i := _mine(Net.players[id].name)
	if i < 0:
		return
	var nm := str(d.get("name", "")).strip_edges().left(24)
	if nm != "":
		_store()[i]["name"] = nm
	_store()[i]["color"] = clampi(int(d.get("color", 0)), 0, COLORS.size() - 1)
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_collect(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var i := _mine(Net.players[id].name)
	if i < 0 or _pos(id).distance_to(Map.stall_front(i)) > 120.0:
		return
	var st: Dictionary = _store()[i]
	var m := int(st.till)
	if m <= 0:
		return
	st["till"] = 0
	Net.add_money(id, m)
	Net.notify(id, "Kasadan %s aldın." % U.money(m))
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_release(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var i := _mine(Net.players[id].name)
	if i < 0:
		return
	_return_goods(_store()[i])
	_store()[i] = {}
	Net.notify(id, "Tezgâhı bıraktın; malların ve kasa sana döndü.")
	Net.mark_dirty()
	_broadcast()


## Mallar ve kasa sahibine döner (yer yoksa mal değeri parayla ödenir).
func _return_goods(st: Dictionary) -> void:
	var owner := str(st.owner)
	var money := int(st.get("till", 0))
	for it in st.items:
		if _give(owner, it.kind, it.item, int(it.qty)) != "":
			money += int(it.base) * int(it.qty)
	if money > 0:
		var pid := Net.id_by_name(owner)
		if pid != 0:
			Net.add_money(pid, money)
		else:
			Net.add_money_by_name(owner, money)
	_refresh_inv(owner)


func _sell(i: int, idx: int, buyer: String) -> void:
	var st: Dictionary = _store()[i]
	var it: Dictionary = st.items[idx]
	var price := int(it.price)
	it["qty"] = int(it.qty) - 1
	var label := str(it.label)
	if int(it.qty) <= 0:
		st.items.remove_at(idx)
	st["till"] = int(st.till) + int(round(price * (1.0 - COMMISSION)))
	st["sold"] = int(st.get("sold", 0)) + 1
	var oid := Net.id_by_name(str(st.owner))
	if oid != 0:
		Ach.event(oid, "stall_sales")
		Net.notify(oid, "Tezgâhından %s satıldı: %s (%s)" % [label, U.money(price), buyer])
	else:
		var orec := _rec_by(str(st.owner))
		if not orec.is_empty():
			var a := Ach.ach_of(orec)
			a.c["stall_sales"] = int(a.c.get("stall_sales", 0)) + 1


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var i := int(d.get("i", -1))
	var idx := int(d.get("idx", -1))
	if i < 0 or i >= Map.STALL_COUNT or _pos(id).distance_to(Map.stall_front(i)) > 120.0:
		return
	var st: Dictionary = _store()[i]
	if not _open(st) or idx < 0 or idx >= st.items.size():
		return
	if st.owner == me:
		Net.notify(id, "Kendi tezgâhından alamazsın (malı geri almak için 'Kaldır').", false)
		return
	var it: Dictionary = st.items[idx]
	var err := _give(me, it.kind, it.item, 1, true)
	if err != "":
		Net.notify(id, err, false)
		return
	if not Net.try_spend(id, int(it.price)):
		Net.notify(id, "%s gerekli." % U.money(int(it.price)), false)
		return
	_give(me, it.kind, it.item, 1)
	_refresh_inv(me)
	Net.notify(id, "%s aldın (%s)." % [it.label, U.money(int(it.price))])
	_sell(i, idx, me)
	Net.mark_dirty()
	_broadcast()


# --- alım ilanları

@rpc("any_peer", "call_remote", "reliable")
func req_want(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _pos(id).distance_to(Map.WANTED_BOARD) > 130.0:
		return
	var me: String = Net.players[id].name
	var kind := str(d.get("kind", ""))
	var key := str(d.get("key", ""))
	var label := ""
	if kind == "food" and not Rpg.food_info(key).is_empty():
		label = Rpg.food_info(key).name
	elif kind == "crop" and not Farm.item_info(key).is_empty():
		label = Farm.item_info(key).name
	else:
		return
	var qty := clampi(int(d.get("qty", 1)), 1, 99)
	var price := clampi(int(d.get("price", 1)), 1, 10000)
	var n := 0
	for w in _wanted():
		if w.buyer == me:
			n += 1
	if n >= MAX_WANTED:
		Net.notify(id, "En fazla %d alım ilanın olabilir." % MAX_WANTED, false)
		return
	if not Net.try_spend(id, qty * price):
		Net.notify(id, "İlan için %s emanete alınır." % U.money(qty * price), false)
		return
	var wid := int(Net.save_data.get("wanted_next", 1))
	Net.save_data["wanted_next"] = wid + 1
	_wanted().append({"id": wid, "buyer": me, "kind": kind, "key": key, "label": label, "qty": qty, "price": price})
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "Alım ilanı asıldı: %d %s, tanesi %s (para emanette)" % [qty, label, U.money(price)])


func _find_wanted(wid: int) -> int:
	var w := _wanted()
	for i in w.size():
		if int(w[i].id) == wid:
			return i
	return -1


@rpc("any_peer", "call_remote", "reliable")
func req_fulfill(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _pos(id).distance_to(Map.WANTED_BOARD) > 130.0:
		return
	var me: String = Net.players[id].name
	var wi := _find_wanted(int(d.get("wid", -1)))
	if wi < 0:
		return
	var w: Dictionary = _wanted()[wi]
	if w.buyer == me:
		return
	var rec := _rec_by(me)
	var have := 0
	if w.kind == "food":
		have = int(Rpg.ensure(rec).items.get(w.key, 0))
	else:
		have = int(Farm.barn(rec).get(w.key, 0))
	var n := mini(mini(int(d.get("qty", 1)), int(w.qty)), have)
	if n <= 0:
		Net.notify(id, "Sende %s yok." % w.label, false)
		return
	var err := _give(str(w.buyer), w.kind, w.key, n, true)
	if err != "":
		Net.notify(id, "Alıcının deposu dolu: %s" % err, false)
		return
	_take(id, rec, w.kind, w.key, n)
	_give(str(w.buyer), w.kind, w.key, n)
	_refresh_inv(str(w.buyer))
	var pay := n * int(w.price)
	Net.add_money(id, pay)
	w["qty"] = int(w.qty) - n
	if int(w.qty) <= 0:
		_wanted().remove_at(wi)
	var bid := Net.id_by_name(str(w.buyer))
	if bid != 0:
		Net.notify(bid, "Alım ilanın: %s sana %d %s sattı." % [me, n, w.label])
	Ach.event(id, "stall_sales", n)
	Net.notify(id, "%d %s sattın: %s" % [n, w.label, U.money(pay)])
	Net.mark_dirty()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_unwant(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var wi := _find_wanted(int(d.get("wid", -1)))
	if wi < 0 or _wanted()[wi].buyer != Net.players[id].name:
		return
	var w: Dictionary = _wanted()[wi]
	Net.add_money(id, int(w.qty) * int(w.price))
	_wanted().remove_at(wi)
	Net.notify(id, "İlan kaldırıldı, emanetteki para iade edildi.")
	Net.mark_dirty()
	_broadcast()


# --- meydana gelen müşteriler

## NPC müşteri bu fiyata bir tane alır mı? (değerine göre olasılık)
static func npc_chance(price: int, base: int) -> float:
	var r := float(base) * 1.4 / maxf(1.0, float(price))
	if r < 0.55:
		return 0.0               # değerinin ~2,5 katından pahalı: kimse almaz
	return clampf(0.12 * r * r, 0.0, 0.6)


func npc_round() -> int:
	var sold := 0
	var s := _store()
	var now := Time.get_unix_time_from_system()
	for i in s.size():
		var st: Dictionary = s[i]
		if st.is_empty():
			continue
		if float(st.until) <= now:
			# kira bitti: mallar sahibine döner, tezgâh boşalır
			var owner := str(st.owner)
			_return_goods(st)
			s[i] = {}
			sold += 1
			var pid := Net.id_by_name(owner)
			if pid != 0:
				Net.notify(pid, "Tezgâh kiran bitti; malların ve kasan sana döndü.", false)
			continue
		for idx in range(st.items.size() - 1, -1, -1):
			var it: Dictionary = st.items[idx]
			if randf() < npc_chance(int(it.price), int(it.base)) * (2.0 if Projects.market_day() else 1.0):
				_sell(i, idx, "bir müşteri")
				sold += 1
				break
	return sold


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_npc_acc += delta
	if _npc_acc < NPC_EVERY:
		return
	_npc_acc = 0.0
	if npc_round() > 0:
		Net.mark_dirty()
		_broadcast()
