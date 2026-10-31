extends "res://scripts/ui/game_panel.gd"
## Mağara zindanı girişi (1.8): yeni sefer başlat ya da süren bir sefere katıl.

var box: VBoxContainer


func _ready() -> void:
	build("Mağara Zindanı", Vector2(560, 0))
	add_label(body, "Katları temizle, sandıkları aç, merdivenden in. 5. katta Taş Golem, 10. katta Mağara Ejderi seni bekliyor.",
		14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Dungeon.changed.connect(_refresh)
	Combat.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var me: Dictionary = Combat.my
	var w: Dictionary = Combat.WEAPONS.get(str(me.get("cur", "yumruk")), Combat.WEAPONS.yumruk)
	add_label(box, "Silahın: %s   •   Zırh: %s   •   İksir: %d   •   Can: %d" % [w.name, Combat.ARMOR[int(me.get("armor", 0))].name,
		int(me.get("potions", 0)), int(me.get("max", 100))], 15, Color("#fde68a"))
	if str(me.get("cur", "yumruk")) == "yumruk":
		add_label(box, "Yumrukla zor! Yandaki silahçı çadırından kılıç ya da yay al.", 13, Color("#fca5a5"))
	add_button(box, "Yeni sefer başlat", func(): Dungeon.start_run(); close())
	if not Dungeon.lobby.is_empty():
		box.add_child(HSeparator.new())
		add_label(box, "Süren seferler:", 15)
	for r in Dungeon.lobby:
		var row := HBoxContainer.new()
		box.add_child(row)
		add_label(row, "%s ekibi — %d. kat — %d/%d kişi" % [r.leader, int(r.floor), r.members.size(), Dungeon.MAX_MEMBERS], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		var b := add_button(row, "Katıl", func(): Dungeon.join(int(r.slot)); close())
		b.disabled = r.members.size() >= Dungeon.MAX_MEMBERS
	add_label(box, "Saldırı: tıkla / dokun ya da Boşluk  •  İksir: Q (dokunmatikte G)", 12, Color("#94a3b8"))
