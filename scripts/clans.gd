extends Node
## Klanlar: oyuncular klan kurar ya da katılır. Ortak kasa (herkes yatırır, lider çeker),
## klan puanı (üyelerin kazandığı XP ve etkinlik zaferleri), klan seviyesi (üyelere maaş bonusu)
## ve klanlar arası sıralama. Klan sohbeti Net.req_chat'in "clan" kanalıdır.
## Veri: save_data["clans"] = {ETİKET: {name, tag, leader, members, bank, points, open, requests, color}}
##       rec["clan"] = ETİKET

signal changed

const U = preload("res://scripts/util.gd")

const CREATE_COST := 5000
const CREATE_LEVEL := 3
const MAX_MEMBERS := 10
const MAX_LEVEL := 10
const COLORS := ["#f87171", "#fb923c", "#facc15", "#4ade80", "#2dd4bf", "#60a5fa", "#a78bfa", "#f472b6"]

var mine: Dictionary = {}         # istemci: kendi klanım (yoksa {})
var ranking: Array = []           # istemci: [{tag, name, points, level, members, open}]


static func level_of(points: int) -> int:
	return mini(MAX_LEVEL, int(floor(sqrt(points / 200.0))) + 1)


static func points_for(level: int) -> int:
	return 200 * (level - 1) * (level - 1)


## Klan seviyesi başına maaş bonusu: Sv.1 %0 ... Sv.10 %18
static func level_bonus(level: int) -> float:
	return 0.02 * (level - 1)


func reset() -> void:
	mine = {}
	ranking = []


# ------------------------------------------------------------------ istemci API

func create(clan_name: String, tag: String) -> void:
	Net.ask(self, "req_create", {"name": clan_name, "tag": tag})


func join(tag: String) -> void:
	Net.ask(self, "req_join", {"tag": tag})


func leave() -> void:
	Net.ask(self, "req_leave")


func accept(player_name: String, yes: bool = true) -> void:
	Net.ask(self, "req_accept", {"name": player_name, "yes": yes})


func kick(player_name: String) -> void:
	Net.ask(self, "req_kick", {"name": player_name})


func deposit(amount: int) -> void:
	Net.ask(self, "req_bank", {"amount": amount})


func withdraw(amount: int) -> void:
	Net.ask(self, "req_bank", {"amount": -amount})


func set_open(open: bool) -> void:
	Net.ask(self, "req_open", {"open": open})


@rpc("authority", "call_local", "reliable")
func on_clan(d: Dictionary) -> void:
	mine = d.get("clan", {})
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_ranking(d: Dictionary) -> void:
	ranking = d.get("list", [])
	changed.emit()


# ------------------------------------------------------------------ sunucu: veri

func _store() -> Dictionary:
	if not Net.save_data.get("clans") is Dictionary:
		Net.save_data["clans"] = {}
	return Net.save_data["clans"]


func _rec_by_name(player_name: String) -> Dictionary:
	return Net.save_data.players.get(player_name, {})


func tag_of_name(player_name: String) -> String:
	var t := str(_rec_by_name(player_name).get("clan", ""))
	return t if _store().has(t) else ""


func clan_of(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return _store().get(tag_of_name(Net.players[id].name), {})


## Maaş çarpanı (Jobs/Police): klan seviyesine göre.
func pay_mult(id: int) -> float:
	var c := clan_of(id)
	return 1.0 + (level_bonus(level_of(int(c.points))) if not c.is_empty() else 0.0)


## Üye XP kazanınca klana puan (XP'nin onda biri).
func on_xp(id: int, amount: int) -> void:
	var c := clan_of(id)
	if c.is_empty() or amount < 10:
		return
	add_points(str(c.tag), int(amount / 10.0))


func add_points(tag: String, n: int) -> void:
	var c: Dictionary = _store().get(tag, {})
	if c.is_empty() or n <= 0:
		return
	var old := level_of(int(c.points))
	c["points"] = int(c.points) + n
	Net.mark_dirty()
	if level_of(int(c.points)) > old:
		Net.announce("[%s] %s klanı %d. seviyeye ulaştı!" % [tag, c.name, level_of(int(c.points))])
	_dirty_tags[tag] = true


var _dirty_tags := {}
var _acc := 0.0


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 3.0:
		return
	_acc = 0.0
	if _dirty_tags.is_empty():
		return
	for t in _dirty_tags:
		_send_clan(t)
	_dirty_tags.clear()
	_broadcast_ranking()


## Oyuncu listesindeki klan etiketini güncelle.
func refresh_roster(id: int) -> void:
	if not Net.players.has(id):
		return
	var t := tag_of_name(Net.players[id].name)
	var col := ""
	if t != "":
		col = COLORS[int(_store()[t].get("color", 0)) % COLORS.size()]
	if Net.players[id].get("clan", "") != t or Net.players[id].get("clan_color", "") != col:
		Net.players[id]["clan"] = t
		Net.players[id]["clan_color"] = col
		Net._broadcast_roster()


func online_members(tag: String) -> Array:
	var out: Array = []
	var c: Dictionary = _store().get(tag, {})
	if c.is_empty():
		return out
	for m in c.members:
		var mid := Net.id_by_name(m)
		if mid != 0:
			out.append(mid)
	return out


func _summary(c: Dictionary) -> Dictionary:
	var members: Array = []
	for m in c.members:
		members.append({"name": m, "online": Net.id_by_name(m) != 0, "leader": m == c.leader})
	var lvl := level_of(int(c.points))
	return {"tag": c.tag, "name": c.name, "leader": c.leader, "members": members, "bank": int(c.bank),
		"points": int(c.points), "level": lvl, "cur": points_for(lvl), "next": points_for(lvl + 1),
		"open": bool(c.open), "requests": c.requests.duplicate(), "color": COLORS[int(c.get("color", 0)) % COLORS.size()]}


func _send_clan(tag: String) -> void:
	var c: Dictionary = _store().get(tag, {})
	if c.is_empty():
		return
	var s := _summary(c)
	for mid in online_members(tag):
		Net.tell(self, mid, "on_clan", {"clan": s})


func _ranking() -> Array:
	var list: Array = []
	for t in _store():
		var c: Dictionary = _store()[t]
		list.append({"tag": t, "name": c.name, "points": int(c.points), "level": level_of(int(c.points)),
			"members": c.members.size(), "open": bool(c.open)})
	list.sort_custom(func(a, b): return int(a.points) > int(b.points))
	return list


func _broadcast_ranking() -> void:
	Net.tell_all(self, "on_ranking", {"list": _ranking()})


func send_state(id: int) -> void:
	var c := clan_of(id)
	Net.tell(self, id, "on_clan", {"clan": _summary(c) if not c.is_empty() else {}})
	Net.tell(self, id, "on_ranking", {"list": _ranking()})
	refresh_roster(id)


## Üyeliği değişen oyuncunun kaydını ve görünümünü güncelle.
func _set_member(player_name: String, tag: String) -> void:
	var rec := _rec_by_name(player_name)
	if rec.is_empty():
		return
	if tag == "":
		rec.erase("clan")
	else:
		rec["clan"] = tag
	var pid := Net.id_by_name(player_name)
	if pid != 0:
		send_state(pid)
	Net.mark_dirty()


static func clean_tag(t: String) -> String:
	var out := ""
	for ch in t.strip_edges().to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in "ÇĞİÖŞÜ":
			out += ch
	return out.left(4)


# ------------------------------------------------------------------ sunucu: istekler

@rpc("any_peer", "call_remote", "reliable")
func req_create(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	if tag_of_name(me) != "":
		Net.notify(id, "Zaten bir klandasın.", false)
		return
	var tag := clean_tag(str(d.get("tag", "")))
	var cname := str(d.get("name", "")).strip_edges().replace("[", "").replace("]", "").left(20)
	if tag.length() < 2 or cname.length() < 3:
		Net.notify(id, "Etiket 2-4 harf/rakam, isim en az 3 harf olmalı.", false)
		return
	if _store().has(tag):
		Net.notify(id, "[%s] etiketi alınmış." % tag, false)
		return
	if Rpg.level(id) < CREATE_LEVEL:
		Net.notify(id, "Klan kurmak için seviye %d gerekli." % CREATE_LEVEL, false)
		return
	if not Net.try_spend(id, CREATE_COST):
		Net.notify(id, "Klan kurmak için %s gerekli." % U.money(CREATE_COST), false)
		return
	_store()[tag] = {"name": cname, "tag": tag, "leader": me, "members": [me], "bank": 0, "points": 0,
		"open": true, "requests": [], "color": _store().size() % COLORS.size()}
	_set_member(me, tag)
	_broadcast_ranking()
	Net.announce("%s yeni bir klan kurdu: [%s] %s" % [me, tag, cname])
	Net.log_line("Klan kuruldu: [%s] %s (%s)" % [tag, cname, me])


@rpc("any_peer", "call_remote", "reliable")
func req_join(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var tag := str(d.get("tag", ""))
	var c: Dictionary = _store().get(tag, {})
	if c.is_empty():
		return
	if tag_of_name(me) != "":
		Net.notify(id, "Önce mevcut klanından ayrıl.", false)
		return
	if c.members.size() >= MAX_MEMBERS:
		Net.notify(id, "Klan dolu (%d üye)." % MAX_MEMBERS, false)
		return
	if not bool(c.open):
		if not c.requests.has(me):
			c.requests.append(me)
			Net.mark_dirty()
			_send_clan(tag)
			var lid := Net.id_by_name(c.leader)
			if lid != 0:
				Net.notify(lid, "%s klanına katılmak istiyor (Klan penceresinden onayla)." % me)
		Net.notify(id, "Başvurun [%s] liderine iletildi." % tag)
		return
	_add_member(c, me)


func _add_member(c: Dictionary, player_name: String) -> void:
	c.requests.erase(player_name)
	if not c.members.has(player_name):
		c.members.append(player_name)
	_set_member(player_name, c.tag)
	_send_clan(c.tag)
	_broadcast_ranking()
	_clan_message(c.tag, "%s klana katıldı. Hoş geldin!" % player_name)


func _clan_message(tag: String, text: String) -> void:
	for mid in online_members(tag):
		Net.tell(Net, mid, "on_chat", {"name": "Klan", "text": text, "color": Color("#4ade80"), "ch": "clan"})


@rpc("any_peer", "call_remote", "reliable")
func req_accept(d: Dictionary) -> void:
	var id := Net.sender()
	var c := clan_of(id)
	if c.is_empty() or c.leader != Net.players[id].name:
		return
	var who := str(d.get("name", ""))
	if not c.requests.has(who):
		return
	if not bool(d.get("yes", true)):
		c.requests.erase(who)
		Net.mark_dirty()
		_send_clan(c.tag)
		return
	if tag_of_name(who) != "" or c.members.size() >= MAX_MEMBERS:
		c.requests.erase(who)
		Net.notify(id, "%s eklenemedi (başka klanda ya da klan dolu)." % who, false)
		_send_clan(c.tag)
		return
	_add_member(c, who)


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	var id := Net.sender()
	var c := clan_of(id)
	if c.is_empty():
		return
	_remove(c, Net.players[id].name)
	Net.notify(id, "[%s] klanından ayrıldın." % c.tag)


@rpc("any_peer", "call_remote", "reliable")
func req_kick(d: Dictionary) -> void:
	var id := Net.sender()
	var c := clan_of(id)
	var who := str(d.get("name", ""))
	if c.is_empty() or c.leader != Net.players[id].name or who == c.leader or not c.members.has(who):
		return
	_remove(c, who)
	var wid := Net.id_by_name(who)
	if wid != 0:
		Net.notify(wid, "[%s] klanından çıkarıldın." % c.tag, false)


func _remove(c: Dictionary, player_name: String) -> void:
	c.members.erase(player_name)
	_set_member(player_name, "")
	if c.members.is_empty():
		# son üye ayrıldı: klan dağılır, kasa ona kalır
		Net.add_money_by_name(player_name, int(c.bank))
		_store().erase(c.tag)
		Net.announce("[%s] %s klanı dağıldı." % [c.tag, c.name])
	else:
		if c.leader == player_name:
			c.leader = c.members[0]
			_clan_message(c.tag, "Yeni lider: %s" % c.leader)
		_clan_message(c.tag, "%s klandan ayrıldı." % player_name)
		_send_clan(c.tag)
	Net.mark_dirty()
	_broadcast_ranking()


@rpc("any_peer", "call_remote", "reliable")
func req_bank(d: Dictionary) -> void:
	var id := Net.sender()
	var c := clan_of(id)
	if c.is_empty():
		return
	var amount := int(d.get("amount", 0))
	var me: String = Net.players[id].name
	if amount > 0:
		if not Net.try_spend(id, amount):
			Net.notify(id, "Yeterli paran yok.", false)
			return
		c["bank"] = int(c.bank) + amount
		_clan_message(c.tag, "%s kasaya %s yatırdı." % [me, U.money(amount)])
	elif amount < 0:
		if c.leader != me:
			Net.notify(id, "Kasadan sadece lider para çekebilir.", false)
			return
		var take := mini(-amount, int(c.bank))
		if take <= 0:
			Net.notify(id, "Kasada para yok.", false)
			return
		c["bank"] = int(c.bank) - take
		Net.add_money(id, take)
		_clan_message(c.tag, "Lider kasadan %s çekti." % U.money(take))
	Net.mark_dirty()
	_send_clan(c.tag)
	Net.log_line("Klan kasası [%s]: %s %+d TL" % [c.tag, me, amount])


@rpc("any_peer", "call_remote", "reliable")
func req_open(d: Dictionary) -> void:
	var id := Net.sender()
	var c := clan_of(id)
	if c.is_empty() or c.leader != Net.players[id].name:
		return
	c["open"] = bool(d.get("open", true))
	Net.mark_dirty()
	_send_clan(c.tag)
	_broadcast_ranking()


## Oyuncu girince/çıkınca üyelerin "çevrimiçi" listesi güncellensin.
func on_presence(player_name: String) -> void:
	var t := tag_of_name(player_name)
	if t != "":
		_dirty_tags[t] = true
