extends Node
## Fabrika (Sanayi bölgesi): üretim bandı. Banttan gelen parçayı (kırmızı / mavi / sarı) doğru kutuya ayır.
## Sunucu her parçanın rengini ve süresini belirler; cevap çok erken (insan dışı) ya da geç gelirse sayılmaz.
## Arka arkaya doğru ayırdıkça seri bonusu artar, bant hızlanır. Üç parçada bir 1 enerji harcar.

signal item(d: Dictionary)
signal result(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const COLORS := ["Kırmızı", "Mavi", "Sarı"]
const BASE_PAY := 10
const MIN_REACT := 0.25
const START_TIME := 3.2
const MIN_TIME := 1.1

var _shift := {}                   # sunucu: id -> {cur: {id, color, sent, window}, combo, count, uid}


func reset() -> void:
	_shift.clear()


func on_player_left(id: int) -> void:
	_shift.erase(id)


# ------------------------------------------------------------------ istemci API

func start() -> void:
	Net.ask(self, "req_start")


func sort(item_id: int, bin: int) -> void:
	Net.ask(self, "req_sort", {"id": item_id, "bin": bin})


func stop() -> void:
	Net.ask(self, "req_stop")


@rpc("authority", "call_local", "reliable")
func on_item(d: Dictionary) -> void:
	item.emit(d)


@rpc("authority", "call_local", "reliable")
func on_result(d: Dictionary) -> void:
	result.emit(d)


# ------------------------------------------------------------------ sunucu

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _at_factory(id: int) -> bool:
	return Map.building("fabrika").rect.grow(80).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


@rpc("any_peer", "call_remote", "reliable")
func req_start(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or Police.is_jailed(id):
		return
	if not _at_factory(id):
		Net.notify(id, "Fabrikada çalışmak için Sanayi bölgesindeki fabrikaya git (feribotla).", false)
		return
	_shift[id] = {"combo": 0, "count": 0, "uid": 1, "cur": {}}
	_next(id)


@rpc("any_peer", "call_remote", "reliable")
func req_stop(_d: Dictionary) -> void:
	_shift.erase(Net.sender())


func _next(id: int) -> void:
	var s: Dictionary = _shift.get(id, {})
	if s.is_empty():
		return
	if int(s.count) % 3 == 0 and int(s.count) > 0 and not Rpg.use_energy(id, 1):
		Net.tell(self, id, "on_result", {"ok": false, "stop": true, "text": "Çok yorgunsun. Bir şeyler ye ya da dinlen."})
		_shift.erase(id)
		return
	var window := maxf(MIN_TIME, START_TIME - 0.08 * int(s.combo))
	s.cur = {"id": int(s.uid), "color": randi() % COLORS.size(), "sent": _now(), "window": window}
	s.uid = int(s.uid) + 1
	Net.tell(self, id, "on_item", {"id": s.cur.id, "color": s.cur.color, "window": window, "combo": int(s.combo)})


@rpc("any_peer", "call_remote", "reliable")
func req_sort(d: Dictionary) -> void:
	var id := Net.sender()
	var s: Dictionary = _shift.get(id, {})
	if s.is_empty() or s.cur.is_empty() or int(d.get("id", -1)) != int(s.cur.id):
		return
	var dt := _now() - float(s.cur.sent)
	var res := {"ok": false, "pay": 0}
	if dt < MIN_REACT:
		res["text"] = "Çok hızlı! Parçayı görmeden ayıramazsın."
		s.combo = 0
	elif dt > float(s.cur.window) + 0.4:
		res["text"] = "Geç kaldın, parça bantın sonuna düştü."
		s.combo = 0
	elif int(d.get("bin", -1)) == int(s.cur.color):
		s.combo = int(s.combo) + 1
		var pay := int((BASE_PAY + mini(int(s.combo), 20)) * Events.pay_mult() * Clans.pay_mult(id) * (1.15 if Rpg.buff(id, "work") else 1.0))
		res = {"ok": true, "pay": pay, "text": "Doğru kutu! +%s (seri %d)" % [U.money(pay), s.combo]}
		Net.add_money(id, pay)
		Rpg.add_xp(id, "", 4)
		Ach.event(id, "factory")
		Bank.activity("MRKT", 1)
	else:
		res["text"] = "Yanlış kutu! O parça %s idi." % COLORS[int(s.cur.color)]
		s.combo = 0
	s.count = int(s.count) + 1
	s.cur = {}
	Net.tell(self, id, "on_result", res)
	get_tree().create_timer(0.35).timeout.connect(_next.bind(id))
