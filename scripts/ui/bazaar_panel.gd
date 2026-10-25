extends "res://scripts/ui/game_panel.gd"
## Pazar Yeri: oyuncuların ilanları (balık, yiyecek, mobilya, arsa, ürün). Satın al, ilan ver, ilanını kaldır.
## Hal: tarla ürünlerini şehre sabit fiyattan sat (mevsim dışı ürün daha pahalı).

var listings_box: VBoxContainer
var sell_box: VBoxContainer
var browse: VBoxContainer
var create: VBoxContainer
var kind_opt: OptionButton
var item_opt: OptionButton
var price_spin: SpinBox
var qty_row: HBoxContainer
var qty_spin: SpinBox
var hal: VBoxContainer
var hal_box: VBoxContainer
var fish_btn: Button
var _items: Array = []      # item_opt sırasıyla ref değerleri
const KINDS := ["fish", "food", "furniture", "plot", "crop"]


func _ready() -> void:
	build("Pazar Yeri", Vector2(760, 520))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	add_button(tabs, "İlanlar", _show.bind(false))
	add_button(tabs, "İlan Ver", _show.bind(true))
	add_button(tabs, "Hal (ürün ve balık sat)", _show_hal)
	add_label(tabs, "   Satıştan %%%d pazar komisyonu kesilir." % int(Bazaar.COMMISSION * 100), 13, Color("#94a3b8"))
	body.add_child(HSeparator.new())

	browse = VBoxContainer.new()
	browse.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(browse)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browse.add_child(scroll)
	listings_box = VBoxContainer.new()
	listings_box.size_flags_horizontal = SIZE_EXPAND_FILL
	listings_box.add_theme_constant_override("separation", 6)
	scroll.add_child(listings_box)

	create = VBoxContainer.new()
	create.visible = false
	create.add_theme_constant_override("separation", 10)
	body.add_child(create)
	add_label(create, "Ne satmak istiyorsun?", 17, Color("#93c5fd"))
	kind_opt = OptionButton.new()
	for k in KINDS:
		kind_opt.add_item(Bazaar.KIND_NAMES[k])
	kind_opt.item_selected.connect(func(_i): _fill_items())
	create.add_child(kind_opt)
	item_opt = OptionButton.new()
	item_opt.item_selected.connect(func(_i): _update_qty())
	create.add_child(item_opt)
	qty_row = HBoxContainer.new()
	create.add_child(qty_row)
	add_label(qty_row, "Adet:", 17)
	qty_spin = add_spin(qty_row, 1, Farm.MAX_STACK, 1, 1)
	var row := HBoxContainer.new()
	create.add_child(row)
	add_label(row, "Fiyat:", 17)
	price_spin = add_spin(row, 1, Bazaar.MAX_PRICE, 10, 100)
	price_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	add_button(create, "İlanı Yayınla", _publish).custom_minimum_size = Vector2(0, 40)
	add_label(create, "Eşya satılana kadar emanette durur; ilanı kaldırırsan geri gelir. Arsa ilanı satılınca arsa ve evi alıcıya geçer (mobilyalar sende kalır).", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hal = VBoxContainer.new()
	hal.visible = false
	hal.add_theme_constant_override("separation", 8)
	body.add_child(hal)
	add_label(hal, "Hal: tarla ürünlerini şehre sat. Mevsimi dışındaki ürün %%%d daha pahalıya gider." % int((Farm.OUT_OF_SEASON_PRICE - 1.0) * 100), 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hal_box = VBoxContainer.new()
	hal_box.add_theme_constant_override("separation", 6)
	hal.add_child(hal_box)
	add_button(hal, "Bütün ürünleri sat", func(): Farm.sell("")).custom_minimum_size = Vector2(0, 40)
	fish_btn = add_button(hal, "", Jobs.sell_fish)
	fish_btn.custom_minimum_size = Vector2(0, 40)
	Jobs.inventory_changed.connect(_fill_hal)
	Farm.crops_changed.connect(_fill_hal)
	Farm.crops_changed.connect(_fill_items)
	Env.changed.connect(_fill_hal)
	_fill_hal()
	Bazaar.listings_changed.connect(_refresh)
	Jobs.inventory_changed.connect(_fill_items)
	Rpg.sheet_changed.connect(_fill_items)
	Homes.depot_changed.connect(_fill_items)
	Land.plots_changed.connect(_fill_items)
	_refresh()
	_fill_items()


func _show(sell: bool) -> void:
	create.visible = sell
	browse.visible = not sell
	hal.visible = false


func _show_hal() -> void:
	create.visible = false
	browse.visible = false
	hal.visible = true


func _fill_hal() -> void:
	for c in hal_box.get_children():
		c.queue_free()
	var any := false
	for k in Farm.CROPS.keys() + Farm.PRODUCTS.keys():
		var n := int(Farm.my_crops.get(k, 0))
		var c: Dictionary = Farm.item_info(k)
		if Farm.PRODUCTS.has(k) and n <= 0:
			continue       # hayvan ürünleri sadece varsa listelenir
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		hal_box.add_child(h)
		var dot := ColorRect.new()
		dot.color = Color(c.color)
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(dot)
		var price := Farm.sell_price(k, Env.season)
		var l := add_label(h, "%s  ×%d   •   %s/adet%s" % [c.name, n, U.money(price), "  (mevsim dışı!)" if c.has("season") and c.season != Env.season else ""], 16,
			Color.WHITE if n > 0 else Color("#64748b"))
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		var b := add_button(h, "Sat (%s)" % U.money(price * n), func(): Farm.sell(k))
		b.disabled = n <= 0
		any = any or n > 0
	if not any:
		add_label(hal_box, "Ambarın boş. Arsana tarla kurup ekin yetiştirebilirsin.", 14, Color("#7c859e"))
	if fish_btn != null:
		var val := 0
		for f in Jobs.my_fish:
			val += int(f.price)
		fish_btn.text = "Kovadaki %d balığı sat (%s)" % [Jobs.my_fish.size(), U.money(val)]
		fish_btn.disabled = Jobs.my_fish.is_empty()


func _refresh() -> void:
	for c in listings_box.get_children():
		c.queue_free()
	if Bazaar.listings.is_empty():
		add_label(listings_box, "Henüz ilan yok. İlk ilanı sen ver!", 16, Color("#7c859e"))
	for l in Bazaar.listings:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#262b3b")
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		row.add_theme_stylebox_override("panel", sb)
		listings_box.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		add_label(h, Bazaar.KIND_NAMES.get(l.kind, "?"), 13, Color("#93c5fd")).custom_minimum_size = Vector2(70, 0)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(info)
		add_label(info, str(l.label), 16)
		add_label(info, "Satıcı: %s" % l.seller, 13, Color("#94a3b8"))
		add_label(h, U.money(int(l.price)), 17, Color("#86efac"))
		if l.seller == Net.my_name:
			add_button(h, "Kaldır", Bazaar.cancel.bind(int(l.id)))
		else:
			add_button(h, "Satın Al", Bazaar.buy.bind(int(l.id)))


func _fill_items() -> void:
	item_opt.clear()
	_items.clear()
	match KINDS[kind_opt.selected]:
		"fish":
			for i in Jobs.my_fish.size():
				var f: Dictionary = Jobs.my_fish[i]
				item_opt.add_item("%s (değeri %s)" % [f.name, U.money(int(f.price))])
				_items.append(i)
		"food":
			var items: Dictionary = Rpg.sheet.get("items", {})
			for k in items:
				item_opt.add_item("%s ×%d" % [Rpg.food_info(k).get("name", k), items[k]])
				_items.append(k)
		"furniture":
			for k in Homes.depot:
				item_opt.add_item("%s ×%d" % [Homes.FURNITURE[k].name, Homes.depot[k]])
				_items.append(k)
		"plot":
			for i in Land.view.size():
				if Land.view[i].owner == Net.my_name:
					item_opt.add_item("Arsa #%d (%s)" % [i + 1, Land.building_name(Land.view[i])])
					_items.append(i)
		"crop":
			for k in Farm.my_crops:
				item_opt.add_item("%s ×%d" % [Farm.item_info(k).get("name", k), Farm.my_crops[k]])
				_items.append(k)
	if _items.is_empty():
		item_opt.add_item("(satılacak bir şeyin yok)")
		item_opt.disabled = true
	else:
		item_opt.disabled = false
	_update_qty()


func _update_qty() -> void:
	var is_crop: bool = KINDS[kind_opt.selected] == "crop"
	qty_row.visible = is_crop
	if is_crop and not _items.is_empty():
		qty_spin.max_value = maxi(1, int(Farm.my_crops.get(_items[item_opt.selected], 1)))


func _publish() -> void:
	if _items.is_empty():
		return
	Bazaar.list_item(KINDS[kind_opt.selected], _items[item_opt.selected], int(price_spin.value), int(qty_spin.value))
	_show(false)
