extends "res://scripts/ui/game_panel.gd"
## Takas penceresi: solda benim teklifim (düzenlenebilir), sağda karşı tarafınki. İkisi onaylayınca takas olur.

var mine_box: VBoxContainer
var theirs_box: VBoxContainer
var status: Label
var ok_btn: Button
var money: SpinBox
var _fish_sel := {}                # kova indeksi -> true
var _barn := {}                    # anahtar -> adet
var _items := {}


func _ready() -> void:
	build("Takas — %s" % Trade.view.get("other", "?"), Vector2(820, 0))
	add_label(body, "Koymak istediklerini seç ve \"Teklifi güncelle\"ye bas. İki taraf da onaylayınca takas tek seferde yapılır; teklif değişirse onaylar sıfırlanır.", 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	body.add_child(cols)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(420, 380)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left)
	mine_box = VBoxContainer.new()
	mine_box.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_child(mine_box)
	theirs_box = VBoxContainer.new()
	theirs_box.custom_minimum_size = Vector2(340, 0)
	cols.add_child(theirs_box)
	status = add_label(body, "", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	add_button(row, "Teklifi güncelle", _push).custom_minimum_size = Vector2(170, 40)
	ok_btn = add_button(row, "Onayla", func(): Trade.confirm())
	ok_btn.custom_minimum_size = Vector2(140, 40)
	add_button(row, "İptal", func(): close()).custom_minimum_size = Vector2(110, 40)
	_load_from_view()
	_build_mine()
	_refresh()
	Trade.updated.connect(func(_d): _refresh())
	Trade.closed.connect(func(_t): super.close())


func _my_offer() -> Dictionary:
	return Trade.view.get("offers", {}).get(Trade.view.get("me", "a"), Trade.empty_offer())


func _load_from_view() -> void:
	var o := _my_offer()
	_fish_sel = {}
	for i in o.fish:
		_fish_sel[int(i)] = true
	_barn = o.barn.duplicate()
	_items = o.items.duplicate()


func _build_mine() -> void:
	for c in mine_box.get_children():
		c.queue_free()
	add_label(mine_box, "Senin teklifin", 18, Color("#facc15"))
	var r := HBoxContainer.new()
	mine_box.add_child(r)
	add_label(r, "Para:", 15)
	money = add_spin(r, 0, maxi(0, Net.my_money()), 10, int(_my_offer().money))
	money.size_flags_horizontal = SIZE_EXPAND_FILL
	if not Jobs.my_fish.is_empty():
		add_label(mine_box, "Balık kovası", 15, Color("#cbd5e1"))
		for i in Jobs.my_fish.size():
			var cb := CheckBox.new()
			cb.text = "%s (%s)" % [Jobs.my_fish[i].name, U.money(int(Jobs.my_fish[i].price))]
			cb.button_pressed = _fish_sel.has(i)
			cb.toggled.connect(func(on): _toggle_fish(i, on))
			mine_box.add_child(cb)
	if not Farm.my_crops.is_empty():
		add_label(mine_box, "Ambar", 15, Color("#cbd5e1"))
		for k in Farm.my_crops:
			_qty_row(k, str(Farm.item_info(k).get("name", k)), int(Farm.my_crops[k]), _barn)
	var items: Dictionary = Rpg.sheet.get("items", {})
	if not items.is_empty():
		add_label(mine_box, "Çanta (yiyecekler)", 15, Color("#cbd5e1"))
		for k in items:
			_qty_row(k, str(Rpg.food_info(k).get("name", k)), int(items[k]), _items)


func _toggle_fish(i: int, on: bool) -> void:
	if on:
		_fish_sel[i] = true
	else:
		_fish_sel.erase(i)


func _qty_row(k: String, label: String, have: int, store: Dictionary) -> void:
	var r := HBoxContainer.new()
	mine_box.add_child(r)
	var l := add_label(r, "%s (%d)" % [label, have], 14)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	var s := add_spin(r, 0, have, 1, int(store.get(k, 0)))
	s.value_changed.connect(func(v):
		if int(v) > 0:
			store[k] = int(v)
		else:
			store.erase(k))


func _push() -> void:
	Trade.offer({"money": int(money.value), "fish": _fish_sel.keys(), "barn": _barn, "items": _items})


func _describe(o: Dictionary, fish_names: Array) -> Array:
	var out: Array = []
	if int(o.money) > 0:
		out.append(U.money(int(o.money)))
	for n in fish_names:
		out.append("Balık: %s" % n)
	for k in o.barn:
		out.append("%d %s" % [int(o.barn[k]), Farm.item_info(k).get("name", k)])
	for k in o.items:
		out.append("%d %s" % [int(o.items[k]), Rpg.food_info(k).get("name", k)])
	return out


func _refresh() -> void:
	var v := Trade.view
	if v.is_empty():
		return
	var me: String = v.me
	var other := "b" if me == "a" else "a"
	for c in theirs_box.get_children():
		c.queue_free()
	add_label(theirs_box, "%s'in teklifi" % v.other, 18, Color("#facc15"))
	var theirs := _describe(v.offers[other], v.get("fish_names", {}).get(other, []))
	if theirs.is_empty():
		add_label(theirs_box, "(henüz bir şey koymadı)", 14, Color("#7c859e"))
	for t in theirs:
		add_label(theirs_box, "• " + t, 15)
	theirs_box.add_child(HSeparator.new())
	add_label(theirs_box, "Senin şu anki teklifin:", 14, Color("#cbd5e1"))
	var mine := _describe(v.offers[me], v.get("fish_names", {}).get(me, []))
	for t in (mine if not mine.is_empty() else ["(boş)"]):
		add_label(theirs_box, "• " + t, 14, Color("#cbd5e1"))
	var ok_me: bool = v.ok[me]
	var ok_other: bool = v.ok[other]
	status.text = "Sen: %s   •   %s: %s" % ["onayladın ✓" if ok_me else "onay bekleniyor", v.other, "onayladı ✓" if ok_other else "onay bekleniyor"]
	status.add_theme_color_override("font_color", Settings.ok_text() if ok_me and ok_other else Color.WHITE)
	ok_btn.disabled = ok_me


func close() -> void:
	if Trade.active():
		Trade.cancel()
	super.close()
