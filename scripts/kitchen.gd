extends Node
## Mutfak: evine Ocak koyan oyuncu, ambarındaki ürünlerle (ekin, yumurta, süt) ve kovadaki balıkla yemek pişirir.
## Yemekler çantaya (Rpg eşyaları) girer; yenince bol enerji ve bazıları geçici bonus verir:
##  work: iş maaşları +%15, luck: nadir balık şansı +%25, xp: XP +%10.

signal cooked(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

# malzemeler: ambardaki ürünler; "balik" = kovadaki en ucuz balık
const RECIPES := {
	"menemen": {"name": "Menemen", "needs": {"domates": 2, "yumurta": 2}, "energy": 60, "buff": ["work", 600]},
	"izgara": {"name": "Izgara Balık", "needs": {"balik": 1, "domates": 1}, "energy": 70, "buff": ["luck", 600]},
	"sutlac": {"name": "Sütlaç", "needs": {"sut": 2, "bugday": 1}, "energy": 50, "buff": ["xp", 600]},
	"corba": {"name": "Mısır Çorbası", "needs": {"misir": 2, "sut": 1}, "energy": 55},
	"salata": {"name": "Mevsim Salatası", "needs": {"domates": 1, "lahana": 1}, "energy": 40},
	"kabak_tatlisi": {"name": "Kabak Tatlısı", "needs": {"kabak": 1}, "energy": 60},
	"borek": {"name": "Su Böreği", "needs": {"bugday": 3, "yumurta": 1, "sut": 1}, "energy": 80, "buff": ["work", 900]},
	"pasta": {"name": "Çilekli Pasta", "needs": {"cilek": 3, "yumurta": 2, "sut": 1, "bugday": 2}, "energy": 100, "buff": ["xp", 900]},
}
const BUFF_NAMES := {"work": "İş maaşı +%15", "luck": "Nadir balık +%25", "xp": "XP +%10"}


static func ing_name(k: String) -> String:
	if k == "balik":
		return "Balık"
	var info: Dictionary = Farm.item_info(k)
	return str(info.get("name", k))


## Yemeğin piyasa değeri (malzemelerin Hal fiyatı + işçilik). Restoran fiyatları buna göre değerlendirilir.
static func dish_value(k: String) -> int:
	if not RECIPES.has(k):
		return 0
	var sum := 0.0
	for ing in RECIPES[k].needs:
		var unit := 60.0 if ing == "balik" else float(Farm.item_info(ing).get("price", 10))
		sum += unit * int(RECIPES[k].needs[ing])
	return int(round((sum + 15.0) * 1.6))


## Oyuncu kendi kafesinin/restoranının mutfağında mı? (kafe ve restoranda da yemek pişirilir)
static func at_own_restaurant(id: int) -> int:
	if not Net.players.has(id):
		return -1
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	for i in mini(Land.plots.size(), Map.PLOT_COUNT):
		var pl: Dictionary = Land.plots[i]
		if Biz.is_biz(pl) and int(pl.level) >= 2 and pl.owner == Net.players[id].name and Map.plot_rect(i).grow(60).has_point(p):
			return i
	return -1


## Bu evde ocak var mı?
static func has_stove(p: Dictionary) -> bool:
	for f in p.get("furniture", []):
		if str(f.get("k", "")) == "stove":
			return true
	return false


func cook(recipe: String) -> void:
	Net.ask(self, "req_cook", {"r": recipe})


@rpc("any_peer", "call_remote", "reliable")
func req_cook(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var k := str(d.get("r", ""))
	if not RECIPES.has(k):
		return
	var room := Map.interior_at(Net.positions.get(id, Vector2(-9999, -9999)))
	var at_home: bool = room >= 0 and room < Land.plots.size() and Land.plots[room].owner == Net.players[id].name and has_stove(Land.plots[room])
	if not at_home and at_own_restaurant(id) < 0:
		Net.notify(id, "Yemek için evinde ocak olmalı (Mobilyacı'da satılır) ya da kendi kafende/restoranında ol.", false)
		return
	var rec: Dictionary = Net.save_data.players[Net.players[id].name]
	var store := Farm.barn(rec)
	var bag: Array = rec.get("fish", [])
	var r: Dictionary = RECIPES[k]
	for ing in r.needs:
		var have := bag.size() if ing == "balik" else int(store.get(ing, 0))
		if have < int(r.needs[ing]):
			Net.notify(id, "%s için %d %s gerekli." % [r.name, int(r.needs[ing]), ing_name(ing)], false)
			return
	var items: Dictionary = Rpg.ensure(rec).items
	if int(items.get(k, 0)) >= Rpg.MAX_FOOD_STACK:
		Net.notify(id, "Çantanda yeterince %s var." % r.name, false)
		return
	for ing in r.needs:
		if ing == "balik":
			for _n in int(r.needs[ing]):
				var cheapest := 0
				for j in bag.size():
					if int(bag[j].price) < int(bag[cheapest].price):
						cheapest = j
				bag.remove_at(cheapest)
			Jobs.send_inventory(id)
		else:
			store[ing] = int(store[ing]) - int(r.needs[ing])
			if int(store[ing]) <= 0:
				store.erase(ing)
	items[k] = int(items.get(k, 0)) + 1
	Net.mark_dirty()
	Farm.send_state(id)
	Rpg.send_sheet(id)
	Rpg.add_xp(id, "", 20)
	Ach.event(id, "cooked")
	Net.notify(id, "%s pişti! Çantanda: yiyince +%d enerji%s." % [r.name, int(r.energy),
		(", " + BUFF_NAMES[r.buff[0]]) if r.has("buff") else ""])
