extends "res://scripts/ui/game_panel.gd"
## Dağ Evi: kazma ve kayak takımı, sıcak yiyecekler, maden alımı, pist rekoru.

var box: VBoxContainer


func _ready() -> void:
	build("Dağ Evi", Vector2(640, 0))
	add_label(body, "Kazmayla maden ocağındaki kayaları kır (E basılı tut). Telesiyejle zirveye çıkıp kayak pistinden in: 12 kapıdan geç, kaçan kapı +3 sn.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	Mountain.changed.connect(_refresh)
	Farm.crops_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _row(text: String, sub: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	box.add_child(r)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	r.add_child(v)
	add_label(v, text, 17)
	if sub != "":
		add_label(v, sub, 13, Color("#94a3b8"))
	return r


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	add_label(box, "Ekipman", 18, Color("#facc15"))
	var r := _row("Kazma", "Kaya kırmak için gerekli. Madencilik seviyesi değerli maden şansını artırır.")
	if Mountain.has_pickaxe:
		add_label(r, "Sende ✓", 15, Settings.ok_text())
	else:
		buy_button(r, Mountain.PICKAXE_PRICE, Mountain.buy.bind("pickaxe"))
	r = _row("Kayak Takımı", "Kendi kayağın olursa telesiyejde kira (%s) ödemezsin." % U.money(Mountain.SKI_RENT))
	if Mountain.has_skis:
		add_label(r, "Sende ✓", 15, Settings.ok_text())
	else:
		buy_button(r, Mountain.SKIS_PRICE, Mountain.buy.bind("skis"))
	add_label(box, "Sıcak bir şeyler", 18, Color("#facc15"))
	for k in Mountain.LODGE_FOODS:
		var f: Dictionary = Mountain.LODGE_FOODS[k]
		r = _row(f.name, "+%d enerji (çantaya girer)" % int(f.energy))
		buy_button(r, int(f.price), Mountain.buy.bind(k))
	add_label(box, "Maden alımı", 18, Color("#facc15"))
	var ores := 0
	var ore_val := 0
	var fos := 0
	var fos_val := 0
	var names: Array = []
	for k in Farm.my_crops:
		if not Mountain.ORES.has(k):
			continue
		var n := int(Farm.my_crops[k])
		names.append("%d %s" % [n, Mountain.ORES[k].name])
		if Mountain.is_fossil(k):
			fos += n
			fos_val += n * int(Mountain.ORES[k].price)
		else:
			ores += n
			ore_val += n * int(Mountain.ORES[k].price)
	add_label(box, "Ambarında: %s" % (", ".join(names) if not names.is_empty() else "maden yok"), 14, Color("#cbd5e1")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	box.add_child(r2)
	add_button(r2, "Madenleri sat (%d parça, ~%s)" % [ores, U.money(ore_val)], Mountain.sell_all.bind(false)).disabled = ores == 0
	add_button(r2, "Fosiller dahil hepsini sat (~%s)" % U.money(ore_val + fos_val), Mountain.sell_all.bind(true)).disabled = ores + fos == 0
	if fos > 0:
		add_label(box, "İpucu: fosilleri satmak yerine Müze'ye bağışlayabilirsin (Sanayi bölgesi).", 13, Color("#7dd3fc"))
	var b: Dictionary = Mountain.best
	add_label(box, "Pist rekoru: %s" % ("%s — %.2f sn" % [b.n, float(b.t)] if not b.is_empty() else "henüz yok, ilk sen ol!"), 15, Color("#fde68a"))
