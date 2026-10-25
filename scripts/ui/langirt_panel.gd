extends "res://scripts/ui/game_panel.gd"
## Langırt masası: otur (ya da bota karşı oyna), W/S veya fareyle çubuklarını oynat.

var table: Control
var info: Label
var _send := 0.0
var _rod_y := 110.0


class Table extends Control:
	func _draw() -> void:
		var k: float = size.x / Langirt.W
		draw_rect(Rect2(Vector2.ZERO, size), Color("#15803d"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#78350f"), false, 8)
		draw_line(Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y), Color(1, 1, 1, 0.5), 2)
		draw_arc(size / 2, 34 * k, 0, TAU, 32, Color(1, 1, 1, 0.5), 2)
		for side in 2:
			var gx := 0.0 if side == 0 else size.x - 8
			draw_rect(Rect2(gx, (Langirt.H / 2 - Langirt.GOAL_HALF) * k, 8, Langirt.GOAL_HALF * 2 * k), Color("#e5e7eb"))
		var st: Dictionary = Langirt.state
		var rods: Array = st.get("r", [Langirt.H / 2, Langirt.H / 2])
		for side in 2:
			var col := Color("#ef4444") if side == 0 else Color("#3b82f6")
			for r in Langirt.RODS:
				var x: float = (float(r[0]) if side == 0 else Langirt.W - float(r[0])) * k
				draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#cbd5e1"), 3)
			for m in Langirt.man_positions(side, float(rods[side])):
				draw_circle(m * k, Langirt.MAN_R * k, col)
				draw_circle(m * k + Vector2(0, -3), Langirt.MAN_R * k * 0.5, Color("#fde68a"))
		var b: Vector2 = st.get("b", Vector2(Langirt.W / 2, Langirt.H / 2))
		draw_circle(b * k + Vector2(2, 3), Langirt.BALL_R * k, Color(0, 0, 0, 0.3))
		draw_circle(b * k, Langirt.BALL_R * k, Color.WHITE)


func _ready() -> void:
	build("Langırt", Vector2(640, 0), true)
	info = add_label(body, "", 20, Color("#fde68a"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table = Table.new()
	table.custom_minimum_size = Vector2(600, 330)
	table.mouse_filter = MOUSE_FILTER_PASS
	body.add_child(table)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	add_button(row, "Kırmızı (sol) otur", func(): Langirt.sit(0))
	add_button(row, "Mavi (sağ) otur", func(): Langirt.sit(1))
	add_button(row, "Bota karşı oyna", func(): Langirt.sit(0, true))
	add_button(row, "Kalk", Langirt.leave)
	add_label(body, "W/S ya da fareyle çubuklarını yukarı-aşağı oynat. Kaleci ve 3 forvet birlikte hareket eder. 5 gole ulaşan kazanır.", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Langirt.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var st := Langirt.state
	var n: Array = st.get("n", ["", ""])
	var s: Array = st.get("s", [0, 0])
	var a := str(n[0]) if str(n[0]) != "" else "(boş)"
	var b := str(n[1]) if str(n[1]) != "" else "(boş)"
	var extra := ""
	match str(st.get("st", "")):
		"wait":
			extra = "  —  rakip bekleniyor"
		"serve":
			extra = "  —  hazır ol!"
		"over":
			extra = "  —  %s KAZANDI!" % (a if int(st.get("w", 0)) == 0 else b)
	info.text = "%s  %d : %d  %s%s" % [a, int(s[0]), int(s[1]), b, extra]
	table.queue_redraw()


func _process(delta: float) -> void:
	if Langirt.my_seat() < 0:
		return
	var speed := 260.0 * delta
	if Settings.held("up"):
		_rod_y -= speed
	elif Settings.held("down"):
		_rod_y += speed
	else:
		var m := table.get_local_mouse_position()
		if Rect2(Vector2.ZERO, table.size).has_point(m):
			_rod_y = m.y / (table.size.x / Langirt.W)
	_rod_y = clampf(_rod_y, Langirt.ROD_RANGE.x, Langirt.ROD_RANGE.y)
	_send += delta
	if _send >= 0.05:
		_send = 0.0
		Langirt.move_rod(_rod_y)


func close() -> void:
	if Langirt.my_seat() >= 0:
		Langirt.leave()
	super.close()
