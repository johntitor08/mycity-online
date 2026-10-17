extends "res://scripts/ui/game_panel.gd"
## Poker salonu: Texas Hold'em masası.

const STAGE_NAMES := {"idle": "Oyuncu bekleniyor", "preflop": "El öncesi", "flop": "Flop",
	"turn": "Turn", "river": "River", "showdown": "El bitti"}
const CARD_BACK := "[bgcolor=#991b1b][color=#fca5a5] ✦✦ [/color][/bgcolor]"
const CARD_EMPTY := "[bgcolor=#2b3245][color=#2b3245] 00 [/color][/bgcolor]"

var info: Label
var board_label: RichTextLabel
var msg_label: Label
var seat_boxes: Array = []
var log_label: RichTextLabel
var my_label: RichTextLabel
var timer_bar: ProgressBar
var btn_fold: Button
var btn_check: Button
var btn_raise: Button
var btn_allin: Button
var raise_spin: SpinBox
var buyin_spin: SpinBox
var btn_sit: Button
var btn_leave: Button
var _last_board := -1
var _last_pot := -1
var _was_my_turn := false
var _had_cards := false


func _ready() -> void:
	build("Poker Salonu — Texas Hold'em", Vector2(1080, 620))
	info = add_label(body, "", 18, Color("#cbd5e1"))
	board_label = add_rich(body, 34, 54)
	msg_label = add_label(body, "", 17, Color("#facc15"))

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	body.add_child(mid)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	mid.add_child(grid)
	for i in Poker.MAX_SEATS:
		seat_boxes.append(_make_seat(grid))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(290, 0)
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 13)
	mid.add_child(log_label)

	var me := HBoxContainer.new()
	body.add_child(me)
	my_label = add_rich(me, 22, 40)
	my_label.size_flags_horizontal = SIZE_EXPAND_FILL
	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(220, 16)
	timer_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	me.add_child(timer_bar)

	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 8)
	body.add_child(act)
	btn_fold = add_button(act, "Pas (Fold)", func(): Poker.act("fold"))
	btn_check = add_button(act, "Kontrol", _on_check)
	raise_spin = add_spin(act, 0, 1, 10, 0)
	btn_raise = add_button(act, "Artır", func(): Poker.act("raise", int(raise_spin.value)))
	btn_allin = add_button(act, "Hepsi (All-in)", func(): Poker.act("allin"))
	var gap := Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	act.add_child(gap)
	add_label(act, "Giriş:")
	buyin_spin = add_spin(act, Poker.MIN_BUYIN, Poker.MAX_BUYIN, 100, 1000)
	btn_sit = add_button(act, "Masaya Otur", func(): Poker.sit(int(buyin_spin.value)))
	btn_leave = add_button(act, "Kalk", Poker.leave_table)
	add_button(act, "Bot Ekle", Poker.add_bot)
	add_button(act, "Botları Çıkar", Poker.remove_bots)

	Poker.table_changed.connect(_refresh)
	Poker.my_cards_changed.connect(_refresh)
	_refresh()


func _make_seat(grid: GridContainer) -> Dictionary:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(240, 112)
	p.size_flags_horizontal = SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f2937")
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color(0, 0, 0, 0)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	grid.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	return {"style": sb, "name": add_label(v, "", 17), "chips": add_label(v, "", 14, Color("#fde68a")),
		"cards": add_rich(v, 22, 32), "status": add_label(v, "", 13, Color("#cbd5e1"))}


func _my_seat() -> int:
	if Poker.view.is_empty():
		return -1
	var seats: Array = Poker.view.seats
	for i in seats.size():
		if seats[i] != null and int(seats[i].id) == Net.my_id():
			return i
	return -1


func _cards_bb(cards: Array) -> String:
	var t := ""
	for c in cards:
		t += Poker.card_bb(c) + " "
	return t


func _on_check() -> void:
	var v := Poker.view
	var mi := _my_seat()
	if mi < 0:
		return
	var to_call: int = int(v.current_bet) - int(v.seats[mi].bet)
	Poker.act("call" if to_call > 0 else "check")


func _refresh() -> void:
	var v := Poker.view
	if v.is_empty():
		info.text = "Masa yükleniyor..."
		return
	var seats: Array = v.seats
	var mi := _my_seat()
	_sounds(v, mi)
	var seated := 0
	for s in seats:
		if s != null:
			seated += 1
	var t: String = "%s   •   Pot: %s   •   Körler: %d / %d" % [STAGE_NAMES.get(v.stage, v.stage), U.money(int(v.pot)), Poker.SMALL_BLIND, Poker.BIG_BLIND]
	if v.stage == "idle":
		t += "   •   " + ("En az 2 oyuncu gerekli — 'Bot Ekle' ile bot çağırabilirsin" if seated < 2 else "El birazdan başlıyor...")
	info.text = t

	var b := _cards_bb(v.board)
	for _k in 5 - v.board.size():
		b += CARD_EMPTY + " "
	board_label.text = "[center]%s[/center]" % b
	msg_label.text = v.msg

	for i in Poker.MAX_SEATS:
		var box: Dictionary = seat_boxes[i]
		var s = seats[i]
		var sb: StyleBoxFlat = box.style
		if s == null:
			box.name.text = "Boş koltuk"
			box.name.add_theme_color_override("font_color", Color("#64748b"))
			box.chips.text = ""
			box.cards.text = ""
			box.status.text = ""
			sb.bg_color = Color("#161b26")
			sb.border_color = Color(0, 0, 0, 0)
			continue
		box.name.text = "%s%s%s" % [s.name, "  (K)" if i == int(v.dealer) and v.stage != "idle" else "", "  ← sen" if i == mi else ""]
		box.name.add_theme_color_override("font_color", Color("#86efac") if i == mi else Color.WHITE)
		box.chips.text = "Fiş: %d%s" % [s.chips, ("    Bahis: %d" % s.bet) if int(s.bet) > 0 else ""]
		if i == mi and not Poker.my_cards.is_empty():
			box.cards.text = _cards_bb(Poker.my_cards)
		elif not s.shown.is_empty():
			box.cards.text = _cards_bb(s.shown)
		elif s.in_hand and not s.folded and v.stage != "idle":
			box.cards.text = CARD_BACK + " " + CARD_BACK
		else:
			box.cards.text = ""
		var st := ""
		if s.left:
			st = "Ayrıldı"
		elif s.folded:
			st = "Pas geçti"
		elif s.allin:
			st = "HEPSİ (all-in)"
		elif i == int(v.turn):
			st = "Düşünüyor..."
		elif not s.in_hand and v.stage != "idle":
			st = "Sonraki eli bekliyor"
		if s.bot:
			st = ("Bot  •  " + st) if st != "" else "Bot"
		box.status.text = st
		sb.border_color = Color("#facc15") if i == int(v.turn) else Color(0, 0, 0, 0)
		sb.bg_color = Color("#14532d") if s.in_hand and not s.folded and v.stage != "idle" else Color("#1f2937")

	log_label.text = "\n".join(v.log)

	if mi >= 0 and not Poker.my_cards.is_empty():
		var hand := ""
		var all: Array = Poker.my_cards + v.board
		if all.size() >= 5:
			hand = Poker.hand_name(Poker.best_hand(all))
		elif Poker.my_cards[0] % 13 == Poker.my_cards[1] % 13:
			hand = "Per"
		else:
			hand = "Yüksek Kart"
		my_label.text = "Kartların: %s  [color=#facc15]%s[/color]" % [_cards_bb(Poker.my_cards), hand]
	elif mi >= 0:
		my_label.text = "[color=#94a3b8]Masadasın, yeni eli bekliyorsun.[/color]"
	else:
		my_label.text = "[color=#94a3b8]Masada değilsin. Giriş miktarını seç ve 'Masaya Otur'a bas.[/color]"

	var my_turn: bool = mi >= 0 and int(v.turn) == mi and v.stage in ["preflop", "flop", "turn", "river"]
	for btn in [btn_fold, btn_check, btn_raise, btn_allin]:
		btn.disabled = not my_turn
	raise_spin.editable = my_turn
	if my_turn:
		var s = seats[mi]
		var to_call: int = int(v.current_bet) - int(s.bet)
		btn_check.text = "Kontrol" if to_call <= 0 else "Gör (%d)" % mini(to_call, int(s.chips))
		var max_t: int = int(s.bet) + int(s.chips)
		var min_t: int = mini(int(v.current_bet) + int(v.min_raise), max_t)
		raise_spin.max_value = max_t
		raise_spin.min_value = min_t
		if raise_spin.value < min_t:
			raise_spin.value = min_t
		btn_raise.disabled = max_t <= int(v.current_bet)
	else:
		btn_check.text = "Kontrol"
	btn_sit.disabled = mi >= 0
	btn_leave.disabled = mi < 0


func _sounds(v: Dictionary, mi: int) -> void:
	var board_n: int = v.board.size()
	var pot := int(v.pot)
	var has_cards := not Poker.my_cards.is_empty()
	if _last_board >= 0:
		if board_n > _last_board or (has_cards and not _had_cards):
			Sfx.play("card")
		elif pot > _last_pot and _last_pot >= 0:
			Sfx.play("chip", -3.0)
	var my_turn: bool = mi >= 0 and int(v.turn) == mi
	if my_turn and not _was_my_turn:
		Sfx.play("notify", -4.0)
	_last_board = board_n
	_last_pot = pot
	_was_my_turn = my_turn
	_had_cards = has_cards


func _process(_delta: float) -> void:
	var v := Poker.view
	var active: bool = not v.is_empty() and int(v.turn) >= 0
	timer_bar.visible = active
	if active:
		var left := Poker.deadline_local - Time.get_ticks_msec() / 1000.0
		timer_bar.value = clampf(left / Poker.TURN_TIME * 100.0, 0.0, 100.0)
