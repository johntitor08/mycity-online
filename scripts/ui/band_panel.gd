extends "res://scripts/ui/game_panel.gd"
## Park Sahnesi: çalgı al, şarkı seç ve çal (ritim oyunu: D F J K), sahnedekilere bahşiş ver.

const LANE_COLS := [Color("#f472b6"), Color("#facc15"), Color("#34d399"), Color("#60a5fa")]
const SPEED := 260.0               # px/sn
const HIT_Y := 330.0

var menu: VBoxContainer
var game: VBoxContainer
var lanes: Control
var info: Label
var score_lbl: Label
var inst_opt: OptionButton
var _resolved := {}                # yerel: vurulmuş/kaçmış notalar
var _flash := [0.0, 0.0, 0.0, 0.0]
var _grade := ""
var _grade_t := 0.0
var _score := 0
var _combo := 0


class Lanes extends Control:
	var p
	func _draw() -> void:
		var s: Dictionary = Band.session
		var w := size.x / 4.0
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0f172a"))
		for i in 4:
			var col: Color = LANE_COLS[i]
			draw_rect(Rect2(i * w + 2, 0, w - 4, size.y), Color(col, 0.07 + 0.25 * p._flash[i]))
			draw_rect(Rect2(i * w + 8, HIT_Y - 6, w - 16, 12), Color(col, 0.5 + 0.5 * p._flash[i]), false, 3)
			p.draw_key(self, Vector2(i * w + w / 2.0, size.y - 22), OS.get_keycode_string(Band.LANE_KEYS[i]), col)
		if s.is_empty():
			return
		var st: float = Time.get_ticks_msec() / 1000.0 - float(s.t0)
		if st < 0.0:
			p.draw_center(self, Vector2(size.x / 2.0, 120), str(int(ceil(-st))), 64, Color.WHITE)
		var notes: Array = s.notes
		for i in notes.size():
			if p._resolved.has(i):
				continue
			var y: float = HIT_Y - (float(notes[i][0]) - st) * SPEED
			if y < -30.0 or y > size.y + 20.0:
				continue
			var lane := int(notes[i][1])
			draw_rect(Rect2(lane * w + 10, y - 9, w - 20, 18), LANE_COLS[lane])
			draw_rect(Rect2(lane * w + 10, y - 9, w - 20, 18), Color.BLACK, false, 2)
		if p._grade != "" and Time.get_ticks_msec() / 1000.0 - p._grade_t < 0.6:
			p.draw_center(self, Vector2(size.x / 2.0, HIT_Y_TEXT), p._grade, 30, Color.WHITE)
	const HIT_Y_TEXT := 260.0


func draw_key(c: Control, at: Vector2, t: String, col: Color) -> void:
	c.draw_string(get_theme_default_font(), at + Vector2(-30, 8), t, HORIZONTAL_ALIGNMENT_CENTER, 60, 22, col)


func draw_center(c: Control, at: Vector2, t: String, sz: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), at + Vector2(-150, sz * 0.35), t, HORIZONTAL_ALIGNMENT_CENTER, 300, sz, col)


func _ready() -> void:
	build("Park Sahnesi", Vector2(660, 0))
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	body.add_child(menu)
	game = VBoxContainer.new()
	game.visible = false
	body.add_child(game)
	score_lbl = add_label(game, "", 18, Color("#facc15"))
	lanes = Lanes.new()
	lanes.p = self
	lanes.custom_minimum_size = Vector2(420, 400)
	lanes.size_flags_horizontal = SIZE_SHRINK_CENTER
	game.add_child(lanes)
	info = add_label(body, "", 15)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Band.changed.connect(_refresh)
	Band.song_started.connect(_on_start)
	Band.hit_result.connect(_on_hit)
	Band.song_ended.connect(_on_end)
	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if Band.is_playing():
		return
	for c in menu.get_children():
		c.queue_free()
	inst_opt = null
	add_label(menu, "Sahnede çal: notalar aşağı akar, çizgiye gelince %s tuşlarına bas. Seyirci ve grup (birlikte çalan oyuncular) kazancı artırır." % " ".join(Band.LANE_KEYS.map(func(k): return OS.get_keycode_string(k))), 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(menu)
	add_label(menu, "Çalgılar", 18, Color("#facc15"))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	menu.add_child(r)
	for k in Band.INSTRUMENTS:
		if k in Band.owned:
			add_label(r, "%s ✓" % Band.INSTRUMENTS[k].name, 15, Settings.ok_text())
		else:
			buy_button(r, int(Band.INSTRUMENTS[k].price), Band.buy.bind(k), 0, Band.INSTRUMENTS[k].name)
	if not Band.owned.is_empty():
		var r2 := HBoxContainer.new()
		menu.add_child(r2)
		add_label(r2, "Çalacağın:", 15)
		inst_opt = OptionButton.new()
		for k in Band.owned:
			inst_opt.add_item(Band.INSTRUMENTS[k].name)
		r2.add_child(inst_opt)
		var mus := int(Rpg.sheet.get("skills", {}).get("music", {}).get("level", 1))
		add_label(menu, "Şarkılar (Müzisyenlik seviyen: %d)" % mus, 18, Color("#facc15"))
		for i in Band.SONGS.size():
			var s: Dictionary = Band.SONGS[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			menu.add_child(row)
			var l := add_label(row, "%s  •  %d BPM  •  %d nota" % [s.name, s.bpm, Band.chart(i).size()], 15)
			l.size_flags_horizontal = SIZE_EXPAND_FILL
			var b := add_button(row, "Çal" if mus >= int(s.level) else "Müzisyenlik %d" % int(s.level), _play.bind(i))
			b.disabled = mus < int(s.level)
	var perf := Band.performers_seen()
	if not perf.is_empty():
		add_label(menu, "Sahnede çalanlar", 18, Color("#facc15"))
		for id in perf:
			if id == Net.my_id():
				continue
			var row := HBoxContainer.new()
			menu.add_child(row)
			add_label(row, "%s — %s" % [Net.roster[id].name, Band.INSTRUMENTS.get(str(Net.roster[id].playing), {"name": "?"}).name], 15).size_flags_horizontal = SIZE_EXPAND_FILL
			add_button(row, "Bahşiş ver (%s)" % U.money(Band.TIP), Band.tip.bind(id))


func _play(i: int) -> void:
	if inst_opt == null:
		return
	Band.play(i, str(Band.owned[inst_opt.selected]))


func _on_start(_s: Dictionary) -> void:
	_resolved = {}
	_score = 0
	_combo = 0
	_grade = ""
	menu.visible = false
	game.visible = true
	info.text = "Hazır ol!  (Esc: bırak)"
	info.remove_theme_color_override("font_color")
	_update_score()


func _update_score() -> void:
	var s: Dictionary = Band.session
	score_lbl.text = "%s  •  Puan %d  •  Seri %d" % [Band.SONGS[int(s.song)].name if not s.is_empty() else "", _score, _combo]


func _on_hit(d: Dictionary) -> void:
	_resolved[int(d.i)] = true
	_score = int(d.get("score", _score))
	_combo = int(d.get("combo", 0))
	if d.get("miss", false) or not d.get("ok", false):
		_grade = "Iska"
		_grade_t = Time.get_ticks_msec() / 1000.0
	_update_score()


func _on_end(d: Dictionary) -> void:
	game.visible = false
	menu.visible = true
	info.text = str(d.get("text", ""))
	info.add_theme_color_override("font_color", Settings.ok_text() if d.get("ok", false) else Settings.bad_text())
	if d.get("ok", false):
		Sfx.play("success", -4.0)
	_refresh()


func _lane_pressed(lane: int) -> void:
	var s: Dictionary = Band.session
	if s.is_empty():
		return
	_flash[lane] = 1.0
	var smp := Band.sample_of(str(s.inst), lane)
	Sfx.play(smp[0], -4.0, smp[1])
	var st: float = Time.get_ticks_msec() / 1000.0 - float(s.t0)
	var best := -1
	var best_dt := 99.0
	var any := -1
	var any_dt := 99.0
	for i in s.notes.size():
		if _resolved.has(i):
			continue
		var dt: float = st - float(s.notes[i][0])
		if dt < -0.25:
			break
		if dt > 0.32:
			continue
		if absf(dt) < any_dt:
			any_dt = absf(dt)
			any = i
		if int(s.notes[i][1]) == lane and absf(dt) < best_dt:
			best_dt = absf(dt)
			best = i
	var pick := best if best >= 0 else any
	if pick < 0:
		return
	_resolved[pick] = true
	Band.hit(pick, lane)
	_grade = ("Mükemmel!" if best_dt < 0.08 else "İyi") if best >= 0 else "Yanlış tuş"
	_grade_t = Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	for i in 4:
		_flash[i] = maxf(0.0, _flash[i] - delta * 5.0)
	if game.visible:
		lanes.queue_redraw()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or not Band.is_playing():
		return
	var k: InputEventKey = e
	var lane: int = Band.LANE_KEYS.find(k.physical_keycode)
	if lane < 0:
		lane = [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT].find(k.physical_keycode)
	if lane >= 0:
		_lane_pressed(lane)
		get_viewport().set_input_as_handled()


func close() -> void:
	if Band.is_playing():
		Band.stop()
	super.close()
