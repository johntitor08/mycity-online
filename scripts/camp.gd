extends Node
## Kamp ve orman (1.3, dağın eteği).
##  Orman: mantar, böğürtlen, yaban mersini, çam kozalağı ve kuru dal (odun) toplanır (E). Ürünler ambara girer;
##   Dağ Evi'nde satılır, mutfakta orman tariflerinde kullanılır, müzenin Orman koleksiyonuna bağışlanır.
##  Kamp ateşi: 2 odunla yak (5 dk yanar). Yanındayken enerji daha hızlı dolar; marshmallow kızart (3 sn).
##  Çadır: Dağ Evi'nden al, kamp alanına kur; çadırında dinlenince enerji dolar (15 dk'da bir).
##  Gece gökyüzü: teleskoptan takımyıldızları izle; kayan yıldız geçerken dilek tut (ödül).
## Veri: save_data["camp"] = {tents: {ad: {x, y, c}}}, rec["tent"], rec["tent_rest"]

signal changed
signal shooting_star(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const FORAGE := {
	"mantar": {"name": "Çayır Mantarı", "price": 15},
	"kuzugobegi": {"name": "Kuzugöbeği Mantarı", "price": 90},
	"sinekmantari": {"name": "Sinek Mantarı (zehirli)", "price": 5},
	"bogurtlen": {"name": "Böğürtlen", "price": 12},
	"yabanmersini": {"name": "Yaban Mersini", "price": 20},
	"kozalak": {"name": "Çam Kozalağı", "price": 4},
	"odun": {"name": "Odun", "price": 3},
}
# yerdeki şey: ağırlık, verdiği ürün, adet
const SPOTS := {
	"mantar": [30, "mantar", 2], "kuzugobegi": [6, "kuzugobegi", 1], "sinekmantari": [8, "sinekmantari", 1],
	"bogurtlen": [20, "bogurtlen", 3], "yabanmersini": [14, "yabanmersini", 3], "kozalak": [10, "kozalak", 2], "dal": [28, "odun", 2],
}
const MAX_SPOTS := 26
const SPOT_EVERY := 7.0
const PICK_RANGE := 70.0
const FIRE_WOOD := 2
const FIRE_TIME := 300.0
const FIRE_RANGE := 150.0
const ROAST_TIME := 3.0
const TENT_PRICE := 1200
const MARSHMALLOW_PRICE := 8
const CAMP_FOODS := {
	"marshmallow": {"name": "Marshmallow (çiğ)", "price": 8, "energy": 2},
	"kizarmis_marshmallow": {"name": "Kızarmış Marshmallow", "price": 0, "energy": 18},
	"yanik_marshmallow": {"name": "Yanık Marshmallow", "price": 0, "energy": 4},
}
const REST_COOLDOWN := 900.0
const STAR_REWARD := 300
const STAR_WINDOW := 5.0

# --- istemci
var spots: Array = []              # [{id, x, y, k}]
var fires: Array = []              # [kalan sn] (CAMPFIRES sırasıyla)
var tents: Dictionary = {}         # ad -> {x, y, c}
var has_tent := false
var _fires_at := 0.0
var star := {}                     # {t0 (yerel), a, b}

# --- sunucu
var _spots: Array = []
var _uid := 1
var _acc := 0.0
var _fire_until: Array = [0.0, 0.0, 0.0]
var _roast := {}                   # id -> bitiş zamanı
var _warm_acc := 0.0
var _star_next := 0.0
var _star_until := 0.0
var _wished := {}


func reset() -> void:
	spots = []
	fires = []
	tents = {}
	star = {}
	_spots.clear()
	_fire_until = [0.0, 0.0, 0.0]
	_roast.clear()


func on_player_left(id: int) -> void:
	_roast.erase(id)


static func item_info(k: String) -> Dictionary:
	return FORAGE.get(k, {})


func fire_left(i: int) -> float:
	if i >= fires.size():
		return 0.0
	return maxf(0.0, float(fires[i]) - (Time.get_ticks_msec() / 1000.0 - _fires_at))


# ------------------------------------------------------------------ istemci API

func pick(spot_id: int) -> void:
	Net.ask(self, "req_pick", {"id": spot_id})


func light(i: int) -> void:
	Net.ask(self, "req_light", {"i": i})


func roast(i: int) -> void:
	Net.ask(self, "req_roast", {"i": i})


func pitch() -> void:
	Net.ask(self, "req_pitch")


func rest() -> void:
	Net.ask(self, "req_rest")


func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func sell_all() -> void:
	Net.ask(self, "req_sell")


func wish() -> void:
	Net.ask(self, "req_wish")


func stargaze() -> void:
	Net.ask(self, "req_gaze")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	if d.has("spots"):
		spots = d.spots
	if d.has("fires"):
		fires = d.fires
		_fires_at = Time.get_ticks_msec() / 1000.0
	if d.has("tents"):
		tents = d.tents
	if d.has("tent"):
		has_tent = bool(d.tent)
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_star(d: Dictionary) -> void:
	star = {"t0": Time.get_ticks_msec() / 1000.0, "a": float(d.a), "b": float(d.b)}
	shooting_star.emit(star)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data() -> Dictionary:
	if not Net.save_data.get("camp") is Dictionary:
		Net.save_data["camp"] = {}
	if not Net.save_data.camp.get("tents") is Dictionary:
		Net.save_data.camp["tents"] = {}
	return Net.save_data.camp


func _fires_view() -> Array:
	var now := Time.get_unix_time_from_system()
	return _fire_until.map(func(t): return maxf(0.0, float(t) - now))


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	Net.tell(self, id, "on_state", {"spots": _spots, "fires": _fires_view(), "tents": _data().tents, "tent": bool(rec.get("tent", false))})


func _broadcast(what: Dictionary) -> void:
	for id in Net.players:
		if Map.MOUNTAIN.has_point(_pos(id)):
			Net.tell(self, id, "on_state", what)


## Ormanda boş bir nokta (maden ocağı, pist, binalar, kamp dışı; karlı zirve altı).
func _free_spot() -> Variant:
	var m: Rect2 = Map.MOUNTAIN
	for _try in 30:
		var p := Vector2(randf_range(m.position.x + 60, m.end.x - 60), randf_range(Map.SNOW_LINE + 80.0, m.end.y - 60))
		var bad := Map.QUARRY.grow(40).has_point(p) or Map.SLOPE.grow(60).has_point(p) or Map.CAMP.grow(20).has_point(p) \
			or absf(p.x - Map.LIFT.x) < 60.0 or p.distance_to(Map.LIFT) < 200.0 or p.distance_to(Map.MOUNTAIN_SPAWN) < 160.0
		for b in Map.MOUNTAIN_BUILDINGS:
			if b.rect.grow(150).has_point(p):
				bad = true
		for s in _spots:
			if Vector2(float(s.x), float(s.y)).distance_to(p) < 70.0:
				bad = true
		if not bad:
			return p
	return null


func _spawn_spot() -> void:
	var p = _free_spot()
	if p == null:
		return
	var total := 0
	for k in SPOTS:
		total += int(SPOTS[k][0])
	var roll := randi() % total
	var kind := "mantar"
	for k in SPOTS:
		roll -= int(SPOTS[k][0])
		if roll < 0:
			kind = k
			break
	_spots.append({"id": _uid, "x": snappedf(p.x, 1.0), "y": snappedf(p.y, 1.0), "k": kind})
	_uid += 1


@rpc("any_peer", "call_remote", "reliable")
func req_pick(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var sid := int(d.get("id", -1))
	for s in _spots:
		if int(s.id) != sid:
			continue
		if Vector2(float(s.x), float(s.y)).distance_to(_pos(id)) > PICK_RANGE + 40.0:
			return
		_spots.erase(s)
		var info: Array = SPOTS[str(s.k)]
		var item: String = info[1]
		var n := int(info[2])
		var store := Farm.barn(rec)
		store[item] = int(store.get(item, 0)) + n
		Ach.event(id, "forage", n)
		Rpg.add_xp(id, "", 4)
		Net.mark_dirty()
		Farm.send_state(id)
		_broadcast({"spots": _spots})
		Net.notify(id, "+%d %s%s" % [n, FORAGE[item].name, "  (yenmez! müzeye ya da Dağ Evi'ne)" if item == "sinekmantari" else ""])
		return


@rpc("any_peer", "call_remote", "reliable")
func req_light(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	if rec.is_empty() or i < 0 or i >= Map.CAMPFIRES.size() or _pos(id).distance_to(Map.CAMPFIRES[i]) > 110.0:
		return
	if Env.weather in ["rain", "storm"]:
		Net.notify(id, "Yağmurda ateş tutuşmuyor.", false)
		return
	var store := Farm.barn(rec)
	if int(store.get("odun", 0)) < FIRE_WOOD:
		Net.notify(id, "Ateş için %d odun lazım (ormandaki kuru dallardan topla ya da Dağ Evi'nden al)." % FIRE_WOOD, false)
		return
	store["odun"] = int(store.odun) - FIRE_WOOD
	if int(store.odun) <= 0:
		store.erase("odun")
	var now := Time.get_unix_time_from_system()
	_fire_until[i] = maxf(float(_fire_until[i]), now) + FIRE_TIME
	Ach.event(id, "campfire")
	Net.mark_dirty()
	Farm.send_state(id)
	_broadcast({"fires": _fires_view()})
	Net.notify(id, "Kamp ateşi yandı! Yanında enerjin daha hızlı dolar; marshmallow kızartabilirsin.")


func _fire_lit(i: int) -> bool:
	return float(_fire_until[i]) > Time.get_unix_time_from_system()


@rpc("any_peer", "call_remote", "reliable")
func req_roast(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var i := int(d.get("i", -1))
	if rec.is_empty() or i < 0 or i >= Map.CAMPFIRES.size() or _roast.has(id):
		return
	if not _fire_lit(i) or _pos(id).distance_to(Map.CAMPFIRES[i]) > FIRE_RANGE:
		Net.notify(id, "Marshmallow için yanan bir ateşin başında ol.", false)
		return
	var items: Dictionary = Rpg.ensure(rec).items
	if int(items.get("marshmallow", 0)) <= 0:
		Net.notify(id, "Marshmallow'un yok (Dağ Evi'nde %s)." % U.money(MARSHMALLOW_PRICE), false)
		return
	items["marshmallow"] = int(items.marshmallow) - 1
	if int(items.marshmallow) <= 0:
		items.erase("marshmallow")
	_roast[id] = Time.get_ticks_msec() / 1000.0 + ROAST_TIME
	Net.players[id]["roast"] = true
	Net._broadcast_roster()
	Rpg.send_sheet(id)


func _finish_roast(id: int) -> void:
	_roast.erase(id)
	if not Net.players.has(id):
		return
	Net.players[id].erase("roast")
	Net._broadcast_roster()
	var rec := _rec(id)
	var items: Dictionary = Rpg.ensure(rec).items
	var good := randf() < 0.8
	var k := "kizarmis_marshmallow" if good else "yanik_marshmallow"
	items[k] = int(items.get(k, 0)) + 1
	if good:
		Ach.event(id, "marshmallow")
	Net.mark_dirty()
	Rpg.send_sheet(id)
	Net.notify(id, "Mmm, altın sarısı marshmallow! (çantada)" if good else "Eyvah, marshmallow yandı... (yine de yenir)", good)


@rpc("any_peer", "call_remote", "reliable")
func req_pitch(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	if not bool(rec.get("tent", false)):
		Net.notify(id, "Önce Dağ Evi'nden çadır al (%s)." % U.money(TENT_PRICE), false)
		return
	var p := _pos(id)
	if not Map.CAMP.grow(-20).has_point(p):
		Net.notify(id, "Çadırı kamp alanına kur.", false)
		return
	for f in Map.CAMPFIRES:
		if p.distance_to(f) < 80.0:
			Net.notify(id, "Ateşe çok yakın!", false)
			return
	var me: String = Net.players[id].name
	var t: Dictionary = _data().tents
	for n in t:
		if n != me and Vector2(float(t[n].x), float(t[n].y)).distance_to(p) < 90.0:
			Net.notify(id, "Burada başka bir çadır var.", false)
			return
	t[me] = {"x": snappedf(p.x, 1.0), "y": snappedf(p.y, 1.0), "c": absi(hash(me)) % 5}
	Ach.event(id, "tent")
	Net.mark_dirty()
	_broadcast({"tents": t})
	Net.notify(id, "Çadırın kuruldu! Yanına gelip E ile dinlenebilirsin.")


@rpc("any_peer", "call_remote", "reliable")
func req_rest(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var t: Dictionary = _data().tents.get(Net.players[id].name, {})
	if t.is_empty() or Vector2(float(t.x), float(t.y)).distance_to(_pos(id)) > 90.0:
		return
	var now := Time.get_unix_time_from_system()
	if now - float(rec.get("tent_rest", 0.0)) < REST_COOLDOWN:
		Net.notify(id, "Henüz uykun yok (%d dk sonra)." % int(ceil((REST_COOLDOWN - (now - float(rec.tent_rest))) / 60.0)), false)
		return
	rec["tent_rest"] = now
	var r := Rpg.ensure(rec)
	var lvl := Rpg.level_of(int(r.xp))
	r["energy"] = float(Rpg.max_energy(lvl))
	Net.mark_dirty()
	Rpg.send_sheet(id)
	Net.notify(id, "Çadırında güzel bir uyku çektin. Enerjin doldu!")


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not Map.MOUNTAIN_BUILDINGS[0].rect.grow(60).has_point(_pos(id)):
		return
	match str(d.get("item", "")):
		"tent":
			if bool(rec.get("tent", false)):
				return
			if not Net.try_spend(id, TENT_PRICE):
				Net.notify(id, "Çadır %s." % U.money(TENT_PRICE), false)
				return
			rec["tent"] = true
			Net.notify(id, "Çadır alındı! Kamp alanına (köyün kuzeybatısı) git ve kur.")
		"marshmallow":
			var items: Dictionary = Rpg.ensure(rec).items
			if int(items.get("marshmallow", 0)) >= Rpg.MAX_FOOD_STACK:
				return
			if not Net.try_spend(id, MARSHMALLOW_PRICE):
				return
			items["marshmallow"] = int(items.get("marshmallow", 0)) + 1
			Rpg.send_sheet(id)
		"odun":
			if not Net.try_spend(id, 10):
				return
			var store := Farm.barn(rec)
			store["odun"] = int(store.get("odun", 0)) + 2
			Farm.send_state(id)
		_:
			return
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_sell(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not Map.MOUNTAIN_BUILDINGS[0].rect.grow(60).has_point(_pos(id)):
		return
	var store := Farm.barn(rec)
	var total := 0
	var n := 0
	for k in store.keys():
		if FORAGE.has(k) and k != "odun":
			total += int(FORAGE[k].price) * int(store[k])
			n += int(store[k])
			store.erase(k)
	if n == 0:
		Net.notify(id, "Satacak orman ürünü yok.", false)
		return
	total = Election.take_tax(total)
	Net.add_money(id, total)
	Net.mark_dirty()
	Farm.send_state(id)
	Net.notify(id, "%d orman ürünü sattın: +%s" % [n, U.money(total)])


@rpc("any_peer", "call_remote", "reliable")
func req_gaze(_d: Dictionary) -> void:
	var id := Net.sender()
	if _pos(id).distance_to(Map.TELESCOPE) > 110.0 or Env.darkness() < 0.45:
		return
	var rec := _rec(id)
	var today := Time.get_date_string_from_system()
	if str(rec.get("gaze_day", "")) != today:
		rec["gaze_day"] = today
		Rpg.add_xp(id, "", 40)
		Ach.event(id, "astronom")
		Net.mark_dirty()


@rpc("any_peer", "call_remote", "reliable")
func req_wish(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Time.get_ticks_msec() / 1000.0 > _star_until or _wished.has(id):
		return
	if not Map.CAMP.grow(260).has_point(_pos(id)):
		return
	_wished[id] = true
	Net.add_money(id, STAR_REWARD)
	Rpg.add_xp(id, "", 30)
	Ach.event(id, "wish_star")
	Net.notify(id, "Kayan yıldıza dilek tuttun! +%s" % U.money(STAR_REWARD))


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _roast.keys():
		if now >= float(_roast[id]):
			_finish_roast(id)
	# kayan yıldız (gece, dağda biri varsa)
	if Env.darkness() > 0.55 and now > _star_next:
		_star_next = now + randf_range(70.0, 150.0)
		var anyone := false
		for id in Net.players:
			if Map.MOUNTAIN.has_point(_pos(id)):
				anyone = true
		if anyone:
			_star_until = now + STAR_WINDOW
			_wished.clear()
			var d := {"a": randf_range(0.1, 0.6), "b": randf_range(0.05, 0.3)}
			for id in Net.players:
				if Map.MOUNTAIN.has_point(_pos(id)):
					Net.tell(self, id, "on_star", d)
	# ateş başında enerji (5 sn'de bir +1)
	_warm_acc += delta
	if _warm_acc >= 5.0:
		_warm_acc = 0.0
		for i in Map.CAMPFIRES.size():
			if not _fire_lit(i):
				continue
			for id in Net.players:
				if _pos(id).distance_to(Map.CAMPFIRES[i]) < FIRE_RANGE:
					var r := Rpg._rec(id)
					var lvl := Rpg.level_of(int(r.xp))
					Rpg._update_energy(r, lvl)
					r["energy"] = minf(float(Rpg.max_energy(lvl)), float(r.energy) + 1.0)
					Rpg.send_sheet(id)
	_acc += delta
	if _acc < SPOT_EVERY:
		return
	_acc = 0.0
	if _spots.size() < MAX_SPOTS:
		_spawn_spot()
		if _spots.size() < 12:
			_spawn_spot()
		_broadcast({"spots": _spots})
	# sönen ateşler için herkese haber (yaklaşık)
	_broadcast({"fires": _fires_view()})
