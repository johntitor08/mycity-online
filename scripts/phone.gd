extends Node
## Telefon (1.3): kalıcı mesajlar (çevrimdışı oyuncuya da ulaşır), arkadaş listesi, şehir haberleri.
## Konum gizliliği: bir arkadaşın nerede olduğunu sadece karşılıklı arkadaşsanız görürsün.
## Fotoğraf modu ve albüm istemcidedir (user://album); sunucu sadece başarım için sayar.
## Veri: save_data["inbox"] = {ad: [{w: karşı taraf, o: giden mi, x: metin, d: unix, r: okundu}]}
##       save_data["news"] = [{d: unix, x: metin}],  rec["friends"] = [ad, ...]

signal changed
signal message(d: Dictionary)

const Map = preload("res://scripts/map.gd")

const INBOX_MAX := 80
const NEWS_MAX := 40
const MSG_LEN := 240

# --- istemci
var inbox: Array = []
var friends: Array = []            # [{n, online, mutual, area, pos?}]
var news: Array = []
var unread := 0


func reset() -> void:
	inbox = []
	friends = []
	news = []
	unread = 0


# ------------------------------------------------------------------ istemci API

func send(to: String, text: String) -> void:
	Net.ask(self, "req_send", {"to": to, "text": text})


func read_all(with: String) -> void:
	Net.ask(self, "req_read", {"w": with})


func add_friend(n: String) -> void:
	Net.ask(self, "req_friend", {"n": n, "add": true})


func remove_friend(n: String) -> void:
	Net.ask(self, "req_friend", {"n": n, "add": false})


func refresh() -> void:
	Net.ask(self, "req_state")


func photo_taken() -> void:
	Net.ask(self, "req_photo")


## Konuşmalar: karşı tarafa göre gruplanmış, en yeni üstte.
func conversations() -> Array:
	var by := {}
	for m in inbox:
		var w := str(m.w)
		if not by.has(w):
			by[w] = {"w": w, "last": m, "unread": 0}
		by[w].last = m
		if not m.get("o", false) and not m.get("r", false):
			by[w].unread += 1
	var out: Array = by.values()
	out.sort_custom(func(a, b): return float(a.last.d) > float(b.last.d))
	return out


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	inbox = d.get("inbox", inbox)
	friends = d.get("friends", friends)
	news = d.get("news", news)
	unread = 0
	for m in inbox:
		if not m.get("o", false) and not m.get("r", false):
			unread += 1
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_message(d: Dictionary) -> void:
	inbox.append(d)
	if not d.get("o", false):
		unread += 1
		message.emit(d)
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _box(n: String) -> Array:
	if not Net.save_data.get("inbox") is Dictionary:
		Net.save_data["inbox"] = {}
	if not Net.save_data.inbox.get(n) is Array:
		Net.save_data.inbox[n] = []
	return Net.save_data.inbox[n]


func _friends_of(n: String) -> Array:
	var rec: Dictionary = Net.save_data.players.get(n, {})
	if not rec.get("friends") is Array:
		rec["friends"] = []
	return rec.friends


## Oyuncunun bulunduğu yerin adı (arkadaş listesi için).
static func where(p: Vector2) -> String:
	if Map.MOUNTAIN.has_point(p):
		return "Dağ"
	if Map.SEA_BED.has_point(p):
		return "Deniz altı"
	if Map.JAIL.has_point(p):
		return "Karakol (hapiste)"
	if Map.INTERIOR_AREA.has_point(p):
		return "bir evin içinde"
	return Map.area_name(p)


func send_state(id: int) -> void:
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var fl: Array = []
	for n in _friends_of(me):
		var fid := Net.id_by_name(n)
		var mutual: bool = me in _friends_of(n)
		var e := {"n": n, "online": fid != 0, "mutual": mutual}
		if fid != 0 and mutual:
			var p: Vector2 = Net.positions.get(fid, Vector2.ZERO)
			e["area"] = where(p)
			if Map.WORLD.has_point(p):
				e["pos"] = p
		fl.append(e)
	Net.tell(self, id, "on_state", {"inbox": _box(me).slice(-INBOX_MAX), "friends": fl, "news": news_list()})


func news_list() -> Array:
	if not Net.save_data.get("news") is Array:
		Net.save_data["news"] = []
	return Net.save_data.news


## Net.announce çağırır: şehir haberleri.
func add_news(text: String) -> void:
	if not Net.is_server():
		return
	var n := news_list()
	n.append({"d": Time.get_unix_time_from_system(), "x": text.left(200)})
	while n.size() > NEWS_MAX:
		n.pop_front()
	Net.mark_dirty()


@rpc("any_peer", "call_remote", "reliable")
func req_state(_d: Dictionary) -> void:
	send_state(Net.sender())


@rpc("any_peer", "call_remote", "reliable")
func req_send(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var to := Net._account_key(str(d.get("to", "")).strip_edges())
	var text := str(d.get("text", "")).strip_edges().replace("[", "(").replace("]", ")").left(MSG_LEN)
	if text == "":
		return
	if not Net.save_data.players.has(to) or to == me:
		Net.notify(id, "Böyle bir oyuncu yok.", false)
		return
	if float(Net._muted.get(me, 0.0)) > Time.get_unix_time_from_system():
		Net.notify(id, "Susturuldun; bir süre mesaj atamazsın.", false)
		return
	var now := Time.get_unix_time_from_system()
	var inc := {"w": me, "o": false, "x": text, "d": now, "r": false}
	var out := {"w": to, "o": true, "x": text, "d": now, "r": true}
	for pair in [[to, inc], [me, out]]:
		var box := _box(pair[0])
		box.append(pair[1])
		while box.size() > INBOX_MAX:
			box.pop_front()
	Net.mark_dirty()
	Ach.event(id, "messages")
	Net.tell(self, id, "on_message", out)
	var tid := Net.id_by_name(to)
	if tid != 0:
		Net.tell(self, tid, "on_message", inc)


@rpc("any_peer", "call_remote", "reliable")
func req_read(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var w := str(d.get("w", ""))
	for m in _box(Net.players[id].name):
		if str(m.w) == w:
			m["r"] = true
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_friend(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var n := Net._account_key(str(d.get("n", "")).strip_edges())
	var fl := _friends_of(me)
	if bool(d.get("add", true)):
		if not Net.save_data.players.has(n) or n == me:
			Net.notify(id, "Böyle bir oyuncu yok.", false)
			return
		if n in fl:
			return
		if fl.size() >= 50:
			Net.notify(id, "Arkadaş listen dolu (50).", false)
			return
		fl.append(n)
		Ach.set_max(id, "friends", fl.size())
		var tid := Net.id_by_name(n)
		if tid != 0 and not me in _friends_of(n):
			Net.notify(tid, "%s seni arkadaş listesine ekledi. Sen de eklersen birbirinizin yerini görebilirsiniz." % me)
		Net.notify(id, "%s arkadaş listene eklendi." % n)
	else:
		fl.erase(n)
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_photo(_d: Dictionary) -> void:
	Ach.event(Net.sender(), "photos")
