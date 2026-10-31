extends Node
## 2.3: kurum iç mekanları (hastane, market, karakol, banka, kaplıca...). Binanın kapısında E ile girilir;
## içeride görevlinin tezgâhında binanın her zamanki penceresi açılır. Odalar harita dışında (Map.INST_AREA)
## ve herkese açık; sunucu denetimleri (Map.at_building) binanın önünü de içini de kabul eder.

const Map = preload("res://scripts/map.gd")


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
