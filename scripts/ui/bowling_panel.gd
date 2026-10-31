extends "res://scripts/ui/game_panel.gd"
## Bowling salonu (1.8): kanal + skor tablosu. Boşluk/E ya da tıkla: önce nişan, sonra falso.

const B = preload("res://scripts/bowling.gd")

var lane: Lane
var board: Board
var side: VBoxContainer
var phase := "aim"                   # aim | curve | roll
var aim := 0.0
var curve := 0.0
var _t0 := 0.0
var anim := {}                       # {frames, t0, mark, down}


class Lane extends Control:
	var p = null

	func _process(_d: float) -> void:
		queue_redraw()

	## Kanal koordinatı (inç) -> panel pikseli. Lobut alanı büyütülmüş çizilir.
	func to_px(v: Vector2) -> Vector2:
		var x := size.x / 2.0 + v.x * 4.0
		var y := 0.0
		if v.y >= -40.0:
			y = 40.0 + (60.0 - v.y) * 3.0
		else:
			y = 340.0 + (-40.0 - v.y) / 680.0 * (size.y - 360.0)
		return Vector2(x, y)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			p.press()
			accept_event()

	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1c1917"))
		var l := to_px(Vector2(-B.LANE_W / 2.0, 60))
		var r := to_px(Vector2(B.LANE_W / 2.0, -B.LANE_LEN))
		draw_rect(Rect2(l.x - 14, 0, 14, size.y), Color("#3f3f46"))           # oluklar
		draw_rect(Rect2(r.x, 0, 14, size.y), Color("#3f3f46"))
		draw_rect(Rect2(l.x, l.y, r.x - l.x, r.y - l.y), Color("#e8c48a"))
		for k in 12:
			var x := l.x + (r.x - l.x) * (k + 0.5) / 12.0
			draw_line(Vector2(x, l.y), Vector2(x, r.y), Color(0.6, 0.4, 0.2, 0.18), 1)
		draw_rect(Rect2(l.x, 0, r.x - l.x, l.y), Color("#111827"))          # lobut arkası (çukur)
		# yön okları
		for k in 7:
			var ap := to_px(Vector2((k - 3) * 5.0, -B.LANE_LEN * 0.78))
			draw_colored_polygon(PackedVector2Array([ap + Vector2(0, -10), ap + Vector2(-5, 4), ap + Vector2(5, 4)]), Color("#92400e"))
		draw_line(to_px(Vector2(-B.LANE_W / 2.0, -B.LANE_LEN + 4)), to_px(Vector2(B.LANE_W / 2.0, -B.LANE_LEN + 4)), Color("#b91c1c"), 3)
		var pins: Array = []
		var ball := Vector2(p.aim, -B.LANE_LEN + 10)
		if not p.anim.is_empty():
			var fr: Array = p.anim.frames
			var k := clampi(int((Time.get_ticks_msec() / 1000.0 - float(p.anim.t0)) / (B.STEP * B.SAMPLE)), 0, fr.size() - 1)
			ball = Vector2(fr[k][0], fr[k][1])
			pins = fr[k][2]
		else:
			var st: Array = Bowling.game.get("standing", B.all_standing())
			var spots := B.pin_spots()
			for i in 10:
				pins.append([spots[i].x, spots[i].y, st[i], false])
		for pn in pins:
			if not pn[2]:
				continue
			var pp := to_px(Vector2(pn[0], pn[1]))
			if pn[3]:
				draw_set_transform(pp, 0.9, Vector2(1.0, 0.45))
				draw_circle(Vector2.ZERO, 10, Color("#d6d3d1"))
				draw_set_transform(Vector2.ZERO)
			else:
				draw_circle(pp + Vector2(2, 3), 10, Color(0, 0, 0, 0.3))
				draw_circle(pp, 10, Color("#fafafa"))
				draw_arc(pp, 6, 0, TAU, 16, Color("#dc2626"), 2.5)
		if ball.y < 70.0:
			var bp := to_px(ball)
			draw_circle(bp + Vector2(2, 3), 15, Color(0, 0, 0, 0.3))
			draw_circle(bp, 15, Color("#1d4ed8"))
			draw_circle(bp + Vector2(-5, -5), 3, Color("#0f172a"))
			draw_circle(bp + Vector2(3, -6), 3, Color("#0f172a"))
		var f := ThemeDB.fallback_font
		if p.phase == "curve":
			# falso göstergesi: topun kanal boyunca kıvrılacağı yol
			var a := Vector2(p.aim, -B.LANE_LEN)
			var prev := to_px(a)
			for s in 20:
				var t := (s + 1) / 20.0
				var y := lerpf(-B.LANE_LEN, 0.0, t)
				var hook := maxf(0.0, t - 0.6) / 0.4
				var q := to_px(Vector2(p.aim + p.curve * 14.0 * hook * hook, y))
				draw_line(prev, q, Color(0.2, 0.6, 1.0, 0.8), 3)
				prev = q
		if not p.anim.is_empty() and str(p.anim.mark) != "" and Time.get_ticks_msec() / 1000.0 - float(p.anim.t0) > 1.8:
			draw_string(f, Vector2(0, size.y * 0.45), p.anim.mark, HORIZONTAL_ALIGNMENT_CENTER, w, 44, Color("#facc15"))


class Board extends Control:
	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var rolls: Array = Bowling.game.get("rolls", [])
		var marks := marks_of(rolls)
		var scores: Array = Bowling.game.get("scores", [])
		var cw := size.x / 10.0
		for i in 10:
			var r := Rect2(i * cw, 0, cw - 2, size.y)
			var cur := int(Bowling.game.get("frame", -1)) == i and not bool(Bowling.game.get("done", false))
			draw_rect(r, Color("#1e293b") if not cur else Color("#334155"))
			draw_rect(r, Color("#64748b"), false, 1)
			draw_string(f, r.position + Vector2(4, 13), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#94a3b8"))
			var m: Array = marks[i]
			for k in m.size():
				draw_string(f, r.position + Vector2(r.size.x - 15 * (m.size() - k), 15), m[k], HORIZONTAL_ALIGNMENT_CENTER, 14, 14, Color.WHITE)
			if i < scores.size() and int(scores[i]) >= 0:
				draw_string(f, r.position + Vector2(0, r.size.y - 8), str(scores[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color("#fde68a"))

	static func marks_of(rolls: Array) -> Array:
		var out: Array = []
		for k in 10:
			out.append([])
		var i := 0
		for fr in 10:
			if i >= rolls.size():
				break
			if fr < 9:
				var a := int(rolls[i])
				if a == 10:
					out[fr] = ["X"]
					i += 1
					continue
				out[fr] = [_n(a)]
				if i + 1 < rolls.size():
					var b := int(rolls[i + 1])
					out[fr].append("/" if a + b == 10 else _n(b))
				i += 2
			else:
				var t: Array = rolls.slice(i, i + 3)
				for k in t.size():
					var v := int(t[k])
					var mk := _n(v)
					if k == 0 and v == 10:
						mk = "X"
					elif k == 1:
						if int(t[0]) == 10:
							mk = "X" if v == 10 else _n(v)
						elif int(t[0]) + v == 10:
							mk = "/"
					elif k == 2:
						if int(t[0]) == 10 and int(t[1]) != 10:
							mk = "/" if int(t[1]) + v == 10 else _n(v)
						elif v == 10:
							mk = "X"
					out[9].append(mk)
				break
		return out

	static func _n(v: int) -> String:
		return "-" if v == 0 else str(v)


func _ready() -> void:
	build("Bowling Salonu", Vector2(760, 0))
	board = Board.new()
	board.custom_minimum_size = Vector2(720, 52)
	body.add_child(board)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	lane = Lane.new()
	lane.p = self
	lane.custom_minimum_size = Vector2(280, 520)
	lane.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(lane)
	side = VBoxContainer.new()
	side.size_flags_horizontal = SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	Bowling.changed.connect(_refresh)
	Bowling.rolled.connect(_on_rolled)
	_t0 = Time.get_ticks_msec() / 1000.0
	_refresh()


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 - _t0
	if phase == "aim":
		aim = sin(t * 1.7) * 17.0
	elif phase == "curve":
		curve = sin(t * 2.3)
	elif phase == "roll" and not anim.is_empty():
		var dur: float = anim.frames.size() * B.STEP * B.SAMPLE
		if Time.get_ticks_msec() / 1000.0 - float(anim.t0) > maxf(dur, 2.0) + 0.6:
			anim = {}
			phase = "aim"
			_t0 = Time.get_ticks_msec() / 1000.0
			_refresh()
	board.queue_redraw()


func _playing() -> bool:
	return Bowling.game.has("rolls") and not bool(Bowling.game.get("done", false))


func press() -> void:
	if not _playing():
		return
	if phase == "aim":
		phase = "curve"
		_t0 = Time.get_ticks_msec() / 1000.0
	elif phase == "curve":
		phase = "roll"
		Bowling.roll(aim, curve, 0.75)
		Sfx.play("place", -4.0, 0.6)
	_refresh()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_SPACE or Settings.is_key(e, "interact")):
		press()
		get_viewport().set_input_as_handled()


func _on_rolled(d: Dictionary) -> void:
	var res := B.simulate(float(d.x), float(d.c), float(d.p), d.standing, int(d.seed))
	anim = {"frames": res.frames, "t0": Time.get_ticks_msec() / 1000.0, "mark": str(d.mark), "down": int(d.down)}
	Sfx.play("splash_small", -8.0, 0.5)
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(self):
			Sfx.play("success" if str(d.mark) != "" else "place", -4.0))


func _refresh() -> void:
	for c in side.get_children():
		c.queue_free()
	var g: Dictionary = Bowling.game
	if g.has("rolls"):
		add_label(side, "Puan: %d" % int(g.get("score", 0)), 22, Color("#fde68a"))
	if _playing():
		add_label(side, "%d. çerçeve, %d. atış" % [int(g.frame) + 1, int(g.ball) + 1], 16)
		var hint := {"aim": "1) Nişan: top gidip geliyor — Boşluk/E ya da kanala tıkla.",
			"curve": "2) Falso: mavi çizgi topun kıvrılışı — doğru anda bas.", "roll": "Top yolda..."}
		add_label(side, hint[phase], 14, Color("#93c5fd")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		if bool(g.get("done", false)):
			add_label(side, "Oyun bitti! Puanın %d." % int(g.get("score", 0)), 16, Settings.ok_text())
		add_label(side, "Bir oyun 10 çerçeve. Puanının 3 katı TL ödül; 300 = mükemmel oyun!", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buy_button(side, Bowling.GAME_PRICE, func():
			anim = {}
			phase = "aim"
			Bowling.start(), 0, "Yeni oyun")
	add_label(side, "Strike: ilk atışta 10 lobut (sonraki 2 atış eklenir). Spare: iki atışta 10 (sonraki 1 atış eklenir).",
		12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
