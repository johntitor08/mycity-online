extends "res://scripts/ui/game_panel.gd"
## Kumarhane: rulet, zar ve at yarışı.

const ROULETTE_KINDS := [["Kırmızı (x2)", "red"], ["Siyah (x2)", "black"], ["Tek (x2)", "odd"], ["Çift (x2)", "even"], ["Tek sayı (x36)", "num"]]
const DICE_FACES := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

var bet_spin: SpinBox
var tabs: TabContainer
var kind_opt: OptionButton
var num_spin: SpinBox
var roulette_label: RichTextLabel
var dice_label: RichTextLabel
var horse_bars: Array = []
var horse_label: Label
var result_label: Label
var bet_buttons: Array = []

var _anim := {}         # oynatılan sonuç
var _anim_start := 0.0
var _horse_times: Array = []
var _spin_n := 0
var _next_tick := 0.0
var _next_gallop := 0.0


func _ready() -> void:
	build("Kumarhane — Bahis", Vector2(760, 540))
	var row := HBoxContainer.new()
	body.add_child(row)
	add_label(row, "Bahis miktarı:", 18)
	bet_spin = add_spin(row, Casino.MIN_BET, Casino.MAX_BET, 10, 100)
	for q in [["½", 0.5], ["×2", 2.0], ["+100", 100], ["+1000", 1000]]:
		add_button(row, q[0], _adjust_bet.bind(q[1]))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_roulette()
	_build_dice()
	_build_horses()
	tabs.set_tab_title(0, "Rulet")
	tabs.set_tab_title(1, "Zar")
	tabs.set_tab_title(2, "At Yarışı")
	result_label = add_label(body, "", 20)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Casino.result.connect(_on_result)


func _adjust_bet(v: float) -> void:
	if v < 10.0:
		bet_spin.value = bet_spin.value * v
	else:
		bet_spin.value += v


func _tab(name_hint: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = name_hint
	v.add_theme_constant_override("separation", 10)
	tabs.add_child(v)
	return v


func _build_roulette() -> void:
	var v := _tab("Rulet")
	add_label(v, "Avrupa ruleti (0-36). Kırmızı/siyah/tek/çift parayı ikiye katlar, tek sayı 36 katı öder.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h := HBoxContainer.new()
	v.add_child(h)
	kind_opt = OptionButton.new()
	for k in ROULETTE_KINDS:
		kind_opt.add_item(k[0])
	h.add_child(kind_opt)
	add_label(h, "Sayı:")
	num_spin = add_spin(h, 0, 36, 1, 7)
	bet_buttons.append(add_button(h, "Çarkı Çevir", _spin_roulette))
	roulette_label = add_rich(v, 60, 90)


func _build_dice() -> void:
	var v := _tab("Zar")
	add_label(v, "İki zar atılır. Toplam 7'den küçük ya da büyükse x2, tam 7 ise x5 öder.", 14, Color("#94a3b8"))
	var h := HBoxContainer.new()
	v.add_child(h)
	bet_buttons.append(add_button(h, "7'den Küçük (x2)", func(): Casino.dice(int(bet_spin.value), "under")))
	bet_buttons.append(add_button(h, "Tam 7 (x5)", func(): Casino.dice(int(bet_spin.value), "seven")))
	bet_buttons.append(add_button(h, "7'den Büyük (x2)", func(): Casino.dice(int(bet_spin.value), "over")))
	dice_label = add_rich(v, 64, 90)


func _build_horses() -> void:
	var v := _tab("AtYarisi")
	add_label(v, "Atını seç ve bahsini yatır. Oranı yüksek atlar daha zor kazanır.", 14, Color("#94a3b8"))
	for i in Casino.HORSES.size():
		var hr: Dictionary = Casino.HORSES[i]
		var h := HBoxContainer.new()
		v.add_child(h)
		var b := add_button(h, "%d. %s (x%s)" % [i + 1, hr.name, str(hr.odds)], func(): Casino.horse(int(bet_spin.value), i))
		b.custom_minimum_size = Vector2(200, 0)
		bet_buttons.append(b)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 22)
		h.add_child(bar)
		horse_bars.append(bar)
	horse_label = add_label(v, "", 16)


func _spin_roulette() -> void:
	var kind: String = ROULETTE_KINDS[kind_opt.selected][1]
	Casino.roulette(int(bet_spin.value), kind, int(num_spin.value))


func _set_busy(busy: bool) -> void:
	for b in bet_buttons:
		b.disabled = busy


func _on_result(d: Dictionary) -> void:
	_anim = d
	_anim_start = Time.get_ticks_msec() / 1000.0
	result_label.text = ""
	_set_busy(true)
	_next_tick = 0.0
	_next_gallop = 0.0
	if d.game == "dice":
		Sfx.play("dice")
	if d.game == "horse":
		_horse_times.clear()
		for i in Casino.HORSES.size():
			_horse_times.append(float(d.delay) if i == d.winner else float(d.delay) * randf_range(1.06, 1.35))


func _color_bb(n: int) -> String:
	var col := "#16a34a" if n == 0 else ("#dc2626" if Casino.RED.has(n) else "#111111")
	return "[center][bgcolor=%s][color=white] %d [/color][/bgcolor][/center]" % [col, n]


func _process(_delta: float) -> void:
	if _anim.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0 - _anim_start
	var done: bool = t >= float(_anim.delay)
	match _anim.game:
		"roulette":
			# Çark yavaşlayarak döner: tıkırtılar giderek seyrekleşir.
			if not done and t >= _next_tick:
				_spin_n = randi_range(0, 36)
				_next_tick = t + 0.05 + 0.25 * pow(t / float(_anim.delay), 2.0)
				Sfx.play("tick", -2.0, randf_range(0.9, 1.1))
			roulette_label.text = _color_bb(_anim.n if done else _spin_n)
		"dice":
			var a: int = _anim.a if done else randi_range(1, 6)
			var b: int = _anim.b if done else randi_range(1, 6)
			dice_label.text = "[center]%s %s  [font_size=28]= %d[/font_size][/center]" % [DICE_FACES[a - 1], DICE_FACES[b - 1], a + b]
		"horse":
			if not done and t >= _next_gallop:
				_next_gallop = t + 1.15
				Sfx.play("gallop", -4.0)
			for i in horse_bars.size():
				horse_bars[i].value = clampf(t / _horse_times[i] * 100.0 + sin(t * 9.0 + i) * 1.5, 0.0, 100.0)
			if done:
				horse_label.text = "Kazanan: %s" % Casino.HORSES[_anim.winner].name
	if done:
		var net: int = int(_anim.payout) - int(_anim.bet)
		Sfx.play("cash" if int(_anim.payout) > 0 else "lose", -3.0)
		if int(_anim.payout) > 0:
			result_label.text = "KAZANDIN! +%s" % U.money(net)
			result_label.add_theme_color_override("font_color", Color("#86efac"))
		else:
			result_label.text = "Kaybettin: -%s" % U.money(int(_anim.bet))
			result_label.add_theme_color_override("font_color", Color("#fca5a5"))
		_anim = {}
		_set_busy(false)
