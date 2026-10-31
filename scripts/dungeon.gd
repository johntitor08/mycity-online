extends Node
## Mağara zindanı (1.8): dağın kuzeybatısındaki mağaradan girilir. Katlar harita dışında (Map.DUNGEON),
## aynı anda 4 sefer (her biri kendi "yuvası"nda). Sefere en fazla 4 kişi; başlatan ya da sonradan katılan.
##  Her kat: rastgele sütunlu bir mağara, kata göre çoğalan ve güçlenen canavarlar; 5. ve 10. katta boss.
##  Kat temizlenince ortada hazine sandığı (herkes bir kez açar) ve sağda aşağı inen merdiven belirir.
##  Başlangıçtaki ışıklı kapıdan istediğin an çıkarsın; bayılırsan köylüler seni mağaranın önüne taşır.
## Veri: rec["combat"].best_floor ; save_data["dungeon_best"] = {floor, by}

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const SLOTS := 4
const MAX_MEMBERS := 4
const DOOR_R := 130.0
const LOOT_ITEMS := [["Ametist", 300, 600], ["Yakut", 500, 900], ["Zümrüt Kristali", 600, 1100]]
const BOSS_ITEMS := {5: ["Golem Kalbi", 2500], 10: ["Ejder Pulu", 5000]}

# --- istemci
var lobby: Array = []               # [{slot, leader, floor, members}]
var run := {}                       # benim seferim: {slot, floor, state, pillars, start, stairs, chest, exit, opened}

# --- sunucu
var _runs := {}                     # slot -> {members: [ad], floor, state, pillars, start, stairs, chest, exit, opened: {}, seed}


func _ready() -> void:
	Combat.zone_resolvers.append(_zone_of)
	Combat.walkable["zindan"] = _walkable
	Combat.monster_died.connect(_on_monster_died)
	Combat.player_down.connect(_on_player_down)


func reset() -> void:
	lobby = []
	run = {}
	_runs.clear()


func on_player_left(id: int) -> void:
	if Net.players.has(id):
		_remove_member(Net.players[id].name)


static func slot_rect(slot: int) -> Rect2:
	return Rect2(Map.DUNGEON.position + Vector2(0, slot * Map.DUNGEON_SLOT_H), Vector2(Map.DUNGEON.size.x, Map.DUNGEON_SLOT_H))


static func arena(slot: int) -> Rect2:
	return slot_rect(slot).grow(-70)


static func in_pillar(pillars: Array, p: Vector2, r: float = 16.0) -> bool:
	for q in pillars:
		if (q as Rect2).grow(r).has_point(p):
			return true
	return false


## Kat üretimi (sunucu ve istemci aynı tohumla aynı sütunları görür).
static func gen_floor(slot: int, seed_v: int, floor_n: int) -> Dictionary:
	var a := arena(slot)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + floor_n * 104729
	var start := Vector2(a.position.x + 120, a.get_center().y)
	var stairs := Vector2(a.end.x - 120, a.get_center().y + rng.randf_range(-250, 250))
	var chest := a.get_center() + Vector2(rng.randf_range(-120, 120), rng.randf_range(-120, 120))
	var pillars: Array = []
	var tries := 0
	while pillars.size() < 7 + mini(floor_n, 6) and tries < 200:
		tries += 1
		var sz := Vector2(rng.randf_range(50, 150), rng.randf_range(50, 130))
		var r := Rect2(Vector2(rng.randf_range(a.position.x + 240, a.end.x - 240 - sz.x), rng.randf_range(a.position.y + 40, a.end.y - 40 - sz.y)), sz)
		if r.grow(90).has_point(chest) or r.grow(110).has_point(stairs) or r.grow(140).has_point(start):
			continue
		var ok := true
		for q in pillars:
			if (q as Rect2).grow(70).intersects(r):
				ok = false
				break
		if ok:
			pillars.append(r)
	return {"pillars": pillars, "start": start, "stairs": stairs, "chest": chest, "exit": start + Vector2(-60, 0)}


func _zone_of(id: int) -> String:
	if not Net.players.has(id):
		return ""
	var me: String = Net.players[id].name
	for slot in _runs:
		if me in _runs[slot].members and slot_rect(slot).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
			return "zindan:%d" % slot
	return ""


func _walkable(zone: String, p: Vector2) -> bool:
	var slot := int(zone.get_slice(":", 1))
	if not _runs.has(slot):
		return false
	return arena(slot).has_point(p) and not in_pillar(_runs[slot].pillars, p)


## İstemci: bu noktada durulabilir mi (sütunlar ve duvarlar)?
func client_free(p: Vector2) -> bool:
	if run.is_empty():
		return true
	return arena(int(run.slot)).grow(-14).has_point(p) and not in_pillar(run.pillars, p)


# ------------------------------------------------------------------ istemci API

func start_run() -> void:
	Net.ask(self, "req_start")


func join(slot: int) -> void:
	Net.ask(self, "req_join", {"slot": slot})


func open_chest() -> void:
	Net.ask(self, "req_chest")


func descend() -> void:
	Net.ask(self, "req_descend")


func leave() -> void:
	Net.ask(self, "req_leave")


@rpc("authority", "call_local", "reliable")
func on_lobby(d: Dictionary) -> void:
	lobby = d.get("l", [])
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_run(d: Dictionary) -> void:
	run = d
	if not run.is_empty():
		var g := gen_floor(int(run.slot), int(run.seed), int(run.floor))
		run["pillars"] = g.pillars
		run["start"] = g.start
		run["stairs"] = g.stairs
		run["chest"] = g.chest
		run["exit"] = g.exit
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _near_door(id: int) -> bool:
	return _pos(id).distance_to(Map.DUNGEON_DOOR) < DOOR_R


func _lobby_view() -> Array:
	var out: Array = []
	for slot in _runs:
		var r: Dictionary = _runs[slot]
		out.append({"slot": slot, "leader": r.members[0] if not r.members.is_empty() else "", "floor": int(r.floor), "members": r.members})
	return out


func _broadcast_lobby() -> void:
	Net.tell_all(self, "on_lobby", {"l": _lobby_view()})


func send_state(id: int) -> void:
	Net.tell(self, id, "on_lobby", {"l": _lobby_view()})
	Combat.send_state(id)


func _send_run(slot: int) -> void:
	var r: Dictionary = _runs[slot]
	for who in r.members:
		var pid := Net.id_by_name(who)
		if pid != 0:
			Net.tell(self, pid, "on_run", {"slot": slot, "floor": int(r.floor), "state": r.state, "seed": int(r.seed),
				"opened": who in r.opened, "members": r.members})


func _setup_floor(slot: int) -> void:
	var r: Dictionary = _runs[slot]
	var g := gen_floor(slot, int(r.seed), int(r.floor))
	r["pillars"] = g.pillars
	r["state"] = "fight"
	r["opened"] = []
	var zone := "zindan:%d" % slot
	Combat.clear_zone(zone)
	var f := int(r.floor)
	var mult: float = (1.0 + 0.15 * (f - 1)) * (1.0 + 0.35 * (r.members.size() - 1))
	var pool: Array = ["slime", "bat"]
	if f >= 3:
		pool += ["spider", "spider"]
	if f >= 6:
		pool += ["skeleton", "skeleton", "bat"]
	var n := mini(4 + f * 2, 18)
	if f % 5 == 0:
		n = 2 + f / 5
		Combat.spawn(zone, "dragon" if f % 10 == 0 else "golem", g.stairs + Vector2(-260, 0), mult)
	var a := arena(slot)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.seed) + f * 31
	var placed := 0
	var guard := 0
	while placed < n and guard < 400:
		guard += 1
		var p := Vector2(rng.randf_range(a.position.x + 500, a.end.x - 60), rng.randf_range(a.position.y + 40, a.end.y - 40))
		if in_pillar(r.pillars, p, 30.0):
			continue
		Combat.spawn(zone, pool[rng.randi() % pool.size()], p, mult)
		placed += 1


func _teleport_members(slot: int) -> void:
	var r: Dictionary = _runs[slot]
	var g := gen_floor(slot, int(r.seed), int(r.floor))
	var k := 0
	for who in r.members:
		var pid := Net.id_by_name(who)
		if pid != 0:
			Garage.set_ride(pid, "")
			Homes._teleport(pid, g.start + Vector2(0, (k - 1.5) * 50.0))
			k += 1


@rpc("any_peer", "call_remote", "reliable")
func req_start(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not _near_door(id):
		return
	var me: String = Net.players[id].name
	_remove_member(me)
	var slot := -1
	for s in SLOTS:
		if not _runs.has(s):
			slot = s
			break
	if slot < 0:
		Net.notify(id, "Mağara şu an çok kalabalık; süren bir sefere katıl ya da biraz bekle.", false)
		return
	_runs[slot] = {"members": [me], "floor": 1, "state": "fight", "seed": randi() % 1000000, "opened": [], "pillars": []}
	_setup_floor(slot)
	_teleport_members(slot)
	Combat.heal_full(id)
	_send_run(slot)
	_broadcast_lobby()
	Ach.event(id, "dungeon")
	Net.notify(id, "Mağaraya girdin! Canavarları temizle; tıkla/dokun ya da Boşluk ile saldır.")


@rpc("any_peer", "call_remote", "reliable")
func req_join(d: Dictionary) -> void:
	var id := Net.sender()
	var slot := int(d.get("slot", -1))
	if not Net.players.has(id) or not _near_door(id) or not _runs.has(slot):
		return
	var r: Dictionary = _runs[slot]
	var me: String = Net.players[id].name
	if r.members.size() >= MAX_MEMBERS:
		Net.notify(id, "Bu seferde yer yok (en fazla %d kişi)." % MAX_MEMBERS, false)
		return
	_remove_member(me)
	r.members.append(me)
	Garage.set_ride(id, "")
	Homes._teleport(id, gen_floor(slot, int(r.seed), int(r.floor)).start)
	Combat.heal_full(id)
	_send_run(slot)
	_broadcast_lobby()
	for who in r.members:
		var pid := Net.id_by_name(who)
		if pid != 0 and pid != id:
			Net.notify(pid, "%s sefere katıldı!" % me)


func _remove_member(who: String) -> void:
	for slot in _runs.keys():
		var r: Dictionary = _runs[slot]
		if who in r.members:
			r.members.erase(who)
			if r.members.is_empty():
				Combat.clear_zone("zindan:%d" % slot)
				_runs.erase(slot)
			else:
				_send_run(slot)
			var pid := Net.id_by_name(who)
			if pid != 0:
				Net.tell(self, pid, "on_run", {})
			_broadcast_lobby()
			return


func _out(id: int) -> void:
	Homes._teleport(id, Map.DUNGEON_DOOR + Vector2(0, 70))
	_remove_member(Net.players[id].name)


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var z := _zone_of(id)
	if z == "":
		return
	var slot := int(z.get_slice(":", 1))
	var r: Dictionary = _runs[slot]
	if _pos(id).distance_to(gen_floor(slot, int(r.seed), int(r.floor)).exit) > 110.0 and r.state == "fight":
		Net.notify(id, "Çıkış kapısı katın başında (soldaki ışık).", false)
		return
	_out(id)
	Net.notify(id, "Mağaradan çıktın. %d. kata kadar indin." % int(r.floor))


func _on_player_down(id: int, zone: String) -> void:
	if not zone.begins_with("zindan"):
		return
	Net.notify(id, "Bayıldın! Köylüler seni mağaranın önüne taşıdı.", false)
	_out(id)


func _on_monster_died(zone: String, _m: Dictionary, _killer: String) -> void:
	if not zone.begins_with("zindan"):
		return
	var slot := int(zone.get_slice(":", 1))
	if not _runs.has(slot) or Combat.count_in(zone) > 0:
		return
	var r: Dictionary = _runs[slot]
	r["state"] = "clear"
	var f := int(r.floor)
	for who in r.members:
		var pid := Net.id_by_name(who)
		if pid == 0:
			continue
		var c: Dictionary = Combat._data(Combat._rec(pid))
		if f > int(c.get("best_floor", 0)):
			c["best_floor"] = f
		Ach.set_max(pid, "dungeon_floor", f)
		League.add(pid, "zindan", 1.0)
		Net.notify(pid, "%d. kat temizlendi! Sandığı aç, sonra merdivenden aşağı in." % f)
	var best = Net.save_data.get("dungeon_best", {"floor": 0, "by": ""})
	if not best is Dictionary:
		best = {"floor": 0, "by": ""}
	if f > int(best.floor):
		Net.save_data["dungeon_best"] = {"floor": f, "by": ", ".join(r.members)}
		if f >= 5:
			Net.announce("Zindan rekoru: %s %d. kata indi!" % [", ".join(r.members), f])
	Net.mark_dirty()
	_send_run(slot)


@rpc("any_peer", "call_remote", "reliable")
func req_chest(_d: Dictionary) -> void:
	var id := Net.sender()
	var z := _zone_of(id)
	if z == "":
		return
	var slot := int(z.get_slice(":", 1))
	var r: Dictionary = _runs[slot]
	var me: String = Net.players[id].name
	var g := gen_floor(slot, int(r.seed), int(r.floor))
	if r.state != "clear" or me in r.opened or _pos(id).distance_to(g.chest) > 110.0:
		return
	r.opened.append(me)
	var f := int(r.floor)
	var money := 60 * f + randi_range(20, 80)
	Net.add_money(id, money)
	var extra := ""
	var rec: Dictionary = Combat._rec(id)
	var bag: Array = rec.get("fish", [])
	if BOSS_ITEMS.has(f) and bag.size() < Jobs.BAG_SIZE:
		bag.append({"name": BOSS_ITEMS[f][0], "price": BOSS_ITEMS[f][1]})
		extra = " ve %s" % BOSS_ITEMS[f][0]
	elif randf() < 0.2 + 0.03 * f and bag.size() < Jobs.BAG_SIZE:
		var it: Array = LOOT_ITEMS[randi() % LOOT_ITEMS.size()]
		bag.append({"name": it[0], "price": randi_range(int(it[1]), int(it[2]))})
		extra = " ve %s" % it[0]
	if extra != "":
		Jobs.send_inventory(id)
	if randf() < 0.25:
		var c: Dictionary = Combat._data(rec)
		c["potions"] = mini(Combat.POTION_MAX, int(c.potions) + 1)
		extra += " (+1 iksir)"
		Combat.send_state(id)
	Net.mark_dirty()
	_send_run(slot)
	Net.notify(id, "Sandıktan %s%s çıktı!" % [U.money(money), extra])


@rpc("any_peer", "call_remote", "reliable")
func req_descend(_d: Dictionary) -> void:
	var id := Net.sender()
	var z := _zone_of(id)
	if z == "":
		return
	var slot := int(z.get_slice(":", 1))
	var r: Dictionary = _runs[slot]
	if r.state != "clear" or _pos(id).distance_to(gen_floor(slot, int(r.seed), int(r.floor)).stairs) > 110.0:
		return
	r["floor"] = int(r.floor) + 1
	_setup_floor(slot)
	_teleport_members(slot)
	for who in r.members:
		var pid := Net.id_by_name(who)
		if pid != 0:
			Combat._hp[pid] = minf(Combat.max_hp(pid), Combat.hp_of(pid) + Combat.max_hp(pid) * 0.3)
			Net.notify(pid, "%d. kata indin!%s" % [int(r.floor), " Dikkat: BOSS!" if int(r.floor) % 5 == 0 else ""])
	_send_run(slot)
	_broadcast_lobby()
