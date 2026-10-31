extends "res://scripts/ui/game_panel.gd"
## Tuning Garajı (1.9): motor, lastik, nitro, spoyler, neon.

var box: VBoxContainer


func _ready() -> void:
	build("Tuning Garajı", Vector2(620, 0))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Tuning.changed.connect(_refresh)
	Garage.owned_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _row(text: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	box.add_child(r)
	add_label(r, text, 15).size_flags_horizontal = SIZE_EXPAND_FILL
	return r


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	if not "car" in Garage.owned:
		add_label(box, "Tuning için önce Galeri'den bir araba almalısın.", 15, Color("#fca5a5"))
		return
	var t: Dictionary = Tuning.my
	add_label(box, "Arabanın hızı: ×%.2f  •  Tutuş: %.1f  •  Drift rekorun: %d" % [Tuning.speed_mult(t), Tuning.grip(t), int(t.get("drift_best", 0))], 15, Color("#fde68a"))
	for part in [["engine", "Motor", Tuning.ENGINE, "her kademe +%6 hız"], ["tires", "Spor lastik", Tuning.TIRES, "daha az kayar, keskin döner"],
			["nitro", "Nitro", Tuning.NITRO, "N: 2,5 sn ×1,5 hız (kademe başına 1 şarj)"]]:
		var lvl := int(t.get(part[0], 0))
		var table: Array = part[2]
		var r := _row("%s %d/%d — %s" % [part[1], lvl, table.size(), part[3]])
		if lvl < table.size():
			buy_button(r, int(table[lvl]), Tuning.buy.bind(part[0]), 0, "Yükselt")
		else:
			add_label(r, "En üst ✓", 14, Settings.ok_text())
	var sr := _row("Spoyler — +%2 hız, sportif görünüm")
	if bool(t.get("spoiler", false)):
		add_label(sr, "Takılı ✓", 14, Settings.ok_text())
	else:
		buy_button(sr, Tuning.SPOILER_PRICE, Tuning.buy.bind("spoiler"))
	box.add_child(HSeparator.new())
	add_label(box, "Neon (arabanın altında ışık) — %s" % U.money(Tuning.NEON_PRICE), 15)
	var nr := HBoxContainer.new()
	box.add_child(nr)
	var cur := int(Garage.vstyle.get("neon", -1))
	for i in Tuning.NEONS.size():
		var b := add_button(nr, Tuning.NEON_NAMES[i] + (" ✓" if cur == i else ""), Tuning.buy.bind("neon", i))
		b.add_theme_color_override("font_color", Tuning.NEONS[i])
		b.disabled = cur == i or Net.my_money() < Tuning.NEON_PRICE
	add_label(box, "İpucu: Araba artık kayarak döner. Hızlıyken keskin dönünce drift yaparsın; Drift Alanı'nda puanın rekora yazılır.",
		12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
