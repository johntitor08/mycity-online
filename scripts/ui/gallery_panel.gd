extends "res://scripts/ui/game_panel.gd"
## Atış poligonu: ördekler üç sırada akar; tıkla ve vur. Hızlı sıra daha çok puan, altın ördek 5 puan.

var stage: Control
var info: Label
var start_btn: Button
var _shot := {}                    # vurulan hedefler (yerel)
var _pops: Array = []              # [konum, zaman]


class ShootRange extends Control:
	var p
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1e3a8a"))
		for i in 3:
			var y := 50.0 + i * 70.0
			draw_rect(Rect2(0, y + 18, size.x, 10), Color("#92400e"))
			draw_rect(Rect2(0, y + 26, size.x, 4), Color("#78350f"))
		draw_rect(Rect2(0, 0, size.x, 26), Color("#dc2626"))
		for k in int(size.x / 30.0):
			draw_rect(Rect2(k * 30, 0, 15, 26), Color.WHITE)
		var g: Dictionary = Fair.gallery
		if g.is_empty():
			return
		var now := Time.get_ticks_msec() / 1000.0
		var t: float = now - float(g.t0)
		for tg in g.targets:
			if p._shot.has(int(tg.id)):
				continue
			var pos = p.target_pos(tg, t)
			if pos == null:
				continue
			var col := Color("#facc15") if tg.get("gold", false) else Color("#f8fafc")
			draw_circle(pos, 16, col)
			draw_circle(pos + Vector2(12 * int(tg.dir), -12), 9, col)
			draw_colored_polygon(PackedVector2Array([pos + Vector2(20 * int(tg.dir), -14), pos + Vector2(28 * int(tg.dir), -11), pos + Vector2(20 * int(tg.dir), -8)]), Color("#f97316"))
			draw_circle(pos + Vector2(14 * int(tg.dir), -14), 2, Color.BLACK)
			draw_rect(Rect2(pos.x - 3, pos.y + 14, 6, 14), Color("#78350f"))
		for pp in p._pops:
			var k := now - float(pp[1])
			if k < 0.4:
				draw_arc(pp[0], 10.0 + k * 60.0, 0, TAU, 20, Color(1, 1, 0.5, 1.0 - k * 2.5), 3.0)
		var m := get_local_mouse_position()
		draw_arc(m, 14, 0, TAU, 24, Color("#ef4444"), 2.0)
		draw_line(m + Vector2(-20, 0), m + Vector2(20, 0), Color("#ef4444"), 1.5)
		draw_line(m + Vector2(0, -20), m + Vector2(0, 20), Color("#ef4444"), 1.5)
		if t < 0.0:
			draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 20, size.y / 2.0), str(int(ceil(-t))), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)


func target_pos(tg: Dictionary, t: float) -> Variant:
	var k := (t - float(tg.t)) / float(tg.dur)
	if k < 0.0 or k > 1.0:
		return null
	var x := lerpf(-30.0, stage.size.x + 30.0, k if int(tg.dir) > 0 else 1.0 - k)
	return Vector2(x, 50.0 + int(tg.lane) * 70.0)


func _ready() -> void:
	build("Atış Poligonu", Vector2(640, 0))
	add_label(body, "Ördeklere tıkla! Üst sıra yavaş (1 puan), orta 2, alt hızlı (3). Altın ördek 5 puan. %d mermi, %d saniye. Puan kadar bilet." % [Fair.GALLERY_AMMO, int(Fair.GALLERY_TIME)], 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage = ShootRange.new()
	stage.p = self
	stage.custom_minimum_size = Vector2(600, 260)
	stage.mouse_filter = MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_click)
	body.add_child(stage)
	info = add_label(body, "Jeton: %d" % Fair.jeton, 17, Color("#facc15"))
	start_btn = add_button(body, "Başla (%d jeton)" % Fair.RIDE_COST, func(): Fair.start_gallery())
	start_btn.custom_minimum_size = Vector2(0, 40)
	Fair.gallery_started.connect(func(_g): _shot = {}; start_btn.visible = false)
	Fair.gallery_hit.connect(func(d): _shot[int(d.id)] = true; _update())
	Fair.gallery_ended.connect(func(d): start_btn.visible = true; info.text = str(d.text); Sfx.play("success", -4.0))
	Fair.changed.connect(_update)


func _update() -> void:
	var g: Dictionary = Fair.gallery
	if g.is_empty():
		info.text = "Jeton: %d   •   Bilet: %d" % [Fair.jeton, Fair.bilet]
	else:
		info.text = "Puan: %d   •   Mermi: %d" % [int(g.get("pts", 0)), int(g.ammo)]


func _on_click(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	var g: Dictionary = Fair.gallery
	if g.is_empty() or int(g.ammo) <= 0:
		return
	g["ammo"] = int(g.ammo) - 1
	Sfx.play("tick", 0.0, 0.7)
	var t: float = Time.get_ticks_msec() / 1000.0 - float(g.t0)
	var m: Vector2 = e.position
	for tg in g.targets:
		if _shot.has(int(tg.id)):
			continue
		var pos = target_pos(tg, t)
		if pos != null and (pos as Vector2).distance_to(m) < 22.0:
			_shot[int(tg.id)] = true
			_pops.append([pos, Time.get_ticks_msec() / 1000.0])
			Fair.shoot(int(tg.id))
			Sfx.play("coin", -6.0, 1.3)
			break
	_update()


func _process(_d: float) -> void:
	stage.queue_redraw()
