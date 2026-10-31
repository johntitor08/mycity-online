extends Node
## İşletmeler: boş arsaya ev yerine büfe açılır (büfe → kafe → restoran).
## Sahip malzeme koyar (toptancıdan ya da balık/yiyecekle), fiyatı ve çalışan sayısını ayarlar.
## Her dakika NPC müşteriler gelir (saat, hava, fiyat, puan, çalışanlara göre), kasaya para birikir;
## sahip çevrimiçiyken çalışır (2.1: çevrimdışıyken dükkân kapalı). Kasa işletmede toplanır.
## 1.2 Menü: kafe ve restoranda pişirdiğin yemekleri menüye koy, fiyatını belirle. NPC müşteriler menüden
## sipariş verir (fiyat yemeğin değerine göre makulse), oyuncular da gelip yemek yer. Menü çeşidi puanı artırır.
## Veri: plots[i]["kind"] = "biz", plots[i]["biz"] = {stock, price, staff, cash, rating, last_customers,
##       menu: {yemek: {n, price}}, menu_sold, last_menu}

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
const MENU_SLOTS := [0, 0, 3, 8]                 # kafe 3, restoran 8 çeşit yemek
const MENU_CUSTOMERS := [0, 0, 1.5, 3.5]         # dakikada menüden sipariş
const MENU_MAX := 30                            # yemek başına en fazla porsiyon


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


func menu_add(plot: int, dish: String) -> void:
	Net.ask(self, "req_menu", {"plot": plot, "dish": dish, "op": "add"})


func menu_take(plot: int, dish: String) -> void:
	Net.ask(self, "req_menu", {"plot": plot, "dish": dish, "op": "take"})


func menu_price(plot: int, dish: String, price: int) -> void:
	Net.ask(self, "req_menu", {"plot": plot, "dish": dish, "op": "price", "price": price})


func order(plot: int, dish: String) -> void:
	Net.ask(self, "req_order", {"plot": plot, "dish": dish})


static func menu_of(p: Dictionary) -> Dictionary:
	var b: Dictionary = p.get("biz", {})
	return b.get("menu", {}) if b.get("menu") is Dictionary else {}


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
		Net.notify(id, "Bu arsa dolu; işletme için boş arsa gerekir.", false)
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
	Ach.event(id, "biz")
	if lvl == 3:
		Ach.event(id, "restaurant")
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
		"crops":
			var store := Farm.barn(rec)
			for k in store.keys():
				if Farm.item_info(k).is_empty() or Mountain.ORES.has(k) or k in ["odun", "sinekmantari", "kozalak"]:
					continue
				var per := maxi(1, int(Farm.item_info(k).price / 6.0))
				while int(store[k]) > 0 and added < room:
					store[k] = int(store[k]) - 1
					added += per
				if int(store[k]) <= 0:
					store.erase(k)
			Farm.send_state(id)
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


@rpc("any_peer", "call_remote", "reliable")
func req_menu(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	var dish := str(d.get("dish", ""))
	if p.is_empty() or not is_biz(p) or not Kitchen.RECIPES.has(dish):
		return
	var lvl := int(p.level)
	if MENU_SLOTS[lvl] <= 0:
		Net.notify(id, "Menü için işletmeni kafeye büyüt.", false)
		return
	if not _near(id, i):
		Net.notify(id, "Menüyü işletmenin başında düzenle.", false)
		return
	if not p.biz.get("menu") is Dictionary:
		p.biz["menu"] = {}
	var menu: Dictionary = p.biz.menu
	var items: Dictionary = Rpg.ensure(Net.save_data.players[Net.players[id].name]).items
	match str(d.get("op", "")):
		"add":
			if not menu.has(dish) and menu.size() >= MENU_SLOTS[lvl]:
				Net.notify(id, "Menü dolu (en fazla %d çeşit)." % MENU_SLOTS[lvl], false)
				return
			var have := int(items.get(dish, 0))
			var cur: int = int(menu.get(dish, {}).get("n", 0))
			var add := mini(have, MENU_MAX - cur)
			if add <= 0:
				Net.notify(id, "Çantanda %s yok." % Kitchen.RECIPES[dish].name if have <= 0 else "Bu yemekten menüde yeterince var.", false)
				return
			items[dish] = have - add
			if int(items[dish]) <= 0:
				items.erase(dish)
			if not menu.has(dish):
				menu[dish] = {"n": 0, "price": Kitchen.dish_value(dish)}
			menu[dish]["n"] = cur + add
			Net.notify(id, "Menüye %d %s eklendi." % [add, Kitchen.RECIPES[dish].name])
		"take":
			if not menu.has(dish):
				return
			items[dish] = int(items.get(dish, 0)) + int(menu[dish].n)
			menu.erase(dish)
		"price":
			if not menu.has(dish):
				return
			var v := Kitchen.dish_value(dish)
			menu[dish]["price"] = clampi(int(d.get("price", v)), maxi(5, int(v * 0.3)), v * 4)
		_:
			return
	Rpg.send_sheet(id)
	Net.mark_dirty()
	Land._broadcast()


## Oyuncu başkasının (ya da kendi) kafesinde/restoranında yemek yer.
@rpc("any_peer", "call_remote", "reliable")
func req_order(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size():
		return
	var p: Dictionary = Land.plots[i]
	var dish := str(d.get("dish", ""))
	var menu := menu_of(p)
	if not is_biz(p) or not menu.has(dish) or int(menu[dish].n) <= 0:
		return
	if not _near(id, i):
		Net.notify(id, "Sipariş için işletmeye git.", false)
		return
	var me: String = Net.players[id].name
	var price := int(menu[dish].price)
	if p.owner != me:
		if not Net.try_spend(id, price):
			Net.notify(id, "Yeterli paran yok (%s)." % U.money(price), false)
			return
		p.biz["cash"] = int(p.biz.cash) + Election.take_tax(price)
		p.biz["menu_sold"] = int(p.biz.get("menu_sold", 0)) + 1
		Ach.event(id, "ate_out")
		var oid := Net.id_by_name(str(p.owner))
		if oid != 0:
			Ach.event(oid, "menu_sold")
			Net.notify(oid, "%s restoranında %s yedi (+%s kasaya)." % [me, Kitchen.RECIPES[dish].name, U.money(price)])
	menu[dish]["n"] = int(menu[dish].n) - 1
	if int(menu[dish].n) <= 0:
		menu.erase(dish)
	p.biz["rating"] = clampf(float(p.biz.rating) + 0.05, 1.0, 5.0)
	Rpg.eat(id, dish, "afiyetle yedin")
	Net.mark_dirty()
	Land._broadcast()


## Menüden NPC siparişleri (dakikalık). Döner: kasaya giren para.
func _menu_tick(i: int, p: Dictionary, f_common: float) -> int:
	var lvl := int(p.level)
	var menu := menu_of(p)
	if MENU_CUSTOMERS[lvl] <= 0.0 or menu.is_empty():
		p.biz["last_menu"] = 0
		return 0
	var m: float = MENU_CUSTOMERS[lvl] * f_common * (1.0 + 0.12 * (menu.size() - 1))
	var orders := int(floor(m + randf()))
	var revenue := 0
	var sold := 0
	for _o in orders:
		var keys: Array = []
		for k in menu:
			if int(menu[k].n) > 0:
				keys.append(k)
		if keys.is_empty():
			break
		var k: String = keys.pick_random()
		var value := float(Kitchen.dish_value(k))
		var accept := clampf(1.7 - float(menu[k].price) / maxf(1.0, value), 0.05, 1.0)
		if randf() > accept:
			p.biz["rating"] = clampf(float(p.biz.rating) - 0.02, 1.0, 5.0)     # pahalı buldu
			continue
		revenue += int(menu[k].price)
		sold += 1
		menu[k]["n"] = int(menu[k].n) - 1
		if int(menu[k].n) <= 0:
			menu.erase(k)
	p.biz["last_menu"] = sold
	p.biz["menu_sold"] = int(p.biz.get("menu_sold", 0)) + sold
	if sold > 0:
		p.biz["rating"] = clampf(float(p.biz.rating) + 0.04 * sold, 1.0, 5.0)
		var oid := Net.id_by_name(str(p.owner))
		if oid != 0:
			Ach.event(oid, "menu_sold", sold)
	return Election.take_tax(revenue)


## Dakikalık satış.
func _tick() -> void:
	if not Net.is_server():
		return
	var changed := false
	for i in Land.plots.size():
		var p: Dictionary = Land.plots[i]
		if not is_biz(p) or p.owner == "" or not p.get("biz") is Dictionary:
			continue
		if Net.id_by_name(str(p.owner)) == 0:
			continue          # 2.1: sahibi çevrimdışıyken dükkân kapalı (çevrimdışı para kazanılmaz)
		var b: Dictionary = p.biz
		var lvl := int(p.level)
		var f: float = BASE_CUSTOMERS[lvl] * _hour_factor() * _weather_factor(lvl)
		f *= clampf(1.6 - 0.6 * float(b.price), 0.2, 1.3)
		f *= 1.0 + 0.25 * int(b.staff)
		f *= 0.6 + 0.1 * float(b.rating)
		f *= Events.customer_mult()
		var oid := Net.id_by_name(str(p.owner))
		if oid != 0 and Map.plot_rect(i).grow(80).has_point(Net.positions.get(oid, Vector2(-9999, -9999))):
			f *= 1.3      # patron dükkânda
		var menu_cash := _menu_tick(i, p, _hour_factor() * _weather_factor(lvl) * (1.0 + 0.25 * int(b.staff)) * (0.6 + 0.1 * float(b.rating)) * Events.customer_mult())
		b["cash"] = int(b.cash) + menu_cash
		var customers := int(floor(f + randf()))
		var served := mini(customers, int(b.stock))
		b["stock"] = int(b.stock) - served
		var revenue := Election.take_tax(served * unit_price(p))
		Bank.activity("MRKT", served)
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
