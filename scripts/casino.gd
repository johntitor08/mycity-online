extends Node
## Kumarhane: rulet, zar ve at yarışı bahisleri. Sonucu sunucu belirler,
## kazanç animasyon bittiğinde hesaba geçer.

signal result(d: Dictionary)

const U = preload("res://scripts/util.gd")

const MIN_BET := 10
const MAX_BET := 50000
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const HORSES := [
	{"name": "Rüzgar", "odds": 2.5, "p": 0.37},
	{"name": "Yıldırım", "odds": 3.5, "p": 0.26},
	{"name": "Karayel", "odds": 5.0, "p": 0.18},
	{"name": "Tarçın", "odds": 8.0, "p": 0.11},
	{"name": "Şahbatur", "odds": 12.0, "p": 0.08},
]
const DELAY := {"roulette": 3.0, "dice": 1.5, "horse": 5.0}


func roulette(bet: int, kind: String, num: int = 0) -> void:
	Net.ask(self, "req_roulette", {"bet": bet, "kind": kind, "num": num})


func dice(bet: int, kind: String) -> void:
	Net.ask(self, "req_dice", {"bet": bet, "kind": kind})


func horse(bet: int, index: int) -> void:
	Net.ask(self, "req_horse", {"bet": bet, "horse": index})


func _take_bet(d: Dictionary) -> int:
	if not multiplayer.is_server():
		return 0
	var id := Net.sender()
	var bet := int(d.get("bet", 0))
	if not Net.players.has(id):
		return 0
	if bet < MIN_BET or bet > MAX_BET:
		Net.notify(id, "Bahis %d ile %d arasında olmalı." % [MIN_BET, MAX_BET], false)
		return 0
	if not Net.try_spend(id, bet):
		Net.notify(id, "Yeterli paran yok.", false)
		return 0
	Rpg.add_xp(id, "", clampi(bet / 50, 1, 20))
	Rpg.quest_event(id, "bet")
	return bet


func _finish(id: int, game: String, bet: int, payout: int, data: Dictionary, label: String) -> void:
	data["game"] = game
	data["bet"] = bet
	data["payout"] = payout
	data["delay"] = DELAY[game]
	Net.tell(self, id, "on_result", data)
	if payout > 0:
		var pname: String = Net.players[id].name
		get_tree().create_timer(DELAY[game]).timeout.connect(func():
			Net.add_money_by_name(pname, payout)
			if payout - bet >= 5000:
				Net.announce("%s %s oyununda %s kazandı!" % [pname, label, U.money(payout - bet)])
		)


@rpc("any_peer", "call_remote", "reliable")
func req_roulette(d: Dictionary) -> void:
	var bet := _take_bet(d)
	if bet == 0:
		return
	var id := Net.sender()
	var n := randi_range(0, 36)
	var color := "green" if n == 0 else ("red" if RED.has(n) else "black")
	var mult := 0
	match str(d.get("kind", "")):
		"red":
			mult = 2 if color == "red" else 0
		"black":
			mult = 2 if color == "black" else 0
		"even":
			mult = 2 if n != 0 and n % 2 == 0 else 0
		"odd":
			mult = 2 if n % 2 == 1 else 0
		"num":
			mult = 36 if n == int(d.get("num", -1)) else 0
	_finish(id, "roulette", bet, bet * mult, {"n": n, "color": color}, "rulet")


@rpc("any_peer", "call_remote", "reliable")
func req_dice(d: Dictionary) -> void:
	var bet := _take_bet(d)
	if bet == 0:
		return
	var id := Net.sender()
	var a := randi_range(1, 6)
	var b := randi_range(1, 6)
	var sum := a + b
	var mult := 0
	match str(d.get("kind", "")):
		"under":
			mult = 2 if sum < 7 else 0
		"seven":
			mult = 5 if sum == 7 else 0
		"over":
			mult = 2 if sum > 7 else 0
	_finish(id, "dice", bet, bet * mult, {"a": a, "b": b}, "zar")


@rpc("any_peer", "call_remote", "reliable")
func req_horse(d: Dictionary) -> void:
	var pick := int(d.get("horse", -1))
	if pick < 0 or pick >= HORSES.size():
		return
	var bet := _take_bet(d)
	if bet == 0:
		return
	var id := Net.sender()
	var r := randf()
	var winner := HORSES.size() - 1
	for i in HORSES.size():
		r -= HORSES[i].p
		if r <= 0.0:
			winner = i
			break
	var payout := int(bet * HORSES[pick].odds) if winner == pick else 0
	_finish(id, "horse", bet, payout, {"winner": winner, "pick": pick}, "at yarışı")


@rpc("authority", "call_local", "reliable")
func on_result(d: Dictionary) -> void:
	result.emit(d)
