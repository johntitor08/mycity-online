extends Node
## Araçlar: Galeri'den satın alma, binme/inme (F). Sunucu sahipliği, seviyeyi ve yeri doğrular
## (tekne sadece denizde, kara araçları sadece karada, ev içinde araç yok).
## Kimin neye bindiği oyuncu listesindeki "ride" alanıyla herkese yayılır.

signal owned_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const VEHICLES := {
	"bike": {"name": "Bisiklet", "price": 1500, "level": 2, "speed": 1.6, "desc": "Karada 1,6 kat hız"},
	"boat": {"name": "Sürat Teknesi", "price": 6000, "level": 4, "speed": 2.2, "desc": "Denizde hızlı gezinti; teknede de balık tutulur"},
	"car": {"name": "Araba", "price": 12000, "level": 6, "speed": 2.4, "desc": "Karada 2,4 kat hız, senin renginde"},
}

var owned: Array = []        # istemci: sahip olduğum araçlar
var rent_until := 0.0        # istemci: kiralık teknenin bitiş anı (yerel saat)
const RENT_PRICE := 250
const RENT_SECONDS := 600.0
var _rentals := {}           # sunucu: oyuncu adı -> bitiş (unix)


static func speed_of(ride: String) -> float:
	return float(VEHICLES[ride].speed) if VEHICLES.has(ride) else 1.0


## Bu araç bu noktada kullanılabilir mi?
static func usable_at(ride: String, p: Vector2) -> bool:
	if Map.interior_at(p) >= 0:
		return false
	if ride == "boat":
		return Map.in_sea(p)
	return not Map.in_sea(p)


func reset() -> void:
	owned = []


func _list(id: int) -> Array:
	var rec: Dictionary = Net.save_data.players.get(Net.players[id].name, {})
	if not rec.get("vehicles") is Array:
		rec["vehicles"] = []
	return rec["vehicles"]


# ------------------------------------------------------------------ istemci API

func buy(kind: String) -> void:
	Net.ask(self, "req_buy_vehicle", {"kind": kind})


func ride(kind: String, at = null) -> void:
	var d := {"kind": kind}
	if at is Vector2:
		d["pos"] = at       # iskeleden/kıyıdan binerken teknenin suya konduğu nokta
	Net.ask(self, "req_ride", d)


func rent_boat() -> void:
	Net.ask(self, "req_rent")


func has_boat() -> bool:
	return owned.has("boat") or rent_left() > 0.0


func rent_left() -> float:
	return maxf(0.0, rent_until - Time.get_ticks_msec() / 1000.0)


@rpc("authority", "call_local", "reliable")
func on_owned(d: Dictionary) -> void:
	owned = d.get("owned", [])
	var rl := float(d.get("rent_left", 0.0))
	rent_until = Time.get_ticks_msec() / 1000.0 + rl if rl > 0.0 else 0.0
	owned_changed.emit()


# ------------------------------------------------------------------ sunucu

func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_owned", {"owned": _list(id).duplicate(), "rent_left": _rent_left(id)})


func _rent_left(id: int) -> float:
	return maxf(0.0, float(_rentals.get(Net.players[id].name, 0.0)) - Time.get_unix_time_from_system())


## Deniz iskelesinin başında (Kaptan Rüstem) 10 dakikalığına tekne kirala.
@rpc("any_peer", "call_remote", "reliable")
func req_rent(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if Net.positions.get(id, Vector2(-9999, -9999)).distance_to(Map.BOAT_RENT_SPOT) > 220.0:
		Net.notify(id, "Tekne kiralamak için deniz iskelesinin başına git (Kaptan Rüstem).", false)
		return
	if Env.weather == "storm":
		Net.notify(id, "Fırtınada tekne kiralanmıyor!", false)
		return
	if not Net.try_spend(id, RENT_PRICE):
		Net.notify(id, "Kiralık tekne %s." % U.money(RENT_PRICE), false)
		return
	var me: String = Net.players[id].name
	_rentals[me] = maxf(float(_rentals.get(me, 0.0)), Time.get_unix_time_from_system()) + RENT_SECONDS
	send_state(id)
	Net.notify(id, "Tekne %d dakikalığına senin! İskelede F'ye basıp bin, açık denize ve Martı Adası'na açıl." % int(RENT_SECONDS / 60.0))
	Bank.activity("OTO", 1)


@rpc("any_peer", "call_remote", "reliable")
func req_buy_vehicle(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var kind := str(d.get("kind", ""))
	if not VEHICLES.has(kind):
		return
	var v: Dictionary = VEHICLES[kind]
	var b := Map.building("galeri")
	if not b.rect.grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Araç almak için Galeri'ye git.", false)
		return
	var list := _list(id)
	if list.has(kind):
		Net.notify(id, "Bu araç zaten sende.", false)
		return
	if Rpg.level(id) < int(v.level):
		Net.notify(id, "%s için seviye %d gerekli." % [v.name, v.level], false)
		return
	if not Net.try_spend(id, int(v.price)):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	list.append(kind)
	Bank.activity("OTO", 1)
	if kind == "car" or kind == "boat":
		Ach.event(id, kind)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s senin! Binmek için F tuşuna bas." % v.name)
	Net.announce("%s yeni bir %s aldı!" % [Net.players[id].name, v.name])
	Net.log_line("%s %s aldı" % [Net.players[id].name, v.name])


@rpc("any_peer", "call_remote", "reliable")
func req_ride(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var kind := str(d.get("kind", ""))
	if kind != "":
		if not _list(id).has(kind) and not (kind == "boat" and _rent_left(id) > 0.0):
			if kind == "boat":
				Net.notify(id, "Teknen yok. Galeri'den al ya da iskelede kirala.", false)
			return
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
		# iskeleden/kıyıdan binerken tekne yakındaki suya konur
		if kind == "boat" and d.get("pos") is Vector2:
			var q: Vector2 = d.pos
			if q.distance_to(p) < 160.0 and Map.in_sea(q):
				p = q
				Net.positions[id] = q
		if not usable_at(kind, p):
			Net.notify(id, "Tekneye sadece denizde, kara araçlarına sadece karada binilir." if kind == "boat"
				else "Buraya araçla giremezsin.", false)
			return
		if kind == "boat" and Env.weather == "storm":
			Net.notify(id, "Fırtınada denize tekneyle açılamazsın!", false)
			return
	set_ride(id, kind)


## Sunucu: aracı değiştir (eve girerken vb. de kullanılır).
func set_ride(id: int, kind: String) -> void:
	if not Net.players.has(id) or str(Net.players[id].get("ride", "")) == kind:
		return
	Net.players[id]["ride"] = kind
	Net._broadcast_roster()
