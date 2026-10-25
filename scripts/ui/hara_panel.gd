extends "res://scripts/ui/game_panel.gd"
## Hara: at al, besle, antrenman yaptır, binilecek atı seç.

var box: VBoxContainer


func _ready() -> void:
	build("Hara — At Çiftliği", Vector2(660, 0))
	add_label(body, "At al (en fazla %d), tok tut (yem %s ya da 2 mısır, 2 saat), antrenmanla hız ve dayanıklılığını artır. %s ile atına bin; hipodromda yarış!" % [
		Horses.MAX_HORSES, U.money(Horses.FEED_PRICE), Settings.key_name("horse")], 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	Horses.changed.connect(_refresh)
	Farm.crops_changed.connect(_refresh)
	_refresh()


func _bar(parent: Node, label: String, v: int, col: Color) -> void:
	var r := HBoxContainer.new()
	parent.add_child(r)
	add_label(r, label, 14).custom_minimum_size = Vector2(110, 0)
	var pb := ProgressBar.new()
	pb.max_value = Horses.STAT_MAX
	pb.value = v
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(220, 14)
	pb.modulate = col
	r.add_child(pb)
	add_label(r, " %d" % v, 14)


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var now := Time.get_unix_time_from_system()
	for i in Horses.my_horses.size():
		var h: Dictionary = Horses.my_horses[i]
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#262b3b") if i != Horses.active_idx else Color("#1f3b2d")
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", sb)
		box.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var fed := float(h.get("fed", 0.0)) - now
		add_label(v, "%s  •  %s at  •  %d galibiyet%s" % [h.n, Horses.COLOR_NAMES[int(h.c)], int(h.get("wins", 0)), "  •  BİNİLEN" if i == Horses.active_idx else ""], 17, Color("#facc15"))
		_bar(v, "Hız", int(h.spd), Color("#60a5fa"))
		_bar(v, "Dayanıklılık", int(h.sta), Color("#34d399"))
		add_label(v, ("Tok (%d dk)" % int(fed / 60.0)) if fed > 0 else "AÇ — binilmez, antrenman yapılmaz", 14, Settings.ok_text() if fed > 0 else Settings.bad_text())
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		v.add_child(r)
		add_button(r, "Yemle besle (%s)" % U.money(Horses.FEED_PRICE), Horses.feed.bind(i, false))
		add_button(r, "Mısırla besle (2)", Horses.feed.bind(i, true)).disabled = int(Farm.my_crops.get("misir", 0)) < 2
		var cd := Horses.TRAIN_COOLDOWN - (now - float(h.get("tr", 0.0)))
		var t1 := add_button(r, "Hız antrenmanı", Horses.train.bind(i, "spd"))
		var t2 := add_button(r, "Dayanıklılık antr.", Horses.train.bind(i, "sta"))
		for b in [t1, t2]:
			b.disabled = cd > 0 or fed <= 0
			if cd > 0:
				b.tooltip_text = "%d dk sonra" % int(ceil(cd / 60.0))
		if i != Horses.active_idx:
			add_button(r, "Bu ata bin", Horses.set_active.bind(i))
	if Horses.my_horses.size() < Horses.MAX_HORSES:
		var r2 := HBoxContainer.new()
		box.add_child(r2)
		add_label(r2, "Yeni at (rastgele renk ve özellik)", 16).size_flags_horizontal = SIZE_EXPAND_FILL
		buy_button(r2, Horses.PRICE, Horses.buy, Horses.LEVEL)
