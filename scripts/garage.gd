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


func ride(kind: String) -> void:
	Net.ask(self, "req_ride", {"kind": kind})


@rpc("authority", "call_local", "reliable")
func on_owned(d: Dictionary) -> void:
	owned = d.get("owned", [])
	owned_changed.emit()


# ------------------------------------------------------------------ sunucu

func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_owned", {"owned": _list(id).duplicate()})


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
		if not _list(id).has(kind):
			return
		var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
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
