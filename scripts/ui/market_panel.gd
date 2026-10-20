extends "res://scripts/ui/game_panel.gd"
## Market: kasiyer olarak çalış (sepeti hesapla, doğru para üstünü ver) ya da alışveriş yap.

var receipt: RichTextLabel
var paid_label: Label
var change_edit: LineEdit
var give_btn: Button
var bar: ProgressBar
var result_label: Label
var stats_label: Label
var start_btn: Button
var _deadline := 0.0
var _total := 1.0
var _active := false
var _earned := 0
var _served := 0
var job_box: VBoxContainer
var shop_box: VBoxContainer
var shop_money: Label


func _ready() -> void:
	build("Market", Vector2(640, 540))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	add_button(tabs, "Kasiyer Olarak Çalış", _show.bind(false))
	add_button(tabs, "Alışveriş", _show.bind(true))
	body.add_child(HSeparator.new())
	_build_shop()
	# Kasiyerlik içeriği kendi kutusuna gider (aşağıdaki kod "body" kullanmaya devam eder).
	job_box = VBoxContainer.new()
	job_box.add_theme_constant_override("separation", 8)
	body.add_child(job_box)
	body = job_box
	add_label(body, "Ürünleri kafandan topla, müşterinin verdiği paradan çıkar ve para üstünü gir.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	receipt = add_rich(body, 20, 130)
	paid_label = add_label(body, "", 22, Color("#facc15"))
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	body.add_child(bar)
	var row := HBoxContainer.new()
	body.add_child(row)
	add_label(row, "Para üstü:", 18)
	change_edit = LineEdit.new()
	change_edit.placeholder_text = "TL"
	change_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	change_edit.text_submitted.connect(func(_t): _give())
	change_edit.editable = false
	row.add_child(change_edit)
	give_btn = add_button(row, "Para Üstünü Ver", _give)
	give_btn.disabled = true
	result_label = add_label(body, "", 18)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label = add_label(body, "", 15, Color("#94a3b8"))
	start_btn = add_button(body, "Kasaya Geç", _next)
	Jobs.market_case.connect(_on_case)
	Jobs.job_result.connect(_on_result)


func _show(shop: bool) -> void:
	shop_box.visible = shop
	job_box.visible = not shop
	if shop:
		Rpg.refresh()


func _build_shop() -> void:
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 8)
	shop_box.visible = false
	body.add_child(shop_box)
	shop_money = add_label(shop_box, "", 15, Color("#94a3b8"))
	add_label(shop_box, "Yiyecekler (çantaya gider, Karakter Kartı'ndan ye)", 18, Color("#93c5fd"))
	var foods := GridContainer.new()
	foods.columns = 2
	shop_box.add_child(foods)
	for k in Rpg.FOODS:
		var f: Dictionary = Rpg.FOODS[k]
		add_label(foods, "%s — +%d enerji" % [f.name, f.energy], 16).custom_minimum_size = Vector2(300, 0)
		add_button(foods, "Al (%s)" % U.money(f.price), Rpg.buy.bind(k))
	shop_box.add_child(HSeparator.new())
	add_label(shop_box, "Aletler (kalıcı avantaj)", 18, Color("#93c5fd"))
	var tools := GridContainer.new()
	tools.columns = 2
	tools.name = "tools"
	shop_box.add_child(tools)
	Rpg.sheet_changed.connect(_refresh_shop)
	_refresh_shop()


func _refresh_shop() -> void:
	var tools: GridContainer = shop_box.get_node("tools")
	for c in tools.get_children():
		c.queue_free()
	var owned: Array = Rpg.sheet.get("tools", [])
	for k in Rpg.TOOLS:
		var t: Dictionary = Rpg.TOOLS[k]
		add_label(tools, "%s — %s" % [t.name, t.desc], 15).custom_minimum_size = Vector2(380, 0)
		var b := add_button(tools, "Sende" if owned.has(k) else "Al (%s)" % U.money(t.price), Rpg.buy.bind(k))
		b.disabled = owned.has(k)
	var items: Dictionary = Rpg.sheet.get("items", {})
	var bag := []
	for k in items:
		bag.append("%s ×%d" % [Rpg.FOODS[k].name, items[k]])
	shop_money.text = "Enerji: %d / %d    Çanta: %s" % [int(Rpg.sheet.get("energy", 0)),
		int(Rpg.sheet.get("max_energy", 100)), ", ".join(bag) if bag else "boş"]


func _next() -> void:
	start_btn.visible = false
	Jobs.ask_market()


func _on_case(d: Dictionary) -> void:
	start_btn.visible = false
	var t := "[b]Müşterinin sepeti:[/b]\n"
	for it in d.items:
		t += "  %d × %s  [color=#94a3b8](tanesi %d TL)[/color]\n" % [it.qty, it.name, it.price]
	receipt.text = t
	paid_label.text = "Müşteri %s verdi." % U.money(int(d.paid))
	result_label.text = ""
	change_edit.text = ""
	change_edit.editable = true
	give_btn.disabled = false
	change_edit.grab_focus()
	_total = float(d.time)
	_deadline = Time.get_ticks_msec() / 1000.0 + _total
	_active = true


func _give() -> void:
	if not _active:
		return
	var txt := change_edit.text.strip_edges()
	if not txt.is_valid_int():
		result_label.text = "Sadece sayı gir."
		result_label.add_theme_color_override("font_color", Color("#fde68a"))
		return
	_send(int(txt))


func _send(value: int) -> void:
	_active = false
	change_edit.editable = false
	give_btn.disabled = true
	Jobs.answer_market(value)


func _process(_delta: float) -> void:
	if not _active:
		return
	var left := _deadline - Time.get_ticks_msec() / 1000.0
	bar.value = clampf(left / _total * 100.0, 0.0, 100.0)
	if left <= 0.0:
		_send(-1)


func _on_result(d: Dictionary) -> void:
	if d.job != "market":
		return
	result_label.text = d.text
	result_label.add_theme_color_override("font_color", Color("#86efac") if d.ok else Color("#fca5a5"))
	Sfx.play("success" if d.ok else "error", -4.0)
	_earned += int(d.pay)
	if d.ok:
		_served += 1
	stats_label.text = "Bu vardiya: %d müşteri, net kazanç %s" % [_served, U.money(_earned)]
	if d.get("stop", false):
		start_btn.visible = true     # enerji bitti: otomatik devam etme
		return
	later(1.8, _next)
