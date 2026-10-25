extends Node
## Mevsimlik eğlenceler.
##  Kış: kardan adam yap (E, çimenlik bir yerde), T ile kartopu at (isabet edene puan; Kartopu Savaşı etkinliği).
##  Yaz: plajda dondurmacı (enerji verir).
## Kardan adamlar mevsim bitince erir. Kartopları istemcilerde düz çizgide uçar; isabeti sunucu hesaplar.

signal snowmen_changed
signal snowball(d: Dictionary)
signal hit(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const MAX_SNOWMEN := 40
const SNOWMEN_PER_PLAYER := 3
const SNOWMAN_ENERGY := 5
const SNOWBALL_SPEED := 620.0
const SNOWBALL_RANGE := 520.0
const SNOWBALL_COOLDOWN := 0.7
const HIT_RADIUS := 24.0
const ICECREAM_POS := Vector2(1300, 1705)
const ICECREAM_PRICE := 35
const ICECREAM_ENERGY := 12
const FLAVORS := ["çilekli", "çikolatalı", "fıstıklı", "limonlu", "kaymaklı", "karamelli"]

var snowmen: Array = []            # herkes: [{x, y, by, style}] (JSON'a uygun)
var _flying: Array = []            # sunucu: [{from, pos, dir, left, by}]
var _last_throw := {}              # sunucu: id -> zaman


func reset() -> void:
	snowmen = []
	_flying.clear()


static func can_build_at(p: Vector2) -> bool:
	if not Map.WORLD.has_point(p) or Map.in_water(p) or Map.in_sea(p) or Map.BEACH.has_point(p):
		return false
	for r in Map.ROADS:
		if r.grow(10).has_point(p):
			return false
	for b in Map.BUILDINGS:
		if b.rect.grow(20).has_point(p):
			return false
	return true


func icecream_open() -> bool:
	return Env.season == "summer"


# ------------------------------------------------------------------ istemci API

func build_snowman(at: Vector2) -> void:
	Net.ask(self, "req_snowman", {"pos": at})


func throw(dir: Vector2) -> void:
	Net.ask(self, "req_throw", {"dir": dir})


func buy_icecream() -> void:
	Net.ask(self, "req_icecream")


@rpc("authority", "call_local", "reliable")
func on_snowmen(d: Dictionary) -> void:
	snowmen = d.get("list", [])
	snowmen_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_snowball(d: Dictionary) -> void:
	snowball.emit(d)


@rpc("authority", "call_local", "reliable")
func on_hit(d: Dictionary) -> void:
	hit.emit(d)


# ------------------------------------------------------------------ sunucu

func _store() -> Array:
	if not Net.save_data.get("snowmen") is Array:
		Net.save_data["snowmen"] = []
	return Net.save_data["snowmen"]


func send_state(id: int) -> void:
	Net.tell(self, id, "on_snowmen", {"list": _store()})


func _broadcast() -> void:
	Net.tell_all(self, "on_snowmen", {"list": _store()})


## Mevsim değişince kardan adamlar erir.
func on_season(s: String) -> void:
	if s != "winter" and not _store().is_empty():
		_store().clear()
		Net.mark_dirty()
		_broadcast()
		Net.announce("Kardan adamlar eridi... Gelecek kışa kadar hoşça kalın!")


@rpc("any_peer", "call_remote", "reliable")
func req_snowman(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if Env.season != "winter":
		Net.notify(id, "Kardan adam sadece kışın yapılır.", false)
		return
	var me: String = Net.players[id].name
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	var at = d.get("pos")
	if at is Vector2 and at.distance_to(p) < 120.0:
		p = at
	if not can_build_at(p):
		Net.notify(id, "Burada kardan adam yapılamaz (yol, bina ya da su).", false)
		return
	var mine := 0
	for s in _store():
		if s.by == me:
			mine += 1
		if Vector2(float(s.x), float(s.y)).distance_to(p) < 50.0:
			Net.notify(id, "Burada zaten bir kardan adam var.", false)
			return
	if mine >= SNOWMEN_PER_PLAYER:
		Net.notify(id, "En fazla %d kardan adam yapabilirsin." % SNOWMEN_PER_PLAYER, false)
		return
	if _store().size() >= MAX_SNOWMEN:
		_store().pop_front()       # en eskisi erir
	if not Rpg.use_energy(id, SNOWMAN_ENERGY):
		return
	_store().append({"x": p.x, "y": p.y, "by": me, "style": randi() % 3})
	Net.mark_dirty()
	_broadcast()
	Ach.event(id, "snowman")
	Rpg.add_xp(id, "", 15)
	Net.notify(id, "Kardan adam yaptın! Burnu havuçtan.")


@rpc("any_peer", "call_remote", "reliable")
func req_throw(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Env.season != "winter":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_throw.get(id, -10.0)) < SNOWBALL_COOLDOWN:
		return
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	if not Map.WORLD.has_point(p) or Map.in_sea(p) or Police.is_jailed(id):
		return
	var dir: Vector2 = d.get("dir", Vector2.RIGHT)
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	_last_throw[id] = now
	var from := p + Vector2(0, -28)
	_flying.append({"pos": from, "dir": dir, "left": SNOWBALL_RANGE, "by": id})
	Net.tell_all(self, "on_snowball", {"from": from, "dir": dir, "by": Net.players[id].name})


func _process(delta: float) -> void:
	if _flying.is_empty() or not Net.is_server():
		return
	var done: Array = []
	for b in _flying:
		var step: float = SNOWBALL_SPEED * delta
		b.pos += b.dir * step
		b.left -= step
		if b.left <= 0.0:
			done.append(b)
			continue
		for id in Net.players:
			if id == b.by:
				continue
			var tp: Vector2 = Net.positions.get(id, Vector2(-9999, -9999)) + Vector2(0, -24)
			if tp.distance_to(b.pos) < HIT_RADIUS:
				done.append(b)
				_on_hit(int(b.by), id, b.pos)
				break
	for b in done:
		_flying.erase(b)


func _on_hit(by: int, victim: int, at: Vector2) -> void:
	if not Net.players.has(by) or not Net.players.has(victim):
		return
	var bn: String = Net.players[by].name
	var vn: String = Net.players[victim].name
	Net.tell_all(self, "on_hit", {"pos": at, "by": bn, "victim": vn})
	Net.notify(victim, "%s seni kartopuyla vurdu!" % bn, false)
	Ach.event(by, "snowball_hit")
	Events.add_score(by, "snow", 1, "%d isabet")
	Rpg.add_xp(by, "", 3)


@rpc("any_peer", "call_remote", "reliable")
func req_icecream(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if not icecream_open():
		Net.notify(id, "Dondurmacı sadece yazın açık.", false)
		return
	if Net.positions.get(id, Vector2(-9999, -9999)).distance_to(ICECREAM_POS) > 140.0:
		return
	if not Net.try_spend(id, ICECREAM_PRICE):
		Net.notify(id, "Dondurma %s." % U.money(ICECREAM_PRICE), false)
		return
	var r := Rpg._rec(id)
	var lvl := Rpg.level_of(int(r.xp))
	Rpg._update_energy(r, lvl)
	r["energy"] = minf(float(Rpg.max_energy(lvl)), float(r.energy) + ICECREAM_ENERGY)
	Rpg.send_sheet(id)
	Ach.event(id, "icecream")
	Bank.activity("MRKT", 1)
	Net.notify(id, "Mmm, %s dondurma! +%d enerji" % [FLAVORS.pick_random(), ICECREAM_ENERGY])
