extends "res://scripts/ui/game_panel.gd"
## Yeni Mahalle muhtarlığı (2.0): aday ol, oy ver; muhtar kira belirler ve Pazar Günü ilan eder.

var box: VBoxContainer


func _ready() -> void:
	build("Mahalle Muhtarlığı", Vector2(560, 0))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Projects.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var m: Dictionary = Projects.mahalle
	var muhtar := str(m.get("muhtar", ""))
	add_label(box, "Muhtar: %s   •   Tezgâh kirası: %s / gün" % [muhtar if muhtar != "" else "yok", U.money(int(m.get("rent", 400)))], 16, Color("#fde68a"))
	if float(m.get("market_day", 0.0)) > 0.0:
		add_label(box, "PAZAR GÜNÜ! %d dk kaldı — meydana iki kat müşteri geliyor." % int(ceil(float(m.market_day) / 60.0)), 15, Color("#86efac"))
	var phase := str(m.get("phase", ""))
	var left := float(m.get("left", 0.0))
	add_label(box, {"basvuru": "Aday başvurusu", "oylama": "Oylama", "sonuc": "Sonuç açıklandı"}.get(phase, "") + " — %d dk kaldı" % int(left / 60.0), 15)
	var cands: Dictionary = m.get("candidates", {})
	if phase == "basvuru":
		buy_button(box, Projects.M_FEE, Projects.m_apply, Projects.M_LEVEL, "Aday ol").disabled = cands.has(Net.my_name) or Net.my_money() < Projects.M_FEE
	for who in cands:
		var row := HBoxContainer.new()
		box.add_child(row)
		add_label(row, "%s — %d oy" % [who, int(cands[who])] if phase != "basvuru" else str(who), 15).size_flags_horizontal = SIZE_EXPAND_FILL
		if phase == "oylama":
			add_button(row, "Oy ver", Projects.m_vote.bind(who)).disabled = bool(m.get("voted", false))
	if cands.is_empty():
		add_label(box, "Henüz aday yok.", 14, Color("#94a3b8"))
	if muhtar == Net.my_name:
		box.add_child(HSeparator.new())
		add_label(box, "Muhtar yetkileri", 16, Color("#93c5fd"))
		var row2 := HBoxContainer.new()
		box.add_child(row2)
		var rent := add_spin(row2, 300, 600, 50, int(m.get("rent", 400)))
		rent.suffix = "TL"
		add_button(row2, "Kirayı belirle", func(): Projects.m_set_rent(int(rent.value)))
		add_button(box, "Pazar Günü ilan et (10 dk iki kat müşteri)", Projects.m_market_day).disabled = not bool(m.get("can_day", false))
	add_label(box, "Muhtar tezgâh kira gelirinin %10'unu alır. Dönem 2 saat: 40 dk başvuru, 40 dk oylama.", 12, Color("#94a3b8"))
