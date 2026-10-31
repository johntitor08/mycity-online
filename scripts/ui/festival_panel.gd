extends "res://scripts/ui/game_panel.gd"
## Festival mini oyunları (2.0, yana yaslanmış pencere): mode "dj" (Boşluk vuruşta, E DROP'ta) ya da "dance" (ok tuşları).

const F = preload("res://scripts/festival.gd")

var mode := "dance"
var lanes: Lanes
var info: Label
var _fb := ["", Color.WHITE, 0.0]


class Lanes extends Control:
	var p = null

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.1, 0.85))
		var bp := Festival.beat_pos()
		var hit_y := 60.0
		var px := 140.0                  # bir vuruş = 140 px
		if bp < 0.0:
			draw_string(f, Vector2(0, size.y / 2.0), "Müzik başlamak üzere...", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color.WHITE)
			return
		var t0 := int(Festival.st.get("t0", 0))
		if p.mode == "dj":
			var cx := size.x / 2.0
			draw_line(Vector2(20, hit_y), Vector2(size.x - 20, hit_y), Color(1, 1, 1, 0.6), 3)
			for k in range(int(floor(bp)), int(floor(bp)) + 5):
				var y := hit_y + (k - bp) * px
				if y < hit_y - 30.0:
					continue
				var drop := F.is_drop(k)
				draw_circle(Vector2(cx, y), 26 if drop else 18, Color("#f472b6") if drop else Color("#60a5fa"))
				draw_string(f, Vector2(cx - 60, y + 6), "DROP (E)" if drop else "", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color.WHITE)
			draw_circle(Vector2(cx, hit_y), 30, Color(1, 1, 1, 0.15 + 0.25 * (1.0 - fmod(bp, 1.0))))
		else:
			var lane_w := (size.x - 40) / 4.0
			var names := ["←", "↓", "↑", "→"]
			for i in 4:
				var lx := 20 + i * lane_w + lane_w / 2.0
				draw_rect(Rect2(lx - 26, hit_y - 26, 52, 52), Color(1, 1, 1, 0.15), false, 3)
				draw_string(f, Vector2(lx - 26, hit_y + 8), names[i], HORIZONTAL_ALIGNMENT_CENTER, 52, 22, Color(1, 1, 1, 0.5))
			for k in range(int(floor(bp)), int(floor(bp)) + 5):
				var a := F.step_at(t0, k)
				if a == "":
					continue
				var y := hit_y + (k - bp) * px
				if y < hit_y - 30.0:
					continue
				var i: int = F.ARROWS.find(a)
				var lx := 20 + i * lane_w + lane_w / 2.0
				draw_rect(Rect2(lx - 22, y - 22, 44, 44), Color.from_hsv(i * 0.22, 0.7, 1.0))
				draw_string(f, Vector2(lx - 22, y + 8), names[i], HORIZONTAL_ALIGNMENT_CENTER, 44, 22, Color.WHITE)
		var fb: Array = p._fb
		if Time.get_ticks_msec() / 1000.0 - float(fb[2]) < 0.6:
			draw_string(f, Vector2(0, hit_y + 60), str(fb[0]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, fb[1])


func _ready() -> void:
	build("DJ Kabini" if mode == "dj" else "Dans Pisti", Vector2(380, 0), true)
	info = add_label(body, "", 15, Color("#fde68a"))
	lanes = Lanes.new()
	lanes.p = self
	lanes.custom_minimum_size = Vector2(360, 520)
	body.add_child(lanes)
	add_label(body, "Boşluk: vuruş · E: DROP (8 vuruşta bir)" if mode == "dj" else "Ok tuşları: kutu çizgiye gelince bas · seri yap!", 13, Color("#94a3b8"))
	# dokunmatik / fare için düğmeler
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	if mode == "dj":
		for spec in [["VUR", false], ["DROP", true]]:
			var b := add_button(row, spec[0], func(): _dj(spec[1]))
			b.custom_minimum_size = Vector2(150, 64)
	else:
		for spec in [["←", "left"], ["↓", "down"], ["↑", "up"], ["→", "right"]]:
			var b2 := add_button(row, spec[0], func(): Festival.dance(spec[1]))
			b2.custom_minimum_size = Vector2(80, 64)
			b2.add_theme_font_size_override("font_size", 28)
	Festival.beat_hit.connect(_on_hit)


func _process(_d: float) -> void:
	var st: Dictionary = Festival.st
	if not Festival.active() or (mode == "dj" and str(st.get("dj", "")) != Net.my_name):
		close()
		return
	if mode == "dj":
		info.text = "Coşku %d / 100 · %s · set %d sn" % [int(st.get("hype", 0)), F.TRACKS[int(st.get("track", 0)) % F.TRACKS.size()].name, int(st.get("set_left", 0))]
	else:
		info.text = "Puan %d · Seri %d · coşku %d" % [Festival.my_points, Festival.my_combo, int(st.get("hype", 0))]


func _on_hit(d: Dictionary) -> void:
	if str(d.get("who", "")) != Net.my_name:
		return
	var g := str(d.get("grade", ""))
	_fb = [{"perfect": "MÜKEMMEL!", "good": "İyi", "miss": "Kaçtı", "drop": "DROP!!"}.get(g, g),
		{"perfect": Color("#facc15"), "good": Color("#86efac"), "miss": Color("#f87171"), "drop": Color("#f472b6")}.get(g, Color.WHITE), Time.get_ticks_msec() / 1000.0]


func _dj(drop: bool) -> void:
	Festival.dj_hit(drop)
	Sfx.play("davul_1" if drop else "davul_3", -2.0 if drop else -4.0, 0.7 if drop else 1.0)


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if mode == "dj":
		if e.physical_keycode == KEY_SPACE:
			_dj(false)
			get_viewport().set_input_as_handled()
		elif Settings.is_key(e, "interact"):
			_dj(true)
			get_viewport().set_input_as_handled()
	else:
		var m := {KEY_LEFT: "left", KEY_DOWN: "down", KEY_UP: "up", KEY_RIGHT: "right"}
		if m.has(e.physical_keycode):
			Festival.dance(m[e.physical_keycode])
			get_viewport().set_input_as_handled()
