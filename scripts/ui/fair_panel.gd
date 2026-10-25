extends "res://scripts/ui/game_panel.gd"
## Lunapark gişesi ve ödül standı: jeton al, biletleri ödüllere çevir.

var box: VBoxContainer


func _ready() -> void:
	build("Lunapark — Gişe ve Ödül Standı", Vector2(560, 0))
	add_label(body, "Dönme dolap, çarpışan arabalar ve atış poligonu %d'şer jeton. Oyunlardan bilet kazan, burada ödüle çevir." % Fair.RIDE_COST, 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	Fair.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	add_label(box, "Jetonun: %d   •   Biletin: %d" % [Fair.jeton, Fair.bilet], 20, Color("#facc15"))
	var r := HBoxContainer.new()
	box.add_child(r)
	add_label(r, "%d jeton" % Fair.JETON_PACK[0], 16).size_flags_horizontal = SIZE_EXPAND_FILL
	buy_button(r, int(Fair.JETON_PACK[1]), Fair.buy_jeton)
	box.add_child(HSeparator.new())
	add_label(box, "Ödüller", 18, Color("#facc15"))
	for k in Fair.PRIZES:
		var p: Array = Fair.PRIZES[k]
		var row := HBoxContainer.new()
		box.add_child(row)
		add_label(row, "%s%s" % [p[0], "  (eve konur)" if p[2] == "furniture" else "  (+%d enerji)" % int(Fair.FAIR_FOODS.get(k, {"energy": 0}).energy)], 15).size_flags_horizontal = SIZE_EXPAND_FILL
		var b := add_button(row, "%d bilet" % int(p[1]), Fair.prize.bind(k))
		b.disabled = Fair.bilet < int(p[1])
