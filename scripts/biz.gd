extends Node
## İşletmeler: boş arsaya ev yerine büfe açılır (büfe → kafe → restoran).
## Sahip malzeme koyar (toptancıdan ya da balık/yiyecekle), fiyatı ve çalışan sayısını ayarlar.
## Her dakika NPC müşteriler gelir (saat, hava, fiyat, puan, çalışanlara göre), kasaya para birikir;
## sahip çevrimdışıyken de çalışır. Kasa işletmede toplanır.
## Veri: plots[i]["kind"] = "biz", plots[i]["biz"] = {stock, price, staff, cash, rating, last_customers}

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const NAMES := ["", "Büfe", "Kafe", "Restoran"]
const BUILD_COST := [0, 2500, 7000, 18000]
const LEVEL_GATE := [0, 2, 5, 9]
const BASE_CUSTOMERS := [0, 3.0, 6.0, 10.0]     # dakikada
const UNIT_PRICE := [0, 12.0, 19.0, 29.0]       # müşteri başına (fiyat çarpanı 1.0'da)
const MAX_STOCK := [0, 400, 800, 1500]
const WAGE := 15                                # çalışan başına dakikalık maaş × seviye
const MAX_STAFF := 3
const WHOLESALE := [10, 60]                     # toptancı: 10 birim 60 TL
const FOOD_UNITS := {"simit": 2, "kahve": 3, "tost": 5, "doner": 10}


static func is_biz(p: Dictionary) -> bool:
	return str(p.get("kind", "home")) == "biz"


static func default_data(owner: String) -> Dictionary:
	return {"name": "%s'in Dükkânı" % owner, "stock": 0, "price": 1.0, "staff": 0, "cash": 0,
		"rating": 3.0, "last_customers": 0}


static func unit_price(p: Dictionary) -> int:
	return int(round(UNIT_PRICE[int(p.level)] * float(p.biz.price)))


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 60.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


# ------------------------------------------------------------------ istemci API

func open(plot: int) -> void:
	Net.ask(self, "req_open", {"plot": plot})


func restock(plot: int, source: String, amount: int = 1) -> void:
	Net.ask(self, "req_restock", {"plot": plot, "source": source, "amount": amount})


func configure(plot: int, price: float, staff: int) -> void:
	Net.ask(self, "req_config", {"plot": plot, "price": price, "staff": staff})


func collect(plot: int) -> void:
	Net.ask(self, "req_collect", {"plot": plot})


# ------------------------------------------------------------------ sunucu

func _owned(id: int, i: int) -> Dictionary:
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size():
		return {}
	var p: Dictionary = Land.plots[i]
	if p.owner != Net.players[id].name:
		return {}
	return p


func _near(id: int, i: int) -> bool:
	return Map.plot_rect(i).grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


## Boş arsaya büfe aç ya da işletmeyi büyüt (Land.req_build bunu çağırır).
func build(id: int, i: int) -> void:
	var p := _owned(id, i)
	if p.is_empty():
		return
	if int(p.level) > 0 and not is_biz(p):
		Net.notify(id, "Bu arsada ev var; işletme için boş arsa gerekir.", false)
		return
	var lvl := int(p.level) + 1
	if lvl > 3:
		Net.notify(id, "İşletme zaten restoran.", false)
		return
	if Rpg.level(id) < LEVEL_GATE[lvl]:
		Net.notify(id, "%s için seviye %d gerekli." % [NAMES[lvl], LEVEL_GATE[lvl]], false)
		return
	if not Net.try_spend(id, BUILD_COST[lvl]):
		Net.notify(id, "%s için %s gerekli." % [NAMES[lvl], U.money(BUILD_COST[lvl])], false)
		return
	p["kind"] = "biz"
	p.level = lvl
	if not p.get("biz") is Dictionary:
		p["biz"] = default_data(Net.players[id].name)
	Net.mark_dirty()
	Land._broadcast()
	Rpg.add_xp(id, "realestate", 120 * lvl)
	Rpg.quest_event(id, "build")
	Story.event(id, "own_biz")
	Net.notify(id, "%s açıldı! Malzeme koy ki müşteriler gelsin." % NAMES[lvl])
	Net.announce("%s şehre yeni bir %s açtı!" % [Net.players[id].name, NAMES[lvl].to_lower()])


@rpc("any_peer", "call_remote", "reliable")
func req_open(d: Dictionary) -> void:
	build(Net.sender(), int(d.get("plot", -1)))


@rpc("any_peer", "call_remote", "reliable")
func req_restock(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	if p.is_empty() or not is_biz(p) or not _near(id, i):
		return
	var b: Dictionary = p.biz
	var room: int = MAX_STOCK[int(p.level)] - int(b.stock)
	if room <= 0:
		Net.notify(id, "Depo dolu.", false)
		return
	var rec: Dictionary = Net.save_data.players[Net.players[id].name]
	var added := 0
	match str(d.get("source", "")):
		"wholesale":
			var packs := clampi(int(d.get("amount", 1)), 1, 20)
			packs = mini(packs, int(ceil(room / float(WHOLESALE[0]))))
			if not Net.try_spend(id, packs * WHOLESALE[1]):
				Net.notify(id, "Yeterli paran yok.", false)
				return
			added = packs * WHOLESALE[0]
		"fish":
			var bag: Array = rec.get("fish", [])
			while not bag.is_empty() and added < room:
				var f: Dictionary = bag.pop_back()
				added += maxi(1, int(int(f.price) / 5.0))
			Jobs.send_inventory(id)
		"food":
			var items: Dictionary = Rpg.ensure(rec).items
			for k in items.keys():
				if FOOD_UNITS.has(k):
					added += FOOD_UNITS[k] * int(items[k])
					items.erase(k)
			Rpg.send_sheet(id)
	if added <= 0:
		Net.notify(id, "Koyacak malzeme yok.", false)
		return
	b["stock"] = mini(int(b.stock) + added, MAX_STOCK[int(p.level)])
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "+%d birim malzeme. Depo: %d/%d" % [added, b.stock, MAX_STOCK[int(p.level)]])


@rpc("any_peer", "call_remote", "reliable")
func req_config(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	if p.is_empty() or not is_biz(p):
		return
	p.biz["price"] = snappedf(clampf(float(d.get("price", 1.0)), 0.5, 2.0), 0.05)
	p.biz["staff"] = clampi(int(d.get("staff", 0)), 0, MAX_STAFF)
	Net.mark_dirty()
	Land._broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_collect(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	if p.is_empty() or not is_biz(p) or not _near(id, i):
		return
	var cash := int(p.biz.cash)
	if cash <= 0:
		Net.notify(id, "Kasa boş.", false)
		return
	p.biz["cash"] = 0
	Net.add_money(id, cash)
	Rpg.add_xp(id, "realestate", mini(300, int(cash / 50.0)))
	Story.event(id, "collect")
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "Kasadan %s alındı." % U.money(cash))


## Dakikalık satış.
func _tick() -> void:
	if not Net.is_server():
		return
	var changed := false
	for i in Land.plots.size():
		var p: Dictionary = Land.plots[i]
		if not is_biz(p) or p.owner == "" or not p.get("biz") is Dictionary:
			continue
		var b: Dictionary = p.biz
		var lvl := int(p.level)
		var f: float = BASE_CUSTOMERS[lvl] * _hour_factor() * _weather_factor(lvl)
		f *= clampf(1.6 - 0.6 * float(b.price), 0.2, 1.3)
		f *= 1.0 + 0.25 * int(b.staff)
		f *= 0.6 + 0.1 * float(b.rating)
		var oid := Net.id_by_name(str(p.owner))
		if oid != 0 and Map.plot_rect(i).grow(80).has_point(Net.positions.get(oid, Vector2(-9999, -9999))):
			f *= 1.3      # patron dükkânda
		var customers := int(floor(f + randf()))
		var served := mini(customers, int(b.stock))
		b["stock"] = int(b.stock) - served
		var revenue := served * unit_price(p)
		var wages := int(b.staff) * WAGE * lvl
		b["cash"] = maxi(0, int(b.cash) + revenue - wages)
		var r := float(b.rating)
		if customers > served:
			r -= 0.05 * (customers - served)      # malzeme bitti: müşteri kaçtı
		elif served > 0:
			r += 0.03
		if float(b.price) > 1.5:
			r -= 0.02
		b["rating"] = clampf(r, 1.0, 5.0)
		b["last_customers"] = served
		changed = true
	if changed:
		Net.mark_dirty()
		Land._broadcast()


func _hour_factor() -> float:
	var h := Env.hour
	if h >= 22.0 or h < 7.0:
		return 0.3
	if h >= 11.0 and h < 14.0:
		return 1.4    # öğle
	if h >= 18.0 and h < 22.0:
		return 1.5    # akşam
	return 1.0


func _weather_factor(lvl: int) -> float:
	match Env.weather:
		"rain":
			return 0.7 if lvl < 3 else 0.9    # restoran kapalı mekân
		"storm":
			return 0.4 if lvl < 3 else 0.75
	return 1.0
