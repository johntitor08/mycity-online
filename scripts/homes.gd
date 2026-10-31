extends Node
## Ev içi ve mobilya. Ev (küçük ev/villa/gökdelen) olan her arsanın harita dışında bir odası vardır.
## Mobilyalar Mobilyacı'dan alınır, oyuncunun deposuna (rec["furniture"]) gider, odaya ızgara
## üzerinde yerleştirilir (plots[i]["furniture"]). Kapı kilitliyse sadece sahibi girebilir.
## Yatağın üstünde durmak enerjiyi hızlı doldurur (Rpg), lamba gece ışık verir (dünya sahnesi).

signal depot_changed
signal teleported(pos: Vector2)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

# size: karo (48 birim) cinsinden; floor: üstüne başka mobilya konabilen (halı)
const FURNITURE := {
	"bed": {"name": "Yatak", "price": 2000, "size": Vector2i(2, 3), "desc": "Üstünde dur: enerji çok hızlı dolar"},
	"sofa": {"name": "Koltuk Takımı", "price": 1500, "size": Vector2i(3, 1)},
	"armchair": {"name": "Berjer", "price": 600, "size": Vector2i(1, 1)},
	"table": {"name": "Yemek Masası", "price": 800, "size": Vector2i(2, 2)},
	"chair": {"name": "Sandalye", "price": 200, "size": Vector2i(1, 1)},
	"tv": {"name": "Televizyon", "price": 2500, "size": Vector2i(2, 1)},
	"plant": {"name": "Saksı Bitkisi", "price": 150, "size": Vector2i(1, 1)},
	"rug": {"name": "Halı", "price": 300, "size": Vector2i(3, 2), "floor": true},
	"bookshelf": {"name": "Kitaplık", "price": 900, "size": Vector2i(2, 1)},
	"fridge": {"name": "Buzdolabı", "price": 1800, "size": Vector2i(1, 1)},
	"lamp": {"name": "Lambader", "price": 400, "size": Vector2i(1, 1), "desc": "Gece odayı aydınlatır"},
	"aquarium": {"name": "Akvaryum", "price": 3000, "size": Vector2i(2, 1)},
	"desk": {"name": "Bilgisayar Masası", "price": 3500, "size": Vector2i(2, 1)},
	"stove": {"name": "Ocak ve Tezgâh", "price": 1200, "size": Vector2i(2, 1), "desc": "Evde yemek pişirmeni sağlar"},
	# 1.4: lunapark ödülleri (satılmaz; ödül standında biletle alınır)
	"pelus_ayi": {"name": "Peluş Ayı", "price": 250, "size": Vector2i(1, 1), "prize": true},
	"pelus_zurafa": {"name": "Dev Peluş Zürafa", "price": 500, "size": Vector2i(1, 2), "prize": true},
	"lunapark_feneri": {"name": "Lunapark Feneri", "price": 800, "size": Vector2i(1, 1), "prize": true, "desc": "Gece renkli ışık saçar"},
	"yilbasi_agaci": {"name": "Yılbaşı Ağacı", "price": 600, "size": Vector2i(1, 2), "prize": true},
}
const MAX_PER_ROOM := 40
const SELL_BACK := 0.5          # Mobilyacı kullanılmayan mobilyayı yarı fiyatına geri alır

var depot: Dictionary = {}      # istemci: depomdaki mobilyalar {tür: adet}


func reset() -> void:
	depot = {}


static func furniture_rect(i: int, level: int, f: Dictionary) -> Rect2:
	var r := Map.interior_rect(i, level)
	var sz: Vector2i = FURNITURE[f.k].size
	return Rect2(r.position + Vector2(int(f.x), int(f.y)) * Map.TILE, Vector2(sz) * Map.TILE)


## Oyuncu bir yatağın üstünde mi? (Rpg enerji için kullanır)
static func on_bed(plots: Array, p: Vector2) -> bool:
	var i := Map.interior_at(p)
	if i < 0 or i >= plots.size():
		return false
	var plot: Dictionary = plots[i]
	for f in plot.get("furniture", []):
		if f.k == "bed" and furniture_rect(i, int(plot.level), f).grow(6).has_point(p):
			return true
	return false


func _depot_of(id: int) -> Dictionary:
	var rec: Dictionary = Net.save_data.players.get(Net.players[id].name, {})
	if not rec.get("furniture") is Dictionary:
		rec["furniture"] = {}
	return rec["furniture"]


func _depot_by_name(player_name: String) -> Dictionary:
	var rec: Dictionary = Net.save_data.players.get(player_name, {})
	if not rec.get("furniture") is Dictionary:
		rec["furniture"] = {}
	return rec["furniture"]


## Bu oyuncu bu odada bulunabilir mi? (Net.send_pos izinsiz girişi engeller)
func may_be_in(id: int, i: int) -> bool:
	if i < 0 or i >= Land.plots.size():
		return false
	var p: Dictionary = Land.plots[i]
	if int(p.level) < 1 or p.owner == "" or str(p.get("kind", "home")) != "home":
		return false
	return p.owner == Net.players[id].name or bool(p.get("door_open", false)) or Family.spouse_of(id) == p.owner


# ------------------------------------------------------------------ istemci API

func buy(k: String) -> void:
	Net.ask(self, "req_buy_furniture", {"k": k})


func sell_back(k: String) -> void:
	Net.ask(self, "req_sell_furniture", {"k": k})


func enter(plot: int) -> void:
	Net.ask(self, "req_enter", {"plot": plot})


func exit_home() -> void:
	Net.ask(self, "req_exit")


func place(plot: int, k: String, x: int, y: int) -> void:
	Net.ask(self, "req_place", {"plot": plot, "k": k, "x": x, "y": y})


func pickup(plot: int, index: int) -> void:
	Net.ask(self, "req_pickup", {"plot": plot, "index": index})


func set_door(plot: int, open: bool) -> void:
	Net.ask(self, "req_door", {"plot": plot, "open": open})


@rpc("authority", "call_local", "reliable")
func on_depot(d: Dictionary) -> void:
	depot = d.get("depot", {})
	depot_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_teleport(d: Dictionary) -> void:
	teleported.emit(d.pos)


# ------------------------------------------------------------------ sunucu

func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_depot", {"depot": _depot_of(id).duplicate()})


func _teleport(id: int, pos: Vector2) -> void:
	Net.positions[id] = pos
	Net.tell(self, id, "on_teleport", {"pos": pos})


@rpc("any_peer", "call_remote", "reliable")
func req_buy_furniture(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var k := str(d.get("k", ""))
	if not FURNITURE.has(k) or FURNITURE[k].get("prize", false):
		return
	if not Map.at_building("mobilya", Net.positions.get(id, Vector2(-9999, -9999)), 60):
		Net.notify(id, "Mobilya almak için Mobilyacı'ya git.", false)
		return
	if not Net.try_spend(id, int(FURNITURE[k].price)):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	var dep := _depot_of(id)
	dep[k] = int(dep.get(k, 0)) + 1
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s deponda. Evine girip yerleştirebilirsin." % FURNITURE[k].name)


## Ödül olarak mobilya ver (lunapark ödül standı).
func give(id: int, k: String) -> void:
	if not FURNITURE.has(k) or not Net.players.has(id):
		return
	var dep := _depot_of(id)
	dep[k] = int(dep.get(k, 0)) + 1
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_sell_furniture(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var k := str(d.get("k", ""))
	var dep := _depot_of(id)
	if not FURNITURE.has(k) or int(dep.get(k, 0)) <= 0:
		return
	if not Map.at_building("mobilya", Net.positions.get(id, Vector2(-9999, -9999)), 60):
		Net.notify(id, "Geri satmak için Mobilyacı'ya git.", false)
		return
	dep[k] = int(dep[k]) - 1
	if int(dep[k]) <= 0:
		dep.erase(k)
	var refund := int(int(FURNITURE[k].price) * SELL_BACK)
	Net.add_money(id, refund)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s geri satıldı: +%s" % [FURNITURE[k].name, U.money(refund)])


@rpc("any_peer", "call_remote", "reliable")
func req_enter(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size():
		return
	var plot: Dictionary = Land.plots[i]
	if int(plot.level) < 1 or str(plot.get("kind", "home")) != "home":
		Net.notify(id, "Bu arsada girilecek bir ev yok.", false)
		return
	if not Map.plot_rect(i).grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		return
	if not may_be_in(id, i):
		Net.notify(id, "Kapı kilitli. Ev sahibi kapıyı açarsa girebilirsin.", false)
		return
	Garage.set_ride(id, "")
	_teleport(id, Map.interior_spawn(i, int(plot.level)))


@rpc("any_peer", "call_remote", "reliable")
func req_exit(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var i := Map.interior_at(Net.positions.get(id, Vector2.ZERO))
	if i >= 0:
		_teleport(id, Map.plot_front(i))


@rpc("any_peer", "call_remote", "reliable")
func req_place(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var k := str(d.get("k", ""))
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size() or not FURNITURE.has(k):
		return
	var plot: Dictionary = Land.plots[i]
	if plot.owner != Net.players[id].name or int(plot.level) < 1:
		return
	var dep := _depot_of(id)
	if int(dep.get(k, 0)) <= 0:
		Net.notify(id, "Deponda %s yok." % FURNITURE[k].name, false)
		return
	if not plot.get("furniture") is Array:
		plot["furniture"] = []
	var list: Array = plot.furniture
	if list.size() >= MAX_PER_ROOM:
		Net.notify(id, "Oda dolu.", false)
		return
	var f := {"k": k, "x": int(d.get("x", 0)), "y": int(d.get("y", 0))}
	var room := Map.interior_rect(i, int(plot.level))
	var fr := furniture_rect(i, int(plot.level), f)
	if not room.encloses(fr):
		Net.notify(id, "Mobilya odaya sığmıyor.", false)
		return
	if not FURNITURE[k].get("floor", false):
		if fr.intersects(Map.interior_door(i, int(plot.level)).grow(-2)):
			Net.notify(id, "Kapının önüne koyamazsın.", false)
			return
		for other in list:
			if not FURNITURE[other.k].get("floor", false) and fr.intersects(furniture_rect(i, int(plot.level), other).grow(-1)):
				Net.notify(id, "Orada başka bir eşya var.", false)
				return
	dep[k] = int(dep[k]) - 1
	if int(dep[k]) <= 0:
		dep.erase(k)
	list.append(f)
	Net.mark_dirty()
	send_state(id)
	Land._broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_pickup(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var idx := int(d.get("index", -1))
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size():
		return
	var plot: Dictionary = Land.plots[i]
	var list: Array = plot.get("furniture", [])
	if plot.owner != Net.players[id].name or idx < 0 or idx >= list.size():
		return
	var f: Dictionary = list.pop_at(idx)
	var dep := _depot_of(id)
	dep[f.k] = int(dep.get(f.k, 0)) + 1
	Net.mark_dirty()
	send_state(id)
	Land._broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_door(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size():
		return
	var plot: Dictionary = Land.plots[i]
	if plot.owner != Net.players[id].name:
		return
	plot["door_open"] = bool(d.get("open", false))
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "Kapı artık %s." % ("açık: herkes girebilir" if plot.door_open else "kilitli"))
	if not plot.door_open:
		_evict(i, plot.owner)


## Sahibi dışındakileri dışarı çıkar (kapı kilitlenince ya da arsa el değiştirince).
func _evict(i: int, keep_name: String) -> void:
	for pid in Net.players:
		if Net.players[pid].name != keep_name and Map.interior_at(Net.positions.get(pid, Vector2.ZERO)) == i:
			_teleport(pid, Map.plot_front(i))
			Net.notify(pid, "Ev sahibi kapıyı kilitledi.", false)


## Arsa satılınca / el değiştirince: mobilyalar eski sahibin deposuna döner, içerdekiler çıkar.
func clear_plot(i: int, old_owner: String) -> void:
	var plot: Dictionary = Land.plots[i]
	if old_owner != "":
		var dep := _depot_by_name(old_owner)
		for f in plot.get("furniture", []):
			dep[f.k] = int(dep.get(f.k, 0)) + 1
		var oid := Net.id_by_name(old_owner)
		if oid != 0:
			send_state(oid)
	plot["furniture"] = []
	plot["door_open"] = false
	for pid in Net.players:
		if Map.interior_at(Net.positions.get(pid, Vector2.ZERO)) == i:
			_teleport(pid, Map.plot_front(i))
