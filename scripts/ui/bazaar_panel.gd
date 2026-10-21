extends "res://scripts/ui/game_panel.gd"
## Pazar Yeri: oyuncuların ilanları (balık, yiyecek, mobilya, arsa). Satın al, ilan ver, ilanını kaldır.

var listings_box: VBoxContainer
var sell_box: VBoxContainer
var browse: VBoxContainer
var create: VBoxContainer
var kind_opt: OptionButton
var item_opt: OptionButton
var price_spin: SpinBox
var _items: Array = []      # item_opt sırasıyla ref değerleri
const KINDS := ["fish", "food", "furniture", "plot"]


func _ready() -> void:
	build("Pazar Yeri", Vector2(760, 520))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	add_button(tabs, "İlanlar", _show.bind(false))
	add_button(tabs, "İlan Ver", _show.bind(true))
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
	create.add_child(item_opt)
	var row := HBoxContainer.new()
	create.add_child(row)
	add_label(row, "Fiyat:", 17)
	price_spin = add_spin(row, 1, Bazaar.MAX_PRICE, 10, 100)
	price_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	add_button(create, "İlanı Yayınla", _publish).custom_minimum_size = Vector2(0, 40)
	add_label(create, "Eşya satılana kadar emanette durur; ilanı kaldırırsan geri gelir. Arsa ilanı satılınca arsa ve evi alıcıya geçer (mobilyalar sende kalır).", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
				item_opt.add_item("%s ×%d" % [Rpg.FOODS[k].name, items[k]])
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
	if _items.is_empty():
		item_opt.add_item("(satılacak bir şeyin yok)")
		item_opt.disabled = true
	else:
		item_opt.disabled = false


func _publish() -> void:
	if _items.is_empty():
		return
	Bazaar.list_item(KINDS[kind_opt.selected], _items[item_opt.selected], int(price_spin.value))
	_show(false)
