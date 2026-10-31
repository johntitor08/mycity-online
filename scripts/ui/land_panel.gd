extends "res://scripts/ui/game_panel.gd"
## Emlak ofisi / arsa penceresi: satın al, ev, işletme ya da tarla kur, büyüt, sat; işletmeyi ve tarlayı yönet.

var focus_plot := -1
var list: VBoxContainer
var manage: VBoxContainer
var stats_label: Label
var cash_btn: Button
var price_slider: HSlider
var price_label: Label
var staff_spin: SpinBox
var farm: VBoxContainer
var beds_grid: GridContainer
var crop_opt: OptionButton
var farm_info: Label
var _crop_keys: Array = []
var _bed_widgets: Array = []      # [{name, bar, state}]
var _tick := 0.0


func _ready() -> void:
	var title := "Emlak Ofisi — Arsalar" if focus_plot < 0 else "Arsa #%d" % (focus_plot + 1)
	build(title, Vector2(880, 0 if focus_plot >= 0 else 560))
	add_label(body, "Ev kurarsan dakikalık kira alırsın; büfe açarsan müşterilerden kazanırsın (malzeme koyman gerekir). Kişi başı en fazla %d arsa." % Land.MAX_PER_PLAYER, 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var h := 430
	if focus_plot >= 0 and focus_plot < Land.view.size():
		var fp: Dictionary = Land.view[focus_plot]
		if Biz.is_biz(fp) and int(fp.level) >= 2:
			h = 330
		else:
			h = 360 if Farm.is_ranch(fp) and fp.owner == Net.my_name else (150 if fp.owner == Net.my_name else 96)
	scroll.custom_minimum_size = Vector2(0, h)
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	_build_manage()
	_build_farm()
	Land.plots_changed.connect(_refresh)
	Farm.crops_changed.connect(_refresh_farm)
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
	if farm != null:
		_refresh_farm()


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
	var sec: Dictionary = p.get("sec", {})
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(info)
	var mine: bool = p.owner == Net.my_name
	var is_biz := Biz.is_biz(p)
	var owner_text: String = "Satılık" if p.owner == "" else ("Sahibi: SEN" if mine else "Sahibi: %s" % p.owner)
	var guard := ("  [kilitli]" if sec.get("lock", false) else "") + ("  [alarmlı]" if sec.get("alarm", false) else "")
	add_label(info, "%s  •  %s%s" % [owner_text, Land.building_name(p), guard], 17, Color("#86efac") if mine else Color.WHITE)
	if Farm.is_farm(p):
		add_label(info, "Arsa değeri %s  •  6 tarh  •  %s" % [U.money(int(p.price)), _farm_summary(p)], 14, Color("#94a3b8"))
	elif Farm.is_ranch(p):
		add_label(info, "Arsa değeri %s  •  %d hayvan" % [U.money(int(p.price)), p.get("ranch", {}).get("animals", []).size()], 14, Color("#94a3b8"))
	elif is_biz:
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
		if focus_plot >= 0 and is_biz and lvl >= 2:
			_menu_box(i, p, false)
		return
	if lvl == 0:
		buy_button(h, Land.BUILD_COST[1], Land.build_up.bind(i, "home"), 0, "Ev kur")
		buy_button(h, Biz.BUILD_COST[1], Land.build_up.bind(i, "biz"), Biz.LEVEL_GATE[1], "Büfe aç")
		buy_button(h, Farm.BUILD_COST, Land.build_up.bind(i, "farm"), Farm.LEVEL_GATE, "Tarla kur")
		buy_button(h, Farm.RANCH_COST, Land.build_up.bind(i, "ranch"), Farm.RANCH_LEVEL, "Ahır kur")
	elif lvl < 3 and not Farm.is_farm(p) and not Farm.is_ranch(p):
		if is_biz:
			buy_button(h, Biz.BUILD_COST[lvl + 1], Land.build_up.bind(i, "biz"), Biz.LEVEL_GATE[lvl + 1], "%s'ye büyüt" % Biz.NAMES[lvl + 1])
		else:
			var gate: int = [0, 1, Rpg.LEVEL_GATES.villa, Rpg.LEVEL_GATES.tower][lvl + 1]
			buy_button(h, Land.BUILD_COST[lvl + 1], Land.build_up.bind(i, "home"), gate, "%s inşa et" % Land.LEVEL_NAMES[lvl + 1])
	if focus_plot >= 0 and lvl >= 1 and not Farm.is_farm(p) and not Farm.is_ranch(p):
		_tint_row(i, p)
	if focus_plot >= 0 and Farm.is_ranch(p):
		_ranch_box(i, p)
	if focus_plot >= 0 and is_biz and lvl >= 2:
		_menu_box(i, p, true)
	if focus_plot >= 0 and lvl >= 1 and str(p.get("kind", "home")) == "home":
		add_button(h, "Eve Gir", func(): Homes.enter(i); close())
	add_button(h, "Sat (%s)" % U.money(Land.sell_value(p)), Land.sell.bind(i))


## İşletme yönetimi bölümü (sadece kendi işletmenin yanındayken görünür).
var _kitchen_btn: Button


func _build_manage() -> void:
	manage = VBoxContainer.new()
	manage.add_theme_constant_override("separation", 8)
	manage.visible = false
	body.add_child(manage)
	manage.add_child(HSeparator.new())
	add_label(manage, "İşletme Yönetimi", 20, Color("#facc15"))
	stats_label = add_label(manage, "", 15)
	# 2.0: kafe ve restoranda aktif mutfak servisi
	var kb := add_button(manage, "Mutfağa gir — 90 sn servis vardiyası (siparişleri yetiştir, bahşiş topla)", func():
		var kp = preload("res://scripts/ui/kitchen_panel.gd").new()
		kp.mode = "shift"
		kp.plot = focus_plot
		switch_to(kp))
	kb.custom_minimum_size = Vector2(0, 38)
	_kitchen_btn = kb
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
	if _kitchen_btn != null:
		_kitchen_btn.visible = manage.visible and int(p.get("level", 0)) >= 2
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


## Ahır yönetimi: hayvanlar, besleme, ürün toplama, hayvan alma.
func _ranch_box(i: int, p: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	list.add_child(box)
	var animals: Array = p.get("ranch", {}).get("animals", [])
	var now := Land.server_now()
	add_label(box, "Ahır — %d/%d hayvan" % [animals.size(), Farm.MAX_ANIMALS], 18, Color("#facc15"))
	var ready := 0
	for a in animals:
		var info: Dictionary = Farm.ANIMALS[str(a.k)]
		var n := Farm.animal_ready(a, now)
		ready += n
		var left := float(a.fed) - now
		add_label(box, "%s — %s  •  %s" % [info.name, ("tok (%d dk)" % int(left / 60.0)) if left > 0 else "AÇ! üretmiyor",
			("%d %s hazır" % [n, Farm.PRODUCTS[info.product].name]) if n > 0 else "ürün bekleniyor"], 14,
			Settings.ok_text() if left > 0 else Settings.bad_text())
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	box.add_child(r1)
	add_button(r1, "Ürünleri topla (%d)" % ready, Farm.collect_animals.bind(i)).disabled = ready <= 0
	add_button(r1, "Yemle besle (%s/hayvan)" % U.money(Farm.FEED_PRICE), Farm.feed_animals.bind(i, false))
	add_button(r1, "Buğdayla besle (2/hayvan)", Farm.feed_animals.bind(i, true))
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	box.add_child(r2)
	add_label(r2, "Hayvan al:", 14)
	for k in Farm.ANIMALS:
		var info: Dictionary = Farm.ANIMALS[k]
		buy_button(r2, int(info.price), Farm.buy_animal.bind(i, k), 0, info.name).disabled = animals.size() >= Farm.MAX_ANIMALS or Net.my_money() < int(info.price)
	add_label(box, "Tavuk 4 dk'da yumurta, inek 8 dk'da 2 süt, koyun 10 dk'da 2 yün verir — sadece tokken. Bir besleme 30 dk yeter. Ürünler Hal'de satılır ya da mutfakta yemek olur.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Kafe/restoran menüsü: sahibi yemek koyar ve fiyat belirler (ve burada pişirebilir), misafirler sipariş verir.
func _menu_box(i: int, p: Dictionary, mine: bool) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	list.add_child(box)
	var menu := Biz.menu_of(p)
	var lvl := int(p.level)
	add_label(box, "Menü — %d/%d çeşit  •  Bugüne kadar %d porsiyon satıldı  •  Son dakika %d sipariş" % [menu.size(), Biz.MENU_SLOTS[lvl],
		int(p.biz.get("menu_sold", 0)), int(p.biz.get("last_menu", 0))], 18, Color("#facc15"))
	if menu.is_empty():
		add_label(box, "Menü boş." if not mine else "Menü boş. Pişirdiğin yemekleri menüye koy; NPC müşteriler ve oyuncular sipariş verir.", 14, Color("#94a3b8"))
	for k in menu:
		var e: Dictionary = menu[k]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		box.add_child(r)
		var info: Dictionary = Kitchen.RECIPES[k]
		var val := Kitchen.dish_value(k)
		var l := add_label(r, "%s ×%d  —  %s%s" % [info.name, int(e.n), U.money(int(e.price)), ("  (değeri ~%s)" % U.money(val)) if mine else ("  +%d enerji" % int(info.energy))], 15)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		if mine:
			add_button(r, "−", Biz.menu_price.bind(i, k, int(e.price) - maxi(5, int(val * 0.1))))
			add_button(r, "+", Biz.menu_price.bind(i, k, int(e.price) + maxi(5, int(val * 0.1))))
			add_button(r, "Geri al", Biz.menu_take.bind(i, k))
		else:
			add_button(r, "Sipariş ver (%s)" % U.money(int(e.price)), Biz.order.bind(i, k)).disabled = Net.my_money() < int(e.price)
	if not mine:
		return
	var items: Dictionary = Rpg.sheet.get("items", {})
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	box.add_child(r2)
	add_label(r2, "Çantadan ekle:", 14)
	var any := false
	for k in Kitchen.RECIPES:
		if int(items.get(k, 0)) > 0:
			any = true
			add_button(r2, "%s ×%d" % [Kitchen.RECIPES[k].name, int(items[k])], Biz.menu_add.bind(i, k))
	if not any:
		add_label(r2, "çantanda yemek yok", 14, Color("#7c859e"))
	add_label(box, "Mutfak (burada da pişirebilirsin):", 15, Color("#cbd5e1"))
	var g := GridContainer.new()
	g.columns = 4
	box.add_child(g)
	for k in Kitchen.RECIPES:
		var ok := true
		for ing in Kitchen.RECIPES[k].needs:
			var have := Jobs.my_fish.size() if ing == "balik" else int(Farm.my_crops.get(ing, 0))
			if have < int(Kitchen.RECIPES[k].needs[ing]):
				ok = false
		var b := add_button(g, "Pişir: %s" % Kitchen.RECIPES[k].name, Kitchen.cook.bind(k))
		b.disabled = not ok
		b.tooltip_text = ", ".join(Kitchen.RECIPES[k].needs.keys().map(func(n): return "%d %s" % [Kitchen.RECIPES[k].needs[n], Kitchen.ing_name(n)]))
	add_label(box, "Müşteri fiyat yemeğin değerine yakınsa sipariş verir; çok pahalıysa vazgeçer ve puan düşer. Çeşit arttıkça daha çok müşteri gelir.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Bina dış rengi seçimi (500 TL).
func _tint_row(i: int, p: Dictionary) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	list.add_child(r)
	add_label(r, "Dış boya (%s):" % U.money(Land.TINT_PRICE), 14, Color("#cbd5e1"))
	for k in Land.TINTS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.tooltip_text = Land.TINT_NAMES[k]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Land.TINTS[k]
		sb.set_corner_radius_all(6)
		var cur: bool = int(p.get("tint", 0)) == k
		sb.border_color = Color("#facc15") if cur else Color(0, 0, 0, 0.6)
		sb.set_border_width_all(3 if cur else 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(Land.set_tint.bind(i, k))
		r.add_child(b)


func _farm_summary(p: Dictionary) -> String:
	var now := Land.server_now()
	var counts := {"ready": 0, "growing": 0, "empty": 0, "rotten": 0}
	for b in p.farm.beds:
		var st: String = Farm.bed_state(b, now)[0]
		counts[st] = int(counts[st]) + 1
	return "%d olgun, %d büyüyor, %d boş" % [counts.ready, counts.growing, counts.empty + counts.rotten]


## Tarla yönetimi (sadece kendi tarlanın yanındayken görünür).
func _build_farm() -> void:
	farm = VBoxContainer.new()
	farm.add_theme_constant_override("separation", 8)
	farm.visible = false
	body.add_child(farm)
	farm.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	farm.add_child(head)
	add_label(head, "Tarla", 20, Color("#facc15"))
	farm_info = add_label(head, "", 14, Color("#94a3b8"))
	farm_info.size_flags_horizontal = SIZE_EXPAND_FILL
	farm_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	beds_grid = GridContainer.new()
	beds_grid.columns = 3
	beds_grid.add_theme_constant_override("h_separation", 8)
	beds_grid.add_theme_constant_override("v_separation", 8)
	farm.add_child(beds_grid)
	for k in Farm.BEDS:
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#3b2a1a")
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(270, 0)
		beds_grid.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var nm := add_label(v, "", 16)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		v.add_child(bar)
		var st := add_label(v, "", 13, Color("#cbd5e1"))
		_bed_widgets.append({"name": nm, "bar": bar, "state": st, "box": sb})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	farm.add_child(row)
	crop_opt = OptionButton.new()
	crop_opt.custom_minimum_size = Vector2(330, 0)
	row.add_child(crop_opt)
	add_button(row, "Boş tarhlara ek", _plant)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	farm.add_child(row2)
	add_button(row2, "Sula (⚡1)", func(): Farm.water(focus_plot))
	add_button(row2, "Gübrele (%s/tarh, +1 ürün)" % U.money(Farm.FERTILIZER_PRICE), func(): Farm.fertilize(focus_plot))
	add_button(row2, "Hasat et", func(): Farm.harvest(focus_plot))
	add_label(farm, "Sulanmayan ekin yarı verim verir; yağmur ve kar tarlayı kendiliğinden sular. Fırtına büyüyen ekine zarar verebilir. Olgun ekini uzun süre toplamazsan çürür. Ürünleri Pazar Yeri'ndeki Hal'de sat ya da işletmene malzeme yap.", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Env.changed.connect(_fill_crops)
	Rpg.sheet_changed.connect(_fill_crops)
	_fill_crops()


func _plant() -> void:
	if crop_opt.selected >= 0 and crop_opt.selected < _crop_keys.size():
		Farm.plant(focus_plot, _crop_keys[crop_opt.selected])


func _fill_crops() -> void:
	var sel := crop_opt.selected
	crop_opt.clear()
	_crop_keys.clear()
	var lvl := int(Rpg.sheet.get("level", 1))
	for k in Farm.CROPS:
		var c: Dictionary = Farm.CROPS[k]
		var g := Farm.grow_time(k, Env.season)
		var tag := "  ★mevsimi" if c.season == Env.season else ""
		var txt := "%s — tohum %s, %d dk%s" % [c.name, U.money(int(c.seed)), int(ceil(g / 60.0)), tag]
		if lvl < int(c.level):
			txt = "%s (Sv.%d gerekli)" % [c.name, c.level]
		crop_opt.add_item(txt)
		crop_opt.set_item_disabled(crop_opt.item_count - 1, lvl < int(c.level))
		_crop_keys.append(k)
	crop_opt.selected = clampi(sel, 0, crop_opt.item_count - 1)


func _refresh_farm() -> void:
	var p: Dictionary = Land.view[focus_plot] if focus_plot >= 0 and focus_plot < Land.view.size() else {}
	farm.visible = not p.is_empty() and Farm.is_farm(p) and p.owner == Net.my_name and p.get("farm") is Dictionary
	if not farm.visible:
		return
	var now := Land.server_now()
	var stock := 0
	for k in Farm.my_crops:
		stock += int(Farm.my_crops[k])
	farm_info.text = "Mevsim: %s  •  Ambar: %d ürün" % [Env.SEASON_NAMES.get(Env.season, ""), stock]
	for k in Farm.BEDS:
		var b: Dictionary = p.farm.beds[k]
		var w: Dictionary = _bed_widgets[k]
		var st: Array = Farm.bed_state(b, now)
		var crop: Dictionary = Farm.CROPS.get(str(b.c), {})
		w.name.text = "Tarh %d: %s" % [k + 1, crop.get("name", "boş")]
		w.bar.value = float(st[1]) * 100.0
		var flags := ("  sulandı" if b.w else "  (kuru)") + ("  +gübre" if b.f else "") + ("  hasarlı!" if b.dmg else "")
		match st[0]:
			"empty":
				w.state.text = "Ekime hazır"
				w.box.bg_color = Color("#3b2a1a")
			"growing":
				var left := float(b.t) + float(b.g) - now
				w.state.text = "%d:%02d kaldı%s" % [int(left) / 60, int(left) % 60, flags]
				w.box.bg_color = Color("#2b3a1a") if b.w else Color("#3b2a1a")
			"ready":
				w.state.text = "HASADA HAZIR!%s" % flags
				w.box.bg_color = Color("#14532d")
			"rotten":
				w.state.text = "Çürüdü — hasat et ile temizle"
				w.box.bg_color = Color("#44241a")


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0 and farm != null and farm.visible:
		_tick = 0.0
		_refresh_farm()
