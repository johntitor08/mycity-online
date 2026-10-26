extends "res://scripts/ui/game_panel.gd"
## Tren gişesi (1.7): hedef istasyon seç; tren perondayken bin.

const Map = preload("res://scripts/map.gd")

var here := "sehir"
var box: VBoxContainer
var info: Label
var _acc := 0.0


func _ready() -> void:
	build("%s — Bilet Gişesi" % Map.RAIL[here].name, Vector2(480, 0))
	add_label(body, "Tren her 80 saniyede bir perona girer ve 20 saniye bekler. Bilet %s." % U.money(Rail.PRICE), 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info = add_label(body, "", 18, Color("#facc15"))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	for k in Map.RAIL:
		if k == here:
			continue
		var b := add_button(box, "→ %s" % Map.RAIL[k].name, func():
			Rail.board(k)
			close())
		b.custom_minimum_size = Vector2(0, 40)
		b.set_meta("dest", k)
	_refresh()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.25:
		_acc = 0.0
		_refresh()


func _refresh() -> void:
	var ts := Map.train_state(Land.server_now())
	if ts.stopped:
		info.text = "Tren peronda! Kalkışa %d sn." % int(ceil(float(ts.left)))
	else:
		info.text = "Tren %d sn sonra perona girecek." % int(ceil(float(ts.get("next", 0.0))))
	for b in box.get_children():
		(b as Button).disabled = not ts.stopped or Net.my_money() < Rail.PRICE
