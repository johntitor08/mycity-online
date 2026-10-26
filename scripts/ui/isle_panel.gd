extends "res://scripts/ui/game_panel.gd"
## Özel ada (1.7): satın al, yapı kur, aç/kapat, sat.

const OM = preload("res://scripts/ocean_map.gd")

var island := 0
var box: VBoxContainer


func _ready() -> void:
	var isl: Dictionary = OM.islands()[island]
	build(str(isl.name), Vector2(560, 0))
	add_label(body, "%s adası  •  %s" % [OM.TYPES[isl.type].name, "★".repeat(int(isl.tier))], 14, Color("#94a3b8"))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Isles.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var isl: Dictionary = OM.islands()[island]
	var own: Dictionary = Isles.view.get(str(island), {})
	if own.is_empty():
		add_label(box, "Bu ada satılık! Senin olursa ev, bahçe, havuz, fener ve büyük iskele kurabilirsin. Kendi adanın sandığı 10 dakikada bir dolar; adayı kapatırsan başkası açamaz.",
			14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if Isles.my_island() >= 0:
			add_label(box, "Zaten bir adan var (%s). Önce onu satmalısın." % OM.islands()[Isles.my_island()].name, 14, Settings.bad_text())
		else:
			buy_button(box, Isles.price_of(isl), Isles.buy.bind(island), 0, "Adayı satın al").custom_minimum_size = Vector2(0, 42)
		return
	if str(own.owner) != Net.my_name:
		add_label(box, "Bu ada %s'in. %s" % [own.owner, "Herkese açık: sandığını sen de açabilirsin." if own.get("open", true) else "Özel ada: sandığı sadece sahibi açar."], 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	add_label(box, "Senin adan! Yapılar:", 16, Color("#facc15"))
	var b: Dictionary = own.get("b", {})
	for k in Isles.BUILD:
		var d: Dictionary = Isles.BUILD[k]
		var lvl := int(b.get(k, 0))
		var r := HBoxContainer.new()
		box.add_child(r)
		var cur := "yok" if lvl == 0 else str(d.levels[lvl - 1])
		var l := add_label(r, "%s: %s  —  %s" % [d.name, cur, d.desc], 14)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(320, 0)
		if lvl >= d.price.size():
			add_label(r, "✓", 16, Settings.ok_text())
		else:
			var bt := buy_button(r, int(d.price[lvl]), Isles.build.bind(island, k), 0, str(d.levels[lvl]))
			if k != "ev" and int(b.get("ev", 0)) < 1:
				bt.disabled = true
				bt.tooltip_text = "Önce ev kur."
	box.add_child(HSeparator.new())
	var open: bool = own.get("open", true)
	add_button(box, "Adayı özel yap (sandık sadece sana)" if open else "Adayı herkese aç", Isles.set_open.bind(island, not open))
	var sb := add_button(box, "Adayı sat (harcadığının %%%d'ı geri gelir)" % int(Isles.SELL_BACK * 100), func():
		Isles.sell(island)
		close())
	sb.modulate = Color(1, 0.75, 0.75)
