extends "res://scripts/ui/game_panel.gd"
## Liman Adası tersanesi (1.6): motor, yakıt deposu ve gövde yükseltmeleri; tekne tamiri.

var box: VBoxContainer


func _ready() -> void:
	build("Tersane — Usta Kemal", Vector2(560, 0))
	add_label(body, "\"Okyanus acımasızdır evlat. Uzak adalara gideceksen teknen sağlam, deposu büyük olmalı.\"", 15, Color("#fde68a")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	Ocean.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var o: Dictionary = Ocean.my
	add_label(box, "Yakıt %d / %d L   •   Gövde %d%%   •   Hız ×%.2f" % [int(o.fuel), int(Ocean.max_fuel(o.up)), int(o.hp),
		Ocean.speed_mult(o.up, 1.0) / 0.75], 16, Color("#facc15"))
	for k in Ocean.UPGRADES:
		var u: Dictionary = Ocean.UPGRADES[k]
		var lvl := int(o.up.get(k, 0))
		var r := HBoxContainer.new()
		box.add_child(r)
		var l := add_label(r, "%s  %s   —  %s" % [u.name, "■".repeat(lvl) + "□".repeat(u.price.size() - lvl), u.desc], 15)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		if lvl >= u.price.size():
			add_label(r, "En üst seviye ✓", 14, Settings.ok_text())
		else:
			buy_button(r, int(u.price[lvl]), Ocean.upgrade.bind(k), 0, "Yükselt")
	box.add_child(HSeparator.new())
	var r2 := HBoxContainer.new()
	box.add_child(r2)
	var need := int(ceil(100.0 - float(o.hp)))
	add_label(r2, "Tamir (%d can)" % need if need > 0 else "Teknen sapasağlam", 15).size_flags_horizontal = SIZE_EXPAND_FILL
	if need > 0:
		buy_button(r2, need * Ocean.REPAIR_PRICE, Ocean.repair, 0, "Tamir et")
	add_label(box, "İpucu: Fırtınalar gövdeyi yıpratır, Kraken'in dokunaçları daha da çok. Gövde biterse teknen batar ve buraya çekilirsin (%s)." % U.money(Ocean.TOW_FEE),
		13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
