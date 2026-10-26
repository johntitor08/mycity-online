extends Node
## Hayvanat bahçesi ve akvaryum (1.5, Fuar bölgesinin altı).
##  Giriş bileti (30 TL, 1 saat): turnikeden geç, aslan, fil, zürafa, penguen, maymun ve ayıları izle.
##  Besleme saati: 8 dakikada bir sırayla bir bölmede; o sırada yanında olan ziyaretçiler XP kazanır.
##  Gönüllü bakıcı: ofisten iş al, yem kovasını söylenen bölmeye götür (her teslim ödeme + XP, 2 enerji).
##  Akvaryum: müzeye bağışlanan balıklar burada canlı yüzer (biletle girilir).
## Veri: rec["zoo_until"]

signal changed
signal task_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const TICKET_PRICE := 30
const TICKET_TIME := 3600.0
const FEED_EVERY := 480.0
const FEED_TIME := 60.0
const KEEPER_PAY := 70
const KEEPER_ENERGY := 2
const ANIMALS := {"aslan": "Aslan", "fil": "Fil", "zurafa": "Zürafa", "penguen": "Penguen", "maymun": "Maymun", "ayi": "Boz Ayı"}

# --- istemci
var ticket_until := 0.0            # yerel saat
var task := ""                     # bakıcı görevi: götürülecek bölme

# --- sunucu
var _tasks := {}                   # id -> bölme
var _fed := {}                     # "bölme:başlangıç" -> {ad: true}


func reset() -> void:
	ticket_until = 0.0
	task = ""
	_tasks.clear()


func on_player_left(id: int) -> void:
	_tasks.erase(id)


func has_ticket() -> bool:
	return ticket_until > Time.get_ticks_msec() / 1000.0


## Şu an besleme saati olan bölme ("" yoksa). Herkeste aynı (sunucu saati).
static func feeding(t: float) -> String:
	var k := fmod(t, FEED_EVERY)
	if k > FEED_TIME:
		return ""
	var keys: Array = ANIMALS.keys()
	return keys[int(t / FEED_EVERY) % keys.size()]


static func pen_front(pen: String) -> Vector2:
	var r: Rect2 = Map.ZOO_PENS[pen]
	return Vector2(r.get_center().x, r.end.y + 26)


# ------------------------------------------------------------------ istemci API

func buy_ticket() -> void:
	Net.ask(self, "req_ticket")


func keeper(start: bool) -> void:
	Net.ask(self, "req_keeper", {"start": start})


func deliver() -> void:
	Net.ask(self, "req_deliver")


func watch_feeding() -> void:
	Net.ask(self, "req_watch")


func visit_aquarium() -> void:
	Net.ask(self, "req_aquarium")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	ticket_until = Time.get_ticks_msec() / 1000.0 + float(d.get("left", 0.0))
	if d.has("task"):
		task = str(d.task)
		task_changed.emit()
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _left(rec: Dictionary) -> float:
	return maxf(0.0, float(rec.get("zoo_until", 0.0)) - Time.get_unix_time_from_system())


func send_state(id: int) -> void:
	var rec := _rec(id)
	if not rec.is_empty():
		Net.tell(self, id, "on_state", {"left": _left(rec), "task": _tasks.get(id, "")})


@rpc("any_peer", "call_remote", "reliable")
func req_ticket(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or _pos(id).distance_to(Map.ZOO_GATE) > 140.0:
		return
	if _left(rec) > 60.0:
		Net.notify(id, "Biletin zaten var (%d dk)." % int(_left(rec) / 60.0), false)
		return
	if not Net.try_spend(id, TICKET_PRICE):
		Net.notify(id, "Bilet %s." % U.money(TICKET_PRICE), false)
		return
	rec["zoo_until"] = Time.get_unix_time_from_system() + TICKET_TIME
	Ach.event(id, "zoo")
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Hayvanat bahçesine hoş geldin! Bilet 1 saat geçerli; akvaryuma da girebilirsin.")


@rpc("any_peer", "call_remote", "reliable")
func req_keeper(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or _pos(id).distance_to(Map.ZOO_KEEPER) > 120.0:
		return
	if bool(d.get("start", true)):
		_new_task(id)
		Net.notify(id, "Gönüllü bakıcılık başladı! Yem kovasını %s bölmesine götür." % ANIMALS[_tasks[id]])
	else:
		_tasks.erase(id)
		send_state(id)


func _new_task(id: int) -> void:
	var keys: Array = ANIMALS.keys()
	var cur: String = _tasks.get(id, "")
	var next: String = keys.pick_random()
	while next == cur:
		next = keys.pick_random()
	_tasks[id] = next
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_deliver(_d: Dictionary) -> void:
	var id := Net.sender()
	if not _tasks.has(id):
		return
	var pen: String = _tasks[id]
	if _pos(id).distance_to(pen_front(pen)) > 110.0:
		return
	if not Rpg.use_energy(id, KEEPER_ENERGY):
		Net.notify(id, "Çok yorgunsun.", false)
		return
	var pay := int(KEEPER_PAY * Events.pay_mult() * (1.15 if Rpg.buff(id, "work") else 1.0))
	Net.add_money(id, pay)
	Rpg.add_xp(id, "", 15)
	Ach.event(id, "keeper")
	Net.notify(id, "%s bölmesine yem verildi: +%s. Sıradaki görev geldi." % [ANIMALS[pen], U.money(pay)])
	_new_task(id)


@rpc("any_peer", "call_remote", "reliable")
func req_watch(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var t := Land.server_now()
	var pen := feeding(t)
	if pen == "" or _pos(id).distance_to(pen_front(pen)) > 160.0:
		return
	var key := "%s:%d" % [pen, int(t / FEED_EVERY)]
	if not _fed.has(key):
		_fed.clear()
		_fed[key] = {}
	var me: String = Net.players[id].name
	if _fed[key].has(me):
		return
	_fed[key][me] = true
	Rpg.add_xp(id, "", 25)
	Ach.event(id, "feeding")
	Net.notify(id, "%s besleme saatini izledin! +25 XP" % ANIMALS[pen])


@rpc("any_peer", "call_remote", "reliable")
func req_aquarium(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not Map.ZOO_BUILDINGS[0].rect.grow(80).has_point(_pos(id)):
		return
	if _left(rec) <= 0.0:
		Net.notify(id, "Akvaryum için hayvanat bahçesi bileti gerekir (turnikede %s)." % U.money(TICKET_PRICE), false)
		return
	Ach.event(id, "aquarium")
