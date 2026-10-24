extends "res://scripts/ui/game_panel.gd"
## Banka: hesap (yatır/çek, faiz), kredi ve borsa (hisse al/sat, fiyat grafikleri).

var acc_box: VBoxContainer
var stock_box: VBoxContainer
var amount: SpinBox
var info_label: Label
var loan_label: Label
var qty: SpinBox
var _rows := {}                    # sembol -> {price, chg, hold, chart}
var _tab := "acc"


class Spark extends Control:
	var hist: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05))
		if hist.size() < 2:
			return
		var lo := INF
		var hi := -INF
		for v in hist:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		var span := maxf(hi - lo, 0.01)
		var pts := PackedVector2Array()
		for i in hist.size():
			pts.append(Vector2(size.x * i / float(hist.size() - 1), size.y - 2 - (size.y - 4) * (float(hist[i]) - lo) / span))
		var up := float(hist[-1]) >= float(hist[0])
		draw_polyline(pts, Color("#4ade80") if up else Color("#f87171"), 1.6, true)


func _ready() -> void:
	build("Banka", Vector2(900, 560))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	add_button(tabs, "Hesap ve Kredi", _show.bind("acc")).custom_minimum_size = Vector2(160, 36)
	add_button(tabs, "Borsa", _show.bind("stock")).custom_minimum_size = Vector2(160, 36)
	add_label(tabs, "   Borsa oyun içi sanaldır; fiyatlar şehirdeki olaylarla oynar.", 12, Color("#7c859e"))
	body.add_child(HSeparator.new())
	_build_account()
	_build_stocks()
	Bank.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_show("acc")


func _show(t: String) -> void:
	_tab = t
	acc_box.visible = t == "acc"
	stock_box.visible = t == "stock"
	_refresh()


func _build_account() -> void:
	acc_box = VBoxContainer.new()
	acc_box.add_theme_constant_override("separation", 10)
	body.add_child(acc_box)
	info_label = add_label(acc_box, "", 18, Color("#86efac"))
	add_label(acc_box, "Mevduat oyun günü (48 dk) başına %%%d faiz getirir (%s'ye kadar). Bankadaki para soyulamaz." % [int(Bank.INTEREST_PER_DAY * 100), U.money(Bank.INTEREST_CAP)], 13, Color("#94a3b8"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	acc_box.add_child(row)
	add_label(row, "Tutar:", 16)
	amount = add_spin(row, 0, 10000000, 100, 1000)
	amount.custom_minimum_size = Vector2(160, 0)
	add_button(row, "Yatır", func(): Bank.deposit(int(amount.value)))
	add_button(row, "Çek", func(): Bank.withdraw(int(amount.value)))
	add_button(row, "Tümünü yatır", func(): Bank.deposit(Net.my_money()))
	acc_box.add_child(HSeparator.new())
	add_label(acc_box, "Kredi", 19, Color("#facc15"))
	loan_label = add_label(acc_box, "", 15)
	loan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	acc_box.add_child(row2)
	add_button(row2, "Kredi çek (tutar kadar)", func(): Bank.borrow(int(amount.value)))
	add_button(row2, "Borç öde (tutar kadar)", func(): Bank.repay(int(amount.value)))
	add_label(acc_box, "Kredi %%%d masrafla verilir ve %d oyun günü (~%d saat) içinde ödenmelidir; vadesi geçerse banka borcu önce hesabından, sonra cebinden tahsil eder." % [int(Bank.LOAN_FEE * 100), Bank.LOAN_DAYS, int(Bank.LOAN_DAYS * 48 / 60.0 + 0.5)], 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_stocks() -> void:
	stock_box = VBoxContainer.new()
	stock_box.add_theme_constant_override("separation", 6)
	body.add_child(stock_box)
	var top := HBoxContainer.new()
	stock_box.add_child(top)
	add_label(top, "İşlem adedi:", 15)
	qty = add_spin(top, 1, Bank.MAX_SHARES, 1, 10)
	add_label(top, "   Komisyon %%%d. Fiyatlar dakikada bir güncellenir." % int(Bank.STOCK_FEE * 100), 12, Color("#94a3b8"))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	stock_box.add_child(grid)
	for t in ["Şirket", "Fiyat", "Değişim", "Son 1 saat", "Elindeki", "", ""]:
		add_label(grid, t, 13, Color("#7c859e"))
	for sym in Bank.STOCKS:
		var name_l := add_label(grid, "%s  %s" % [sym, Bank.STOCKS[sym].name], 15)
		name_l.custom_minimum_size = Vector2(230, 0)
		var price_l := add_label(grid, "", 15, Color("#fde68a"))
		price_l.custom_minimum_size = Vector2(80, 0)
		var chg_l := add_label(grid, "", 15)
		chg_l.custom_minimum_size = Vector2(70, 0)
		var chart := Spark.new()
		chart.custom_minimum_size = Vector2(130, 30)
		grid.add_child(chart)
		var hold_l := add_label(grid, "", 13, Color("#cbd5e1"))
		hold_l.custom_minimum_size = Vector2(150, 0)
		add_button(grid, "Al", func(): Bank.trade(sym, int(qty.value)))
		add_button(grid, "Sat", func(): Bank.trade(sym, -int(qty.value)))
		_rows[sym] = {"price": price_l, "chg": chg_l, "hold": hold_l, "chart": chart}
	add_label(stock_box, "Balık tutulunca BALK, hasat olunca TARM, kumarhanede bahis oynandıkça KMRH, arsa alınıp inşa edildikçe EMLK, araç satıldıkça OTO, market ve işletme satışlarıyla MRKT yükselir. Fırtına balıkçılık ve tarımı vurur; festival market ve kumarhaneye yarar.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh() -> void:
	var a := Bank.account
	info_label.text = "Hesabındaki para: %s     Cebindeki: %s" % [U.money(int(a.get("bal", 0))), U.money(Net.my_money())]
	var debt := int(a.get("debt", 0))
	if debt > 0:
		var left := float(a.get("due_in", 0.0))
		loan_label.text = "Borcun: %s  •  %s" % [U.money(debt), "vadesi %d dk sonra" % int(left / 60.0) if left > 0 else "VADESİ GEÇTİ, banka tahsil ediyor!"]
		loan_label.add_theme_color_override("font_color", Color("#fca5a5"))
	else:
		loan_label.text = "Borcun yok. Kredi limitin: %s (seviye × %s)" % [U.money(int(a.get("loan_limit", 0))), U.money(Bank.LOAN_PER_LEVEL)]
		loan_label.add_theme_color_override("font_color", Color.WHITE)
	for sym in _rows:
		var r: Dictionary = _rows[sym]
		var p := Bank.price(sym)
		r.price.text = "%.2f" % p
		var c := Bank.change_pct(sym)
		r.chg.text = "%+.1f%%" % c
		r.chg.add_theme_color_override("font_color", Color("#4ade80") if c >= 0 else Color("#f87171"))
		r.chart.hist = Bank.market.get(sym, {}).get("hist", [])
		r.chart.queue_redraw()
		var h: Dictionary = Bank.holdings.get(sym, {})
		if int(h.get("n", 0)) > 0:
			var val := int(h.n) * p
			var pl := val - float(h.cost) * int(h.n)
			r.hold.text = "%d adet  %s%s" % [int(h.n), "+" if pl >= 0 else "", U.money(int(pl))]
			r.hold.add_theme_color_override("font_color", Color("#86efac") if pl >= 0 else Color("#fca5a5"))
		else:
			r.hold.text = "—"
			r.hold.add_theme_color_override("font_color", Color("#64748b"))
