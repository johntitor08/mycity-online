extends "res://scripts/ui/game_panel.gd"
## Belediye proje panosu (2.0): oylama, bağış, yapılan projeler; başkan proje önerir.

var box: VBoxContainer


func _ready() -> void:
	build("Belediye Projeleri", Vector2(640, 0))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Projects.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var st: Dictionary = Projects.state
	var mayor := str(st.get("mayor", ""))
	add_label(box, "Başkan: %s   •   Belediye kasası: %s" % [mayor if mayor != "" else "yok (Muhtar Rıza vekil)", U.money(int(st.get("treasury", 0)))], 15, Color("#fde68a"))
	var cur: Dictionary = st.get("cur", {})
	if not cur.is_empty():
		var k := str(cur.k)
		var pinfo: Dictionary = Projects.PROJECTS[k]
		box.add_child(HSeparator.new())
		add_label(box, "%s — %s" % [pinfo.name, pinfo.desc], 17, Color("#86efac")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		match str(cur.phase):
			"oylama":
				add_label(box, "Oylama: %d evet, %d hayır — %d dk %d sn kaldı (öneren %s)" % [int(cur.yes), int(cur.no), int(float(cur.left)) / 60, int(float(cur.left)) % 60, cur.get("by", "")], 15)
				var row := HBoxContainer.new()
				box.add_child(row)
				var voted := bool(st.get("voted", false))
				add_button(row, "Evet", Projects.vote.bind(true)).disabled = voted
				add_button(row, "Hayır", Projects.vote.bind(false)).disabled = voted
				if voted:
					add_label(row, "Oyunu kullandın ✓", 14, Settings.ok_text())
			"butce":
				var cost := int(pinfo.cost)
				add_label(box, "Bütçe: %s / %s toplandı" % [U.money(int(cur.funds)), U.money(cost)], 15)
				var bar := ProgressBar.new()
				bar.max_value = cost
				bar.value = int(cur.funds)
				bar.custom_minimum_size = Vector2(0, 18)
				box.add_child(bar)
				var row2 := HBoxContainer.new()
				box.add_child(row2)
				for amt in [500, 2000, 5000]:
					add_button(row2, "%s bağışla" % U.money(amt), Projects.donate.bind(amt)).disabled = Net.my_money() < amt
				var donors: Dictionary = cur.get("donors", {})
				if not donors.is_empty():
					var list: Array = donors.keys()
					list.sort_custom(func(a, b): return int(donors[a]) > int(donors[b]))
					add_label(box, "Destekçiler: " + ", ".join(PackedStringArray(list.slice(0, 5).map(func(n): return "%s (%s)" % [n, U.money(int(donors[n]))]))), 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			"insaat":
				add_label(box, "İnşaat sürüyor: %d dk %d sn" % [int(float(cur.left)) / 60, int(float(cur.left)) % 60], 15, Color("#fde68a"))
	box.add_child(HSeparator.new())
	add_label(box, "Projeler", 16, Color("#93c5fd"))
	var done: Dictionary = st.get("done", {})
	for k in Projects.PROJECTS:
		var pi: Dictionary = Projects.PROJECTS[k]
		var row := HBoxContainer.new()
		box.add_child(row)
		var txt := "%s — %s (%s)" % [pi.name, pi.desc, U.money(int(pi.cost))]
		var col := Color.WHITE
		if done.has(k):
			txt = "✓ %s — yapıldı%s" % [pi.name, (" (en büyük destekçi: %s)" % done[k].by) if str(done[k].get("by", "")) != "" else ""]
			col = Settings.ok_text()
		var l := add_label(row, txt, 14, col)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not done.has(k) and mayor == Net.my_name and cur.is_empty():
			add_button(row, "Oylamaya sun", Projects.propose.bind(k))
	add_label(box, "Başkan projeyi oylamaya sunar; kabul edilirse belediye kasası bütçenin yarısına kadar öder, gerisi bağışla toplanır.", 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
