extends Node
## Arsalar: satın alma, inşaat, satış ve dakikalık kira geliri (sunucu yetkili).

signal plots_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const LEVEL_NAMES := ["Boş arsa", "Küçük ev", "Villa", "Gökdelen"]
const BUILD_COST := [0, 1500, 5000, 15000]   # o seviyeye çıkma maliyeti
const LEVEL_INCOME := [0, 25, 80, 250]       # dakikalık ek kira
const INCOME_INTERVAL := 60.0
const SELL_RATIO := 0.7
const MAX_PER_PLAYER := 6

var plots: Array = []   # sunucu: [{owner, level, price}]
var view: Array = []    # herkes: sunucudan gelen kopya
var _clock_offset := 0.0  # sunucu saati - yerel saat (tarla süreleri için)
var _timer: Timer


static func income_of(p: Dictionary) -> int:
	if Biz.is_biz(p) or Farm.is_farm(p) or Farm.is_ranch(p):
		return 0          # işletme, tarla ve ahır kira değil satış/hasat geliri getirir
	return int(int(p.price) * 0.006) + LEVEL_INCOME[int(p.level)]


## Arsadaki yapının adı (ev/villa/gökdelen ya da büfe/kafe/restoran).
static func building_name(p: Dictionary) -> String:
	if Farm.is_farm(p):
		return "Tarla"
	if Farm.is_ranch(p):
		return "Ahır"
	return Biz.NAMES[int(p.level)] if Biz.is_biz(p) else LEVEL_NAMES[int(p.level)]


static func sell_value(p: Dictionary) -> int:
	var total := int(p.price)
	if Farm.is_farm(p):
		return int((total + Farm.BUILD_COST) * SELL_RATIO)
	if Farm.is_ranch(p):
		var val := total + Farm.RANCH_COST
		for a in p.get("ranch", {}).get("animals", []):
			val += int(Farm.ANIMALS.get(str(a.k), {}).get("price", 0)) / 2
		return int(val * SELL_RATIO)
	var costs: Array = Biz.BUILD_COST if Biz.is_biz(p) else BUILD_COST
	for l in range(1, int(p.level) + 1):
		total += costs[l]
	return int(total * SELL_RATIO)


func reset() -> void:
	plots.clear()
	view.clear()
	if _timer:
		_timer.stop()
	plots_changed.emit()


func server_init() -> void:
	plots.clear()
	var saved = Net.save_data.get("plots", [])
	for i in Map.PLOT_COUNT:
		var p := {"owner": "", "level": 0, "price": Map.PLOT_PRICES[i]}
		if saved is Array and i < saved.size() and saved[i] is Dictionary:
			p.owner = str(saved[i].get("owner", ""))
			p.level = clampi(int(saved[i].get("level", 0)), 0, 3)
			p["door_open"] = bool(saved[i].get("door_open", false))
			if str(saved[i].get("kind", "home")) == "biz" and saved[i].get("biz") is Dictionary:
				p["kind"] = "biz"
				var b: Dictionary = Biz.default_data(p.owner)
				for k in b:
					if saved[i].biz.has(k):
						b[k] = saved[i].biz[k]
				p["biz"] = b
			elif str(saved[i].get("kind", "home")) == "farm" and saved[i].get("farm") is Dictionary:
				p["kind"] = "farm"
				var beds: Array = []
				var old = saved[i].farm.get("beds", [])
				for k in Farm.BEDS:
					var b: Dictionary = Farm.empty_bed()
					if old is Array and k < old.size() and old[k] is Dictionary and Farm.CROPS.has(str(old[k].get("c", ""))):
						for key in b:
							if old[k].has(key):
								b[key] = old[k][key]
					beds.append(b)
				p["farm"] = {"beds": beds}
			for key in ["party_until", "guestbook", "rating", "tint"]:
				if saved[i].has(key):
					p[key] = saved[i][key]
			if str(saved[i].get("kind", "home")) == "ranch" and saved[i].get("ranch") is Dictionary:
				p["kind"] = "ranch"
				var animals: Array = []
				for a in saved[i].ranch.get("animals", []):
					if a is Dictionary and Farm.ANIMALS.has(str(a.get("k", ""))):
						animals.append({"k": str(a.k), "fed": float(a.get("fed", 0.0)), "last": float(a.get("last", 0.0))})
				p["ranch"] = {"animals": animals}
			if saved[i].get("sec") is Dictionary:
				p["sec"] = {"lock": bool(saved[i].sec.get("lock", false)), "alarm": bool(saved[i].sec.get("alarm", false))}
			var furn: Array = []
			if saved[i].get("furniture") is Array:
				for f in saved[i].furniture:
					if f is Dictionary and Homes.FURNITURE.has(str(f.get("k", ""))):
						furn.append({"k": str(f.k), "x": int(f.get("x", 0)), "y": int(f.get("y", 0))})
			p["furniture"] = furn
		plots.append(p)
	if _timer == null:
		_timer = Timer.new()
		add_child(_timer)
		_timer.timeout.connect(_pay_rent)
	_timer.start(INCOME_INTERVAL)


func _pay_rent() -> void:
	if not Net.is_server():
		return
	var totals := {}
	for p in plots:
		if p.owner != "":
			totals[p.owner] = totals.get(p.owner, 0) + income_of(p)
	for owner in totals:
		totals[owner] = Election.take_tax(int(totals[owner] * Rpg.rent_mult_by_name(owner)))
		Net.add_money_by_name(owner, totals[owner])
		var id := Net.id_by_name(owner)
		if id != 0:
			Net.notify(id, "Kira geliri: +%s" % U.money(totals[owner]))


func _owned_count(owner: String) -> int:
	var n := 0
	for p in plots:
		if p.owner == owner:
			n += 1
	return n


func _check(d: Dictionary) -> int:
	if not multiplayer.is_server():
		return -1
	var i := int(d.get("i", -1))
	if not Net.players.has(Net.sender()) or i < 0 or i >= plots.size():
		return -1
	return i


# ------------------------------------------------------------------ istemci API

func buy(i: int) -> void:
	Net.ask(self, "req_buy", {"i": i})


func build_up(i: int, kind: String = "home") -> void:
	Net.ask(self, "req_build", {"i": i, "kind": kind})


func sell(i: int) -> void:
	Net.ask(self, "req_sell", {"i": i})


# 1.1: ev / dükkân dış rengi
const TINTS := [Color("#ffffff"), Color("#fecaca"), Color("#fed7aa"), Color("#fef08a"), Color("#bbf7d0"),
	Color("#bae6fd"), Color("#c7d2fe"), Color("#f5d0fe"), Color("#d6d3d1")]
const TINT_NAMES := ["Doğal", "Gül", "Şeftali", "Limon", "Nane", "Gök", "Lavanta", "Leylak", "Taş"]
const TINT_PRICE := 500


func set_tint(i: int, idx: int) -> void:
	Net.ask(self, "req_tint", {"i": i, "idx": idx})


@rpc("any_peer", "call_remote", "reliable")
func req_tint(d: Dictionary) -> void:
	var i := _check(d)
	if i < 0:
		return
	var id := Net.sender()
	var p: Dictionary = plots[i]
	var idx := clampi(int(d.get("idx", 0)), 0, TINTS.size() - 1)
	if p.owner != Net.players[id].name or int(p.level) < 1 or Farm.is_farm(p):
		return
	if not Map.plot_rect(i).grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Boyamak için arsanın yanına git.", false)
		return
	if int(p.get("tint", 0)) == idx:
		return
	if not Net.try_spend(id, TINT_PRICE):
		Net.notify(id, "Boya %s." % U.money(TINT_PRICE), false)
		return
	p["tint"] = idx
	Net.mark_dirty()
	_broadcast()
	Ach.event(id, "custom")
	Net.notify(id, "Binan %s renge boyandı!" % TINT_NAMES[idx])


# ------------------------------------------------------------------ sunucu

@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var i := _check(d)
	if i < 0:
		return
	var id := Net.sender()
	var pname: String = Net.players[id].name
	var p: Dictionary = plots[i]
	if p.owner != "":
		Net.notify(id, "Bu arsa zaten satılmış.", false)
		return
	if _owned_count(pname) >= MAX_PER_PLAYER:
		Net.notify(id, "En fazla %d arsan olabilir." % MAX_PER_PLAYER, false)
		return
	if not Net.try_spend(id, int(p.price)):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	p.owner = pname
	p.level = 0
	Net.mark_dirty()
	_broadcast()
	Rpg.add_xp(id, "realestate", 50)
	Bank.activity("EMLK", 1)
	Rpg.quest_event(id, "build")
	Story.send_state(id)
	Net.announce("%s, %d numaralı arsayı %s karşılığında satın aldı!" % [pname, i + 1, U.money(int(p.price))])


@rpc("any_peer", "call_remote", "reliable")
func req_build(d: Dictionary) -> void:
	var i := _check(d)
	if i < 0:
		return
	var id := Net.sender()
	var p: Dictionary = plots[i]
	if p.owner != Net.players[id].name:
		return
	if Farm.is_farm(p) or Farm.is_ranch(p):
		Net.notify(id, "Tarla ve ahır büyütülemez; satıp başka bir şey kurabilirsin.", false)
		return
	if int(p.level) == 0 and str(d.get("kind", "home")) == "ranch":
		Farm.build_ranch(id, i)
		return
	if int(p.level) == 0 and str(d.get("kind", "home")) == "farm":
		Farm.build(id, i)
		return
	if Biz.is_biz(p) or (int(p.level) == 0 and str(d.get("kind", "home")) == "biz"):
		Biz.build(id, i)
		return
	if int(p.level) >= 3:
		Net.notify(id, "Bu arsa zaten en üst seviyede.", false)
		return
	var gate: int = [0, 1, Rpg.LEVEL_GATES.villa, Rpg.LEVEL_GATES.tower][int(p.level) + 1]
	if Rpg.level(id) < gate:
		Net.notify(id, "%s inşa etmek için seviye %d gerekli." % [LEVEL_NAMES[int(p.level) + 1], gate], false)
		return
	var cost: int = BUILD_COST[int(p.level) + 1]
	if not Net.try_spend(id, cost):
		Net.notify(id, "İnşaat için %s gerekli." % U.money(cost), false)
		return
	p.level = int(p.level) + 1
	Net.mark_dirty()
	_broadcast()
	Rpg.add_xp(id, "realestate", 100 * int(p.level))
	Bank.activity("EMLK", 1)
	if int(p.level) == 3:
		Ach.event(id, "tower")
	Rpg.quest_event(id, "build")
	Net.notify(id, "%s inşa edildi! Yeni kira: %s/dk" % [building_name(p), U.money(income_of(p))])


@rpc("any_peer", "call_remote", "reliable")
func req_sell(d: Dictionary) -> void:
	var i := _check(d)
	if i < 0:
		return
	var id := Net.sender()
	var p: Dictionary = plots[i]
	if p.owner != Net.players[id].name:
		return
	var value := sell_value(p)
	if Biz.is_biz(p) and p.get("biz") is Dictionary:
		value += int(p.biz.cash)      # kasadaki para da sahibine
	p.erase("biz")
	p.erase("farm")
	p.erase("ranch")
	p.erase("sec")
	p.erase("guestbook")
	p.erase("rating")
	p.erase("party_until")
	p.erase("tint")
	p["kind"] = "home"
	Bazaar.drop_plot_listing(i)
	Homes.clear_plot(i, str(p.owner))
	p.owner = ""
	p.level = 0
	Net.add_money(id, value)
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "Arsa satıldı: +%s" % U.money(value))


func _broadcast() -> void:
	Net.tell_all(self, "on_plots", {"plots": plots, "now": Time.get_unix_time_from_system()})


func send_state(id: int) -> void:
	Net.tell(self, id, "on_plots", {"plots": plots, "now": Time.get_unix_time_from_system()})


## İstemci: sunucunun şu anki saati (unix).
func server_now() -> float:
	return Time.get_unix_time_from_system() + _clock_offset


@rpc("authority", "call_local", "reliable")
func on_plots(d: Dictionary) -> void:
	if d.has("now"):
		_clock_offset = float(d.now) - Time.get_unix_time_from_system()
	view = d.plots.duplicate(true)
	plots_changed.emit()
