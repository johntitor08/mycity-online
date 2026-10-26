extends "res://scripts/ui/game_panel.gd"
## Spor salonu: günlük giriş, koşu bandı (A/D sırayla), ağırlık (Boşluk zamanlaması), maraton.

signal marathon_started

var info: Label
var box: VBoxContainer
var game: Control
var status: Label
var _steps: Array = []
var _last_k := -1
var _rep_flash := 0.0


class Meter extends Control:
	func _draw() -> void:
		var c: Dictionary = Gym.current
		draw_rect(Rect2(Vector2.ZERO, size), Color("#111827"))
		if c.is_empty():
			return
		var t: float = Time.get_ticks_msec() / 1000.0 - float(c.t0)
		var font := ThemeDB.fallback_font
		if t < 0.0:
			draw_string(font, Vector2(0, size.y / 2.0 + 16), "Hazır... %d" % int(ceil(-t)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color.WHITE)
			return
		if c.kind == "cardio":
			# tempo göstergesi: son 1 sn'deki adım sayısı
			var p = get_parent().get_parent().get_parent()
			var n := 0
			for s in p._steps:
				if t - float(s) < 1.0:
					n += 1
			var lo: float = Gym.CARDIO_ZONE[0] / 10.0
			var hi: float = Gym.CARDIO_ZONE[1] / 10.0
			draw_rect(Rect2(size.x * lo, 20, size.x * (hi - lo), size.y - 40), Color(0.2, 0.8, 0.3, 0.35))
			var x := size.x * clampf(n / 10.0, 0.0, 1.0)
			draw_rect(Rect2(x - 4, 10, 8, size.y - 20), Color("#facc15"))
			draw_string(font, Vector2(0, size.y - 6), "A / D sırayla bas — tempo: %d adım/sn — kalan %d sn" % [n, int(ceil(Gym.CARDIO_TIME - t))], HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color.WHITE)
		else:
			var pos := Gym.lift_pos(t)
			var zone := Gym.LIFT_ZONE
			draw_rect(Rect2(size.x * (0.5 - zone), 20, size.x * zone * 2.0, size.y - 40), Color(0.2, 0.8, 0.3, 0.35))
			draw_rect(Rect2(size.x * pos - 5, 10, 10, size.y - 20), Color("#e5e7eb"))
			draw_string(font, Vector2(0, size.y - 6), "Çubuk yeşildeyken BOŞLUK — tekrar %d/%d, temiz %d" % [int(c.reps), Gym.LIFT_REPS, int(c.ok)], HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color.WHITE)


func _ready() -> void:
	build("Spor Salonu", Vector2(600, 0))
	info = add_label(body, "", 15, Color("#facc15"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game = Meter.new()
	game.custom_minimum_size = Vector2(560, 120)
	body.add_child(game)
	status = add_label(body, "", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Gym.changed.connect(_refresh)
	Gym.session.connect(func(_c): _refresh())
	Gym.session_ended.connect(func(d): status.text = str(d.text); Sfx.play("success", -4.0); _refresh())
	_refresh()


func _refresh() -> void:
	var f: Dictionary = Gym.fitness
	info.text = "Kondisyon %d/100 (max enerji +%d, yürüyüş hızı +%%%d)   •   Kuvvet %d/100 (kaya kırarken çift darbe %%%d)" % [
		int(f.cardio), mini(20, int(int(f.cardio) / 5.0)), int(float(f.cardio) / 4.0), int(f.strength), int(float(f.strength) / 2.0)]
	for c in box.get_children():
		c.queue_free()
	game.visible = not Gym.current.is_empty()
	if not Gym.current.is_empty():
		return
	if not Gym.has_pass:
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, "Günlük giriş", 16).size_flags_horizontal = SIZE_EXPAND_FILL
		buy_button(r, Gym.PASS_PRICE, Gym.buy_pass)
	else:
		add_label(box, "Bugün kalan antrenman: %d (her biri %d enerji)" % [Gym.sessions_left, Gym.ENERGY], 14, Color("#94a3b8"))
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 8)
		box.add_child(r2)
		add_button(r2, "Koşu bandı (kondisyon)", func(): _steps = []; _last_k = -1; Gym.train("cardio")).disabled = Gym.sessions_left <= 0
		add_button(r2, "Ağırlık (kuvvet)", func(): Gym.train("strength")).disabled = Gym.sessions_left <= 0
	box.add_child(HSeparator.new())
	var b: Dictionary = Gym.best
	add_label(box, "Maraton: salonun önünden başlar, şehirde %d noktadan geçip buraya dönersin (yaya). Rekor: %s" % [
		Map.MARATHON.size() - 1, ("%s — %.1f sn" % [b.n, float(b.t)]) if not b.is_empty() else "yok"], 14, Color("#cbd5e1")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_button(box, "Maratona başla", func(): Gym.start_marathon(); marathon_started.emit()).disabled = not Gym.run.is_empty()


const Map = preload("res://scripts/map.gd")


func _process(delta: float) -> void:
	if game.visible:
		game.queue_redraw()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or Gym.current.is_empty():
		return
	var k: InputEventKey = e
	var c: Dictionary = Gym.current
	var t: float = Time.get_ticks_msec() / 1000.0 - float(c.t0)
	if c.kind == "cardio" and k.physical_keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
		var side := 0 if k.physical_keycode in [KEY_A, KEY_LEFT] else 1
		if side != _last_k and t >= 0.0:
			_last_k = side
			_steps.append(t)
			Gym.step(side)
			Sfx.play("step", -6.0)
		get_viewport().set_input_as_handled()
	elif c.kind == "strength" and k.physical_keycode == KEY_SPACE:
		Gym.lift()
		Sfx.play("place", -4.0, 0.8)
		get_viewport().set_input_as_handled()
