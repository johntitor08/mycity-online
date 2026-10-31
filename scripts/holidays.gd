extends Node
## Özel günler ve bayramlar (1.5). Gerçek takvime göre kendiliğinden başlar (yönetici /ozelgun ile açıp kapatabilir).
##  Cadılar Bayramı (25 Eki – 2 Kas): bal kabakları, yarasalar, kostümler; G ile kapıları çal → şeker (ya da şaka!).
##  Yılbaşı (20 Ara – 5 Oca): parkta süslü çam ve Noel Baba (günde bir hediye), şehre saçılan hediye kutuları.
##  Ramazan / Kurban Bayramı: NPC'lerin elini öp (G) → harçlık ve lokum (bayram başına bir kez).
##  Sevgililer Günü (12–15 Şub): parktaki tezgâhtan gül al, G ile bir oyuncuya gül ver.
## Veri: rec["holiday"] = {key, day, doors: [], gifts: n, santa, hands: [], roses}, rec["costume"]

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const NAMES := {"cadilar": "Cadılar Bayramı", "yilbasi": "Yılbaşı", "ramazan": "Ramazan Bayramı", "kurban": "Kurban Bayramı", "sevgililer": "Sevgililer Günü"}
# dini bayramlar (tarihler yaklaşık; yönetici /ozelgun ile düzeltebilir)
const BAYRAMS := [
	["2026-03-20", "2026-03-22", "ramazan"], ["2026-05-27", "2026-05-30", "kurban"],
	["2027-03-09", "2027-03-11", "ramazan"], ["2027-05-16", "2027-05-19", "kurban"],
	["2028-02-26", "2028-02-28", "ramazan"], ["2028-05-04", "2028-05-07", "kurban"],
]
const STALL := Vector2(700, 1500)              # parktaki bayram tezgâhı (kostüm / gül / şeker)
const TREE := Vector2(585, 1494)               # yılbaşı çamı
const SANTA := Vector2(700, 1585)              # Noel Baba
const COSTUMES := {"cadi": "Cadı Şapkası", "hayalet": "Hayalet", "vampir": "Vampir Pelerini", "kabak": "Bal Kabağı Kafa"}
const COSTUME_PRICE := 100
const ROSE_PRICE := 50
const MAX_GIFTS := 12
const HOLIDAY_FOODS := {
	"seker": {"name": "Cadı Şekeri", "price": 0, "energy": 6},
	"kurabiye": {"name": "Yılbaşı Kurabiyesi", "price": 0, "energy": 15},
	"lokum": {"name": "Bayram Lokumu", "price": 0, "energy": 10},
}

# --- istemci
var active := ""
var gifts: Array = []              # [{id, x, y}]

# --- sunucu
var _forced := ""                  # "" = takvime göre; "yok" = kapalı; aksi halde zorla
var _current := ""
var _gifts: Array = []
var _uid := 1
var _acc := 0.0


func reset() -> void:
	active = ""
	gifts = []
	_gifts.clear()


static func by_date(d: Dictionary) -> String:
	var m := int(d.month)
	var day := int(d.day)
	if (m == 10 and day >= 25) or (m == 11 and day <= 2):
		return "cadilar"
	if (m == 12 and day >= 20) or (m == 1 and day <= 5):
		return "yilbasi"
	if m == 2 and day >= 12 and day <= 15:
		return "sevgililer"
	var today := "%04d-%02d-%02d" % [int(d.year), m, day]
	for b in BAYRAMS:
		if today >= str(b[0]) and today <= str(b[1]):
			return b[2]
	return ""


func current() -> String:
	if _forced == "yok":
		return ""
	if _forced != "":
		return _forced
	return by_date(Time.get_date_dict_from_system())


func is_bayram() -> bool:
	return active == "ramazan" or active == "kurban"


# ------------------------------------------------------------------ istemci API

func knock(door: String) -> void:
	Net.ask(self, "req_knock", {"door": door})


func costume(k: String) -> void:
	Net.ask(self, "req_costume", {"k": k})


func pick_gift(gid: int) -> void:
	Net.ask(self, "req_gift", {"id": gid})


func santa() -> void:
	Net.ask(self, "req_santa")


func kiss_hand(npc: String) -> void:
	Net.ask(self, "req_hand", {"npc": npc})


func buy_rose() -> void:
	Net.ask(self, "req_rose_buy")


func give_rose(to: int) -> void:
	Net.ask(self, "req_rose", {"to": to})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	active = str(d.get("active", ""))
	if d.has("gifts"):
		gifts = d.gifts
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


## Bu bayram için oyuncunun kaydı (yeni bayramda / yeni günde sıfırlanır).
func _hd(rec: Dictionary) -> Dictionary:
	var key := current()
	var day := Time.get_date_string_from_system()
	if not rec.get("holiday") is Dictionary or str(rec.holiday.get("key", "")) != key:
		rec["holiday"] = {"key": key, "day": day, "doors": [], "gifts": 0, "santa": "", "hands": [], "roses": 0}
	if str(rec.holiday.get("day", "")) != day:
		rec.holiday["day"] = day
		rec.holiday["doors"] = []
		rec.holiday["gifts"] = 0
	return rec.holiday


func send_state(id: int) -> void:
	Net.tell(self, id, "on_state", {"active": current(), "gifts": _gifts})
	var rec := _rec(id)
	if not rec.is_empty() and str(rec.get("costume", "")) != "" and current() == "cadilar":
		Net.players[id]["costume"] = rec.costume
		Net._broadcast_roster()


## Yönetici: /ozelgun cadilar|yilbasi|ramazan|kurban|sevgililer|yok|takvim
func force(k: String) -> void:
	_forced = "" if k == "takvim" else k
	_check(true)


func _check(announce: bool) -> void:
	var c := current()
	if c == _current:
		return
	_current = c
	_gifts.clear()
	if c != "cadilar":
		for id in Net.players:
			Net.players[id].erase("costume")
		Net._broadcast_roster()
	for id in Net.players:
		send_state(id)
	if announce and c != "":
		Net.announce("%s başladı! Şehir süslendi, parktaki tezgâha uğra." % NAMES[c])


func door_pos(door: String) -> Vector2:
	if door.begins_with("b:"):
		var b := Map.building(door.substr(2))
		return Vector2(b.rect.get_center().x, b.rect.end.y + 10) if not b.is_empty() else Vector2(-1e6, -1e6)
	if door.begins_with("p:"):
		return Map.plot_front(int(door.substr(2))) + Vector2(0, 20)
	return Vector2(-1e6, -1e6)


@rpc("any_peer", "call_remote", "reliable")
func req_knock(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var door := str(d.get("door", ""))
	if rec.is_empty() or current() != "cadilar" or _pos(id).distance_to(door_pos(door)) > 110.0:
		return
	if door.begins_with("p:"):
		var i := int(door.substr(2))
		if i < 0 or i >= Land.plots.size() or int(Land.plots[i].level) < 1 or str(Land.plots[i].get("kind", "home")) != "home":
			return
		if str(Land.plots[i].owner) == Net.players[id].name:
			Net.notify(id, "Kendi kapını çalıp kendine şeker veremezsin!", false)
			return
	var hd := _hd(rec)
	if door in hd.doors:
		Net.notify(id, "Bu kapıyı bugün zaten çaldın.", false)
		return
	hd.doors.append(door)
	if randf() < 0.15:
		Net.notify(id, "Şaka! Kapıyı açan seni korkuttu, şekersiz kaldın. BÖÖ!", false)
		Net.mark_dirty()
		return
	var n := randi_range(1, 3)
	var items: Dictionary = Rpg.ensure(rec).items
	items["seker"] = int(items.get("seker", 0)) + n
	Ach.event(id, "candy", n)
	Rpg.send_sheet(id)
	Net.mark_dirty()
	Net.notify(id, "Şeker mi şaka mı? Şeker! +%d Cadı Şekeri" % n)


@rpc("any_peer", "call_remote", "reliable")
func req_costume(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("k", ""))
	if rec.is_empty() or current() != "cadilar" or _pos(id).distance_to(STALL) > 130.0:
		return
	if k == "":
		rec.erase("costume")
		Net.players[id].erase("costume")
	else:
		if not COSTUMES.has(k):
			return
		if str(rec.get("costume", "")) != k and not Net.try_spend(id, COSTUME_PRICE):
			Net.notify(id, "Kostüm %s." % U.money(COSTUME_PRICE), false)
			return
		rec["costume"] = k
		Net.players[id]["costume"] = k
		Ach.event(id, "costume")
	Net.mark_dirty()
	Net._broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func req_gift(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or current() != "yilbasi":
		return
	var gid := int(d.get("id", -1))
	for g in _gifts:
		if int(g.id) != gid or Vector2(float(g.x), float(g.y)).distance_to(_pos(id)) > 110.0:
			continue
		var hd := _hd(rec)
		if int(hd.gifts) >= 10:
			Net.notify(id, "Bugünlük yeterince hediye topladın, yarın yine gel!", false)
			return
		_gifts.erase(g)
		hd["gifts"] = int(hd.gifts) + 1
		var roll := randf()
		if roll < 0.5:
			var m := randi_range(50, 250)
			Net.add_money(id, m)
			Net.notify(id, "Hediye kutusundan %s çıktı!" % U.money(m))
		else:
			var items: Dictionary = Rpg.ensure(rec).items
			items["kurabiye"] = int(items.get("kurabiye", 0)) + 1
			Rpg.send_sheet(id)
			Net.notify(id, "Hediye kutusundan Yılbaşı Kurabiyesi çıktı!")
		Ach.event(id, "gifts")
		Net.mark_dirty()
		_broadcast_gifts()
		return


@rpc("any_peer", "call_remote", "reliable")
func req_santa(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or current() != "yilbasi" or _pos(id).distance_to(SANTA) > 110.0:
		return
	var hd := _hd(rec)
	var today := Time.get_date_string_from_system()
	if str(hd.santa) == today:
		Net.notify(id, "Ho ho ho! Bugünkü hediyeni aldın, yarın yine gel!", false)
		return
	hd["santa"] = today
	if randf() < 0.35:
		Homes.give(id, "yilbasi_agaci")
		Net.notify(id, "Ho ho ho! Noel Baba sana minik bir Yılbaşı Ağacı verdi (mobilya deponda)!")
	else:
		var m := randi_range(200, 800)
		Net.add_money(id, m)
		Net.notify(id, "Ho ho ho! Noel Baba'dan %s hediye!" % U.money(m))
	Ach.event(id, "santa")
	Net.mark_dirty()


@rpc("any_peer", "call_remote", "reliable")
func req_hand(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var npc := str(d.get("npc", ""))
	if rec.is_empty() or not (current() in ["ramazan", "kurban"]) or not Map.NPCS.has(npc) or _pos(id).distance_to(Map.NPCS[npc].pos) > 110.0:
		return
	var hd := _hd(rec)
	if npc in hd.hands:
		Net.notify(id, "%s'nın elini bu bayram zaten öptün." % Map.NPCS[npc].name, false)
		return
	hd.hands.append(npc)
	Net.add_money(id, 100)
	var items: Dictionary = Rpg.ensure(rec).items
	items["lokum"] = int(items.get("lokum", 0)) + 1
	Rpg.send_sheet(id)
	Ach.event(id, "hands")
	Net.mark_dirty()
	Net.notify(id, "%s: \"Bayramın mübarek olsun evladım!\" +%s harçlık ve lokum." % [Map.NPCS[npc].name, U.money(100)])


@rpc("any_peer", "call_remote", "reliable")
func req_rose_buy(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or current() != "sevgililer" or _pos(id).distance_to(STALL) > 130.0:
		return
	if not Net.try_spend(id, ROSE_PRICE):
		return
	var hd := _hd(rec)
	hd["roses"] = int(hd.roses) + 1
	Net.mark_dirty()
	Net.notify(id, "Bir gül aldın (%d). Bir oyuncunun yanına gidip G ile ver." % int(hd.roses))


@rpc("any_peer", "call_remote", "reliable")
func req_rose(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var to := int(d.get("to", 0))
	if rec.is_empty() or current() != "sevgililer" or not Net.players.has(to) or to == id or _pos(id).distance_to(_pos(to)) > 120.0:
		return
	var hd := _hd(rec)
	if int(hd.roses) <= 0:
		Net.notify(id, "Gülün yok (parktaki tezgâhta %s)." % U.money(ROSE_PRICE), false)
		return
	hd["roses"] = int(hd.roses) - 1
	Rpg.add_xp(to, "", 30)
	Rpg.add_xp(id, "", 30)
	Ach.event(id, "roses")
	Ach.event(to, "roses_got")
	Net.mark_dirty()
	Net.notify(id, "%s'e bir gül verdin ♥" % Net.players[to].name)
	Net.notify(to, "%s sana bir gül verdi ♥" % Net.players[id].name)


func _broadcast_gifts() -> void:
	for id in Net.players:
		Net.tell(self, id, "on_state", {"active": current(), "gifts": _gifts})


func _spawn_gift() -> void:
	# şehirde, kaldırımlarda ve parkta rastgele bir yer
	var spots := [Vector2(randf_range(80, 2700), 383), Vector2(randf_range(80, 2700), 518), Vector2(randf_range(1070, 2780), 870),
		Vector2(randf_range(120, 880), randf_range(1470, 1610)), Vector2(randf_range(100, 2700), randf_range(1680, 1820))]
	var p: Vector2 = spots.pick_random()
	_gifts.append({"id": _uid, "x": snappedf(p.x, 1.0), "y": snappedf(p.y, 1.0)})
	_uid += 1


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 20.0:
		return
	_acc = 0.0
	_check(true)
	if _current == "yilbasi" and _gifts.size() < MAX_GIFTS:
		_spawn_gift()
		_spawn_gift()
		_broadcast_gifts()
