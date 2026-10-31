extends Node
## Ortak savaş sistemi (1.8): mağara zindanı ve zombi gecesi kullanır.
##  Oyuncu canı, silahlar (yumruk, kılıç, balta, çelik kılıç, yay), zırh ve iksirler.
##  Canavarlar sunucuda yaşar; her biri bir "bölge"dedir (ör. "zindan:2", "zombi"). Bölgenin sahibi modül
##  (Dungeon, Zombies) oyuncunun hangi bölgede olduğunu ve neresinin yürünebilir olduğunu söyler.
##  Saldırı: tıkla/dokun (fareye doğru) ya da Boşluk (baktığın yöne). Kılıç yay şeklinde vurur, yay ok atar.
## Veri: rec["combat"] = {owned: [silahlar], cur: silah, armor: 0..2, potions, kills}

signal changed
signal hit_fx(d: Dictionary)
signal monster_died(zone: String, m: Dictionary, killer: String)
signal player_down(id: int, zone: String)

const U = preload("res://scripts/util.gd")

const WEAPONS := {
	"yumruk": {"name": "Yumruk", "dmg": 4, "range": 46.0, "arc": 1.6, "cd": 0.5, "ranged": false, "price": 0, "level": 1},
	"kilic": {"name": "Kılıç", "dmg": 12, "range": 72.0, "arc": 1.9, "cd": 0.45, "ranged": false, "price": 1500, "level": 3},
	"yay": {"name": "Yay", "dmg": 9, "range": 520.0, "arc": 0.0, "cd": 0.55, "ranged": true, "price": 2500, "level": 5},
	"balta": {"name": "Savaş Baltası", "dmg": 24, "range": 80.0, "arc": 2.3, "cd": 0.8, "ranged": false, "price": 5000, "level": 8},
	"celik": {"name": "Çelik Kılıç", "dmg": 20, "range": 78.0, "arc": 2.0, "cd": 0.4, "ranged": false, "price": 9000, "level": 12},
}
const ARMOR := [{"name": "Zırhsız", "price": 0}, {"name": "Deri Zırh", "price": 4000}, {"name": "Demir Zırh", "price": 10000}]
const POTION_PRICE := 150
const POTION_HEAL := 45.0
const POTION_MAX := 10
const ARROW_SPEED := 760.0
const BODY_R := 18.0
const MONSTERS := {
	"slime": {"name": "Balçık", "hp": 30, "dmg": 6, "speed": 70.0, "range": 34.0, "cd": 1.2, "r": 18.0, "xp": 6, "gold": 15, "col": "#4ade80"},
	"bat": {"name": "Yarasa", "hp": 16, "dmg": 4, "speed": 170.0, "range": 28.0, "cd": 0.9, "r": 14.0, "xp": 5, "gold": 10, "col": "#6b21a8"},
	"spider": {"name": "Mağara Örümceği", "hp": 40, "dmg": 8, "speed": 130.0, "range": 32.0, "cd": 1.0, "r": 17.0, "xp": 10, "gold": 22, "col": "#1f2937"},
	"skeleton": {"name": "İskelet", "hp": 55, "dmg": 10, "speed": 95.0, "range": 40.0, "cd": 1.1, "r": 18.0, "xp": 12, "gold": 30, "col": "#e5e7eb"},
	"golem": {"name": "Taş Golem", "hp": 500, "dmg": 22, "speed": 60.0, "range": 72.0, "cd": 1.6, "r": 42.0, "xp": 150, "gold": 600, "col": "#78716c", "boss": true},
	"dragon": {"name": "Mağara Ejderi", "hp": 900, "dmg": 30, "speed": 85.0, "range": 90.0, "cd": 1.4, "r": 50.0, "xp": 300, "gold": 1500, "col": "#b91c1c", "boss": true},
	"zombie": {"name": "Zombi", "hp": 35, "dmg": 8, "speed": 62.0, "range": 34.0, "cd": 1.2, "r": 18.0, "xp": 8, "gold": 0, "col": "#65a30d"},
	"brute": {"name": "İri Zombi", "hp": 110, "dmg": 16, "speed": 48.0, "range": 46.0, "cd": 1.5, "r": 26.0, "xp": 25, "gold": 0, "col": "#3f6212"},
}

# --- istemci
var my := {"hp": 100.0, "max": 100.0, "owned": ["yumruk"], "cur": "yumruk", "armor": 0, "potions": 0, "zone": ""}
var monsters := {}                  # id -> [tür, x, y, can, en çok can, yön]
var arrows: Array = []              # [{p, v, t0}]

# --- sunucu
var _mon := {}                      # id -> {kind, zone, p, hp, max, cd, target, f, dmg_by}
var _next_id := 1
var _hp := {}                       # oyuncu id -> can
var _last_hit := {}                 # oyuncu id -> son hasar zamanı
var _atk_t := {}
var _arrows: Array = []             # {p, v, zone, by, dmg, t}
var _fx: Array = []                 # bu gönderimde yayınlanacak vuruşlar [zone, x, y, dmg, tür]
var _acc := 0.0
var zone_resolvers: Array = []      # Callable(id) -> bölge ("" değilse); Dungeon ve Zombies ekler
var walkable: Dictionary = {}       # bölge öneki -> Callable(zone, p) -> bool


func reset() -> void:
	my = {"hp": 100.0, "max": 100.0, "owned": ["yumruk"], "cur": "yumruk", "armor": 0, "potions": 0, "zone": ""}
	monsters = {}
	arrows = []
	_mon.clear()
	_hp.clear()
	_arrows.clear()
	_fx.clear()


func on_player_left(id: int) -> void:
	_hp.erase(id)
	_atk_t.erase(id)
	_last_hit.erase(id)


func in_combat() -> bool:
	return str(my.get("zone", "")) != ""


# ------------------------------------------------------------------ istemci API

func attack(dir: Vector2) -> void:
	Net.ask(self, "req_attack", {"d": dir.normalized()})


func drink() -> void:
	Net.ask(self, "req_potion")


func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func equip(w: String) -> void:
	Net.ask(self, "req_equip", {"w": w})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_world(d: Dictionary) -> void:
	monsters = d.get("m", {})
	my["hp"] = float(d.get("hp", my.hp))
	my["max"] = float(d.get("max", my.max))
	my["zone"] = str(d.get("zone", ""))
	for f in d.get("fx", []):
		hit_fx.emit({"p": Vector2(float(f[0]), float(f[1])), "dmg": int(f[2]), "kind": str(f[3])})


@rpc("authority", "call_local", "unreliable")
func on_arrow(d: Dictionary) -> void:
	arrows.append({"p": d.p, "v": d.v, "t0": Time.get_ticks_msec() / 1000.0})


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("combat") is Dictionary:
		rec["combat"] = {"owned": ["yumruk"], "cur": "yumruk", "armor": 0, "potions": 0, "kills": 0}
	return rec.combat


func max_hp(id: int) -> float:
	return 100.0 + 4.0 * float(Rpg.level(id))


func hp_of(id: int) -> float:
	if not _hp.has(id):
		_hp[id] = max_hp(id)
	return float(_hp[id])


func heal_full(id: int) -> void:
	_hp[id] = max_hp(id)


func zone_of(id: int) -> String:
	for c in zone_resolvers:
		var z: String = c.call(id)
		if z != "":
			return z
	return ""


func _free(zone: String, p: Vector2) -> bool:
	var key := zone.get_slice(":", 0)
	if walkable.has(key):
		return walkable[key].call(zone, p)
	return true


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var c := _data(rec)
	Net.tell(self, id, "on_state", {"hp": hp_of(id), "max": max_hp(id), "owned": c.owned, "cur": c.cur, "armor": int(c.armor),
		"potions": int(c.potions), "zone": zone_of(id), "kills": int(c.get("kills", 0))})


## Canavar çıkar (bölgenin sahibi çağırır). hp_mult: kat ve oyuncu sayısına göre güçlendirme.
func spawn(zone: String, kind: String, p: Vector2, hp_mult: float = 1.0) -> int:
	var cfg: Dictionary = MONSTERS[kind]
	var id := _next_id
	_next_id += 1
	var hp := int(round(float(cfg.hp) * hp_mult))
	_mon[id] = {"kind": kind, "zone": zone, "p": p, "hp": hp, "max": hp, "cd": randf_range(0.3, 1.0), "f": 1.0,
		"dmg_by": {}, "wander": p}
	return id


func clear_zone(zone: String) -> void:
	for id in _mon.keys():
		if _mon[id].zone == zone:
			_mon.erase(id)
	_arrows = _arrows.filter(func(a): return a.zone != zone)


func count_in(zone: String) -> int:
	var n := 0
	for id in _mon:
		if _mon[id].zone == zone:
			n += 1
	return n


func _shop_ok(id: int) -> bool:
	var p := _pos(id)
	return p.distance_to(preload("res://scripts/map.gd").DUNGEON_SHOP) < 160.0 or Zombies.at_defense(p)


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _shop_ok(id):
		return
	var c := _data(rec)
	var item := str(d.get("item", ""))
	if WEAPONS.has(item):
		var w: Dictionary = WEAPONS[item]
		if item in c.owned:
			return
		if Rpg.level(id) < int(w.level):
			Net.notify(id, "%s için seviye %d gerekli." % [w.name, w.level], false)
			return
		if not Net.try_spend(id, int(w.price)):
			Net.notify(id, "%s %s." % [w.name, U.money(int(w.price))], false)
			return
		c.owned.append(item)
		c["cur"] = item
		Net.notify(id, "%s alındı ve kuşanıldı!" % w.name)
	elif item == "armor":
		var lvl := int(c.armor)
		if lvl + 1 >= ARMOR.size():
			return
		var price: int = ARMOR[lvl + 1].price
		if not Net.try_spend(id, price):
			Net.notify(id, "%s %s." % [ARMOR[lvl + 1].name, U.money(price)], false)
			return
		c["armor"] = lvl + 1
		Net.notify(id, "%s giyildi: alınan hasar %%%d azaldı." % [ARMOR[lvl + 1].name, (lvl + 1) * 20])
	elif item == "potion":
		if int(c.potions) >= POTION_MAX:
			Net.notify(id, "En fazla %d iksir taşıyabilirsin." % POTION_MAX, false)
			return
		if not Net.try_spend(id, POTION_PRICE):
			Net.notify(id, "Can iksiri %s." % U.money(POTION_PRICE), false)
			return
		c["potions"] = int(c.potions) + 1
	else:
		return
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_equip(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var w := str(d.get("w", ""))
	if rec.is_empty() or not w in _data(rec).owned:
		return
	_data(rec)["cur"] = w
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_potion(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var c := _data(rec)
	if int(c.potions) <= 0 or hp_of(id) >= max_hp(id):
		return
	c["potions"] = int(c.potions) - 1
	_hp[id] = minf(max_hp(id), hp_of(id) + POTION_HEAL)
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_attack(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var zone := zone_of(id)
	if rec.is_empty() or zone == "":
		return
	var c := _data(rec)
	var wk := str(c.cur) if WEAPONS.has(str(c.cur)) else "yumruk"
	var w: Dictionary = WEAPONS[wk]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_atk_t.get(id, 0.0)) < float(w.cd):
		return
	_atk_t[id] = now
	var dir: Vector2 = d.get("d", Vector2.RIGHT)
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var me: String = Net.players[id].name
	var p := _pos(id) + Vector2(0, -16)
	var dmg := int(w.dmg) + int(Rpg.level(id) / 4)
	if bool(w.ranged):
		var a := {"p": p + dir * 24.0, "v": dir * ARROW_SPEED, "zone": zone, "by": me, "dmg": dmg, "t": 0.0}
		_arrows.append(a)
		for pid in Net.players:
			if zone_of(pid) == zone:
				Net.tell(self, pid, "on_arrow", {"p": a.p, "v": a.v})
		return
	_fx.append([zone, p.x + dir.x * 40.0, p.y + dir.y * 40.0, 0, "swing"])
	for mid in _mon.keys():
		var m: Dictionary = _mon[mid]
		if m.zone != zone:
			continue
		var to: Vector2 = m.p - _pos(id)
		var cfg: Dictionary = MONSTERS[m.kind]
		if to.length() > float(w.range) + float(cfg.r):
			continue
		if to.length() > 8.0 and absf(to.angle_to(dir)) > float(w.arc) / 2.0:
			continue
		_damage_monster(mid, dmg, me)


func _damage_monster(mid: int, dmg: int, by: String) -> void:
	var m: Dictionary = _mon[mid]
	m["hp"] = int(m.hp) - dmg
	m.dmg_by[by] = int(m.dmg_by.get(by, 0)) + dmg
	_fx.append([m.zone, m.p.x, m.p.y - 20.0, dmg, "hit"])
	if int(m.hp) <= 0:
		_mon.erase(mid)
		var cfg: Dictionary = MONSTERS[m.kind]
		# öldüren (en çok vuran) XP alır; bölge sahibi ganimeti dağıtır
		var best := by
		var bd := -1
		for k in m.dmg_by:
			if int(m.dmg_by[k]) > bd:
				bd = int(m.dmg_by[k])
				best = k
		for k in m.dmg_by:
			var pid := Net.id_by_name(k)
			if pid != 0:
				Rpg.add_xp(pid, "", int(cfg.xp))
		var kid := Net.id_by_name(best)
		if kid != 0:
			var c := _data(_rec(kid))
			c["kills"] = int(c.get("kills", 0)) + 1
			Ach.event(kid, "monsters")
		_fx.append([m.zone, m.p.x, m.p.y, 0, "die"])
		monster_died.emit(m.zone, m, best)


func _hurt_player(id: int, dmg: float, zone: String) -> void:
	var c := _data(_rec(id))
	dmg *= 1.0 - 0.2 * int(c.get("armor", 0))
	_hp[id] = hp_of(id) - dmg
	_last_hit[id] = Time.get_ticks_msec() / 1000.0
	_fx.append([zone, _pos(id).x, _pos(id).y - 30.0, -int(round(dmg)), "ouch"])
	if float(_hp[id]) <= 0.0:
		_hp[id] = max_hp(id)
		player_down.emit(id, zone)


func _tick(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# oyuncuların bölgeleri
	var by_zone := {}
	for id in Net.players:
		var z := zone_of(id)
		if z != "":
			if not by_zone.has(z):
				by_zone[z] = []
			by_zone[z].append(id)
		elif hp_of(id) < max_hp(id):
			_hp[id] = minf(max_hp(id), hp_of(id) + 6.0 * delta)          # savaş dışında can dolar
		if z != "" and now - float(_last_hit.get(id, 0.0)) > 6.0 and hp_of(id) < max_hp(id):
			_hp[id] = minf(max_hp(id), hp_of(id) + 1.5 * delta)
	# canavarlar
	for mid in _mon.keys():
		if not _mon.has(mid):
			continue
		var m: Dictionary = _mon[mid]
		var cfg: Dictionary = MONSTERS[m.kind]
		var targets: Array = by_zone.get(m.zone, [])
		var best := 0
		var bd := 650.0
		for pid in targets:
			var dd: float = _pos(pid).distance_to(m.p)
			if dd < bd:
				bd = dd
				best = pid
		m["cd"] = float(m.cd) - delta
		var goal: Vector2 = m.wander
		if best != 0:
			goal = _pos(best)
		elif m.p.distance_to(m.wander) < 20.0:
			m["wander"] = m.p + Vector2(randf_range(-160, 160), randf_range(-120, 120))
		var to: Vector2 = goal - m.p
		var reach := float(cfg.range) + BODY_R
		if best != 0 and to.length() <= reach:
			if float(m.cd) <= 0.0:
				m["cd"] = float(cfg.cd)
				_hurt_player(best, float(cfg.dmg), m.zone)
		elif to.length() > 4.0:
			var spd := float(cfg.speed) * (1.0 if best != 0 else 0.4)
			var want := to.normalized()
			for k in 5:
				var dirv := want.rotated([0.0, 0.7, -0.7, 1.4, -1.4][k])
				var np: Vector2 = m.p + dirv * spd * delta
				if _free(m.zone, np):
					m["p"] = np
					if absf(dirv.x) > 0.2:
						m["f"] = signf(dirv.x)
					break
	# oklar
	for i in range(_arrows.size() - 1, -1, -1):
		var a: Dictionary = _arrows[i]
		a.p += a.v * delta
		a.t = float(a.t) + delta
		var gone := float(a.t) > 0.75 or not _free(a.zone, a.p)
		if not gone:
			for mid in _mon.keys():
				var m: Dictionary = _mon[mid]
				if m.zone == a.zone and m.p.distance_to(a.p) < float(MONSTERS[m.kind].r) + 6.0:
					_damage_monster(mid, int(a.dmg), str(a.by))
					gone = true
					break
		if gone:
			_arrows.remove_at(i)


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_tick(delta)
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	var fx_by_zone := {}
	for f in _fx:
		if not fx_by_zone.has(f[0]):
			fx_by_zone[f[0]] = []
		fx_by_zone[f[0]].append([snappedf(f[1], 1.0), snappedf(f[2], 1.0), f[3], f[4]])
	_fx.clear()
	for id in Net.players:
		var z := zone_of(id)
		if z == "":
			if str(_sent_zone.get(id, "")) != "":
				Net.tell(self, id, "on_world", {"m": {}, "hp": hp_of(id), "max": max_hp(id), "zone": ""})
				_sent_zone[id] = ""
			continue
		_sent_zone[id] = z
		var view := {}
		var me_p := _pos(id)
		for mid in _mon:
			var m: Dictionary = _mon[mid]
			if m.zone == z and m.p.distance_to(me_p) < 1500.0:
				view[mid] = [m.kind, snappedf(m.p.x, 1.0), snappedf(m.p.y, 1.0), int(m.hp), int(m.max), m.f]
		Net.tell(self, id, "on_world", {"m": view, "hp": snappedf(hp_of(id), 0.1), "max": max_hp(id), "zone": z, "fx": fx_by_zone.get(z, [])})


var _sent_zone := {}
