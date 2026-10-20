extends "res://scripts/ui/game_panel.gd"
## Emlak ofisi / arsa penceresi: satın al, inşa et, sat.

var focus_plot := -1
var list: VBoxContainer


func _ready() -> void:
	var title := "Emlak Ofisi — Arsalar" if focus_plot < 0 else "Arsa #%d" % (focus_plot + 1)
	build(title, Vector2(860, 0 if focus_plot >= 0 else 560))
	add_label(body, "Arsalar her dakika kira getirir (çevrimdışıyken bile). Bina dikerek kirayı artır. Kişi başı en fazla %d arsa." % Land.MAX_PER_PLAYER, 15, Color("#94a3b8"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 90 if focus_plot >= 0 else 440)
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	Land.plots_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var money := Net.my_money()
	for i in Land.view.size():
		if focus_plot >= 0 and i != focus_plot:
			continue
		var p: Dictionary = Land.view[i]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#262b3b")
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		row.add_theme_stylebox_override("panel", sb)
		list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		add_label(h, "#%d" % (i + 1), 22, Color("#facc15")).custom_minimum_size = Vector2(46, 0)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(info)
		var mine: bool = p.owner == Net.my_name
		var owner_text: String = "Satılık" if p.owner == "" else ("Sahibi: SEN" if mine else "Sahibi: %s" % p.owner)
		add_label(info, "%s  •  %s" % [owner_text, Land.LEVEL_NAMES[int(p.level)]], 17,
			Color("#86efac") if mine else Color.WHITE)
		add_label(info, "Arsa değeri %s  •  Kira %s/dk" % [U.money(int(p.price)), U.money(Land.income_of(p))], 14, Color("#94a3b8"))
		if focus_plot >= 0 and int(p.level) >= 1 and (mine or p.get("door_open", false)):
			add_button(h, "Eve Gir", func(): Homes.enter(i); close())
		if p.owner == "":
			var b := add_button(h, "Satın Al (%s)" % U.money(int(p.price)), Land.buy.bind(i))
			b.disabled = money < int(p.price)
		elif mine:
			if int(p.level) < 3:
				var cost: int = Land.BUILD_COST[int(p.level) + 1]
				var b := add_button(h, "%s inşa et (%s)" % [Land.LEVEL_NAMES[int(p.level) + 1], U.money(cost)], Land.build_up.bind(i))
				b.disabled = money < cost
			add_button(h, "Sat (%s)" % U.money(Land.sell_value(p)), Land.sell.bind(i))
