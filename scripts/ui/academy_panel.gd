extends "res://scripts/ui/game_panel.gd"
## Aşçılık Akademisi (2.0): dönem sıralaması ve yarışmaya katılım.

const KitchenPanel = preload("res://scripts/ui/kitchen_panel.gd")

var box: VBoxContainer


func _ready() -> void:
	build("Aşçılık Akademisi", Vector2(560, 0))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Chef.changed.connect(_refresh)
	Chef.refresh_board()
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var b: Dictionary = Chef.board
	var left := float(b.get("period_left", 0.0))
	add_label(box, "Bu dönem %d dk sonra bitiyor. Ödüller: %s / %s / %s" % [int(left / 60.0), U.money(Chef.CONTEST_PRIZES[0]), U.money(Chef.CONTEST_PRIZES[1]), U.money(Chef.CONTEST_PRIZES[2])], 15, Color("#fde68a"))
	add_label(box, "3 zor yemeği zamanında ve kusursuz hazırla, evde pişirdiğin bir imza yemeğini jüriye sun. 3 jüri teknik, lezzet ve sunuma puan verir (en çok 30).",
		13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := add_button(box, "Yarışmaya katıl", func():
		var p := KitchenPanel.new()
		p.mode = "contest"
		switch_to(p))
	btn.disabled = bool(b.get("entered", false))
	if btn.disabled:
		btn.text = "Bu dönem yarıştın"
	add_label(box, "Bu dönemin sıralaması", 16, Color("#93c5fd"))
	var sc: Array = b.get("scores", [])
	if sc.is_empty():
		add_label(box, "Henüz kimse yarışmadı.", 14, Color("#94a3b8"))
	for i in sc.size():
		add_label(box, "%d. %s — %.1f" % [i + 1, sc[i][0], float(sc[i][1])], 15, Color("#86efac") if sc[i][0] == Net.my_name else Color.WHITE)
	var last: Array = b.get("last", [])
	if not last.is_empty():
		add_label(box, "Geçen dönemin ilk üçü: " + ", ".join(PackedStringArray(last.map(func(x): return "%s (%.1f)" % [x[0], float(x[1])]))), 13, Color("#fde68a"))
