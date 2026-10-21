extends Node
## Oyuncu ekonomisi: pazar yeri ilanları (balık, yiyecek, mobilya, arsa) ve oyuncular arası para gönderme.
## İlan verilen eşya satıcıdan alınıp emanete konur (arsa hariç: arsa satıcıda kalır, ilan kilitler);
## satılınca para satıcıya geçer (çevrimdışıysa kaydına), %5 pazar komisyonu kesilir.

signal listings_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const KIND_NAMES := {"fish": "Balık", "food": "Yiyecek", "furniture": "Mobilya", "plot": "Arsa"}
const COMMISSION := 0.05
const MAX_LISTINGS := 8
const MAX_PRICE := 1000000
const TRANSFER_MIN_LEVEL := 3      # yeni hesap açıp başlangıç parasını aktarmayı zorlaştırır
const TRANSFER_MAX := 100000

var listings: Array = []           # herkes: [{id, seller, kind, item, label, price}]


func reset() -> void:
	listings = []


func _store() -> Array:
	if not Net.save_data.get("bazaar") is Array:
		Net.save_data["bazaar"] = []
	return Net.save_data["bazaar"]


func _next_id() -> int:
	var n := int(Net.save_data.get("bazaar_next", 1))
	Net.save_data["bazaar_next"] = n + 1
	return n


func _at_bazaar(id: int) -> bool:
	return Map.building("pazar").rect.grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


func _rec(player_name: String) -> Dictionary:
	return Net.save_data.players.get(player_name, {})


## Arsa ilanda mı? (Land satış/inşaatı engellemek için)
func plot_listed(i: int) -> bool:
	for l in _store():
		if l.kind == "plot" and int(l.item) == i:
			return true
	return false


# ------------------------------------------------------------------ istemci API

## ref: balık için çantadaki sıra, yiyecek/mobilya için tür, arsa için indeks
func list_item(kind: String, ref, price: int) -> void:
	Net.ask(self, "req_list", {"kind": kind, "ref": ref, "price": price})


func buy(listing_id: int) -> void:
	Net.ask(self, "req_buy", {"lid": listing_id})


func cancel(listing_id: int) -> void:
	Net.ask(self, "req_cancel", {"lid": listing_id})


func send_money(to_name: String, amount: int) -> void:
	Net.ask(self, "req_transfer", {"to": to_name, "amount": amount})


@rpc("authority", "call_local", "reliable")
func on_listings(d: Dictionary) -> void:
	listings = d.get("list", [])
	listings_changed.emit()


# ------------------------------------------------------------------ sunucu

func _broadcast() -> void:
	Net.tell_all(self, "on_listings", {"list": _store()})


func send_state(id: int) -> void:
	Net.tell(self, id, "on_listings", {"list": _store()})


func _mine(player_name: String) -> int:
	var n := 0
	for l in _store():
		if l.seller == player_name:
			n += 1
	return n


@rpc("any_peer", "call_remote", "reliable")
func req_list(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if not _at_bazaar(id):
		Net.notify(id, "İlan vermek için Pazar Yeri'ne git.", false)
		return
	var me: String = Net.players[id].name
	var kind := str(d.get("kind", ""))
	var price := int(d.get("price", 0))
	if price < 1 or price > MAX_PRICE:
		Net.notify(id, "Fiyat 1 ile %s arasında olmalı." % U.money(MAX_PRICE), false)
		return
	if _mine(me) >= MAX_LISTINGS:
		Net.notify(id, "En fazla %d ilanın olabilir." % MAX_LISTINGS, false)
		return
	var rec := _rec(me)
	var item = null
	var label := ""
	match kind:
		"fish":
			var bag: Array = rec.get("fish", [])
			var idx := int(d.get("ref", -1))
			if idx < 0 or idx >= bag.size():
				return
			item = bag.pop_at(idx)
			label = "%s (değeri %s)" % [item.name, U.money(int(item.price))]
			Jobs.send_inventory(id)
		"food":
			var k := str(d.get("ref", ""))
			var items: Dictionary = Rpg.ensure(rec).items
			if not Rpg.FOODS.has(k) or int(items.get(k, 0)) <= 0:
				return
			items[k] = int(items[k]) - 1
			if int(items[k]) <= 0:
				items.erase(k)
			item = k
			label = Rpg.FOODS[k].name
			Rpg.send_sheet(id)
		"furniture":
			var k := str(d.get("ref", ""))
			var dep: Dictionary = rec.get("furniture", {})
			if not Homes.FURNITURE.has(k) or int(dep.get(k, 0)) <= 0:
				return
			dep[k] = int(dep[k]) - 1
			if int(dep[k]) <= 0:
				dep.erase(k)
			item = k
			label = Homes.FURNITURE[k].name
			Homes.send_state(id)
		"plot":
			var i := int(d.get("ref", -1))
			if i < 0 or i >= Land.plots.size() or Land.plots[i].owner != me:
				return
			if plot_listed(i):
				Net.notify(id, "Bu arsa zaten ilanda.", false)
				return
			item = i
			label = "Arsa #%d (%s)" % [i + 1, Land.building_name(Land.plots[i])]
		_:
			return
	_store().append({"id": _next_id(), "seller": me, "kind": kind, "item": item, "label": label, "price": price})
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "İlan verildi: %s — %s" % [label, U.money(price)])
	if kind == "plot":
		Net.announce("%s, %s satışa çıkardı: %s" % [me, label, U.money(price)])


func _find(lid: int) -> int:
	var store := _store()
	for i in store.size():
		if int(store[i].id) == lid:
			return i
	return -1


## Eşyayı oyuncuya ver; veremiyorsa (çanta dolu vb.) sebebi döner.
func _give(player_name: String, l: Dictionary, check_only: bool) -> String:
	var rec := _rec(player_name)
	match str(l.kind):
		"fish":
			var bag: Array = rec.get("fish", [])
			if bag.size() >= Jobs.BAG_SIZE:
				return "Kovan dolu."
			if not check_only:
				bag.append(l.item)
		"food":
			var items: Dictionary = Rpg.ensure(rec).items
			if int(items.get(l.item, 0)) >= Rpg.MAX_FOOD_STACK:
				return "Çantanda yer yok."
			if not check_only:
				items[l.item] = int(items.get(l.item, 0)) + 1
		"furniture":
			if not rec.get("furniture") is Dictionary:
				rec["furniture"] = {}
			if not check_only:
				rec.furniture[l.item] = int(rec.furniture.get(l.item, 0)) + 1
		"plot":
			var owned := 0
			for p in Land.plots:
				if p.owner == player_name:
					owned += 1
			if owned >= Land.MAX_PER_PLAYER:
				return "En fazla %d arsan olabilir." % Land.MAX_PER_PLAYER
			if not check_only:
				var i := int(l.item)
				Homes.clear_plot(i, str(l.seller))
				Land.plots[i].owner = player_name
				Land._broadcast()
	return ""


func _refresh_owner(player_name: String) -> void:
	var pid := Net.id_by_name(player_name)
	if pid != 0:
		Jobs.send_inventory(pid)
		Rpg.send_sheet(pid)
		Homes.send_state(pid)


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if not _at_bazaar(id):
		Net.notify(id, "Satın almak için Pazar Yeri'ne git.", false)
		return
	var idx := _find(int(d.get("lid", -1)))
	if idx < 0:
		Net.notify(id, "Bu ilan artık yok.", false)
		return
	var l: Dictionary = _store()[idx]
	var me: String = Net.players[id].name
	if l.seller == me:
		Net.notify(id, "Kendi ilanını alamazsın; iptal edebilirsin.", false)
		return
	var why := _give(me, l, true)
	if why != "":
		Net.notify(id, why, false)
		return
	if not Net.try_spend(id, int(l.price)):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	_store().remove_at(idx)
	_give(me, l, false)
	var earned := int(l.price) - int(round(int(l.price) * COMMISSION))
	Net.add_money_by_name(str(l.seller), earned)
	Net.mark_dirty()
	_broadcast()
	_refresh_owner(me)
	Net.notify(id, "Satın aldın: %s" % l.label)
	var sid := Net.id_by_name(str(l.seller))
	if sid != 0:
		Net.notify(sid, "%s ilanını %s aldı: +%s (komisyon %%%d)" % [l.label, me, U.money(earned), int(COMMISSION * 100)])
	Net.log_line("Pazar: %s → %s, %s, %d TL" % [l.seller, me, l.label, int(l.price)])
	if l.kind == "plot":
		Rpg.quest_event(id, "build")


@rpc("any_peer", "call_remote", "reliable")
func req_cancel(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var idx := _find(int(d.get("lid", -1)))
	if idx < 0:
		return
	var l: Dictionary = _store()[idx]
	var me: String = Net.players[id].name
	if l.seller != me:
		return
	if l.kind != "plot":
		var why := _give(me, l, true)
		if why != "":
			Net.notify(id, "İptal edilemedi: %s" % why, false)
			return
		_give(me, l, false)
	_store().remove_at(idx)
	Net.mark_dirty()
	_broadcast()
	_refresh_owner(me)
	Net.notify(id, "İlan kaldırıldı: %s" % l.label)


## Arsa başka yolla el değiştirirse (bankaya satış) ilanını sil.
func drop_plot_listing(i: int) -> void:
	var store := _store()
	for k in range(store.size() - 1, -1, -1):
		if store[k].kind == "plot" and int(store[k].item) == i:
			store.remove_at(k)
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_transfer(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var to := str(d.get("to", ""))
	var amount := int(d.get("amount", 0))
	var tid := Net.id_by_name(to)
	if tid == 0 or tid == id:
		Net.notify(id, "Para sadece çevrimiçi başka bir oyuncuya gönderilebilir.", false)
		return
	if Rpg.level(id) < TRANSFER_MIN_LEVEL:
		Net.notify(id, "Para göndermek için seviye %d gerekli." % TRANSFER_MIN_LEVEL, false)
		return
	if amount < 1 or amount > TRANSFER_MAX:
		Net.notify(id, "Tutar 1 ile %s arasında olmalı." % U.money(TRANSFER_MAX), false)
		return
	if not Net.try_spend(id, amount):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	Net.add_money(tid, amount)
	Net.notify(id, "%s oyuncusuna %s gönderdin." % [to, U.money(amount)])
	Net.notify(tid, "%s sana %s gönderdi!" % [Net.players[id].name, U.money(amount)])
	Net.log_line("Transfer: %s → %s %d TL" % [Net.players[id].name, to, amount])
