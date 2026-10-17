extends Node
## Texas Hold'em masası. Bütün kurallar (dağıtım, körler, bahis turları,
## yan potlar, el karşılaştırma) sunucuda işlenir; istemciler yalnızca
## herkese açık masa görünümünü ve kendi kartlarını alır.

signal table_changed
signal my_cards_changed

const MAX_SEATS := 6
const SMALL_BLIND := 10
const BIG_BLIND := 20
const MIN_BUYIN := 200
const MAX_BUYIN := 10000
const BOT_BUYIN := 1500
const TURN_TIME := 25.0
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["♠", "♥", "♦", "♣"]
const HAND_NAMES := ["Yüksek Kart", "Per", "Döper", "Üçlü", "Kent", "Floş", "Ful", "Kare", "Renk Kent"]
const BOT_NAMES := ["Bot Ahmet", "Bot Ayşe", "Bot Mehmet", "Bot Zeynep", "Bot Can", "Bot Elif", "Bot Kaan", "Bot Derya"]

# --- sunucu durumu ---
var seats: Array = []
var deck: Array = []
var board: Array = []
var stage := "idle"          # idle, preflop, flop, turn, river, showdown
var dealer := -1
var turn := -1
var current_bet := 0
var min_raise := BIG_BLIND
var turn_deadline := 0.0
var next_hand_at := 0.0
var runout_at := 0.0
var bot_act_at := 0.0
var message := ""
var log_lines: Array = []
var _bot_counter := 0

# --- istemci görünümü ---
var view: Dictionary = {}
var my_cards: Array = []
var deadline_local := 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	seats.clear()
	for i in MAX_SEATS:
		seats.append(null)
	deck.clear()
	board.clear()
	log_lines.clear()
	stage = "idle"
	dealer = -1
	turn = -1
	current_bet = 0
	next_hand_at = 0.0
	runout_at = 0.0
	message = ""
	view = {}
	my_cards = []


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ================================================================== kart yardımcıları

static func suit_of(c: int) -> int:
	return int(c / 13.0)


static func card_text(c: int) -> String:
	return RANKS[c % 13] + SUITS[suit_of(c)]


static func card_bb(c: int) -> String:
	var red := suit_of(c) == 1 or suit_of(c) == 2
	return "[bgcolor=#f4f4f4][color=%s] %s [/color][/bgcolor]" % ["#c81e1e" if red else "#111111", card_text(c)]


## 5 kartlık eli puanlar: [kategori, eşitlik bozucular...] (büyük olan kazanır)
static func eval5(cards: Array) -> Array:
	var ranks: Array = []
	var suits: Array = []
	for c in cards:
		ranks.append(c % 13)
		suits.append(suit_of(c))
	ranks.sort()
	ranks.reverse()
	var flush := true
	for s in suits:
		if s != suits[0]:
			flush = false
	var counts := {}
	for r in ranks:
		counts[r] = counts.get(r, 0) + 1
	var groups: Array = []
	for r in counts:
		groups.append([counts[r], r])
	groups.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var straight_high := -1
	if groups.size() == 5:
		if ranks[0] - ranks[4] == 4:
			straight_high = ranks[0]
		elif ranks[0] == 12 and ranks[1] == 3:   # A-2-3-4-5
			straight_high = 3
	if straight_high >= 0 and flush:
		return [8, straight_high]
	if groups[0][0] == 4:
		return [7, groups[0][1], groups[1][1]]
	if groups[0][0] == 3 and groups[1][0] == 2:
		return [6, groups[0][1], groups[1][1]]
	if flush:
		return [5] + ranks
	if straight_high >= 0:
		return [4, straight_high]
	if groups[0][0] == 3:
		return [3, groups[0][1], groups[1][1], groups[2][1]]
	if groups[0][0] == 2 and groups[1][0] == 2:
		return [2, groups[0][1], groups[1][1], groups[2][1]]
	if groups[0][0] == 2:
		return [1, groups[0][1], groups[1][1], groups[2][1], groups[3][1]]
	return [0] + ranks


static func cmp(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


static func _combos(n: int, k: int) -> Array:
	var out: Array = []
	var idx: Array = range(k)
	while true:
		out.append(idx.duplicate())
		var i := k - 1
		while i >= 0 and idx[i] == n - k + i:
			i -= 1
		if i < 0:
			break
		idx[i] += 1
		for j in range(i + 1, k):
			idx[j] = idx[j - 1] + 1
	return out


## 5-7 karttan en iyi 5'li eli bulur.
static func best_hand(cards: Array) -> Array:
	if cards.size() < 5:
		return []
	var best: Array = []
	for combo in _combos(cards.size(), 5):
		var five: Array = []
		for i in combo:
			five.append(cards[i])
		var sc := eval5(five)
		if best.is_empty() or cmp(sc, best) > 0:
			best = sc
	return best


static func hand_name(score: Array) -> String:
	if score.is_empty():
		return ""
	if score[0] == 8 and score[1] == 12:
		return "Royal Floş"
	return HAND_NAMES[score[0]]


# ================================================================== istemci API

func sit(buyin: int) -> void:
	Net.ask(self, "req_sit", {"buyin": buyin})


func leave_table() -> void:
	Net.ask(self, "req_leave")


func act(action: String, amount: int = 0) -> void:
	Net.ask(self, "req_action", {"act": action, "amount": amount})


func add_bot() -> void:
	Net.ask(self, "req_add_bot")


func remove_bots() -> void:
	Net.ask(self, "req_remove_bots")


@rpc("authority", "call_local", "reliable")
func on_table(d: Dictionary) -> void:
	view = d
	deadline_local = _now() + float(d.get("time_left", 0.0))
	table_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_cards(d: Dictionary) -> void:
	my_cards = d.get("cards", [])
	my_cards_changed.emit()


# ================================================================== sunucu: istekler

func _seat_of(id: int) -> int:
	for i in MAX_SEATS:
		if seats[i] != null and seats[i].id == id:
			return i
	return -1


func _free_seat() -> int:
	for i in MAX_SEATS:
		if seats[i] == null:
			return i
	return -1


func _new_seat(id: int, seat_name: String, chips: int, bot: bool) -> Dictionary:
	return {"id": id, "name": seat_name, "chips": chips, "bet": 0, "total": 0, "cards": [],
		"folded": false, "allin": false, "acted": false, "in_hand": false,
		"bot": bot, "left": false, "shown": []}


@rpc("any_peer", "call_remote", "reliable")
func req_sit(d: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := Net.sender()
	if not Net.players.has(id):
		return
	if _seat_of(id) >= 0:
		Net.notify(id, "Zaten masadasın.", false)
		return
	var free := _free_seat()
	if free < 0:
		Net.notify(id, "Masa dolu.", false)
		return
	var buyin := clampi(int(d.get("buyin", 0)), MIN_BUYIN, MAX_BUYIN)
	if not Net.try_spend(id, buyin):
		Net.notify(id, "Masaya oturmak için yeterli paran yok.", false)
		return
	seats[free] = _new_seat(id, Net.players[id].name, buyin, false)
	_log("%s masaya oturdu (%d fiş)." % [Net.players[id].name, buyin])
	_maybe_schedule()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_leave(_d: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var i := _seat_of(Net.sender())
	if i >= 0:
		_leave_seat(i)
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_add_bot(_d: Dictionary) -> void:
	if not multiplayer.is_server() or not Net.players.has(Net.sender()):
		return
	var free := _free_seat()
	if free < 0:
		Net.notify(Net.sender(), "Masada boş koltuk yok.", false)
		return
	var bot_name: String = BOT_NAMES[_bot_counter % BOT_NAMES.size()]
	_bot_counter += 1
	seats[free] = _new_seat(-100 - _bot_counter, bot_name, BOT_BUYIN, true)
	_log("%s masaya oturdu." % bot_name)
	_maybe_schedule()
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_remove_bots(_d: Dictionary) -> void:
	if not multiplayer.is_server() or not Net.players.has(Net.sender()):
		return
	for i in MAX_SEATS:
		if seats[i] != null and seats[i].bot:
			_leave_seat(i)
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_action(d: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var i := _seat_of(Net.sender())
	if i < 0 or i != turn or stage not in ["preflop", "flop", "turn", "river"]:
		return
	_do_action(i, str(d.get("act", "")), int(d.get("amount", 0)))


func on_player_left(id: int) -> void:
	var i := _seat_of(id)
	if i >= 0:
		_leave_seat(i)
		_broadcast()


func send_state(id: int) -> void:
	Net.tell(self, id, "on_table", _public())


# ================================================================== sunucu: oyun akışı

func _process(_delta: float) -> void:
	if not Net.is_server():
		return
	var now := _now()
	match stage:
		"idle":
			if next_hand_at > 0.0 and now >= next_hand_at:
				_start_hand()
		"showdown":
			if now >= next_hand_at:
				_end_hand()
		_:
			if runout_at > 0.0:
				if now >= runout_at:
					runout_at = 0.0
					_next_street()
					_broadcast()
			elif turn >= 0 and seats[turn] != null:
				var s: Dictionary = seats[turn]
				if s.bot and now >= bot_act_at:
					_bot_act(turn)
				elif now >= turn_deadline:
					var to_call: int = current_bet - s.bet
					_log("%s süreyi doldurdu." % s.name)
					_do_action(turn, "check" if to_call <= 0 else "fold", 0)


func _log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 30:
		log_lines.pop_front()


func _count_ready() -> int:
	var n := 0
	for s in seats:
		if s != null and not s.left and s.chips > 0:
			n += 1
	return n


func _maybe_schedule() -> void:
	if stage == "idle" and next_hand_at == 0.0 and _count_ready() >= 2:
		next_hand_at = _now() + 3.0


func _can_act(s) -> bool:
	return s != null and s.in_hand and not s.folded and not s.allin


func _alive() -> Array:
	var out: Array = []
	for i in MAX_SEATS:
		var s = seats[i]
		if s != null and s.in_hand and not s.folded:
			out.append(i)
	return out


func _pot() -> int:
	var p := 0
	for s in seats:
		if s != null:
			p += int(s.total)
	return p


func _next_in_hand(from: int) -> int:
	for k in range(1, MAX_SEATS + 1):
		var j := (from + k) % MAX_SEATS
		if seats[j] != null and seats[j].in_hand:
			return j
	return -1


## Sıradaki hamle yapması gereken oyuncu; yoksa -1 (bahis turu bitti).
func _next_to_act(from: int) -> int:
	for k in range(1, MAX_SEATS + 1):
		var j := (from + k) % MAX_SEATS
		var s = seats[j]
		if _can_act(s) and (not s.acted or s.bet < current_bet):
			return j
	return -1


func _put(s: Dictionary, amount: int) -> void:
	amount = mini(amount, s.chips)
	s.chips -= amount
	s.bet += amount
	s.total += amount
	if s.chips == 0:
		s.allin = true


func _start_hand() -> void:
	next_hand_at = 0.0
	var ready: Array = []
	for i in MAX_SEATS:
		var s = seats[i]
		if s == null:
			continue
		var ok: bool = not s.left and s.chips > 0
		s.in_hand = ok
		s.cards = []
		s.shown = []
		s.bet = 0
		s.total = 0
		s.folded = false
		s.allin = false
		s.acted = false
		if ok:
			ready.append(i)
	if ready.size() < 2:
		_broadcast()
		return
	deck = range(52)
	deck.shuffle()
	board.clear()
	message = ""
	dealer = _next_in_hand(dealer)
	var sb_i: int
	var bb_i: int
	if ready.size() == 2:
		sb_i = dealer
		bb_i = _next_in_hand(dealer)
	else:
		sb_i = _next_in_hand(dealer)
		bb_i = _next_in_hand(sb_i)
	for _k in 2:
		for i in ready:
			seats[i].cards.append(deck.pop_back())
	_put(seats[sb_i], SMALL_BLIND)
	_put(seats[bb_i], BIG_BLIND)
	current_bet = BIG_BLIND
	min_raise = BIG_BLIND
	stage = "preflop"
	_log("— Yeni el. Krupiye: %s, körler: %s / %s" % [seats[dealer].name, seats[sb_i].name, seats[bb_i].name])
	_send_private_all()
	var first := _next_to_act(bb_i)
	if first < 0:
		turn = -1
		runout_at = _now() + 1.5
	else:
		turn = first
		_start_turn()
	_broadcast()


func _start_turn() -> void:
	turn_deadline = _now() + TURN_TIME
	if seats[turn].bot:
		bot_act_at = _now() + randf_range(0.8, 2.2)


func _do_action(i: int, action: String, amount: int) -> void:
	var s: Dictionary = seats[i]
	var to_call: int = current_bet - s.bet
	match action:
		"fold":
			s.folded = true
			_log("%s pas geçti." % s.name)
		"check":
			if to_call > 0:
				return
			_log("%s kontrol etti." % s.name)
		"call":
			if to_call <= 0:
				_log("%s kontrol etti." % s.name)
			else:
				var amt := mini(to_call, int(s.chips))
				_put(s, amt)
				_log("%s gördü (%d)%s." % [s.name, amt, " — HEPSİ" if s.allin else ""])
		"raise", "allin":
			var max_target: int = s.bet + s.chips
			var target: int = max_target if action == "allin" else mini(amount, max_target)
			if target <= current_bet:
				_do_action(i, "call", 0)
				return
			var min_target := current_bet + min_raise
			if target < min_target:
				target = mini(min_target, max_target)
			var raise_by := target - current_bet
			_put(s, target - s.bet)
			if raise_by >= min_raise:
				min_raise = raise_by
			current_bet = target
			for j in MAX_SEATS:
				if j != i and seats[j] != null:
					seats[j].acted = false
			_log("%s artırdı → %d%s" % [s.name, target, " — HEPSİ" if s.allin else ""])
		_:
			return
	s.acted = true
	_after_action()


func _after_action() -> void:
	var alive := _alive()
	if alive.size() == 1:
		_win_uncontested(alive[0])
	else:
		var nxt := _next_to_act(turn)
		if nxt < 0:
			_next_street()
		else:
			turn = nxt
			_start_turn()
	_broadcast()


func _next_street() -> void:
	for s in seats:
		if s != null:
			s.bet = 0
			s.acted = false
	current_bet = 0
	min_raise = BIG_BLIND
	match stage:
		"preflop":
			stage = "flop"
			for _k in 3:
				board.append(deck.pop_back())
		"flop":
			stage = "turn"
			board.append(deck.pop_back())
		"turn":
			stage = "river"
			board.append(deck.pop_back())
		"river":
			_showdown()
			return
	var actors := 0
	for s in seats:
		if _can_act(s):
			actors += 1
	if actors <= 1:
		# Kimse bahis yapamıyor (herkes "hepsi" dedi): kartları sırayla aç.
		turn = -1
		runout_at = _now() + 1.5
		return
	turn = _next_to_act(dealer)
	_start_turn()


func _win_uncontested(i: int) -> void:
	var pot := _pot()
	seats[i].chips += pot
	message = "%s %d kazandı (herkes pas geçti)." % [seats[i].name, pot]
	_log(message)
	stage = "showdown"
	turn = -1
	next_hand_at = _now() + 3.5


func _showdown() -> void:
	stage = "showdown"
	turn = -1
	var alive := _alive()
	var scores := {}
	for i in alive:
		scores[i] = best_hand(seats[i].cards + board)
		seats[i].shown = seats[i].cards.duplicate()
	var hand_idx: Array = []
	var levels: Array = []
	for i in MAX_SEATS:
		var s = seats[i]
		if s != null and s.in_hand:
			hand_idx.append(i)
			if s.total > 0 and not levels.has(s.total):
				levels.append(s.total)
	levels.sort()
	# Yan potlar: her katkı seviyesi ayrı bir pot, sadece o seviyeye ulaşanlar kazanabilir.
	var won := {}
	var prev := 0
	for level in levels:
		var portion := 0
		for i in hand_idx:
			portion += mini(seats[i].total, level) - mini(seats[i].total, prev)
		var elig: Array = alive.filter(func(i): return seats[i].total >= level)
		if elig.is_empty():
			elig = alive
		var best: Array = []
		var winners: Array = []
		for i in elig:
			var c := 1 if best.is_empty() else cmp(scores[i], best)
			if c > 0:
				best = scores[i]
				winners = [i]
			elif c == 0:
				winners.append(i)
		var share := floori(float(portion) / winners.size())
		for w in winners:
			won[w] = won.get(w, 0) + share
		won[winners[0]] += portion - share * winners.size()
		prev = level
	var parts: Array = []
	for w in won:
		seats[w].chips += won[w]
		parts.append("%s %d kazandı (%s)" % [seats[w].name, won[w], hand_name(scores[w])])
	for i in alive:
		if not won.has(i):
			_log("%s: %s" % [seats[i].name, hand_name(scores[i])])
	message = ", ".join(parts)
	_log(message)
	next_hand_at = _now() + 7.0


func _end_hand() -> void:
	for i in MAX_SEATS:
		var s = seats[i]
		if s == null:
			continue
		if s.left:
			seats[i] = null
			continue
		if s.chips <= 0:
			if not s.bot:
				Net.notify(s.id, "Fişlerin bitti, masadan kalktın.", false)
			_log("%s fişleri bittiği için masadan kalktı." % s.name)
			seats[i] = null
			continue
		s.in_hand = false
		s.cards = []
		s.shown = []
		s.bet = 0
		s.total = 0
		s.folded = false
		s.allin = false
	board.clear()
	stage = "idle"
	turn = -1
	current_bet = 0
	message = ""
	_send_private_all()
	next_hand_at = 0.0
	_maybe_schedule()
	_broadcast()


func _leave_seat(i: int) -> void:
	var s: Dictionary = seats[i]
	var playing: bool = s.in_hand and not s.folded and stage in ["preflop", "flop", "turn", "river"]
	if playing:
		if turn == i:
			_do_action(i, "fold", 0)
		else:
			s.folded = true
			var alive := _alive()
			if alive.size() == 1:
				_win_uncontested(alive[0])
	if not s.bot:
		Net.add_money(s.id, s.chips)
		Net.tell(self, s.id, "on_cards", {"cards": []})
	_log("%s masadan kalktı." % s.name)
	s.chips = 0
	if s.in_hand and stage != "idle":
		s.left = true      # el bitene kadar katkısı potta kalsın
	else:
		seats[i] = null
	_maybe_schedule()


func _send_private_all() -> void:
	for s in seats:
		if s != null and not s.bot:
			Net.tell(self, s.id, "on_cards", {"cards": s.cards if s.in_hand else []})


func _bot_strength(s: Dictionary) -> float:
	var c: Array = s.cards
	if board.is_empty():
		var r1: int = c[0] % 13
		var r2: int = c[1] % 13
		var v := (r1 + r2) / 24.0 * 0.45
		if r1 == r2:
			v += 0.35 + r1 / 12.0 * 0.15
		if suit_of(c[0]) == suit_of(c[1]):
			v += 0.06
		if absi(r1 - r2) == 1:
			v += 0.04
		return clampf(v, 0.0, 1.0)
	var sc := best_hand(c + board)
	var base: float = [0.2, 0.5, 0.7, 0.8, 0.85, 0.88, 0.93, 0.97, 1.0][sc[0]]
	if sc[0] <= 1:
		base += sc[1] / 12.0 * 0.08
	return base


func _bot_act(i: int) -> void:
	var s: Dictionary = seats[i]
	var to_call: int = current_bet - s.bet
	var st := _bot_strength(s)
	var pot := _pot()
	var r := randf()
	if to_call <= 0:
		if st > 0.65 and r < 0.55:
			_do_action(i, "raise", current_bet + maxi(min_raise, int(pot * 0.5)))
		else:
			_do_action(i, "check", 0)
	else:
		var odds := float(to_call) / float(pot + to_call)
		if st > 0.8 and r < 0.45:
			_do_action(i, "raise", current_bet + maxi(min_raise, int(pot * 0.75)))
		elif st > odds + 0.05 or (to_call <= BIG_BLIND and r < 0.75) or r < 0.08:
			_do_action(i, "call", 0)
		else:
			_do_action(i, "fold", 0)


func _public() -> Dictionary:
	var ss: Array = []
	for s in seats:
		if s == null:
			ss.append(null)
		else:
			ss.append({"id": s.id, "name": s.name, "chips": s.chips, "bet": s.bet,
				"folded": s.folded, "allin": s.allin, "in_hand": s.in_hand, "bot": s.bot,
				"left": s.left, "shown": s.shown})
	return {"seats": ss, "board": board.duplicate(), "pot": _pot(), "stage": stage,
		"dealer": dealer, "turn": turn, "current_bet": current_bet, "min_raise": min_raise,
		"time_left": maxf(0.0, turn_deadline - _now()) if turn >= 0 else 0.0,
		"msg": message, "log": log_lines.duplicate()}


func _broadcast() -> void:
	Net.tell_all(self, "on_table", _public())
