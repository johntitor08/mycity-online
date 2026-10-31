extends Node
## Restoran mutfağı ve aşçılık yarışması (2.0).
##  Servis vardiyası: kafe ya da restoran sahibi işletmesinin panelinden mutfağa girer (90 sn). Siparişler gelir;
##  her yemeğin adımları vardır (1 doğra, 2 ocak, 3 fırın, 4 ızgara, 5 sos, 6 tabakla). Ocak/fırın/ızgarada
##  bir kez basınca pişmeye başlar, yeşil bölgede yeniden basınca tam kıvamında olur (erken çiğ, geç yanık).
##  Doğru ve çabuk servis bahşiş getirir ve işletmenin puanını artırır; kaçan sipariş puanı düşürür.
##  Aşçılık yarışması: Yeni Mahalle'deki Aşçılık Akademisi'nde 2 saatlik dönemler. Her dönem bir kez katılınır:
##  3 zor yemek pişirilir, istersen çantandan bir imza yemeği (evde pişirdiğin) jüriye sunulur. 3 jüri teknik,
##  lezzet ve sunuma puan verir. Dönem bitince ilk üç ödül alır.
## Veri: rec["chef"] = {orders, perfect, best}; save_data["chef_contest"] = {period, scores: {ad: puan}, last: [[ad, puan]]}

signal changed
signal order_event(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const STATIONS := {
	"dogra": ["Doğra", KEY_1], "ocak": ["Ocak", KEY_2], "firin": ["Fırın", KEY_3],
	"izgara": ["Izgara", KEY_4], "sos": ["Sos", KEY_5], "tabak": ["Tabakla", KEY_6],
}
const COOKING := ["ocak", "firin", "izgara"]
const COOK_TIME := 1.6               # pişme çubuğunun dolma süresi
const GOOD := [0.62, 0.88]           # yeşil bölge (çubuk oranı)
const DISHES := {
	"menemen": {"name": "Menemen", "steps": ["dogra", "ocak", "tabak"], "price": 45, "level": 2},
	"corba": {"name": "Mercimek Çorbası", "steps": ["ocak", "sos", "tabak"], "price": 35, "level": 2},
	"salata": {"name": "Çoban Salata", "steps": ["dogra", "dogra", "sos", "tabak"], "price": 30, "level": 2},
	"baklava": {"name": "Baklava", "steps": ["firin", "sos", "tabak"], "price": 55, "level": 2},
	"doner": {"name": "Döner Dürüm", "steps": ["dogra", "izgara", "sos", "tabak"], "price": 60, "level": 3},
	"kofte": {"name": "Izgara Köfte", "steps": ["dogra", "izgara", "tabak"], "price": 70, "level": 3},
	"pide": {"name": "Kıymalı Pide", "steps": ["dogra", "firin", "tabak"], "price": 65, "level": 3},
	"iskender": {"name": "İskender", "steps": ["izgara", "firin", "sos", "tabak"], "price": 95, "level": 3},
}
const CONTEST_DISHES := {
	"karniyarik": {"name": "Karnıyarık", "steps": ["dogra", "izgara", "dogra", "firin", "tabak"]},
	"manti": {"name": "Kayseri Mantısı", "steps": ["dogra", "ocak", "sos", "firin", "tabak"]},
	"hunkar": {"name": "Hünkâr Beğendi", "steps": ["izgara", "ocak", "sos", "ocak", "tabak"]},
	"kunefe": {"name": "Künefe", "steps": ["dogra", "firin", "sos", "tabak"]},
	"levrek": {"name": "Fırında Levrek", "steps": ["dogra", "sos", "firin", "dogra", "tabak"]},
}
const SHIFT_TIME := 90.0
const MAX_ORDERS := 3
const CONTEST_PERIOD := 7200.0
const CONTEST_PRIZES := [3000, 1500, 750]
const CONTEST_DISH_TIME := 30.0

# --- istemci
var shift := {}                      # {left, orders: [{id, dish, left}], served, missed, earned} ya da {}
var contest := {}                    # {orders: [...], done: n} ya da {} ; sonuç için "result"
var board := {}                      # {period_left, scores: [[ad, puan]], last: [[ad, puan]], entered}

# --- sunucu
var _shifts := {}                    # id -> {plot, t0, orders: {oid: {dish, t, dl}}, next, spawn, served, missed, earned, perfect}
var _contests := {}                  # id -> {t0, orders: {oid: {dish, t, dl}}, q: [], next}
var _acc := 0.0


func reset() -> void:
	shift = {}
	contest = {}
	board = {}
	_shifts.clear()
	_contests.clear()


func on_player_left(id: int) -> void:
	_shifts.erase(id)
	_contests.erase(id)


static func dish_info(k: String) -> Dictionary:
	if DISHES.has(k):
		return DISHES[k]
	return CONTEST_DISHES.get(k, {})


## Bir pişirme adımının kalitesi (çubuğun durduğu oran).
static func cook_quality(frac: float) -> float:
	if frac >= GOOD[0] and frac <= GOOD[1]:
		return 1.0
	if frac < GOOD[0]:
		return clampf(0.3 + frac / GOOD[0] * 0.5, 0.3, 0.8)      # çiğ
	return clampf(1.0 - (frac - GOOD[1]) * 2.0, 0.15, 0.8)       # yanık


static func period_of(t: float) -> int:
	return int(t / CONTEST_PERIOD)


# ------------------------------------------------------------------ istemci API

func start_shift(plot: int) -> void:
	Net.ask(self, "req_shift", {"plot": plot})


func serve(oid: int, q: float) -> void:
	Net.ask(self, "req_serve", {"oid": oid, "q": q})


func start_contest() -> void:
	Net.ask(self, "req_contest")


func contest_dish(oid: int, q: float) -> void:
	Net.ask(self, "req_contest_dish", {"oid": oid, "q": q})


func finish_contest(signature: String) -> void:
	Net.ask(self, "req_contest_end", {"sig": signature})


func refresh_board() -> void:
	Net.ask(self, "req_board")


@rpc("authority", "call_local", "reliable")
func on_shift(d: Dictionary) -> void:
	shift = d
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_order(d: Dictionary) -> void:
	order_event.emit(d)


@rpc("authority", "call_local", "reliable")
func on_contest(d: Dictionary) -> void:
	contest = d
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_board(d: Dictionary) -> void:
	board = d
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("chef") is Dictionary:
		rec["chef"] = {"orders": 0, "perfect": 0, "best": 0.0}
	return rec.chef


func _store() -> Dictionary:
	if not Net.save_data.get("chef_contest") is Dictionary:
		Net.save_data["chef_contest"] = {"period": period_of(Time.get_unix_time_from_system()), "scores": {}, "last": []}
	return Net.save_data.chef_contest


func _shift_view(id: int) -> Dictionary:
	if not _shifts.has(id):
		return {}
	var s: Dictionary = _shifts[id]
	var now := _now()
	var list: Array = []
	for oid in s.orders:
		var o: Dictionary = s.orders[oid]
		list.append({"id": oid, "dish": o.dish, "left": snappedf(float(o.dl) - now, 0.1), "total": float(o.dl) - float(o.t)})
	return {"left": snappedf(SHIFT_TIME - (now - float(s.t0)), 0.1), "orders": list, "served": int(s.served), "missed": int(s.missed),
		"earned": int(s.earned), "perfect": int(s.perfect)}


func send_state(id: int) -> void:
	Net.tell(self, id, "on_shift", _shift_view(id))
	_send_board(id)


func _send_board(id: int) -> void:
	var st := _store()
	var list: Array = []
	for k in st.scores:
		list.append([k, float(st.scores[k])])
	list.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var me: String = Net.players[id].name if Net.players.has(id) else ""
	var now := Time.get_unix_time_from_system()
	Net.tell(self, id, "on_board", {"period_left": CONTEST_PERIOD - fmod(now, CONTEST_PERIOD), "scores": list.slice(0, 10),
		"last": st.get("last", []), "entered": st.scores.has(me)})


@rpc("any_peer", "call_remote", "reliable")
func req_board(_d: Dictionary) -> void:
	var id := Net.sender()
	if Net.players.has(id):
		_send_board(id)


@rpc("any_peer", "call_remote", "reliable")
func req_shift(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _shifts.has(id):
		return
	var i := int(d.get("plot", -1))
	if i < 0 or i >= Land.plots.size():
		return
	var p: Dictionary = Land.plots[i]
	if p.owner != Net.players[id].name or not Biz.is_biz(p) or int(p.level) < 2:
		Net.notify(id, "Mutfak servisi kendi kafende ya da restoranında yapılır.", false)
		return
	if not Map.plot_rect(i).grow(80).has_point(_pos(id)):
		Net.notify(id, "Mutfağa girmek için işletmenin başında ol.", false)
		return
	var now := _now()
	_shifts[id] = {"plot": i, "level": int(p.level), "t0": now, "orders": {}, "next": 1, "spawn": now, "served": 0, "missed": 0, "earned": 0, "perfect": 0}
	_spawn_order(id)
	Net.tell(self, id, "on_shift", _shift_view(id))


func _spawn_order(id: int) -> void:
	var s: Dictionary = _shifts[id]
	var pool: Array = []
	for k in DISHES:
		if int(DISHES[k].level) <= int(s.level):
			pool.append(k)
	var k: String = pool[randi() % pool.size()]
	var now := _now()
	var oid := int(s.next)
	s["next"] = oid + 1
	s.orders[oid] = {"dish": k, "t": now, "dl": now + 16.0 + 4.0 * DISHES[k].steps.size()}
	s["spawn"] = now + (randf_range(6.0, 8.0) if int(s.level) >= 3 else randf_range(8.0, 10.0))


@rpc("any_peer", "call_remote", "reliable")
func req_serve(d: Dictionary) -> void:
	var id := Net.sender()
	if not _shifts.has(id):
		return
	var s: Dictionary = _shifts[id]
	var oid := int(d.get("oid", -1))
	if not s.orders.has(oid):
		return
	var o: Dictionary = s.orders[oid]
	var now := _now()
	var info: Dictionary = DISHES[o.dish]
	# en az bu kadar sürede pişer (adım başına; pişirme adımları daha uzun)
	var min_t := 0.0
	for st in info.steps:
		min_t += COOK_TIME * GOOD[0] * 0.8 if st in COOKING else 0.15
	if now - float(o.t) < min_t or now > float(o.dl):
		return
	s.orders.erase(oid)
	var q := clampf(float(d.get("q", 0.0)), 0.0, 1.0)
	var fast := clampf((float(o.dl) - now) / (float(o.dl) - float(o.t)), 0.0, 1.0)
	var pay := int(round(float(info.price) * (0.5 + 0.7 * q) * (1.0 + 0.3 * fast)))
	var tip := 0
	if q >= 0.9:
		tip = int(info.price * 0.25)
		s["perfect"] = int(s.perfect) + 1
	pay += tip
	s["served"] = int(s.served) + 1
	s["earned"] = int(s.earned) + pay
	Net.add_money(id, pay)
	var b: Dictionary = Land.plots[int(s.plot)].get("biz", {})
	if not b.is_empty():
		b["rating"] = clampf(float(b.get("rating", 3.0)) + 0.04 * (q - 0.5), 1.0, 5.0)
	var c := _data(_rec(id))
	c["orders"] = int(c.orders) + 1
	Ach.event(id, "chef_orders")
	if q >= 0.9:
		c["perfect"] = int(c.perfect) + 1
		Ach.event(id, "chef_perfect")
	Rpg.add_xp(id, "", 6)
	Net.tell(self, id, "on_order", {"id": oid, "pay": pay, "tip": tip, "q": q})
	Net.tell(self, id, "on_shift", _shift_view(id))


func _end_shift(id: int) -> void:
	var s: Dictionary = _shifts[id]
	_shifts.erase(id)
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "Vardiya bitti: %d sipariş, %d mükemmel, %d kaçtı. Kazanç %s" % [int(s.served), int(s.perfect), int(s.missed), U.money(int(s.earned))])
	Net.tell(self, id, "on_shift", {"over": true, "served": int(s.served), "missed": int(s.missed), "earned": int(s.earned), "perfect": int(s.perfect)})


# --- yarışma

@rpc("any_peer", "call_remote", "reliable")
func req_contest(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _contests.has(id):
		return
	if not (Map.ACADEMY.rect as Rect2).grow(80).has_point(_pos(id)):
		return
	var me: String = Net.players[id].name
	_roll_period()
	if _store().scores.has(me):
		Net.notify(id, "Bu dönem zaten yarıştın; %d dk sonra yeni dönem." % int((CONTEST_PERIOD - fmod(Time.get_unix_time_from_system(), CONTEST_PERIOD)) / 60.0), false)
		return
	var keys: Array = CONTEST_DISHES.keys()
	keys.shuffle()
	var now := _now()
	var orders := {}
	for k in 3:
		orders[k + 1] = {"dish": keys[k], "t": now, "dl": now + CONTEST_DISH_TIME * (k + 1)}
	_contests[id] = {"t0": now, "orders": orders, "q": []}
	Net.tell(self, id, "on_contest", {"orders": _contest_list(id), "done": 0})


func _contest_list(id: int) -> Array:
	var list: Array = []
	var now := _now()
	for oid in _contests[id].orders:
		var o: Dictionary = _contests[id].orders[oid]
		list.append({"id": oid, "dish": o.dish, "left": snappedf(float(o.dl) - now, 0.1), "total": CONTEST_DISH_TIME})
	return list


@rpc("any_peer", "call_remote", "reliable")
func req_contest_dish(d: Dictionary) -> void:
	var id := Net.sender()
	if not _contests.has(id):
		return
	var c: Dictionary = _contests[id]
	var oid := int(d.get("oid", -1))
	if not c.orders.has(oid):
		return
	var o: Dictionary = c.orders[oid]
	if _now() > float(o.dl) + 1.0:
		return
	c.orders.erase(oid)
	c.q.append(clampf(float(d.get("q", 0.0)), 0.0, 1.0))
	Net.tell(self, id, "on_contest", {"orders": _contest_list(id), "done": c.q.size()})


@rpc("any_peer", "call_remote", "reliable")
func req_contest_end(d: Dictionary) -> void:
	var id := Net.sender()
	if not _contests.has(id):
		return
	var c: Dictionary = _contests[id]
	_contests.erase(id)
	var qs: Array = c.q
	while qs.size() < 3:
		qs.append(0.0)                 # bitirilemeyen yemek
	var tech := 0.0
	for q in qs:
		tech += float(q)
	tech = tech / 3.0 * 10.0
	var taste := 4.0
	var sig := str(d.get("sig", ""))
	var sig_name := ""
	var rec := _rec(id)
	var items: Dictionary = Rpg.ensure(rec).items
	if sig != "" and Kitchen.RECIPES.has(sig) and int(items.get(sig, 0)) > 0:
		items[sig] = int(items[sig]) - 1
		if int(items[sig]) <= 0:
			items.erase(sig)
		Rpg.send_sheet(id)
		var r: Dictionary = Kitchen.RECIPES[sig]
		taste = minf(10.0, 5.0 + float(r.energy) / 25.0 + float(r.needs.size()) * 0.4)
		sig_name = str(r.name)
	var judges: Array = []
	var total := 0.0
	for j in 3:
		var pres := randf_range(5.5, 8.5) + (1.0 if tech > 8.0 else 0.0)
		var v := clampf(tech * 0.5 + taste * 0.3 + pres * 0.2 + randf_range(-0.8, 0.8), 0.0, 10.0)
		judges.append(snappedf(v, 0.1))
		total += snappedf(v, 0.1)
	total = snappedf(total, 0.1)
	_roll_period()
	var me: String = Net.players[id].name
	_store().scores[me] = total
	var ch := _data(rec)
	ch["best"] = maxf(float(ch.get("best", 0.0)), total)
	Ach.event(id, "chef_contests")
	Rpg.add_xp(id, "", 60)
	Net.mark_dirty()
	Net.tell(self, id, "on_contest", {"result": {"judges": judges, "total": total, "tech": snappedf(tech, 0.1), "taste": snappedf(taste, 0.1), "sig": sig_name}})
	_send_board(id)


## Dönem değiştiyse ödülleri dağıt ve yeni döneme geç.
func _roll_period() -> void:
	var st := _store()
	var cur := period_of(Time.get_unix_time_from_system())
	if int(st.period) == cur:
		return
	var list: Array = []
	for k in st.scores:
		list.append([k, float(st.scores[k])])
	list.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	for i in mini(list.size(), CONTEST_PRIZES.size()):
		var who: String = list[i][0]
		var pid := Net.id_by_name(who)
		if pid != 0:
			Net.add_money(pid, CONTEST_PRIZES[i])
			Net.notify(pid, "Aşçılık yarışmasında %d. oldun! Ödül %s" % [i + 1, U.money(CONTEST_PRIZES[i])])
			if i == 0:
				Ach.event(pid, "chef_champion")
		else:
			Net.add_money_by_name(who, CONTEST_PRIZES[i])
	if not list.is_empty():
		Net.announce("Aşçılık yarışmasının şampiyonu: %s (%.1f puan)!" % [list[0][0], float(list[0][1])])
	st["last"] = list.slice(0, 3)
	st["scores"] = {}
	st["period"] = cur
	Net.mark_dirty()


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := _now()
	for id in _shifts.keys():
		if not Net.players.has(id):
			_shifts.erase(id)
			continue
		var s: Dictionary = _shifts[id]
		var dirty := false
		for oid in s.orders.keys():
			if now > float(s.orders[oid].dl):
				s.orders.erase(oid)
				s["missed"] = int(s.missed) + 1
				var b: Dictionary = Land.plots[int(s.plot)].get("biz", {})
				if not b.is_empty():
					b["rating"] = clampf(float(b.get("rating", 3.0)) - 0.05, 1.0, 5.0)
				Net.tell(self, id, "on_order", {"id": oid, "missed": true})
				dirty = true
		if now - float(s.t0) >= SHIFT_TIME:
			_end_shift(id)
			continue
		if now >= float(s.spawn) and s.orders.size() < MAX_ORDERS and now - float(s.t0) < SHIFT_TIME - 12.0:
			_spawn_order(id)
			dirty = true
		if dirty:
			Net.tell(self, id, "on_shift", _shift_view(id))
	for id in _contests.keys():
		if not Net.players.has(id) or now - float(_contests[id].t0) > CONTEST_DISH_TIME * 3 + 30.0:
			_contests.erase(id)
	_acc += delta
	if _acc > 30.0:
		_acc = 0.0
		_roll_period()
