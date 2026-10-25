extends "res://scripts/ui/game_panel.gd"
## Galeri: bisiklet, tekne ve araba satın al.

var list: VBoxContainer
var style_box: VBoxContainer


func _ready() -> void:
	build("Galeri — Araçlar", Vector2(680, 0))
	add_label(body, "Aldığın araca F tuşuyla binip inersin. Bisiklet ve araba karada, tekne sadece denizde kullanılır.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	style_box = VBoxContainer.new()
	style_box.add_theme_constant_override("separation", 6)
	body.add_child(style_box)
	Garage.owned_changed.connect(_refresh)
	Dive.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var lvl := int(Rpg.sheet.get("level", 1))
	for k in Garage.VEHICLES:
		var v: Dictionary = Garage.VEHICLES[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(info)
		add_label(info, "%s  —  %s" % [v.name, U.money(int(v.price))], 19, Color("#facc15"))
		add_label(info, "%s  •  Seviye %d gerekli" % [v.desc, v.level], 14,
			Color("#94a3b8") if lvl >= int(v.level) else Color("#fca5a5"))
		if Garage.owned.has(k):
			add_label(row, "Sende ✓", 17, Color("#86efac"))
		else:
			buy_button(row, int(v.price), Garage.buy.bind(k), int(v.level))
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 12)
	list.add_child(gear)
	var gi := VBoxContainer.new()
	gi.size_flags_horizontal = SIZE_EXPAND_FILL
	gear.add_child(gi)
	add_label(gi, "Dalış Tüpü  —  %s" % U.money(Dive.GEAR_PRICE), 19, Color("#facc15"))
	add_label(gi, "Teknedeyken V ile dal: oksijen %d sn yerine %d sn. Deniz tabanında inci ve batık hazinesi." % [int(Dive.BASE_OXY), int(Dive.GEAR_OXY)], 14, Color("#94a3b8"))
	if Dive.has_gear:
		add_label(gear, "Sende ✓", 17, Color("#86efac"))
	else:
		buy_button(gear, Dive.GEAR_PRICE, Dive.buy_gear)
	_refresh_style()


func _swatches(parent: Node, what: String, current: int, price: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	for i in Garage.PAINTS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.tooltip_text = "%s (%s)" % [Garage.PAINT_NAMES[i], U.money(price)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Garage.PAINTS[i]
		sb.set_corner_radius_all(6)
		sb.border_color = Color.WHITE if i == current else Color(0, 0, 0, 0.6)
		sb.set_border_width_all(3 if i == current else 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(Garage.set_style.bind(what, i))
		h.add_child(b)


func _refresh_style() -> void:
	for c in style_box.get_children():
		c.queue_free()
	if not Garage.owned.has("car") and not Garage.owned.has("bike"):
		return
	style_box.add_child(HSeparator.new())
	add_label(style_box, "Özelleştir (herkes görür)", 18, Color("#facc15"))
	var st := Garage.vstyle
	if Garage.owned.has("car"):
		add_label(style_box, "Araba boyası — %s" % U.money(Garage.CAR_PAINT_PRICE), 14, Color("#cbd5e1"))
		_swatches(style_box, "car", int(st.get("car", -1)), Garage.CAR_PAINT_PRICE)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		style_box.add_child(r)
		add_label(r, "Jant:", 14)
		for i in Garage.RIMS.size():
			var b := add_button(r, "%s%s" % [Garage.RIMS[i], (" (%s)" % U.money(Garage.RIM_PRICES[i])) if Garage.RIM_PRICES[i] > 0 else ""], Garage.set_style.bind("rims", i))
			b.disabled = int(st.get("rims", 0)) == i
	if Garage.owned.has("bike"):
		add_label(style_box, "Bisiklet rengi — %s" % U.money(Garage.BIKE_PAINT_PRICE), 14, Color("#cbd5e1"))
		_swatches(style_box, "bike", int(st.get("bike", -1)), Garage.BIKE_PAINT_PRICE)
