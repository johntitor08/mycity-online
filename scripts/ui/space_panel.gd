extends "res://scripts/ui/game_panel.gd"
## Uzay üssü atölyesi ve Ay üssü kubbesi (1.8). mode = "shop" (Dünya) ya da "base" (Ay).

var mode := "shop"
var box: VBoxContainer


func _ready() -> void:
	build("Roket Atölyesi ve Uzay Pazarı" if mode == "shop" else "Ay Üssü", Vector2(600, 0))
	if mode == "shop":
		money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Space.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var my: Dictionary = Space.my
	var cargo := "Ay Taşı: %d   •   Helyum-3: %d" % [int(my.rocks), int(my.he)]
	add_label(box, cargo, 15, Color("#c4b5fd"))
	if mode == "shop":
		for it in [["rocket", "Kendi roketin (fırlatma başına %s yakıt)" % U.money(Space.FUEL_PRICE), Space.ROCKET_PRICE, Space.ROCKET_LEVEL],
				["suit", "Uzay giysisi (%d sn oksijen)" % int(Space.O2_MAX), Space.SUIT_PRICE, 0],
				["drill", "Ay matkabı (Ay taşı kazar)", Space.DRILL_PRICE, 0]]:
			var row := HBoxContainer.new()
			box.add_child(row)
			add_label(row, it[1], 14).size_flags_horizontal = SIZE_EXPAND_FILL
			if bool(my.get(it[0], false)):
				add_label(row, "Sende ✓", 14, Settings.ok_text())
			else:
				buy_button(row, it[2], Space.buy.bind(it[0]), it[3])
	else:
		add_label(box, "Ortak üs projesi: herkesin bağışıyla modüller kurulur.", 14, Color("#94a3b8"))
		for k in Space.MODULES:
			var m: Dictionary = Space.MODULES[k]
			var b: Dictionary = Space.base.get(k, {})
			var row := HBoxContainer.new()
			box.add_child(row)
			var done := Space.module_done(Space.base, k)
			add_label(row, "%s — taş %d/%d, helyum %d/%d" % [m.name, int(b.get("rocks", 0)), int(m.rocks), int(b.get("he", 0)), int(m.he)], 14,
				Settings.ok_text() if done else Color.WHITE).size_flags_horizontal = SIZE_EXPAND_FILL
			if done:
				add_label(row, "Kuruldu ✓", 14, Settings.ok_text())
			else:
				add_button(row, "Bağışla", Space.donate.bind(k)).disabled = int(my.rocks) + int(my.he) <= 0
		if Space.module_done(Space.base, "sera"):
			var h := add_button(box, "Seradan Ay Çileği topla (%s)" % U.money(600), Space.harvest)
			h.disabled = bool(my.get("harvested", false))
	var money := int(my.rocks) * Space.ROCK_PRICE + int(my.he) * Space.HE_PRICE
	var sr := HBoxContainer.new()
	box.add_child(sr)
	add_label(sr, "Pazar: Ay Taşı %s, Helyum-3 %s" % [U.money(Space.ROCK_PRICE), U.money(Space.HE_PRICE)], 14).size_flags_horizontal = SIZE_EXPAND_FILL
	add_button(sr, "Hepsini sat (%s)" % U.money(money), Space.sell).disabled = money <= 0
