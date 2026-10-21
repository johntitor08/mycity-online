extends "res://scripts/ui/game_panel.gd"
## Galeri: bisiklet, tekne ve araba satın al.

var list: VBoxContainer


func _ready() -> void:
	build("Galeri — Araçlar", Vector2(680, 0))
	add_label(body, "Aldığın araca F tuşuyla binip inersin. Bisiklet ve araba karada, tekne sadece denizde kullanılır.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	Garage.owned_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var lvl := int(Rpg.sheet.get("level", 1))
	for k in Garage.VEHICLES:
		var v: Dictionary = Garage.VEHICLES[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(info)
		add_label(info, "%s  —  %s" % [v.name, U.money(int(v.price))], 19, Color("#facc15"))
		add_label(info, "%s  •  Seviye %d gerekli" % [v.desc, v.level], 14,
			Color("#94a3b8") if lvl >= int(v.level) else Color("#fca5a5"))
		if Garage.owned.has(k):
			add_label(row, "Sende ✓", 17, Color("#86efac"))
		else:
			buy_button(row, int(v.price), Garage.buy.bind(k), int(v.level))
