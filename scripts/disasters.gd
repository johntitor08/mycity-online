extends Node
## Afetler (1.9): arada bir şehri deprem, sel ya da kar fırtınası vurur; herkes birlikte toparlar.
##  Deprem: sokaklarda enkaz (E basılı tut: temizle), hasarlı binalar (onarılana dek kapalı; E basılı tut: onar),
##          yaralılar (yardım çadırından ilk yardım çantası al, yaralıya götür).
##  Sel: su baskını gölleri (yardım çadırından kum torbası al, gölün kenarına koy; 3 torba suyu çeker,
##       baskında yürümek yavaştır) ve arabanın tepesinde mahsur kalanlar (E: kurtar).
##  Kar fırtınası: yolları kapatan kar yığınları (E basılı tut: kürekle), donan vatandaşlar (çadırdan battaniye götür).
##  İtfaiye görevindekiler enkazı/karı iki kat hızlı temizler; doktorluğu 3+ olan tek seferde ilk yardım yapar.
##  Hepsi bitince katkı veren herkes ödül alır. 12 dakikada bitmezse belediye ekipleri kalanları toplar.
##  Sunucu 2,5–4 saatte bir (zombi gecesi dışında) kendiliğinden başlatır. Yönetici: /afet deprem|sel|kar|bitir
## Veri: save_data["disaster_stats"] = {done, last}

signal changed
signal started(kind: String)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const KINDS := {
	"deprem": {"name": "Deprem", "supply": "ilkyardim", "supply_name": "İlk yardım çantası"},
	"sel": {"name": "Sel", "supply": "kum", "supply_name": "Kum torbası"},
	"kar": {"name": "Kar Fırtınası", "supply": "battaniye", "supply_name": "Battaniye"},
}
const DURATION := 720.0
const CARRY_MAX := 3
const PILE_HP := 4
const BLD_NEED := 12
const POOL_BAGS := 3
const BLOCK_R := 34.0
const TENT_R := 110.0
const REWARD_BASE := 300
const REWARD_PER := 40

# --- istemci
var state := {"kind": ""}            # {kind, left, piles, bld, people, pools, done, total, carry}
var shake_t := -99.0

# --- sunucu
var _kind := ""
var _t0 := 0.0
var _piles: Array = []               # [{p, hp}]
var _bld: Array = []                 # [{type, prog}]
var _people: Array = []              # [{p, need, kind}]   kind: yarali | mahsur | donuk
var _pools: Array = []               # [{p, r, bags}]
var _carry := {}                     # id -> n
var _helped := {}                    # ad -> katkı
var _total := 0
var _next_at := -1.0
var _sync := 0.0


func reset() -> void:
	state = {"kind": ""}
	_kind = ""
	_piles.clear()
	_bld.clear()
	_people.clear()
	_pools.clear()
	_carry.clear()
	_helped.clear()


func on_player_left(id: int) -> void:
	_carry.erase(id)


func active() -> bool:
	return str(state.get("kind", "")) != ""


## İstemci: hasarlı bina mı (paneli açılmaz)?
func damaged(btype: String) -> bool:
	for b in state.get("bld", []):
		if str(b[0]) == btype:
			return true
	return false


## İstemci: enkaz/kar yığını yolu kesiyor mu?
func blocked_at(p: Vector2) -> bool:
	for pl in state.get("piles", []):
		if Vector2(pl[0], pl[1]).distance_to(p) < BLOCK_R:
			return true
	return false


## İstemci: su baskınında mı (yavaş yürünür)?
func in_flood(p: Vector2) -> bool:
	for pl in state.get("pools", []):
		if Vector2(pl[0], pl[1]).distance_to(p) < float(pl[2]):
			return true
	return false


# ------------------------------------------------------------------ istemci API

func take_supply() -> void:
	Net.ask(self, "req_supply")


func work_pile(i: int) -> void:
	Net.ask(self, "req_pile", {"i": i})


func repair(btype: String) -> void:
	Net.ask(self, "req_repair", {"t": btype})


func help_person(i: int) -> void:
	Net.ask(self, "req_person", {"i": i})


func bag_pool(i: int) -> void:
	Net.ask(self, "req_pool", {"i": i})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	var was := str(state.get("kind", ""))
	state = d
	if was != str(d.get("kind", "")):
		if str(d.get("kind", "")) == "deprem":
			shake_t = Time.get_ticks_msec() / 1000.0
		changed.emit()


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _view(id: int) -> Dictionary:
	if _kind == "":
		return {"kind": ""}
	var piles: Array = []
	for p in _piles:
		piles.append([p.p.x, p.p.y, int(p.hp)])
	var bld: Array = []
	for b in _bld:
		bld.append([b.type, int(b.prog), BLD_NEED])
	var people: Array = []
	for p in _people:
		people.append([p.p.x, p.p.y, int(p.need), p.kind])
	var pools: Array = []
	for p in _pools:
		pools.append([p.p.x, p.p.y, float(p.r), int(p.bags)])
	return {"kind": _kind, "left": snappedf(DURATION - (Time.get_ticks_msec() / 1000.0 - _t0), 1.0), "piles": piles, "bld": bld,
		"people": people, "pools": pools, "done": _total - _remaining(), "total": _total, "carry": int(_carry.get(id, 0))}


func send_state(id: int) -> void:
	Net.tell(self, id, "on_state", _view(id))


func _broadcast() -> void:
	for id in Net.players:
		send_state(id)


func _remaining() -> int:
	var n := _piles.size() + _bld.size() + _people.size()
	for p in _pools:
		n += 1
	return n


static func road_point(rng: RandomNumberGenerator) -> Vector2:
	match rng.randi() % 3:
		0:
			return Vector2(rng.randf_range(120, 2680), 445 + rng.randf_range(-14, 14))
		1:
			return Vector2(rng.randf_range(1080, 2680), 822 + rng.randf_range(-14, 14))
	return Vector2(1005 + rng.randf_range(-14, 14), rng.randf_range(520, 1500))


func _far(p: Vector2, list: Array, d: float) -> bool:
	for q in list:
		if (q.p as Vector2).distance_to(p) < d:
			return false
	return p.distance_to(Map.AID_TENT) > 200.0 and p.distance_to(Map.SPAWN) > 120.0


func start(kind: String) -> void:
	if not KINDS.has(kind) or _kind != "":
		return
	_kind = kind
	_t0 = Time.get_ticks_msec() / 1000.0
	_piles.clear()
	_bld.clear()
	_people.clear()
	_pools.clear()
	_carry.clear()
	_helped.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var guard := 0
	match kind:
		"deprem":
			while _piles.size() < 10 and guard < 400:
				guard += 1
				var p := road_point(rng)
				if _far(p, _piles, 160.0):
					_piles.append({"p": p, "hp": PILE_HP})
			var types: Array = ["market", "casino", "poker", "galeri", "mobilya", "muhtarlik", "carsi", "banka"]
			types.shuffle()
			for t in types.slice(0, 3):
				_bld.append({"type": t, "prog": 0})
			guard = 0
			while _people.size() < 6 and guard < 400:
				guard += 1
				var p := road_point(rng) + Vector2(0, rng.randf_range(40, 60) * (1 if rng.randf() < 0.5 else -1))
				if _far(p, _people + _piles, 140.0):
					_people.append({"p": p, "need": 1, "kind": "yarali"})
		"sel":
			while _pools.size() < 7 and guard < 400:
				guard += 1
				var p := Vector2(rng.randf_range(150, 2650), rng.randf_range(1430, 1600)) if rng.randf() < 0.6 else road_point(rng)
				if _far(p, _pools, 330.0):
					var r0 := rng.randf_range(110, 160)
					_pools.append({"p": p, "r": r0, "r0": r0, "bags": 0})
			for pl in _pools.slice(0, 4):
				_people.append({"p": pl.p + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20)), "need": 1, "kind": "mahsur"})
		"kar":
			while _piles.size() < 12 and guard < 400:
				guard += 1
				var p := road_point(rng)
				if _far(p, _piles, 150.0):
					_piles.append({"p": p, "hp": PILE_HP})
			guard = 0
			while _people.size() < 6 and guard < 400:
				guard += 1
				var p := road_point(rng) + Vector2(0, 55 * (1 if rng.randf() < 0.5 else -1))
				if _far(p, _people + _piles, 140.0):
					_people.append({"p": p, "need": 1, "kind": "donuk"})
	_total = _remaining()
	var msg: String = {"deprem": "DEPREM! Sokaklarda enkaz, bazı binalar hasarlı, yaralılar var. Yardım çadırı sahil yolunun başında — birlikte toparlayalım!",
		"sel": "SEL BASKINI! Sahil ve yollar su altında. Yardım çadırından kum torbası al, suyu durdur, mahsur kalanları kurtar!",
		"kar": "KAR FIRTINASI! Yollar kar yığınlarıyla kapandı, donmak üzere olanlar var. Yardım çadırından battaniye al!"}[kind]
	Net.announce(msg)
	started.emit(kind)
	_broadcast()


func stop(success: bool) -> void:
	if _kind == "":
		return
	var nm: String = KINDS[_kind].name
	for who in _helped:
		var n := int(_helped[who])
		var reward := (REWARD_BASE if success else 100) + REWARD_PER * n
		var pid := Net.id_by_name(who)
		if pid != 0:
			Net.add_money(pid, reward)
			Rpg.add_xp(pid, "", 30 + 10 * n)
			Ach.event(pid, "disasters")
			Net.notify(pid, "%s atlatıldı! %d görevde yardım ettin. Ödül: %s" % [nm, n, U.money(reward)])
		else:
			Net.add_money_by_name(who, reward)
	var top := ""
	var top_n := 0
	for who in _helped:
		if int(_helped[who]) > top_n:
			top_n = int(_helped[who])
			top = who
	if success:
		Net.announce("%s atlatıldı, şehir toparlandı! %s" % [nm, ("En çok yardım eden: %s (%d görev)." % [top, top_n]) if top != "" else ""])
	else:
		Net.announce("%s sona erdi; belediye ekipleri kalan işleri tamamladı." % nm)
	if not Net.save_data.get("disaster_stats") is Dictionary:
		Net.save_data["disaster_stats"] = {"done": 0}
	Net.save_data.disaster_stats["done"] = int(Net.save_data.disaster_stats.get("done", 0)) + 1
	_kind = ""
	_piles.clear()
	_bld.clear()
	_people.clear()
	_pools.clear()
	_carry.clear()
	_helped.clear()
	Net.mark_dirty()
	_broadcast()


func _credit(id: int, n: int = 1) -> void:
	var who: String = Net.players[id].name
	_helped[who] = int(_helped.get(who, 0)) + n
	Ach.event(id, "disaster_tasks", n)
	Rpg.add_xp(id, "", 15)
	if _remaining() == 0:
		stop(true)
	else:
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_supply(_d: Dictionary) -> void:
	var id := Net.sender()
	if _kind == "" or not Net.players.has(id) or _pos(id).distance_to(Map.AID_TENT) > TENT_R:
		return
	if int(_carry.get(id, 0)) >= CARRY_MAX:
		Net.notify(id, "En fazla %d tane taşıyabilirsin." % CARRY_MAX, false)
		return
	_carry[id] = CARRY_MAX
	Net.notify(id, "%d %s aldın." % [CARRY_MAX, KINDS[_kind].supply_name])
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_pile(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	if _kind == "" or not Net.players.has(id) or i < 0 or i >= _piles.size() or _pos(id).distance_to(_piles[i].p) > 90.0:
		return
	var hit := 2 if Work._firemen.has(id) else 1
	_piles[i]["hp"] = int(_piles[i].hp) - hit
	if int(_piles[i].hp) <= 0:
		_piles.remove_at(i)
		_credit(id)
	else:
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_repair(d: Dictionary) -> void:
	var id := Net.sender()
	var t := str(d.get("t", ""))
	if _kind == "" or not Net.players.has(id):
		return
	for i in _bld.size():
		if _bld[i].type != t:
			continue
		var b: Dictionary = Map.building(t)
		if b.is_empty() or not (b.rect as Rect2).grow(40).has_point(_pos(id)):
			return
		_bld[i]["prog"] = int(_bld[i].prog) + (2 if Work._firemen.has(id) else 1)
		if int(_bld[i].prog) >= BLD_NEED:
			_bld.remove_at(i)
			Net.notify(id, "%s onarıldı ve yeniden açıldı!" % b.label)
			_credit(id, 2)
		else:
			_broadcast()
		return


@rpc("any_peer", "call_remote", "reliable")
func req_person(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	if _kind == "" or not Net.players.has(id) or i < 0 or i >= _people.size() or _pos(id).distance_to(_people[i].p) > 90.0:
		return
	var p: Dictionary = _people[i]
	if p.kind != "mahsur":
		if int(_carry.get(id, 0)) <= 0:
			Net.notify(id, "Önce yardım çadırından %s al." % KINDS[_kind].supply_name.to_lower(), false)
			return
		_carry[id] = int(_carry[id]) - 1
	var reward := 120
	if p.kind == "yarali" and Rpg.skill(id, "medicine") >= 3:
		reward = 200                      # doktor ilk yardımı ustalıkla yapar
	Net.add_money(id, reward)
	_people.remove_at(i)
	Net.notify(id, {"yarali": "Yaralıya ilk yardım yaptın", "mahsur": "Mahsur kalanı kurtardın", "donuk": "Donan vatandaşa battaniye verdin"}[p.kind] + " (+%s)" % U.money(reward))
	_credit(id)


@rpc("any_peer", "call_remote", "reliable")
func req_pool(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	if _kind != "sel" or not Net.players.has(id) or i < 0 or i >= _pools.size():
		return
	var pl: Dictionary = _pools[i]
	if _pos(id).distance_to(pl.p) > float(pl.get("r0", pl.r)) + 60.0:
		return
	if int(_carry.get(id, 0)) <= 0:
		Net.notify(id, "Önce yardım çadırından kum torbası al.", false)
		return
	_carry[id] = int(_carry[id]) - 1
	pl["bags"] = int(pl.bags) + 1
	pl["r"] = float(pl.r) * 0.7
	if int(pl.bags) >= POOL_BAGS:
		# sudaki mahsurlar da kurtulmuş sayılmaz: onları ayrıca kurtarmak gerekir
		_pools.remove_at(i)
		_credit(id)
	else:
		_broadcast()


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _kind == "":
		if _next_at < 0.0:
			_next_at = now + randf_range(9000.0, 14400.0)
		elif now >= _next_at and not Net.players.is_empty() and not Zombies._active:
			_next_at = now + randf_range(9000.0, 14400.0)
			start(["deprem", "sel", "kar"][randi() % 3] if Env.season != "summer" else ["deprem", "sel"][randi() % 2])
		return
	if now - _t0 > DURATION:
		stop(false)
		return
	_sync += delta
	if _sync > 5.0:
		_sync = 0.0
		_broadcast()
