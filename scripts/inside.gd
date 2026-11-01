extends Node
## 2.3: kurum iç mekanları (hastane, market, karakol, banka, kaplıca...). Binanın kapısında E ile girilir;
## içeride görevlinin tezgâhında binanın her zamanki penceresi açılır. Odalar harita dışında (Map.INST_AREA)
## ve herkese açık; sunucu denetimleri (Map.at_building) binanın önünü de içini de kabul eder.

const Map = preload("res://scripts/map.gd")


const InsideView = preload("res://scripts/world_inside.gd")
const POOL_TICK := 4.0                  # kaplıca havuzunda 4 sn'de 1 enerji
var _pool_acc := 0.0


## Kaplıca havuzunda bekleyen yavaşça dinlenir (tezgâhtaki ücretli hizmet anında doldurur).
func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_pool_acc += delta
	if _pool_acc < POOL_TICK:
		return
	_pool_acc = 0.0
	for id in Net.players:
		if InsideView.in_pool(_pos(id)):
			Rpg.add_energy(id, 1.0)


func enter(type: String) -> void:
	Net.ask(self, "req_enter", {"t": type})


func leave() -> void:
	Net.ask(self, "req_leave")


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


@rpc("any_peer", "call_remote", "reliable")
func req_enter(d: Dictionary) -> void:
	var id := Net.sender()
	var t := str(d.get("t", ""))
	if not Net.players.has(id) or not t in Map.INST_TYPES:
		return
	var b := Map.any_building(t)
	if b.is_empty() or not (b.rect as Rect2).grow(80).has_point(_pos(id)):
		return
	Garage.set_ride(id, "")
	Homes._teleport(id, Map.inst_spawn(t))


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary = {}) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var t := Map.inst_at(_pos(id))
	if t != "":
		Homes._teleport(id, Map.inst_exit(t))
