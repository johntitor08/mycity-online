extends "res://scripts/ui/game_panel.gd"
## Emlak ofisi / arsa penceresi: satın al, ev ya da işletme kur, büyüt, sat; işletmeyi yönet.

var focus_plot := -1
var list: VBoxContainer
var manage: VBoxContainer
var stats_label: Label
var cash_btn: Button
var price_slider: HSlider
var price_label: Label
var staff_spin: SpinBox


func _ready() -> void:
	var title := "Emlak Ofisi — Arsalar" if focus_plot < 0 else "Arsa #%d" % (focus_plot + 1)
	build(title, Vector2(880, 0 if focus_plot >= 0 else 560))
	add_label(body, "Ev kurarsan dakikalık kira alırsın; büfe açarsan müşterilerden kazanırsın (malzeme koyman gerekir). Kişi başı en fazla %d arsa." % Land.MAX_PER_PLAYER, 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 96 if focus_plot >= 0 else 430)
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	_build_manage()
	Land.plots_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	for i in Land.view.size():
		if focus_plot >= 0 and i != focus_plot:
			continue
		_row(i, Land.view[i])
	_refresh_manage()


func _row(i: int, p: Dictionary) -> void:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#262b3b")
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", sb)
	list.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	add_label(h, "#%d" % (i + 1), 22, Color("#facc15")).custom_minimum_size = Vector2(46, 0)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(info)
	var mine: bool = p.owner == Net.my_name
	var is_biz := Biz.is_biz(p)
	var owner_text: String = "Satılık" if p.owner == "" else ("Sahibi: SEN" if mine else "Sahibi: %s" % p.owner)
	add_label(info, "%s  •  %s" % [owner_text, Land.building_name(p)], 17, Color("#86efac") if mine else Color.WHITE)
	if is_biz:
		var b: Dictionary = p.biz
		add_label(info, "Puan %.1f/5  •  Son dakika %d müşteri  •  Depo %d" % [float(b.rating), int(b.last_customers), int(b.stock)], 14, Color("#94a3b8"))
	else:
		add_label(info, "Arsa değeri %s  •  Kira %s/dk" % [U.money(int(p.price)), U.money(Land.income_of(p))], 14, Color("#94a3b8"))
	if p.owner == "":
		buy_button(h, int(p.price), Land.buy.bind(i), 0, "Satın Al")
		return
	var lvl := int(p.level)
	if not mine:
		if focus_plot >= 0 and not is_biz and lvl >= 1 and p.get("door_open", false):
			add_button(h, "Eve Gir", func(): Homes.enter(i); close())
		return
	if lvl == 0:
		buy_button(h, Land.BUILD_COST[1], Land.build_up.bind(i, "home"), 0, "Ev kur")
		buy_button(h, Biz.BUILD_COST[1], Land.build_up.bind(i, "biz"), Biz.LEVEL_GATE[1], "Büfe aç")
	elif lvl < 3:
		if is_biz:
			buy_button(h, Biz.BUILD_COST[lvl + 1], Land.build_up.bind(i, "biz"), Biz.LEVEL_GATE[lvl + 1], "%s'ye büyüt" % Biz.NAMES[lvl + 1])
		else:
			var gate: int = [0, 1, Rpg.LEVEL_GATES.villa, Rpg.LEVEL_GATES.tower][lvl + 1]
			buy_button(h, Land.BUILD_COST[lvl + 1], Land.build_up.bind(i, "home"), gate, "%s inşa et" % Land.LEVEL_NAMES[lvl + 1])
	if focus_plot >= 0 and lvl >= 1 and not is_biz:
		add_button(h, "Eve Gir", func(): Homes.enter(i); close())
	add_button(h, "Sat (%s)" % U.money(Land.sell_value(p)), Land.sell.bind(i))


## İşletme yönetimi bölümü (sadece kendi işletmenin yanındayken görünür).
func _build_manage() -> void:
	manage = VBoxContainer.new()
	manage.add_theme_constant_override("separation", 8)
	manage.visible = false
	body.add_child(manage)
	manage.add_child(HSeparator.new())
	add_label(manage, "İşletme Yönetimi", 20, Color("#facc15"))
	stats_label = add_label(manage, "", 15)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	manage.add_child(row1)
	cash_btn = add_button(row1, "", func(): Biz.collect(focus_plot))
	add_button(row1, "Toptancı: %d birim (%s)" % [Biz.WHOLESALE[0], U.money(Biz.WHOLESALE[1])], func(): Biz.restock(focus_plot, "wholesale", 1))
	add_button(row1, "×5", func(): Biz.restock(focus_plot, "wholesale", 5))
	add_button(row1, "Balıkları koy", func(): Biz.restock(focus_plot, "fish"))
	add_button(row1, "Yiyecekleri koy", func(): Biz.restock(focus_plot, "food"))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	manage.add_child(row2)
	add_label(row2, "Fiyat:", 15)
	price_slider = HSlider.new()
	price_slider.min_value = 0.5
	price_slider.max_value = 2.0
	price_slider.step = 0.05
	price_slider.custom_minimum_size = Vector2(200, 0)
	price_slider.value_changed.connect(func(_v): _update_price_label())
	row2.add_child(price_slider)
	price_label = add_label(row2, "", 15, Color("#86efac"))
	price_label.custom_minimum_size = Vector2(150, 0)
	add_label(row2, "Çalışan:", 15)
	staff_spin = add_spin(row2, 0, Biz.MAX_STAFF, 1, 0)
	staff_spin.custom_minimum_size = Vector2(80, 0)
	add_button(row2, "Kaydet", func(): Biz.configure(focus_plot, price_slider.value, int(staff_spin.value)))
	add_label(manage, "Malzeme bitince müşteri kaçar ve puan düşer. Pahalı fiyat müşteri azaltır. Her çalışan +%%25 müşteri getirir ama dakikada %s × seviye maaş alır. Sen dükkândayken müşteri %%30 artar." % U.money(Biz.WAGE), 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if focus_plot >= 0 and focus_plot < Land.view.size() and Biz.is_biz(Land.view[focus_plot]):
		price_slider.value = float(Land.view[focus_plot].biz.price)
		staff_spin.value = int(Land.view[focus_plot].biz.staff)


func _refresh_manage() -> void:
	var p: Dictionary = Land.view[focus_plot] if focus_plot >= 0 and focus_plot < Land.view.size() else {}
	manage.visible = not p.is_empty() and Biz.is_biz(p) and p.owner == Net.my_name
	if not manage.visible:
		return
	var b: Dictionary = p.biz
	var lvl := int(p.level)
	stats_label.text = "%s  •  Depo %d/%d birim  •  Puan %.1f/5  •  Son dakika %d müşteri  •  Birim fiyat %s" % [
		Biz.NAMES[lvl], int(b.stock), Biz.MAX_STOCK[lvl], float(b.rating), int(b.last_customers), U.money(Biz.unit_price(p))]
	cash_btn.text = "Kasayı Topla (%s)" % U.money(int(b.cash))
	cash_btn.disabled = int(b.cash) <= 0
	_update_price_label()


func _update_price_label() -> void:
	if focus_plot < 0 or focus_plot >= Land.view.size() or not Biz.is_biz(Land.view[focus_plot]):
		return
	var lvl := int(Land.view[focus_plot].level)
	price_label.text = "×%.2f = %s/müşteri" % [price_slider.value, U.money(int(round(Biz.UNIT_PRICE[lvl] * price_slider.value)))]
