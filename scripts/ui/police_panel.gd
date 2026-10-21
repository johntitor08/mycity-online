extends "res://scripts/ui/game_panel.gd"
## Karakol: polis görevi (olay vakaları), aranan oyuncular listesi, sabıka kaydı ve güvenlik ürünleri.

var status_label: Label
var duty_btn: Button
var wanted_box: VBoxContainer
var shop_box: VBoxContainer
var case_box: VBoxContainer
var case_label: Label
var options: GridContainer
var bar: ProgressBar
var result_label: Label
var case_btn: Button
var plot_opt: OptionButton
var _plots: Array = []
var _deadline := 0.0
var _total := 1.0
var _active := false
var _earned := 0


func _ready() -> void:
	build("Karakol", Vector2(860, 560))
	status_label = add_label(body, "", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	duty_btn = add_button(top, "", _toggle_duty)
	duty_btn.custom_minimum_size = Vector2(200, 40)
	case_btn = add_button(top, "Olay Bekle (devriye)", _next_case)
	case_btn.custom_minimum_size = Vector2(200, 40)
	add_label(top, "Görevde: aranan birine yaklaş, G ile tutukla.", 13, Color("#94a3b8"))
	body.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	body.add_child(h)
	# sol: vaka ekranı + aranananlar
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	case_box = VBoxContainer.new()
	case_box.add_theme_constant_override("separation", 6)
	left.add_child(case_box)
	case_label = add_label(case_box, "", 20)
	case_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	case_box.add_child(bar)
	options = GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 8)
	options.add_theme_constant_override("v_separation", 8)
	case_box.add_child(options)
	result_label = add_label(case_box, "", 15)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_label(left, "Arananlar", 18, Color("#fca5a5"))
	wanted_box = VBoxContainer.new()
	left.add_child(wanted_box)
	h.add_child(VSeparator.new())
	# sağ: güvenlik dükkânı
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	add_label(right, "Güvenlik Ürünleri", 18, Color("#93c5fd"))
	var pr := HBoxContainer.new()
	right.add_child(pr)
	add_label(pr, "Arsa:", 15)
	plot_opt = OptionButton.new()
	plot_opt.size_flags_horizontal = SIZE_EXPAND_FILL
	plot_opt.item_selected.connect(func(_i): _refresh())
	pr.add_child(plot_opt)
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 6)
	right.add_child(shop_box)
	add_label(right, "Suç işleyen yıldız alır (3 dk'da bir düşer). Görevdeki polisler ve şehirdeki devriye aranan oyuncuları yakalar: hapis ve para cezası. Seviye %d altındakiler suç işleyemez ve soyulamaz." % Police.CRIME_LEVEL, 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Police.changed.connect(_refresh)
	Police.patrol_case.connect(_on_case)
	Police.patrol_result.connect(_on_result)
	Net.roster_changed.connect(_refresh)
	Land.plots_changed.connect(_fill_plots)
	_fill_plots()
	_refresh()


func _fill_plots() -> void:
	var sel := plot_opt.selected
	plot_opt.clear()
	_plots.clear()
	for i in Land.view.size():
		var p: Dictionary = Land.view[i]
		if p.owner == Net.my_name:
			plot_opt.add_item("Arsa #%d (%s)" % [i + 1, Land.building_name(p)])
			_plots.append(i)
	if _plots.is_empty():
		plot_opt.add_item("(arsan yok)")
	plot_opt.disabled = _plots.is_empty()
	plot_opt.selected = clampi(sel, 0, plot_opt.item_count - 1)
	_refresh()


func _refresh() -> void:
	var s := Police.status
	var stars := int(s.get("wanted", 0))
	var lvl := int(Rpg.sheet.get("level", 1))
	status_label.text = "Durumun: %s  •  Suç kaydı: %d  •  Tutuklama: %d" % [
		("ARANIYORSUN " + "★".repeat(stars)) if stars > 0 else ("Görevde polis" if Police.on_duty() else "Temiz"),
		int(s.get("crimes", 0)), int(s.get("arrests", 0))]
	status_label.add_theme_color_override("font_color", Color("#fca5a5") if stars > 0 else Color("#86efac"))
	if Police.on_duty():
		duty_btn.text = "Görevi Bırak"
		duty_btn.disabled = false
	elif lvl < Police.POLICE_LEVEL:
		duty_btn.text = "Polislik: Sv.%d gerekli" % Police.POLICE_LEVEL
		duty_btn.disabled = true
	else:
		duty_btn.text = "Göreve Başla"
		duty_btn.disabled = stars > 0
	case_btn.visible = Police.on_duty() and not _active
	case_box.visible = Police.on_duty()
	if Police.on_duty() and not _active and case_label.text == "":
		case_label.text = "Devriyedesin. \"Olay Bekle\" ile ihbar al."
	# arananlar
	for c in wanted_box.get_children():
		c.queue_free()
	var any := false
	for id in Net.roster:
		var r = Net.roster[id]
		if int(r.get("wanted", 0)) > 0:
			any = true
			add_label(wanted_box, "%s  %s" % [r.name, "★".repeat(int(r.wanted))], 15, Color("#fca5a5"))
	if not any:
		add_label(wanted_box, "Şu an aranan kimse yok.", 14, Color("#7c859e"))
	# güvenlik dükkânı
	for c in shop_box.get_children():
		c.queue_free()
	var plot: int = _plots[plot_opt.selected] if not _plots.is_empty() and plot_opt.selected < _plots.size() else -1
	var sec: Dictionary = Land.view[plot].get("sec", {}) if plot >= 0 else {}
	var mine: Array = s.get("security", [])
	for k in Police.SECURITY:
		var info: Dictionary = Police.SECURITY[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		shop_box.add_child(row)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(v)
		add_label(v, info.name, 16)
		add_label(v, info.desc, 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var have: bool = sec.get(k, false) if info.plot else mine.has(k)
		if have:
			add_label(row, "✓ Var", 15, Color("#86efac"))
		else:
			var b := buy_button(row, int(info.price), Police.buy_security.bind(k, plot), 0, "Al")
			if info.plot and plot < 0:
				b.disabled = true


func _toggle_duty() -> void:
	Police.set_duty(not Police.on_duty())


func _next_case() -> void:
	case_btn.visible = false
	Police.ask_patrol()


func _on_case(d: Dictionary) -> void:
	case_label.text = "İhbar: %s" % d.case
	result_label.text = ""
	for c in options.get_children():
		c.queue_free()
	for i in d.options.size():
		var b := add_button(options, d.options[i], _answer.bind(i))
		b.custom_minimum_size = Vector2(205, 52)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_total = float(d.time)
	_deadline = Time.get_ticks_msec() / 1000.0 + _total
	_active = true
	case_btn.visible = false


func _answer(i: int) -> void:
	if not _active:
		return
	_active = false
	for c in options.get_children():
		c.disabled = true
	Police.answer_patrol(i)


func _process(_delta: float) -> void:
	if not _active:
		return
	var left := _deadline - Time.get_ticks_msec() / 1000.0
	bar.value = clampf(left / _total * 100.0, 0.0, 100.0)
	if left <= 0.0:
		_answer(-1)


func _on_result(d: Dictionary) -> void:
	result_label.text = d.text
	result_label.add_theme_color_override("font_color", Color("#86efac") if d.ok else Color("#fca5a5"))
	Sfx.play("success" if d.ok else "error", -4.0)
	_earned += int(d.pay)
	if d.get("stop", false):
		case_btn.visible = true
		return
	later(1.6, _next_case)
