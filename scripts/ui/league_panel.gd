extends "res://scripts/ui/game_panel.gd"
## Lig: haftalık sezon sıralamaları, sezon sonu ödülleri, Şampiyonlar Duvarı ve rozetlerim.

var cat := "wealth"
var head: Label
var board: VBoxContainer
var _tick := 0.0


func _ready() -> void:
	build("Lig ve Sezonlar", Vector2(760, 560))
	head = add_label(body, "", 16, Color("#fde68a"))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for c in League.CATS:
		add_button(tabs, League.CATS[c][0], _show.bind(c)).custom_minimum_size = Vector2(110, 34)
	add_button(tabs, "Şampiyonlar Duvarı", _show.bind("wall")).custom_minimum_size = Vector2(170, 34)
	body.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 410)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	board = VBoxContainer.new()
	board.size_flags_horizontal = SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 4)
	sc.add_child(board)
	League.changed.connect(_refresh)
	League.refresh()
	_refresh()


func _show(c: String) -> void:
	cat = c
	_refresh()


func _fmt(c: String, v: float) -> String:
	match c:
		"race", "ski":
			return "%.2f sn" % v
		"wealth", "fish":
			return U.money(int(v))
	return "%d %s" % [int(v), League.CATS[c][1]]


func _refresh() -> void:
	var v := League.view
	var left := League.time_left()
	head.text = "Sezon %s — bitmesine %d gün %d saat  •  Her kategoride ilk üçe %s / %s / %s ve kalıcı rozet" % [
		v.get("season", "?"), int(left / 86400.0), int(fmod(left, 86400.0) / 3600.0),
		U.money(League.PRIZES[0]), U.money(League.PRIZES[1]), U.money(League.PRIZES[2])]
	for ch in board.get_children():
		ch.queue_free()
	if cat == "wall":
		var badges: Array = v.get("badges", [])
		add_label(board, "Rozetlerim: %s" % (", ".join(badges) if not badges.is_empty() else "henüz yok"), 15, Color("#fcd34d")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var hist: Array = v.get("history", [])
		if hist.is_empty():
			add_label(board, "Henüz biten sezon yok. İlk şampiyon sen ol!", 15, Color("#7c859e"))
		for h in hist:
			add_label(board, "Sezon %s" % h.season, 17, Color("#facc15"))
			for c in League.CATS:
				var top: Array = h.winners.get(c, [])
				var names: Array = []
				for k in top.size():
					names.append("%d. %s (%s)" % [k + 1, top[k][0], _fmt(c, float(top[k][1]))])
				add_label(board, "   %s: %s" % [League.CATS[c][0], "  ".join(names) if not names.is_empty() else "—"], 14)
		return
	var list: Array = v.get("boards", {}).get(cat, [])
	add_label(board, {"wealth": "Cebindeki para + banka hesabı", "fish": "Bu sezon tutulan balıkların toplam değeri", "race": "Bu sezonun en iyi pist turu",
		"goals": "Bu sezon plaj sahasında atılan goller", "xp": "Bu sezon kazanılan tecrübe puanı",
		"ski": "Bu sezonun en hızlı kayak inişi (dağ, kaçan kapı +3 sn)"}[cat], 13, Color("#94a3b8"))
	if list.is_empty():
		add_label(board, "Bu sezon henüz kimse puan almadı.", 15, Color("#7c859e"))
	for i in list.size():
		var mine: bool = list[i][0] == Net.my_name
		var col := Color("#facc15") if i == 0 else (Settings.ok_text() if mine else Color.WHITE)
		add_label(board, "%d.  %s   —   %s" % [i + 1, list[i][0], _fmt(cat, float(list[i][1]))], 17 if i < 3 else 15, col)


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 10.0:
		_tick = 0.0
		League.refresh()
