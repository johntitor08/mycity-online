extends Node
## Zombi gecesi (1.8): iki oyun gününde bir dolunay gecesi (22:00–02:00) şehre zombiler gelir.
##  Zombiler şehrin kenarlarından çıkar, sokaktaki oyunculara saldırır (ev içleri güvenli).
##  Savunma: Karakol önündeki savunma merkezinde silah/zırh/iksir; G ile önüne barikat kur (zombileri durdurur,
##  zamanla kırılır). Mahsur kalan vatandaşları bul, E ile kurtar. Bayılırsan hastaneye taşınırsın.
##  Sabah olunca katılan herkes ödül alır, en çok zombi öldüren ilan edilir. Yönetici: /zombi
## Veri: save_data["zombie_best"] = {kills, by}

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const START_HOUR := 22.0
const END_HOUR := 2.0
const BARRICADE_PRICE := 80
const BARRICADE_HP := 120.0
const BARRICADE_MAX := 3
const RESCUE_REWARD := 150
const CIVILIANS := 4
const DEFENSE_R := 150.0

# --- istemci
var state := {"active": false}       # {active, kills: {ad: n}, civ: [[x, y]], bar: [[x, y, hp, sahip]]}

# --- sunucu
var _active := false
var _forced_until := -1.0
var _kills := {}                     # ad -> öldürülen zombi
var _rescues := {}                   # ad -> kurtarılan
var _civ: Array = []                 # [Vector2]
var _bar: Array = []                 # [{p, hp, owner}]
var _spawn_acc := 0.0
var _sync := 0.0
var _last_day := -1
var _skipped_night := -1            # yönetici bu doğal geceyi bitirdiyse aynı gece yeniden başlamaz
var natural := true                  # testler doğal geceleri kapatır (force_start yine çalışır)


func _ready() -> void:
	Combat.zone_resolvers.append(_zone_of)
	Combat.walkable["zombi"] = _walkable
	Combat.monster_died.connect(_on_monster_died)
	Combat.player_down.connect(_on_player_down)


func reset() -> void:
	state = {"active": false}
	_active = false
	_kills.clear()
	_rescues.clear()
	_civ.clear()
	_bar.clear()


func on_player_left(_id: int) -> void:
	pass


func active() -> bool:
	return bool(state.get("active", false))


static func defense_pos() -> Vector2:
	var k: Dictionary = Map.building("karakol")
	return Vector2(k.rect.position.x - 70, k.rect.end.y + 30)


## Savunma merkezi yakınında mı? (Combat dükkânı sorar; sadece zombi gecesinde açık)
func at_defense(p: Vector2) -> bool:
	return (_active if Net.is_server() else active()) and p.distance_to(defense_pos()) < DEFENSE_R


func _zone_of(id: int) -> String:
	if not _active:
		return ""
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	if Map.WORLD.has_point(p) and Map.interior_at(p) < 0 and not Map.JAIL.has_point(p):
		return "zombi"
	return ""


func _walkable(_zone: String, p: Vector2) -> bool:
	if not Map.WORLD.grow(-10).has_point(p) or Map.in_sea(p) or Map.in_water(p):
		return false
	for b in _bar:
		if b.p.distance_to(p) < 30.0:
			return false
	return true


# ------------------------------------------------------------------ istemci API

func barricade(p: Vector2) -> void:
	Net.ask(self, "req_barricade", {"p": p})


func rescue(i: int) -> void:
	Net.ask(self, "req_rescue", {"i": i})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	var was := active()
	state = d
	if was != active():
		changed.emit()


# ------------------------------------------------------------------ sunucu

func send_state(id: int) -> void:
	Net.tell(self, id, "on_state", _view())


func _view() -> Dictionary:
	if not _active:
		return {"active": false}
	var civ: Array = []
	for c in _civ:
		civ.append([c.x, c.y])
	var bar: Array = []
	for b in _bar:
		bar.append([b.p.x, b.p.y, int(b.hp), b.owner])
	return {"active": true, "kills": _kills, "civ": civ, "bar": bar}


func _broadcast() -> void:
	Net.tell_all(self, "on_state", _view())


func force_start(minutes: float = 8.0) -> void:
	_forced_until = Time.get_ticks_msec() / 1000.0 + minutes * 60.0
	_start()


func force_stop() -> void:
	_forced_until = -1.0
	_skipped_night = _night_key()
	if _active:
		_end()


func _night_key() -> int:
	var day := int(Time.get_unix_time_from_system() / Env.DAY_SECONDS)
	if Env.hour < END_HOUR:
		day -= 1                 # gece yarısından sonra hâlâ önceki günün gecesi
	return day


func _night_due() -> bool:
	var h := Env.hour
	var day := _night_key()
	return natural and day % 2 == 0 and (h >= START_HOUR or h < END_HOUR) and day != _skipped_night


func _start() -> void:
	if _active:
		return
	_active = true
	_kills.clear()
	_rescues.clear()
	_bar.clear()
	_civ.clear()
	var rng := RandomNumberGenerator.new()
	var guard := 0
	while _civ.size() < CIVILIANS and guard < 300:
		guard += 1
		var p := Vector2(rng.randf_range(80, Map.WORLD.size.x - 80), rng.randf_range(420, Map.BEACH.position.y - 40))
		var inside_b := false
		for b in Map.BUILDINGS:
			if (b.rect as Rect2).grow(30).has_point(p):
				inside_b = true
		if _walkable("zombi", p) and Map.interior_at(p) < 0 and not inside_b:
			_civ.append(p)
	Net.announce("DOLUNAY! Zombiler şehre giriyor! Karakol'un önündeki savunma merkezinde silah al, barikat kur (G), vatandaşları kurtar!")
	_broadcast()


func _end() -> void:
	_active = false
	Combat.clear_zone("zombi")
	var top := ""
	var top_n := 0
	var who_all := {}
	for k in _kills:
		who_all[k] = true
		if int(_kills[k]) > top_n:
			top_n = int(_kills[k])
			top = k
	for k in _rescues:
		who_all[k] = true
	for who in who_all:
		var pid := Net.id_by_name(who)
		var n := int(_kills.get(who, 0))
		var reward := 200 + 25 * n
		if who == top:
			reward += 2000
		if pid != 0:
			Net.add_money(pid, reward)
			Ach.event(pid, "zombie_nights")
			Net.notify(pid, "Sabah oldu, şehir kurtuldu! %d zombi öldürdün. Ödül: %s" % [n, U.money(reward)])
		else:
			Net.add_money_by_name(who, reward)
	if top != "":
		var best = Net.save_data.get("zombie_best", {"kills": 0, "by": ""})
		if not best is Dictionary or top_n > int(best.get("kills", 0)):
			Net.save_data["zombie_best"] = {"kills": top_n, "by": top}
		Net.announce("Gün doğdu, zombiler çekildi! Gecenin kahramanı: %s (%d zombi)." % [top, top_n])
	else:
		Net.announce("Gün doğdu, zombiler çekildi.")
	_civ.clear()
	_bar.clear()
	Net.mark_dirty()
	_broadcast()


func _spawn_point(rng: RandomNumberGenerator) -> Vector2:
	for k in 30:
		var side := rng.randi() % 3
		var p := Vector2.ZERO
		match side:
			0:
				p = Vector2(rng.randf_range(40, Map.WORLD.size.x - 40), 40)
			1:
				p = Vector2(40, rng.randf_range(80, Map.BEACH.position.y - 60))
			_:
				p = Vector2(Map.WORLD.size.x - 40, rng.randf_range(80, Map.BEACH.position.y - 60))
		if _walkable("zombi", p):
			return p
	return Vector2(1200, 440)


func _on_monster_died(zone: String, _m: Dictionary, killer: String) -> void:
	if zone != "zombi":
		return
	_kills[killer] = int(_kills.get(killer, 0)) + 1
	var pid := Net.id_by_name(killer)
	if pid != 0:
		Ach.event(pid, "zombie_kills")


func _on_player_down(id: int, zone: String) -> void:
	if zone != "zombi":
		return
	var loss := mini(300, int(Net.get_money(id) * 0.05))
	Net.try_spend(id, loss)
	Homes._teleport(id, Map.inst_rect("hospital").get_center() + Vector2(0, 60))     # 2.3: hastanenin içine
	Net.notify(id, "Zombiler seni yere serdi! Hastaneye kaldırıldın (%s)." % U.money(loss), false)


@rpc("any_peer", "call_remote", "reliable")
func req_barricade(d: Dictionary) -> void:
	var id := Net.sender()
	if not _active or not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var p: Vector2 = d.get("p", Vector2.ZERO)
	var here: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	if p.distance_to(here) > 90.0 or not _walkable("zombi", p):
		return
	var mine := 0
	for b in _bar:
		if b.owner == me:
			mine += 1
	if mine >= BARRICADE_MAX:
		Net.notify(id, "En fazla %d barikatın olabilir." % BARRICADE_MAX, false)
		return
	if not Net.try_spend(id, BARRICADE_PRICE):
		Net.notify(id, "Barikat %s." % U.money(BARRICADE_PRICE), false)
		return
	_bar.append({"p": p, "hp": BARRICADE_HP, "owner": me})
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_rescue(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	if not _active or not Net.players.has(id) or i < 0 or i >= _civ.size():
		return
	if Net.positions.get(id, Vector2(-9999, -9999)).distance_to(_civ[i]) > 90.0:
		return
	_civ.remove_at(i)
	var me: String = Net.players[id].name
	_rescues[me] = int(_rescues.get(me, 0)) + 1
	Net.add_money(id, RESCUE_REWARD)
	Rpg.add_xp(id, "", 40)
	Ach.event(id, "rescues")
	Net.notify(id, "Vatandaşı kurtardın ve karakola götürdün! (+%s)" % U.money(RESCUE_REWARD))
	_broadcast()


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var forced := now < _forced_until
	var due := forced or (_night_due() and not Net.players.is_empty())
	if due and not _active:
		_start()
	elif not due and _active:
		_end()
	if not _active:
		return
	# zombileri tamamla: sokaktaki oyuncu sayısına göre
	var out := 0
	for pid in Net.players:
		if _zone_of(pid) != "":
			out += 1
	var want := mini(6 + 3 * out, 30) if out > 0 else 4
	_spawn_acc += delta
	if _spawn_acc >= 1.5 and Combat.count_in("zombi") < want:
		_spawn_acc = 0.0
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		Combat.spawn("zombi", "brute" if rng.randf() < 0.15 else "zombie", _spawn_point(rng), 1.0 + 0.1 * out)
	# barikatlar zombilerin yüklenmesiyle kırılır
	var changed_bar := false
	for i in range(_bar.size() - 1, -1, -1):
		var b: Dictionary = _bar[i]
		var n := 0
		for mid in Combat._mon:
			var m: Dictionary = Combat._mon[mid]
			if m.zone == "zombi" and m.p.distance_to(b.p) < 52.0:
				n += 1
		if n > 0:
			b["hp"] = float(b.hp) - 8.0 * n * delta
			changed_bar = true
		if float(b.hp) <= 0.0:
			_bar.remove_at(i)
	_sync += delta
	if changed_bar and _sync > 1.0:
		_sync = 0.0
		_broadcast()
