extends Node
## RPG sistemi: seviye/XP, meslek yetenekleri, enerji, eşyalar ve günlük görevler.
## Sunucu yetkilidir; veriler hesap kaydında (rec["rpg"]) saklanır.
## İstemci yalnızca kendi "karakter kartını" (sheet) alır.

signal sheet_changed

const U = preload("res://scripts/util.gd")
const Map = preload("res://scripts/map.gd")

const SKILLS := {
	"fishing": "Balıkçılık",
	"medicine": "Doktorluk",
	"cashier": "Kasiyerlik",
	"realestate": "Emlakçılık",
	"farming": "Çiftçilik",
	"police": "Polislik",
	"mining": "Madencilik",
	"music": "Müzisyenlik",
	"riding": "Binicilik",
}
const SKILL_PERKS := {
	"fishing": "Her seviye: nadir balık şansı +%8, çekme süresi +0,1 sn",
	"medicine": "Her seviye: maaş +%5, teşhis süresi +0,5 sn",
	"cashier": "Her seviye: maaş +%5, süre +1 sn",
	"realestate": "Her seviye: kira geliri +%5",
	"farming": "Her seviye: hasat +%5",
	"police": "Her seviye: devriye maaşı +%5, süre +0,5 sn",
	"mining": "Her seviye: değerli maden ve fosil şansı +%6",
	"music": "Her seviye yeni bir şarkı açar",
	"riding": "Her seviye: yarışta atın hızı +%1",
}
const FOODS := {
	"simit": {"name": "Simit", "price": 15, "energy": 10},
	"kahve": {"name": "Türk Kahvesi", "price": 30, "energy": 15},
	"tost": {"name": "Kaşarlı Tost", "price": 40, "energy": 25},
	"doner": {"name": "Döner", "price": 90, "energy": 50},
}
const TOOLS := {
	"rod": {"name": "Profesyonel Olta", "price": 2500, "desc": "Nadir balık şansı +%25"},
	"stetho": {"name": "Steteskop", "price": 3000, "desc": "Hastane maaşı +%20"},
	"calc": {"name": "Hesap Makinesi", "price": 1500, "desc": "Market maaşı +%20, süre +5 sn"},
	"card": {"name": "Altın Kartvizit", "price": 5000, "desc": "Kira geliri +%15"},
}
const QUESTS := {
	"fish": ["Balık tut", 5],
	"patient": ["Hasta iyileştir", 5],
	"customer": ["Müşteriye doğru para üstü ver", 5],
	"poker": ["Pokerde el kazan", 1],
	"bet": ["Kumarhanede bahis oyna", 3],
	"swim": ["Denizde yüz", 1],
	"build": ["Arsa al ya da inşa et", 1],
	"harvest": ["Tarlada hasat yap", 2],
	"race": ["Yarış pistinde tur tamamla", 1],
	"patrol": ["Karakolda olay çöz", 3],
}
const QUEST_XP := 80
const QUEST_MONEY := 300
const ENERGY_REGEN_SEC := 20.0     # 1 enerji / 20 sn (plajda ve denizde 3 kat)
const MAX_FOOD_STACK := 20
const LEVEL_GATES := {"sea": 3, "villa": 5, "tower": 10}

var sheet: Dictionary = {}           # istemci: kendi karakter kartı
var _sheet_at := 0.0
var _tick := 0.0


# ================================================================== formüller

static func level_of(xp: int) -> int:
	return int(floor(sqrt(xp / 100.0))) + 1


static func xp_for(level: int) -> int:
	return 100 * (level - 1) * (level - 1)


static func skill_level_of(xp: int) -> int:
	return mini(20, int(floor(sqrt(xp / 50.0))) + 1)


static func skill_xp_for(level: int) -> int:
	return 50 * (level - 1) * (level - 1)


static func max_energy(level: int, r: Dictionary = {}) -> int:
	var bonus := 0
	if r.get("fitness") is Dictionary:
		bonus = mini(20, int(int(r.fitness.get("cardio", 0)) / 5.0))     # 1.5: spor salonu (kondisyon)
	return 100 + 5 * (level - 1) + bonus


# ================================================================== kayıt

func _now() -> float:
	return Time.get_unix_time_from_system()


## Hesap kaydındaki RPG bölümü (yoksa oluşturur).
static func ensure(rec: Dictionary) -> Dictionary:
	if not rec.get("rpg") is Dictionary:
		rec["rpg"] = {}
	var r: Dictionary = rec["rpg"]
	if not r.has("xp"):
		r["xp"] = 0
	if not r.get("skills") is Dictionary:
		r["skills"] = {}
	for k in SKILLS:
		r["skills"][k] = int(r["skills"].get(k, 0))
	if not r.has("energy"):
		r["energy"] = float(max_energy(1))
		r["energy_t"] = Time.get_unix_time_from_system()
	if not r.get("items") is Dictionary:
		r["items"] = {}
	if not r.get("tools") is Array:
		r["tools"] = []
	if not r.get("quests") is Dictionary:
		r["quests"] = {"day": "", "list": []}
	return r


func _rec(id: int) -> Dictionary:
	if not Net.players.has(id) or not Net.save_data.players.has(Net.players[id].name):
		return {}
	return ensure(Net.save_data.players[Net.players[id].name])


static func level_of_rec(rec: Dictionary) -> int:
	return level_of(int(ensure(rec)["xp"]))


## Yiyecek bilgisi: marketteki yiyecekler ya da mutfakta pişen yemekler.
func food_info(k: String) -> Dictionary:
	if FOODS.has(k):
		return FOODS[k]
	if Holidays.HOLIDAY_FOODS.has(k):
		return Holidays.HOLIDAY_FOODS[k]
	if Fair.FAIR_FOODS.has(k):
		return Fair.FAIR_FOODS[k]
	if Camp.CAMP_FOODS.has(k):
		return Camp.CAMP_FOODS[k]
	if Mountain.LODGE_FOODS.has(k):
		return Mountain.LODGE_FOODS[k]
	if Kitchen.RECIPES.has(k):
		var r: Dictionary = Kitchen.RECIPES[k]
		return {"name": r.name, "price": 0, "energy": int(r.energy), "dish": true, "buff": r.get("buff", [])}
	return {}


## Yemek bonusu etkin mi? (work, luck, xp)
func buff(id: int, kind: String) -> bool:
	var r := _rec(id)
	if r.is_empty() or not r.get("buffs") is Dictionary:
		return false
	return float(r.buffs.get(kind, 0.0)) > Time.get_unix_time_from_system()


func level(id: int) -> int:
	var r := _rec(id)
	return level_of(int(r.xp)) if not r.is_empty() else 1


func skill(id: int, key: String) -> int:
	var r := _rec(id)
	return skill_level_of(int(r.skills.get(key, 0))) if not r.is_empty() else 1


func has_tool(id: int, tool: String) -> bool:
	var r := _rec(id)
	return not r.is_empty() and r.tools.has(tool)


## Yetenek ve aletlerden gelen bonuslar.
func perk(id: int, kind: String) -> float:
	var r := _rec(id)
	return _perk_rec(r if not r.is_empty() else ensure({}), kind)


static func _perk_rec(r: Dictionary, kind: String) -> float:
	var sk := func(k: String) -> int: return skill_level_of(int(r.skills.get(k, 0))) - 1
	var tools: Array = r.tools
	var dip: Array = r.get("diplomas", [])
	match kind:
		"fish_rare":
			return 1.0 + 0.08 * sk.call("fishing") + (0.25 if tools.has("rod") else 0.0)
		"fish_window":
			return 0.1 * sk.call("fishing")
		"medicine_pay":
			return 1.0 + 0.05 * sk.call("medicine") + (0.2 if tools.has("stetho") else 0.0) + (0.15 if "ilkyardim" in dip else 0.0)
		"medicine_time":
			return 0.5 * sk.call("medicine")
		"cashier_pay":
			return 1.0 + 0.05 * sk.call("cashier") + (0.2 if tools.has("calc") else 0.0)
		"cashier_time":
			return 1.0 * sk.call("cashier") + (5.0 if tools.has("calc") else 0.0)
		"rent":
			return 1.0 + 0.05 * sk.call("realestate") + (0.15 if tools.has("card") else 0.0) + (0.1 if "finans" in dip else 0.0)
		"farm_yield":
			return 1.0 + 0.05 * sk.call("farming")
		"police_pay":
			return 1.0 + 0.05 * sk.call("police")
		"police_time":
			return 0.5 * sk.call("police")
	return 1.0


## Kira gibi çevrimdışıyken de hesaplanan bonuslar için.
func rent_mult_by_name(player_name: String) -> float:
	if not Net.save_data.players.has(player_name):
		return 1.0
	return _perk_rec(ensure(Net.save_data.players[player_name]), "rent")


# ================================================================== enerji

func _update_energy(r: Dictionary, lvl: int) -> void:
	var now := _now()
	var gained := (now - float(r.get("energy_t", now))) / ENERGY_REGEN_SEC
	r["energy"] = minf(float(max_energy(lvl, r)), float(r.energy) + maxf(gained, 0.0))
	r["energy_t"] = now


## Enerji harcar; yetmiyorsa oyuncuyu uyarır ve false döner.
## Enerji ver (yiyecek, dinlenme...). En fazla maksimum enerjiye kadar.
func add_energy(id: int, amount: float) -> void:
	var r := _rec(id)
	if r.is_empty():
		return
	var lvl := level_of(int(r.xp))
	_update_energy(r, lvl)
	r["energy"] = minf(float(max_energy(lvl, r)), float(r.energy) + amount)
	send_sheet(id)


func use_energy(id: int, amount: int) -> bool:
	var r := _rec(id)
	if r.is_empty():
		return false
	var cost := float(amount) * (0.85 if Pets.bonus(id, "cat") else 1.0)
	_update_energy(r, level_of(int(r.xp)))
	if float(r.energy) < cost:
		Net.notify(id, "Enerjin bitti! Marketten yiyecek al ya da plajda dinlen.", false)
		send_sheet(id)
		return false
	r["energy"] = float(r.energy) - cost
	Net.mark_dirty()
	send_sheet(id)
	return true


# ================================================================== XP ve seviye

## skill boş olabilir (sadece genel XP).
func add_xp(id: int, skill_key: String, amount: int) -> void:
	var r := _rec(id)
	if r.is_empty() or amount <= 0:
		return
	amount = int(round(amount * Family.xp_mult(id) * (1.1 if buff(id, "xp") else 1.0)))
	League.add(id, "xp", float(amount))
	var old_level := level_of(int(r.xp))
	r["xp"] = int(r.xp) + amount
	Clans.on_xp(id, amount)
	var new_level := level_of(int(r.xp))
	if skill_key != "" and SKILLS.has(skill_key):
		var old_sk := skill_level_of(int(r.skills[skill_key]))
		r.skills[skill_key] = int(r.skills[skill_key]) + amount
		var new_sk := skill_level_of(int(r.skills[skill_key]))
		if new_sk > old_sk:
			Net.notify(id, "%s yeteneğin %d. seviyeye çıktı!" % [SKILLS[skill_key], new_sk])
	if new_level > old_level:
		var reward := 100 * new_level
		_update_energy(r, new_level)
		r["energy"] = float(max_energy(new_level, r))
		Net.players[id]["level"] = new_level
		Ach.set_max(id, "level", new_level)
		Net.add_money(id, reward)     # roster'ı da yayınlar (yeni seviye görünür)
		Net.notify(id, "SEVİYE ATLADIN! Seviye %d — ödül %s, enerji doldu." % [new_level, U.money(reward)])
		Story.send_state(id)
		if new_level % 5 == 0 or LEVEL_GATES.values().has(new_level):
			Net.announce("%s %d. seviyeye ulaştı!" % [Net.players[id].name, new_level])
	Net.mark_dirty()
	send_sheet(id)


# ================================================================== günlük görevler

func _today() -> String:
	return Time.get_date_string_from_system()


func _ensure_quests(id: int, r: Dictionary) -> void:
	var day := _today()
	if r.quests.get("day", "") == day:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Net.players[id].name + day)
	var keys: Array = QUESTS.keys()
	var picked: Array = []
	while picked.size() < 3:
		var k: String = keys[rng.randi() % keys.size()]
		if not picked.has(k):
			picked.append(k)
	var list: Array = []
	for k in picked:
		list.append({"id": k, "progress": 0, "goal": QUESTS[k][1], "done": false})
	r["quests"] = {"day": day, "list": list}


## Oyun olaylarını görevlere işler (balık, hasta, müşteri, poker, bahis, yüzme, inşaat).
func quest_event(id: int, kind: String, n: int = 1) -> void:
	var r := _rec(id)
	if r.is_empty():
		return
	Ach.event(id, kind, n)
	_ensure_quests(id, r)
	var changed := false
	for q in r.quests.list:
		if q.id == kind and not q.done:
			q.progress = mini(int(q.progress) + n, int(q.goal))
			changed = true
			if int(q.progress) >= int(q.goal):
				q.done = true
				Net.add_money(id, QUEST_MONEY)
				Net.notify(id, "Görev tamamlandı: %s! +%s, +%d XP" % [QUESTS[kind][0], U.money(QUEST_MONEY), QUEST_XP])
				add_xp(id, "", QUEST_XP)
	if changed:
		Net.mark_dirty()
		send_sheet(id)


# ================================================================== istemci API

func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func use(item: String) -> void:
	Net.ask(self, "req_use", {"item": item})


func refresh() -> void:
	Net.ask(self, "req_sheet")


@rpc("authority", "call_local", "reliable")
func on_sheet(d: Dictionary) -> void:
	sheet = d
	_sheet_at = Time.get_ticks_msec() / 1000.0
	sheet_changed.emit()


## İstemci: son karttan bu yana dolan enerjiyi de hesaba katarak tahmini enerji.
func energy_now() -> float:
	if sheet.is_empty():
		return 0.0
	var rate := (3.0 if sheet.get("regen_beach", false) else 1.0) / ENERGY_REGEN_SEC
	var e := float(sheet.energy) + (Time.get_ticks_msec() / 1000.0 - _sheet_at) * rate
	return minf(e, float(sheet.max_energy))


func reset() -> void:
	sheet = {}


# ================================================================== sunucu: istekler

func _at_market(id: int) -> bool:
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	for b in Map.BUILDINGS:
		if b.type == "market":
			return b.rect.grow(40).has_point(p)
	return false


@rpc("any_peer", "call_remote", "reliable")
func req_sheet(_d: Dictionary) -> void:
	var id := Net.sender()
	if Net.players.has(id):
		send_sheet(id)


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var r := _rec(id)
	if r.is_empty():
		return
	var item := str(d.get("item", ""))
	if not _at_market(id):
		Net.notify(id, "Alışveriş için markete git.", false)
		return
	if FOODS.has(item) and not FOODS[item].get("dish", false):
		if int(r.items.get(item, 0)) >= MAX_FOOD_STACK:
			Net.notify(id, "Çantanda yeterince %s var." % FOODS[item].name, false)
			return
		if not Net.try_spend(id, int(FOODS[item].price)):
			Net.notify(id, "Yeterli paran yok.", false)
			return
		r.items[item] = int(r.items.get(item, 0)) + 1
	elif TOOLS.has(item):
		if r.tools.has(item):
			Net.notify(id, "Bu alet zaten sende.", false)
			return
		if not Net.try_spend(id, int(TOOLS[item].price)):
			Net.notify(id, "Yeterli paran yok.", false)
			return
		r.tools.append(item)
		Net.notify(id, "%s satın alındı: %s" % [TOOLS[item].name, TOOLS[item].desc])
	else:
		return
	Net.mark_dirty()
	send_sheet(id)


@rpc("any_peer", "call_remote", "reliable")
func req_use(d: Dictionary) -> void:
	var id := Net.sender()
	var r := _rec(id)
	var item := str(d.get("item", ""))
	var food := food_info(item)
	if r.is_empty() or food.is_empty() or int(r.items.get(item, 0)) <= 0:
		return
	var lvl := level_of(int(r.xp))
	_update_energy(r, lvl)
	if float(r.energy) >= max_energy(lvl, r):
		Net.notify(id, "Enerjin zaten dolu.", false)
		return
	r.items[item] = int(r.items[item]) - 1
	if int(r.items[item]) <= 0:
		r.items.erase(item)
	eat(id, item, "yedin")


## Yemeği hemen ye: enerji ve (varsa) yemek bonusu. Restoranda sipariş de bunu kullanır.
func eat(id: int, item: String, verb: String) -> void:
	var r := _rec(id)
	var food := food_info(item)
	if r.is_empty() or food.is_empty():
		return
	var lvl := level_of(int(r.xp))
	_update_energy(r, lvl)
	r["energy"] = minf(float(max_energy(lvl, r)), float(r.energy) + int(food.energy))
	var extra := ""
	if not food.get("buff", []).is_empty():
		if not r.get("buffs") is Dictionary:
			r["buffs"] = {}
		var b: Array = food.buff
		r.buffs[b[0]] = maxf(float(r.buffs.get(b[0], 0.0)), Time.get_unix_time_from_system()) + float(b[1])
		extra = " Bonus: %s (%d dk)" % [Kitchen.BUFF_NAMES[b[0]], int(float(b[1]) / 60.0)]
	Net.notify(id, "%s %s, +%d enerji.%s" % [food.name, verb, food.energy, extra])
	Net.mark_dirty()
	send_sheet(id)


func send_sheet(id: int) -> void:
	var r := _rec(id)
	if r.is_empty():
		return
	var lvl := level_of(int(r.xp))
	_update_energy(r, lvl)
	_ensure_quests(id, r)
	var skills := {}
	for k in SKILLS:
		var sx := int(r.skills[k])
		var sl := skill_level_of(sx)
		skills[k] = {"xp": sx, "level": sl, "cur": skill_xp_for(sl), "next": skill_xp_for(sl + 1)}
	var quests: Array = []
	for q in r.quests.list:
		quests.append({"id": q.id, "name": QUESTS.get(q.id, ["?", 1])[0], "progress": int(q.progress),
			"goal": int(q.goal), "done": bool(q.done)})
	Net.tell(self, id, "on_sheet", {
		"level": lvl, "xp": int(r.xp), "cur": xp_for(lvl), "next": xp_for(lvl + 1),
		"energy": float(r.energy), "max_energy": max_energy(lvl, r), "skills": skills,
		"items": r.items.duplicate(), "tools": r.tools.duplicate(), "quests": quests,
		"regen_beach": _on_beach(id),
		"buffs": _buffs_left(r),
		"regen_bed": Homes.on_bed(Land.plots, Net.positions.get(id, Vector2(-9999, -9999))),
	})


func _buffs_left(r: Dictionary) -> Dictionary:
	var out := {}
	var now := Time.get_unix_time_from_system()
	if r.get("buffs") is Dictionary:
		for k in r.buffs:
			if float(r.buffs[k]) > now:
				out[k] = float(r.buffs[k]) - now
	return out


func _on_beach(id: int) -> bool:
	if Env.is_rainy():
		return false      # yağmurda plajda dinlenilmez
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	return Map.BEACH.has_point(p) or (Map.in_sea(p) and Map.interior_at(p) < 0)


## Her 5 sn: plaj/denizdekilere ek enerji, yüzme görevi.
func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_tick += delta
	if _tick < 5.0:
		return
	_tick = 0.0
	for id in Net.players.keys():
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
		if Map.in_sea(p):
			quest_event(id, "swim")
		var bonus := 0.0
		if Homes.on_bed(Land.plots, p):
			bonus = 5.0           # yatakta: ~1 enerji/sn
		elif _on_beach(id):
			bonus = 2.0 * 5.0 / ENERGY_REGEN_SEC    # normal hızın 2 katı ek: toplam 3 kat
		if bonus > 0.0:
			var r := _rec(id)
			if r.is_empty():
				continue
			var lvl := level_of(int(r.xp))
			_update_energy(r, lvl)
			if float(r.energy) < max_energy(lvl, r):
				r["energy"] = minf(float(max_energy(lvl, r)), float(r.energy) + bonus)
				send_sheet(id)
