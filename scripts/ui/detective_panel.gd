extends "res://scripts/ui/game_panel.gd"
## Dedektif Ferhat'ın dosyası: vaka al, ipuçları ve ifadeler, haritada işaretle, suçluyu seç.

signal nav_requested(pos: Vector2)

var box: VBoxContainer


func _ready() -> void:
	build("Dedektif Bürosu — Ferhat", Vector2(680, 0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	Detective.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var solved: Array = Detective.state.get("solved", [])
	add_label(box, "Çözülen vakalar: %d / %d" % [solved.size(), Detective.CASES.size()], 15, Color("#94a3b8"))
	var cs := Detective.active_case()
	if cs.is_empty():
		if solved.size() >= Detective.CASES.size():
			add_label(box, "\"Bütün dosyalar kapandı, Baş Dedektif! Şehir sana emanet.\"", 17, Color("#facc15"))
			return
		var nxt: Dictionary = Detective.CASES[solved.size()]
		add_label(box, "Yeni vaka: %s" % nxt.name, 20, Color("#facc15"))
		add_label(box, nxt.brief, 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_label(box, "Ödül: %s" % U.money(int(nxt.reward)), 15, Settings.ok_text())
		add_button(box, "Vakayı al", Detective.take_case).custom_minimum_size = Vector2(0, 40)
		return
	add_label(box, "Vaka: %s" % cs.name, 20, Color("#facc15"))
	add_label(box, cs.brief, 14, Color("#cbd5e1")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_label(box, "İpuçları", 17, Color("#facc15"))
	for cl in cs.clues:
		var r := HBoxContainer.new()
		box.add_child(r)
		if Detective.has_clue(cl.id):
			add_label(r, "✓ " + cl.text, 14, Settings.ok_text()).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			r.get_child(0).size_flags_horizontal = SIZE_EXPAND_FILL
		else:
			add_label(r, "? Bulunmadı — %s" % Phone.where(cl.pos), 14, Color("#94a3b8")).size_flags_horizontal = SIZE_EXPAND_FILL
			add_button(r, "Haritada göster", func(): nav_requested.emit(cl.pos))
	add_label(box, "Şüpheliler", 17, Color("#facc15"))
	var says: Dictionary = Detective.state.get("says", {})
	var ready_all: bool = Detective.state.get("clues", []).size() >= cs.clues.size() and Detective.state.get("talked", []).size() >= cs.suspects.size()
	var wait := float(Detective.state.get("wrong_left", 0.0))
	for s in cs.suspects:
		var card := VBoxContainer.new()
		box.add_child(card)
		var r := HBoxContainer.new()
		card.add_child(r)
		add_label(r, s.name + ("" if says.has(s.id) else "  (sorgulanmadı — %s)" % Phone.where(s.pos)), 16).size_flags_horizontal = SIZE_EXPAND_FILL
		if not says.has(s.id):
			add_button(r, "Haritada göster", func(): nav_requested.emit(s.pos))
		else:
			var b := add_button(r, "SUÇLA", Detective.accuse.bind(s.id))
			b.disabled = not ready_all or wait > 0.0
			b.modulate = Color("#fca5a5")
			var l := add_label(card, "  \"%s\"" % says[s.id], 13, Color("#cbd5e1"))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not ready_all:
		add_label(box, "Suçlamak için bütün ipuçlarını topla ve herkesi sorgula (yanlarına gidip E).", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif wait > 0.0:
		add_label(box, "Yanlış suçlama sonrası bekleme: %d sn" % int(wait), 13, Settings.bad_text())
