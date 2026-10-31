extends Node
## Evcil hayvan yarışı ve şovu (1.9): Yeni Mahalle'deki Evcil Hayvan Parkı.
##  Eğitim: koşu bandı (hız), slalom direkleri (çeviklik), bakım masası (çekicilik). Hayvanın tok olmalı;
##  her eğitim biraz acıktırır, günde en fazla 12 eğitim.
##  Aksesuarlar: şapka/taç, papyon/tasma, gözlük. Hayvanın üstünde görünür ve çekiciliğe eklenir.
##  Engelli parkur yarışı: gişeden katıl (100 TL), 15 sn bekleme; NPC hayvanlarla birlikte çember, slalom,
##  engel ve tünelden geçilir. Hız ve çeviklik belirler, şans da var. İlk üç kupa ve ödül alır.
##  Güzellik şovu: sahnede 3 jüri puan verir (çekicilik + aksesuar + mutluluk + şans). 10 dk'da bir katılınır.
## Veri: rec["pet"]["show"] = {speed, agility, charm, day, trains, cups: {gold, silver, bronze}, acc: [], wear: {}}

signal changed
signal race_changed
signal show_result(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const ACCESSORIES := {
	"kurdele": {"name": "Kurdele", "slot": "head", "charm": 4, "price": 300, "color": "#f472b6"},
	"parti": {"name": "Parti Şapkası", "slot": "head", "charm": 6, "price": 600, "color": "#38bdf8"},
	"tac": {"name": "Taç", "slot": "head", "charm": 12, "price": 2500, "color": "#facc15"},
	"papyon": {"name": "Papyon", "slot": "neck", "charm": 5, "price": 400, "color": "#ef4444"},
	"fular": {"name": "Fular", "slot": "neck", "charm": 7, "price": 800, "color": "#22c55e"},
	"altin": {"name": "Altın Tasma", "slot": "neck", "charm": 14, "price": 3500, "color": "#eab308"},
	"gozluk": {"name": "Güneş Gözlüğü", "slot": "eyes", "charm": 6, "price": 700, "color": "#111827"},
	"kalp": {"name": "Kalp Gözlük", "slot": "eyes", "charm": 9, "price": 1500, "color": "#e11d48"},
}
const STATS := {"kosu": ["speed", "Hız"], "slalom": ["agility", "Çeviklik"], "bakim": ["charm", "Çekicilik"]}
const DAILY_TRAINS := 12
const TRAIN_COOLDOWN := 15.0
const TRAIN_FOOD := 6.0
const RACE_FEE := 100
const RACE_LOBBY := 15.0
const RACE_PRIZES := [800, 400, 200]
const SHOW_FEE := 150
const SHOW_COOLDOWN := 600.0
const SHOW_PRIZES := [1000, 500, 250]
const NPC_PETS := [["Karabaş", "dog"], ["Pamuk", "cat"], ["Boncuk", "cat"], ["Tarçın", "dog"], ["Duman", "cat"], ["Zıpzıp", "dog"]]
## Parkurdaki engeller: [parkur oranı, tür]
const OBSTACLES := [[0.12, "cember"], [0.3, "slalom"], [0.5, "engel"], [0.68, "tunel"], [0.86, "cember"]]
const OBSTACLE_HALF := 50.0

# --- istemci
var my := {}                          # {speed, agility, charm, trains_left, cups, acc, wear} ya da {}
var race := {}                        # {state, left, pets: [[ad, sahip, tür, mesafe, bitiş]]}
var last_show := {}

# --- sunucu
var _race_state := "idle"
var _race_t := 0.0
var _runners := {}                    # ad -> {owner, id, kind, speed, agility, d, done, jit}
var _train_t := {}                    # id -> son eğitim
var _sync := 0.0


func reset() -> void:
	my = {}
	race = {}
	last_show = {}
	_race_state = "idle"
	_runners.clear()
	_train_t.clear()


func on_player_left(id: int) -> void:
	_train_t.erase(id)


static func track_len() -> float:
	var n := 0.0
	for i in Map.PET_TRACK.size() - 1:
		n += Map.PET_TRACK[i].distance_to(Map.PET_TRACK[i + 1])
	return n


static func track_pos(d: float) -> Vector2:
	var pts: Array = Map.PET_TRACK
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if d <= seg:
			return pts[i].lerp(pts[i + 1], d / seg)
		d -= seg
	return pts[-1]


static func wear_charm(wear: Dictionary) -> int:
	var n := 0
	for slot in wear:
		var k := str(wear[slot])
		if ACCESSORIES.has(k):
			n += int(ACCESSORIES[k].charm)
	return n


# ------------------------------------------------------------------ istemci API

func train(spot: String) -> void:
	Net.ask(self, "req_train", {"spot": spot})


func buy_acc(k: String) -> void:
	Net.ask(self, "req_acc", {"k": k, "buy": true})


func wear(k: String) -> void:
	Net.ask(self, "req_acc", {"k": k, "buy": false})


func join_race() -> void:
	Net.ask(self, "req_race")


func enter_show() -> void:
	Net.ask(self, "req_show")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	my = d
	changed.emit()


@rpc("authority", "call_local", "unreliable_ordered")
func on_race(d: Dictionary) -> void:
	var was := str(race.get("state", ""))
	race = d
	if was != str(d.get("state", "")):
		race_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_show(d: Dictionary) -> void:
	last_show = d
	show_result.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _pet(rec: Dictionary) -> Dictionary:
	var p = rec.get("pet")
	return p if p is Dictionary else {}


func _show(pet: Dictionary) -> Dictionary:
	if not pet.get("show") is Dictionary:
		pet["show"] = {"speed": 20, "agility": 20, "charm": 20, "day": "", "trains": 0, "cups": {"gold": 0, "silver": 0, "bronze": 0}, "acc": [], "wear": {}}
	var s: Dictionary = pet.show
	var today := Time.get_date_string_from_system()
	if str(s.get("day", "")) != today:
		s["day"] = today
		s["trains"] = 0
	return s


func send_state(id: int) -> void:
	var pet := _pet(_rec(id))
	if pet.is_empty():
		Net.tell(self, id, "on_state", {})
		return
	var s := _show(pet)
	Net.tell(self, id, "on_state", {"speed": int(s.speed), "agility": int(s.agility), "charm": int(s.charm),
		"trains_left": DAILY_TRAINS - int(s.trains), "cups": s.cups, "acc": s.acc, "wear": s.wear,
		"show_left": maxf(0.0, SHOW_COOLDOWN - (Time.get_unix_time_from_system() - float(s.get("show_t", 0.0))))})


@rpc("any_peer", "call_remote", "reliable")
func req_train(d: Dictionary) -> void:
	var id := Net.sender()
	var pet := _pet(_rec(id))
	var spot := str(d.get("spot", ""))
	if pet.is_empty() or not STATS.has(spot) or _pos(id).distance_to(Map.PET_SPOTS[spot]) > 110.0:
		return
	Pets._tick(pet)
	if float(pet.food) < Pets.HAPPY_AT:
		Net.notify(id, "%s aç; önce besle (mama ya da balık)." % pet.name, false)
		return
	var s := _show(pet)
	if int(s.trains) >= DAILY_TRAINS:
		Net.notify(id, "%s bugün yeterince çalıştı; yarın yine gel." % pet.name, false)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_train_t.get(id, -99.0)) < TRAIN_COOLDOWN:
		return
	_train_t[id] = now
	var stat: String = STATS[spot][0]
	var gain := randi_range(3, 6)
	s[stat] = mini(100, int(s[stat]) + gain)
	s["trains"] = int(s.trains) + 1
	pet["food"] = maxf(0.0, float(pet.food) - TRAIN_FOOD)
	Ach.event(id, "pet_trains")
	Rpg.add_xp(id, "", 10)
	Net.mark_dirty()
	send_state(id)
	Pets.send_state(id)
	Net.notify(id, "%s: %s +%d (%d/100)" % [pet.name, STATS[spot][1], gain, int(s[stat])])


@rpc("any_peer", "call_remote", "reliable")
func req_acc(d: Dictionary) -> void:
	var id := Net.sender()
	var pet := _pet(_rec(id))
	var k := str(d.get("k", ""))
	if pet.is_empty() or not ACCESSORIES.has(k):
		return
	var s := _show(pet)
	var a: Dictionary = ACCESSORIES[k]
	if bool(d.get("buy", false)):
		if k in s.acc or _pos(id).distance_to(Map.PET_KIOSK) > 140.0:
			return
		if not Net.try_spend(id, int(a.price)):
			Net.notify(id, "%s %s." % [a.name, U.money(int(a.price))], false)
			return
		s.acc.append(k)
		s.wear[a.slot] = k
		Net.notify(id, "%s aldın ve %s'e taktın!" % [a.name, pet.name])
	else:
		if not k in s.acc:
			return
		if str(s.wear.get(a.slot, "")) == k:
			s.wear.erase(a.slot)
		else:
			s.wear[a.slot] = k
	Net.mark_dirty()
	send_state(id)
	Pets._update_roster(id)


# --- engelli parkur yarışı

func _race_view() -> Dictionary:
	if _race_state == "idle":
		return {"state": "idle"}
	var now := Time.get_ticks_msec() / 1000.0
	var list: Array = []
	for k in _runners:
		var r: Dictionary = _runners[k]
		list.append([k, r.owner, r.kind, snappedf(float(r.d), 1.0), snappedf(float(r.done), 0.01)])
	return {"state": _race_state, "left": snappedf((RACE_LOBBY - (now - _race_t)) if _race_state == "lobby" else (now - _race_t), 0.1), "pets": list}


func _race_broadcast() -> void:
	var v := _race_view()
	for id in Net.players:
		if Map.TOWN.has_point(_pos(id)):
			Net.tell(self, id, "on_race", v)


@rpc("any_peer", "call_remote", "reliable")
func req_race(_d: Dictionary) -> void:
	var id := Net.sender()
	var pet := _pet(_rec(id))
	if pet.is_empty():
		Net.notify(id, "Yarışa katılmak için bir evcil hayvanın olmalı (Pet Shop).", false)
		return
	if _pos(id).distance_to(Map.PET_BOOTH) > 140.0:
		return
	if _race_state == "run":
		Net.notify(id, "Yarış sürüyor; bir sonrakine katıl.", false)
		return
	var key: String = "%s (%s)" % [pet.name, Net.players[id].name]
	if _runners.has(key):
		return
	Pets._tick(pet)
	if float(pet.food) < Pets.HAPPY_AT:
		Net.notify(id, "%s aç; yarıştan önce besle." % pet.name, false)
		return
	if not Net.try_spend(id, RACE_FEE):
		Net.notify(id, "Yarış ücreti %s." % U.money(RACE_FEE), false)
		return
	var s := _show(pet)
	_runners[key] = {"owner": Net.players[id].name, "id": id, "kind": str(pet.kind), "speed": int(s.speed), "agility": int(s.agility), "d": 0.0, "done": -1.0, "jit": 1.0}
	if _race_state == "idle":
		_race_state = "lobby"
		_race_t = Time.get_ticks_msec() / 1000.0
	Net.notify(id, "%s parkur yarışına yazıldı! 15 sn sonra başlıyor." % pet.name)
	_race_broadcast()


func _race_start() -> void:
	var names: Array = NPC_PETS.duplicate()
	names.shuffle()
	var k := 0
	while _runners.size() < 4 and k < names.size():
		var lvl := randi_range(25, 70)
		_runners[str(names[k][0])] = {"owner": "", "id": 0, "kind": str(names[k][1]), "speed": lvl + randi_range(-10, 10), "agility": lvl + randi_range(-10, 10),
			"d": 0.0, "done": -1.0, "jit": 1.0}
		k += 1
	_race_state = "run"
	_race_t = Time.get_ticks_msec() / 1000.0
	_race_broadcast()


static func pace(speed: int, agility: int, d: float, jit: float) -> float:
	var v := 150.0 * (0.7 + speed / 200.0) * jit
	var frac := d / track_len()
	for o in OBSTACLES:
		if absf(frac * track_len() - float(o[0]) * track_len()) < OBSTACLE_HALF:
			v *= 0.4 + agility / 170.0
	return v


func _race_finish() -> void:
	var order: Array = _runners.keys()
	order.sort_custom(func(a, b): return float(_runners[a].done) < float(_runners[b].done))
	var lines: Array = []
	for i in order.size():
		var r: Dictionary = _runners[order[i]]
		lines.append("%d. %s" % [i + 1, order[i]])
		if int(r.id) == 0 or not Net.players.has(int(r.id)):
			continue
		var pid := int(r.id)
		var pet := _pet(_rec(pid))
		if pet.is_empty():
			continue
		var s := _show(pet)
		if i < 3:
			var cup: String = ["gold", "silver", "bronze"][i]
			s.cups[cup] = int(s.cups.get(cup, 0)) + 1
			Net.add_money(pid, RACE_PRIZES[i])
			Net.notify(pid, "%s parkur yarışında %d. oldu! %s kupa ve %s" % [pet.name, i + 1, ["Altın", "Gümüş", "Bronz"][i], U.money(RACE_PRIZES[i])])
			if i == 0:
				Ach.event(pid, "pet_gold")
		else:
			Net.notify(pid, "%s parkur yarışında %d. oldu." % [pet.name, i + 1])
		Rpg.add_xp(pid, "", 40 - i * 8)
		send_state(pid)
	for id in Net.players:
		if Map.TOWN.has_point(_pos(id)):
			Net.notify(id, "Parkur yarışı: " + ", ".join(lines.slice(0, 3)))
	_race_state = "done"
	_race_t = Time.get_ticks_msec() / 1000.0
	Net.mark_dirty()
	_race_broadcast()


# --- güzellik şovu

@rpc("any_peer", "call_remote", "reliable")
func req_show(_d: Dictionary) -> void:
	var id := Net.sender()
	var pet := _pet(_rec(id))
	if pet.is_empty() or not Map.PET_STAGE.grow(90).has_point(_pos(id)):
		return
	var s := _show(pet)
	var now := Time.get_unix_time_from_system()
	if now - float(s.get("show_t", 0.0)) < SHOW_COOLDOWN:
		Net.notify(id, "%s biraz dinlensin; %d dk sonra yine sahneye çıkabilir." % [pet.name, int(ceil((SHOW_COOLDOWN - (now - float(s.show_t))) / 60.0))], false)
		return
	if not Net.try_spend(id, SHOW_FEE):
		Net.notify(id, "Şov ücreti %s." % U.money(SHOW_FEE), false)
		return
	Pets._tick(pet)
	s["show_t"] = now
	var entries: Array = []
	var mine := _judge(int(s.charm), wear_charm(s.wear), Pets.is_happy(pet))
	entries.append([str(pet.name), Net.players[id].name, str(pet.kind), mine, s.wear.duplicate()])
	var names: Array = NPC_PETS.duplicate()
	names.shuffle()
	var accs: Array = ACCESSORIES.keys()
	for k in 3:
		var w := {}
		if randf() < 0.7:
			var a: String = accs[randi() % accs.size()]
			w[ACCESSORIES[a].slot] = a
		entries.append([str(names[k][0]), "", str(names[k][1]), _judge(randi_range(25, 75), wear_charm(w), true), w])
	entries.sort_custom(func(a, b): return _sum(a[3]) > _sum(b[3]))
	var place := 0
	for i in entries.size():
		if entries[i][1] == Net.players[id].name:
			place = i
	if place < 3:
		var cup: String = ["gold", "silver", "bronze"][place]
		s.cups[cup] = int(s.cups.get(cup, 0)) + 1
		Net.add_money(id, SHOW_PRIZES[place])
		if place == 0:
			Ach.event(id, "pet_show_win")
			Net.announce("%s, güzellik şovunda birinci oldu! (%s'in %s'i)" % [pet.name, Net.players[id].name, Pets.PETS.get(pet.kind, {}).get("name", "hayvanı").to_lower()])
	Rpg.add_xp(id, "", 30)
	Net.mark_dirty()
	send_state(id)
	Net.tell(self, id, "on_show", {"entries": entries, "place": place, "prize": SHOW_PRIZES[place] if place < 3 else 0})


static func _sum(a: Array) -> float:
	var n := 0.0
	for v in a:
		n += float(v)
	return n


func _judge(charm: int, acc: int, happy: bool) -> Array:
	var out: Array = []
	for j in 3:
		var v := 1.0 + charm / 16.0 + acc / 8.0 + (0.5 if happy else -1.0) + randf_range(-1.2, 1.2)
		out.append(snappedf(clampf(v, 1.0, 10.0), 0.1))
	return out


func _process(delta: float) -> void:
	if not Net.is_server() or _race_state == "idle":
		return
	var now := Time.get_ticks_msec() / 1000.0
	match _race_state:
		"lobby":
			if now - _race_t >= RACE_LOBBY:
				_race_start()
		"run":
			var L := track_len()
			var running := false
			for k in _runners:
				var r: Dictionary = _runners[k]
				if float(r.done) >= 0.0:
					continue
				if randf() < delta * 1.5:
					r["jit"] = randf_range(0.88, 1.12)
				r["d"] = minf(L, float(r.d) + pace(int(r.speed), int(r.agility), float(r.d), float(r.jit)) * delta)
				if float(r.d) >= L:
					r["done"] = now - _race_t
				else:
					running = true
			if not running or now - _race_t > 90.0:
				for k in _runners:
					if float(_runners[k].done) < 0.0:
						_runners[k]["done"] = 999.0
				_race_finish()
				return
		"done":
			if now - _race_t > 6.0:
				_race_state = "idle"
				_runners.clear()
				_race_broadcast()
				return
	_sync += delta
	if _sync >= 0.2:
		_sync = 0.0
		_race_broadcast()
