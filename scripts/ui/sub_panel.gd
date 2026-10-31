extends "res://scripts/ui/game_panel.gd"
## Denizaltı tersanesi (2.0): denizaltı al, yükselt, dal. mode = "book": deniz canlıları ansiklopedisi.

var mode := "shop"
var box: VBoxContainer


func _ready() -> void:
	build("Deniz Canlıları Ansiklopedisi" if mode == "book" else "Denizaltı Tersanesi", Vector2(600, 0))
	if mode == "shop":
		money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Deep.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var my: Dictionary = Deep.my
	if mode == "book":
		var found: Array = my.get("found", [])
		add_label(box, "Keşfedilen: %d / %d (hepsine %s ödül)" % [found.size(), Deep.CREATURES.size(), U.money(Deep.ALL_REWARD)], 16, Color("#fde68a"))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 30)
		box.add_child(grid)
		for k in Deep.CREATURES:
			var known: bool = k in found
			add_label(grid, ("✓ " + str(Deep.CREATURES[k][0])) if known else "? ? ?", 15, Color(str(Deep.CREATURES[k][1])) if known else Color("#64748b"))
		add_label(box, "Canlının yanına git ve E ile tara. Bazıları nadir ve hızlıdır; Mavi Balina en büyük ödülü verir.", 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	if not bool(my.get("sub", false)):
		add_label(box, "Batık Şehir'e inmek için bir denizaltı gerekir. Karanlıkta farınla keşfet, eserler bul, canlıları tara.", 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buy_button(box, Deep.SUB_PRICE, Deep.buy.bind("sub"), Deep.SUB_LEVEL, "Denizaltı al")
		return
	add_button(box, "BATIK ŞEHİR'E DAL", func(): Deep.dive(); close()).custom_minimum_size = Vector2(0, 44)
	for up in [["battery_lv", "Akü", Deep.BATTERY, "sn"], ["light_lv", "Far", Deep.LIGHT, "px görüş"], ["motor_lv", "Motor", Deep.MOTOR, "× hız"]]:
		var lvl := int(my.get(up[0], 0))
		var row := HBoxContainer.new()
		box.add_child(row)
		var table: Array = up[2]
		add_label(row, "%s: %s %s (kademe %d/%d)" % [up[1], str(table[lvl]), up[3], lvl + 1, table.size()], 15).size_flags_horizontal = SIZE_EXPAND_FILL
		if lvl + 1 < table.size():
			buy_button(row, Deep.UP_PRICES[lvl], Deep.buy.bind(up[0]), 0, "Yükselt")
		else:
			add_label(row, "En üst ✓", 14, Settings.ok_text())
	add_label(box, "Ansiklopedi: %d / %d tür" % [my.get("found", []).size(), Deep.CREATURES.size()], 14, Color("#bae6fd"))
