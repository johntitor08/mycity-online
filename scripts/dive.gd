extends Node
## Dalgıçlık: teknedeyken denize dal (V). Deniz tabanı harita dışında ayrı bir alandır; oksijen bitince
## (ya da V ile) yüzeye, teknene dönersin. İstiridyelerden inci, batık gemiden hazine sandığı toplanır;
## bunlar kovaya girer ve balık gibi satılır. Galeri'deki dalış tüpü oksijeni artırır.

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const BASE_OXY := 25.0
const GEAR_OXY := 60.0
const GEAR_PRICE := 2500
const MAX_OYSTERS := 16
const OYSTER_EVERY := 8.0
const WRECK_EVERY := 600.0
const PICK_RANGE := 60.0

# --- istemci
var state := ""                    # "" ya da "down"
var oxy_until := 0.0               # yerel saat
var items: Array = []              # [{id, x, y, k}]
var has_gear := false

# --- sunucu
var _divers := {}                  # id -> {until, surface}
var _items: Array = []
var _uid := 1
var _acc := 0.0
var _wreck_at := 0.0


func reset() -> void:
	state = ""
	items = []
	_divers.clear()
	_items.clear()


func on_player_left(id: int) -> void:
	_divers.erase(id)


func oxygen_left() -> float:
	return maxf(0.0, oxy_until - Time.get_ticks_msec() / 1000.0)


func is_diving(id: int) -> bool:
	return _divers.has(id)


# ------------------------------------------------------------------ istemci API

func dive() -> void:
	Net.ask(self, "req_dive")


func surface() -> void:
	Net.ask(self, "req_surface")


func pick(item_id: int) -> void:
	Net.ask(self, "req_pick", {"id": item_id})


func buy_gear() -> void:
	Net.ask(self, "req_gear")


@rpc("authority", "call_local", "reliable")
func on_dive(d: Dictionary) -> void:
	state = str(d.get("state", ""))
	if d.has("left"):
		oxy_until = Time.get_ticks_msec() / 1000.0 + float(d.left)
	if d.has("gear"):
		has_gear = bool(d.gear)
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_items(d: Dictionary) -> void:
	items = d.get("items", [])
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func send_state(id: int) -> void:
	Net.tell(self, id, "on_dive", {"state": "down" if _divers.has(id) else "", "gear": bool(_rec(id).get("dive_gear", false))})
	Net.tell(self, id, "on_items", {"items": _items})


@rpc("any_peer", "call_remote", "reliable")
func req_gear(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or bool(rec.get("dive_gear", false)):
		return
	if not Map.at_building("galeri", Net.positions.get(id, Vector2(-9999, -9999)), 60):
		Net.notify(id, "Dalış tüpü Galeri'de satılır.", false)
		return
	if not Net.try_spend(id, GEAR_PRICE):
		Net.notify(id, "Dalış tüpü %s." % U.money(GEAR_PRICE), false)
		return
	rec["dive_gear"] = true
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Dalış tüpü alındı! Artık su altında %d saniye kalabilirsin." % int(GEAR_OXY))


@rpc("any_peer", "call_remote", "reliable")
func req_dive(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _divers.has(id):
		return
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	if str(Net.players[id].get("ride", "")) != "boat" or not Map.in_sea(p):
		Net.notify(id, "Dalmak için teknedeyken denizde olmalısın.", false)
		return
	if Env.weather == "storm":
		Net.notify(id, "Fırtınada dalış yapılmaz!", false)
		return
	var oxy := GEAR_OXY if bool(_rec(id).get("dive_gear", false)) else BASE_OXY
	if School.has_by_id(id, "dalgic"):
		oxy += 20.0
	_divers[id] = {"until": Time.get_unix_time_from_system() + oxy, "surface": p}
	Garage.set_ride(id, "")
	Homes._teleport(id, Vector2(Map.SEA_BED.position.x + clampf(p.x, 60.0, Map.SEA_BED.size.x - 60.0), Map.SEA_BED.position.y + 160))
	Net.tell(self, id, "on_dive", {"state": "down", "left": oxy})
	Net.tell(self, id, "on_items", {"items": _items})
	Ach.event(id, "dive")


@rpc("any_peer", "call_remote", "reliable")
func req_surface(_d: Dictionary) -> void:
	_surface(Net.sender(), "")


func _surface(id: int, why: String) -> void:
	var dv: Dictionary = _divers.get(id, {})
	if dv.is_empty():
		return
	_divers.erase(id)
	if not Net.players.has(id):
		return
	Homes._teleport(id, dv.surface)
	Garage.set_ride(id, "boat")
	Net.tell(self, id, "on_dive", {"state": ""})
	if why != "":
		Net.notify(id, why, false)


@rpc("any_peer", "call_remote", "reliable")
func req_pick(d: Dictionary) -> void:
	var id := Net.sender()
	if not _divers.has(id):
		return
	var iid := int(d.get("id", -1))
	var me: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	for it in _items:
		if int(it.id) != iid or me.distance_to(Vector2(it.x, it.y)) > PICK_RANGE + 40.0:
			continue
		var bag: Array = _rec(id).get("fish", [])
		if bag.size() >= Jobs.BAG_SIZE:
			Net.notify(id, "Kovan dolu! Önce sat.", false)
			return
		var got := {}
		if it.k == "chest":
			got = {"name": "Batık Hazinesi", "price": randi_range(1500, 3500)}
			_wreck_at = Time.get_unix_time_from_system() + WRECK_EVERY
			Ach.event(id, "wreck")
			Pirates.maybe_piece(id, 0.35)
			Net.announce("%s batık gemide hazine buldu! (%s)" % [Net.players[id].name, U.money(int(got.price))])
		elif randf() < 0.06:
			got = {"name": "Siyah İnci", "price": randi_range(900, 1600)}
			Ach.event(id, "pearl")
		else:
			got = {"name": "İnci", "price": randi_range(120, 400)}
			Ach.event(id, "pearl")
		bag.append(got)
		_items.erase(it)
		Net.mark_dirty()
		Jobs.send_inventory(id)
		Rpg.add_xp(id, "fishing", 15)
		Net.notify(id, "%s buldun! (%s) — kovaya kondu" % [got.name, U.money(int(got.price))])
		_broadcast_items()
		return


func _broadcast_items() -> void:
	for id in _divers:
		Net.tell(self, id, "on_items", {"items": _items})


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_unix_time_from_system()
	for id in _divers.keys():
		if not Net.players.has(id):
			_divers.erase(id)
		elif now >= float(_divers[id].until):
			_surface(id, "Oksijen bitti! Yüzeye çıktın.")
	_acc += delta
	if _acc < OYSTER_EVERY:
		return
	_acc = 0.0
	var changed := false
	var oysters := 0
	var chest := false
	for it in _items:
		if it.k == "oyster":
			oysters += 1
		else:
			chest = true
	if oysters < MAX_OYSTERS:
		var bed: Rect2 = Map.SEA_BED
		_items.append({"id": _uid, "x": randf_range(bed.position.x + 60, bed.end.x - 60), "y": randf_range(bed.end.y - 150, bed.end.y - 40), "k": "oyster"})
		_uid += 1
		changed = true
	if not chest and now >= _wreck_at:
		_items.append({"id": _uid, "x": Map.WRECK.x + 60, "y": Map.WRECK.y + 40, "k": "chest"})
		_uid += 1
		changed = true
	if changed:
		_broadcast_items()
