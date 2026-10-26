extends "res://scripts/ui/game_panel.gd"
## Paintball gişesi (1.7): takım seç, maçı başlat (eksikleri botlar doldurur).

var box: VBoxContainer


func _ready() -> void:
	build("Paintball Arenası", Vector2(520, 0))
	add_label(body, "İki takım, boya topları! Modlar sırayla: ilk %d vuruş / rakip bayrağı %d kez üssüne getir. Sol tıkla fareye doğru at; vurulan 3 sn oyun dışı. Eksik oyuncuları botlar doldurur." % [Paint.WIN_HITS, Paint.WIN_FLAGS],
		14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	Paint.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var st: Dictionary = Paint.st
	var teams: Dictionary = st.get("teams", {})
	if st.get("phase", "") == "play":
		var sc: Dictionary = st.get("score", {})
		add_label(box, "Maç sürüyor: Kırmızı %d – %d Mavi" % [int(sc.get("kirmizi", 0)), int(sc.get("mavi", 0))], 17, Color("#facc15"))
	else:
		add_label(box, "Sıradaki mod: %s" % ("Vuruş (ilk %d)" % Paint.WIN_HITS if st.get("mode", "hits") == "hits" else "Bayrak kapma (%d)" % Paint.WIN_FLAGS), 16, Color("#facc15"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for t in Paint.TEAMS:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(v)
		add_label(v, "%s Takım" % Paint.TEAM_NAME[t], 18, Paint.TEAM_COLOR[t])
		var names: Array = []
		for who in teams:
			if teams[who] == t:
				names.append(who)
		add_label(v, "\n".join(names) if not names.is_empty() else "(botlar)", 14)
		if st.get("phase", "") != "play" and Paint.my_team() != t:
			add_button(v, "Bu takıma geç", Paint.join.bind(t))
	if st.get("phase", "") != "play":
		if Paint.my_team() != "":
			var b := add_button(box, "MAÇI BAŞLAT", func():
				Paint.start()
				close())
			b.custom_minimum_size = Vector2(0, 44)
			add_button(box, "Takımdan çık", Paint.leave_team)
		else:
			add_label(box, "Başlatmak için önce bir takım seç.", 13, Color("#94a3b8"))
	else:
		add_label(box, "Maç bitince yeni maç başlatılabilir.", 13, Color("#94a3b8"))
	add_label(box, "Kazanan takım %s + 60 XP, kaybeden %s + 30 XP. Vuruşların haftalık Paintball ligine yazılır." % [U.money(250), U.money(80)],
		12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
