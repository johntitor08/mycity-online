extends Node
## 2.5: yeni arsa yapıları — dükkân (bakkal → süpermarket), pansiyon → otel ve park.
##  Dükkân: sahip toptancıdan mal alır, her dakika NPC müşteriler mal alır (sahip çevrimiçiyken), para kasada birikir.
##  Otel: oyuncular oda tutar (ücret sahibin kasasına, kiracının enerjisi dolar); NPC konuklar da dakikalık gelir getirir.
##  Park: gelir getirmez; yakınındaki arsaların kirası artar (park sahibinin değil, mahallenin kazancı).
## Veri: plots[i]["kind"] = "shop" | "hotel" | "park", plots[i]["yapi"] = {stock, cash, last}

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const KINDS := ["shop", "hotel", "park"]
const NAMES := {"shop": ["", "Bakkal", "Süpermarket"], "hotel": ["", "Pansiyon", "Otel"], "park": ["", "Park"]}
const COST := {"shop": [0, 3000, 9000], "hotel": [0, 4000, 12000], "park": [0, 3000]}
const GATE := {"shop": [0, 3, 7], "hotel": [0, 4, 8], "park": [0, 2]}
const MAX_LEVEL := {"shop": 2, "hotel": 2, "park": 1}

const SHOP_CUSTOMERS := [0, 4.0, 8.0]       # dakikada
const SHOP_PRICE := [0, 8, 12]              # satış başına
const SHOP_MAX_STOCK := [0, 300, 800]
const WHOLESALE := [20, 100]                # toptancı: 20 mal 100 TL
const ROOM_PRICE := [0, 80, 180]
const ROOM_ENERGY := [0, 50.0, 100.0]
const ROOM_COOLDOWN := 600.0                # aynı otelde iki oda arası (sn)
const HOTEL_NPC := [0, 15, 40]              # NPC konuklardan dakikalık gelir
const PARK_RADIUS := 650.0
const PARK_BONUS := 0.15                    # yakındaki arsaların kirası +%15

var _rooms := {}                            # sunucu: "oyuncu:arsa" -> son oda zamanı


static func is_yapi(p: Dictionary) -> bool:
	return str(p.get("kind", "home")) in KINDS


static func name_of(p: Dictionary) -> String:
	var n: Array = NAMES.get(str(p.get("kind", "")), [""])
	return n[clampi(int(p.get("level", 1)), 0, n.size() - 1)]


static func default_data() -> Dictionary:
	return {"stock": 0, "cash": 0, "last": 0}


## Kurulum ve yükseltmelerin toplam maliyeti (satış değeri için).
static func cost_total(p: Dictionary) -> int:
	var c: Array = COST.get(str(p.get("kind", "")), [0])
	var total := 0
	for l in range(1, mini(int(p.get("level", 0)), c.size() - 1) + 1):
		total += int(c[l])
	return total


## Arsanın yakınında başkasına ait bir park var mı? (kira çarpanı)
static func park_mult(i: int, list: Array) -> float:
	var c := Map.plot_rect(i).get_center()
	for k in list.size():
		if k != i and str(list[k].get("kind", "")) == "park" and str(list[k].get("owner", "")) != "":
			if Map.plot_rect(k).get_center().distance_to(c) < PARK_RADIUS:
				return 1.0 + PARK_BONUS
	return 1.0


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 60.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


func reset() -> void:
	_rooms.clear()


# ------------------------------------------------------------------ istemci API

func restock(plot: int, packs: int) -> void:
	Net.ask(self, "req_restock", {"plot": plot, "n": packs})


func collect(plot: int) -> void:
	Net.ask(self, "req_collect", {"plot": plot})


func rent_room(plot: int) -> void:
	Net.ask(self, "req_room", {"plot": plot})


# ------------------------------------------------------------------ sunucu

func _owned(id: int, i: int, kind: String = "") -> Dictionary:
	if i < 0 or i >= Land.plots.size() or not Net.players.has(id):
		return {}
	var p: Dictionary = Land.plots[i]
	if p.owner != Net.players[id].name or not is_yapi(p) or (kind != "" and p.kind != kind):
		return {}
	return p


## Boş arsaya yapı kur ya da yükselt (Land.req_build çağırır; sınırları Land denetler).
func build(id: int, i: int, kind: String) -> void:
	var p: Dictionary = Land.plots[i]
	var lvl := int(p.level) if is_yapi(p) else 0
	if is_yapi(p) and str(p.kind) != kind:
		return
	if lvl >= int(MAX_LEVEL[kind]):
		Net.notify(id, "%s zaten en üst seviyede." % name_of(p), false)
		return
	var gate: int = GATE[kind][lvl + 1]
	if Rpg.level(id) < gate:
		Net.notify(id, "%s için seviye %d gerekli." % [NAMES[kind][lvl + 1], gate], false)
		return
	var cost: int = COST[kind][lvl + 1]
	if not Net.try_spend(id, cost):
		Net.notify(id, "%s için %s gerekli." % [NAMES[kind][lvl + 1], U.money(cost)], false)
		return
	p["kind"] = kind
	p["level"] = lvl + 1
	if not p.get("yapi") is Dictionary:
		p["yapi"] = default_data()
	Net.mark_dirty()
	Land._broadcast()
	Rpg.add_xp(id, "realestate", 100 * (lvl + 1))
	Rpg.quest_event(id, "build")
	var tip: String = {"shop": "Toptancıdan mal al ki müşteriler gelsin.", "hotel": "Oyuncular oda tutabilir; NPC konuklar da gelir.",
		"park": "Yakındaki arsaların kirası %%%d arttı." % int(PARK_BONUS * 100)}[kind]
	Net.notify(id, "%s %s! %s" % [NAMES[kind][lvl + 1], "açıldı" if lvl == 0 else "oldu", tip])


@rpc("any_peer", "call_remote", "reliable")
func req_restock(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i, "shop")
	if p.is_empty():
		return
	var y: Dictionary = p.yapi
	var room := int(SHOP_MAX_STOCK[int(p.level)]) - int(y.stock)
	var packs := clampi(int(d.get("n", 1)), 1, 20)
	packs = mini(packs, int(room / float(WHOLESALE[0])))
	if packs <= 0:
		Net.notify(id, "Depo dolu.", false)
		return
	if not Net.try_spend(id, packs * int(WHOLESALE[1])):
		Net.notify(id, "Mal için %s gerekli." % U.money(packs * int(WHOLESALE[1])), false)
		return
	y["stock"] = int(y.stock) + packs * int(WHOLESALE[0])
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "%d mal depoya kondu." % (packs * int(WHOLESALE[0])))


@rpc("any_peer", "call_remote", "reliable")
func req_collect(d: Dictionary) -> void:
	var id := Net.sender()
	var p := _owned(id, int(d.get("plot", -1)))
	if p.is_empty() or str(p.kind) == "park":
		return
	var cash := int(p.yapi.cash)
	if cash <= 0:
		Net.notify(id, "Kasa boş.", false)
		return
	p.yapi["cash"] = 0
	Net.add_money(id, cash)
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "Kasadan %s aldın." % U.money(cash))


@rpc("any_peer", "call_remote", "reliable")
func req_room(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	if i < 0 or i >= Land.plots.size() or not Net.players.has(id):
		return
	var p: Dictionary = Land.plots[i]
	if str(p.get("kind", "")) != "hotel" or p.owner == "":
		return
	if not Map.plot_rect(i).grow(160).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Otelin önüne gel.", false)
		return
	var key := "%s:%d" % [Net.players[id].name, i]
	var now := Time.get_unix_time_from_system()
	if now - float(_rooms.get(key, 0.0)) < ROOM_COOLDOWN:
		Net.notify(id, "Odan hâlâ hazırlanıyor (%d dk)." % int(ceil((ROOM_COOLDOWN - (now - float(_rooms[key]))) / 60.0)), false)
		return
	var lvl := int(p.level)
	var mine: bool = p.owner == Net.players[id].name
	var price: int = 0 if mine else int(ROOM_PRICE[lvl])
	if price > 0 and not Net.try_spend(id, price):
		Net.notify(id, "Oda %s." % U.money(price), false)
		return
	_rooms[key] = now
	if price > 0:
		p.yapi["cash"] = int(p.yapi.cash) + Election.take_tax(price)
		var oid := Net.id_by_name(str(p.owner))
		if oid != 0:
			Net.notify(oid, "%s %s'nda oda tuttu (+%s kasaya)." % [Net.players[id].name, name_of(p), U.money(price)])
	Rpg.add_energy(id, float(ROOM_ENERGY[lvl]))
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "%s'nda dinlendin: +%d enerji%s" % [name_of(p), int(ROOM_ENERGY[lvl]), "" if price == 0 else " (%s)" % U.money(price)])


func _tick() -> void:
	if not Net.is_server():
		return
	var changed := false
	for i in Land.plots.size():
		var p: Dictionary = Land.plots[i]
		if not is_yapi(p) or p.owner == "" or not p.get("yapi") is Dictionary:
			continue
		if Net.id_by_name(str(p.owner)) == 0:
			continue           # sahibi çevrimdışıyken kapalı (çevrimdışı para kazanılmaz)
		var y: Dictionary = p.yapi
		var lvl := int(p.level)
		match str(p.kind):
			"shop":
				var f: float = SHOP_CUSTOMERS[lvl] * Events.customer_mult()
				var served := mini(int(floor(f + randf())), int(y.stock))
				y["stock"] = int(y.stock) - served
				y["cash"] = int(y.cash) + Election.take_tax(served * int(SHOP_PRICE[lvl]))
				y["last"] = served
				Bank.activity("MRKT", served)
				changed = true
			"hotel":
				var g := int(HOTEL_NPC[lvl])
				y["cash"] = int(y.cash) + Election.take_tax(g)
				y["last"] = g
				changed = true
	if changed:
		Net.mark_dirty()
		Land._broadcast()
