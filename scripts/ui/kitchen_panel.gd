extends "res://scripts/ui/game_panel.gd"
## Mutfak mini oyunu (2.0): servis vardiyası (mode "shift") ya da aşçılık yarışması (mode "contest").
##  Sipariş fişindeki adımları sırayla yap: 1 doğra, 2 ocak, 3 fırın, 4 ızgara, 5 sos, 6 tabakla.
##  Ocak/fırın/ızgarada tuşa bir kez bas (pişmeye başlar), çubuk yeşildeyken yeniden bas.

const C = preload("res://scripts/chef.gd")

var mode := "shift"
var plot := -1
var board: Board
var info: Label
var side: VBoxContainer
var prog := {}                      # sipariş -> {step, qs, cook (yerel zaman ya da -1), dish}
var active := -1
var _flash := {}                    # sipariş -> [metin, renk, zaman]
var _done_contest := false
var _result_shown := false


class Board extends Control:
	var p = null

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1c1917"))
		var orders: Array = p._orders()
		var now := Time.get_ticks_msec() / 1000.0
		for i in orders.size():
			var o: Dictionary = orders[i]
			var oid := int(o.id)
			var r := Rect2(12 + i * 236, 12, 224, 190)
			var act: bool = oid == p.active
			draw_rect(r, Color("#fef3c7") if act else Color("#e7e5e4"))
			draw_rect(r, Color("#f59e0b") if act else Color("#78716c"), false, 3 if act else 1)
			var di := C.dish_info(str(o.dish))
			draw_string(f, r.position + Vector2(10, 26), str(di.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 204, 18, Color("#1c1917"))
			var pr: Dictionary = p.prog.get(oid, {"step": 0})
			var steps: Array = di.get("steps", [])
			for k in steps.size():
				var sp := r.position + Vector2(14 + (k % 3) * 70, 46 + (k / 3) * 46)
				var st := str(steps[k])
				var done: bool = k < int(pr.step)
				var cur: bool = k == int(pr.step)
				draw_rect(Rect2(sp, Vector2(62, 38)), Color("#86efac") if done else (Color("#fde68a") if cur else Color("#d6d3d1")))
				draw_string(f, sp + Vector2(0, 16), "%d" % (C.STATIONS.keys().find(st) + 1), HORIZONTAL_ALIGNMENT_CENTER, 62, 14, Color("#57534e"))
				draw_string(f, sp + Vector2(0, 33), C.STATIONS[st][0], HORIZONTAL_ALIGNMENT_CENTER, 62, 13, Color("#1c1917"))
			# kalan süre
			var left := float(o.left) - (now - float(p._recv_t))
			var frac := clampf(left / maxf(1.0, float(o.total)), 0.0, 1.0)
			draw_rect(Rect2(r.position.x + 10, r.end.y - 22, 204, 10), Color("#d6d3d1"))
			draw_rect(Rect2(r.position.x + 10, r.end.y - 22, 204 * frac, 10), Color("#22c55e") if frac > 0.35 else Color("#ef4444"))
			# pişirme çubuğu
			if act and float(pr.get("cook", -1.0)) > 0.0:
				var cf := (now - float(pr.cook)) / C.COOK_TIME
				var br := Rect2(12, 214, size.x - 24, 26)
				draw_rect(br, Color("#44403c"))
				draw_rect(Rect2(br.position.x + br.size.x * C.GOOD[0], br.position.y, br.size.x * (C.GOOD[1] - C.GOOD[0]), br.size.y), Color("#16a34a"))
				draw_rect(Rect2(br.position.x + br.size.x * minf(cf, 1.0) - 3, br.position.y - 4, 6, br.size.y + 8), Color("#fafafa") if cf <= 1.0 else Color("#ef4444"))
				draw_string(f, br.position + Vector2(0, -6), "Pişiyor... yeşildeyken yeniden bas!", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 14, Color("#fde68a"))
			if p._flash.has(oid) and now - float(p._flash[oid][2]) < 1.2:
				draw_string(f, r.position + Vector2(0, 120), str(p._flash[oid][0]), HORIZONTAL_ALIGNMENT_CENTER, 224, 22, p._flash[oid][1])
		# istasyonlar
		var keys: Array = C.STATIONS.keys()
		for k in keys.size():
			var sp := Vector2(12 + k * 118, size.y - 62)
			draw_rect(Rect2(sp, Vector2(110, 50)), Color("#44403c"))
			draw_string(f, sp + Vector2(0, 22), "[%d]" % (k + 1), HORIZONTAL_ALIGNMENT_CENTER, 110, 16, Color("#fde68a"))
			draw_string(f, sp + Vector2(0, 42), C.STATIONS[keys[k]][0], HORIZONTAL_ALIGNMENT_CENTER, 110, 16, Color.WHITE)


var _recv_t := 0.0


func _ready() -> void:
	build("Mutfak — Servis Vardiyası" if mode == "shift" else "Aşçılık Yarışması", Vector2(740, 0))
	info = add_label(body, "", 16, Color("#fde68a"))
	board = Board.new()
	board.p = self
	board.custom_minimum_size = Vector2(716, 330)
	body.add_child(board)
	side = VBoxContainer.new()
	body.add_child(side)
	add_label(body, "Fişe tıklayarak sıradaki siparişi seç. Tuşlar 1–6 (ya da istasyona tıkla). Yanlış adım kaliteyi düşürür.", 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Chef.changed.connect(_on_changed)
	Chef.order_event.connect(_on_order)
	if mode == "shift":
		Chef.start_shift(plot)
	else:
		Chef.start_contest()
	_on_changed()


func _orders() -> Array:
	return Chef.shift.get("orders", []) if mode == "shift" else Chef.contest.get("orders", [])


func _on_changed() -> void:
	_recv_t = Time.get_ticks_msec() / 1000.0
	var orders := _orders()
	var ids: Array = []
	for o in orders:
		ids.append(int(o.id))
		if not prog.has(int(o.id)):
			prog[int(o.id)] = {"step": 0, "qs": [], "cook": -1.0, "dish": str(o.dish)}
	if not active in ids:
		active = ids[0] if not ids.is_empty() else -1
	for c in side.get_children():
		c.queue_free()
	if mode == "shift":
		var s: Dictionary = Chef.shift
		if s.get("over", false):
			info.text = "Vardiya bitti! %d sipariş (%d mükemmel), %d kaçtı — kazanç %s" % [int(s.served), int(s.perfect), int(s.missed), U.money(int(s.earned))]
			add_button(side, "Yeni vardiya", func():
				prog.clear()
				Chef.start_shift(plot))
		else:
			info.text = "Kalan %d sn  ·  Servis %d  ·  Mükemmel %d  ·  Kaçan %d  ·  Kazanç %s" % [int(s.get("left", 0)), int(s.get("served", 0)), int(s.get("perfect", 0)), int(s.get("missed", 0)), U.money(int(s.get("earned", 0)))]
	else:
		var c: Dictionary = Chef.contest
		if c.has("result"):
			var r: Dictionary = c.result
			info.text = "Jüri: %s  →  Toplam %.1f / 30  (teknik %.1f, lezzet %.1f%s)" % [", ".join(PackedStringArray(r.judges.map(func(v): return "%.1f" % float(v)))),
				float(r.total), float(r.tech), float(r.taste), (", imza: %s" % r.sig) if str(r.sig) != "" else ""]
			_result_shown = true
		elif c.has("orders") and (int(c.get("done", 0)) >= 3 or orders.is_empty()) and not _done_contest:
			_done_contest = true
			info.text = "3 yemek bitti! İmza yemeğini seç ve jüriye sun."
			_sig_picker()
		else:
			info.text = "Yarışma: %d/3 yemek hazır" % int(c.get("done", 0))


func _sig_picker() -> void:
	var row := HBoxContainer.new()
	side.add_child(row)
	var opt := OptionButton.new()
	opt.add_item("İmza yemeği yok")
	var keys: Array = [""]
	for k in Rpg.sheet.get("items", {}):
		if Kitchen.RECIPES.has(k):
			opt.add_item(Kitchen.RECIPES[k].name)
			keys.append(k)
	row.add_child(opt)
	add_button(row, "Jüriye sun", func(): Chef.finish_contest(keys[opt.selected]))


func _on_order(d: Dictionary) -> void:
	var oid := int(d.get("id", -1))
	if d.get("missed", false):
		_flash[oid] = ["KAÇTI!", Color("#ef4444"), Time.get_ticks_msec() / 1000.0]
		Sfx.play("lose", -6.0)
	else:
		_flash[oid] = ["+%s%s" % [U.money(int(d.pay)), " BAHŞİŞ!" if int(d.tip) > 0 else ""], Color("#16a34a"), Time.get_ticks_msec() / 1000.0]
		Sfx.play("cash", -4.0)


func _press(station: String) -> void:
	if active < 0 or not prog.has(active):
		return
	var pr: Dictionary = prog[active]
	var steps: Array = C.dish_info(str(pr.dish)).get("steps", [])
	if int(pr.step) >= steps.size():
		return
	var want := str(steps[int(pr.step)])
	var now := Time.get_ticks_msec() / 1000.0
	if float(pr.cook) > 0.0:
		if station == want:
			pr.qs.append(C.cook_quality((now - float(pr.cook)) / C.COOK_TIME))
			pr["cook"] = -1.0
			pr["step"] = int(pr.step) + 1
			Sfx.play("splash_small", -8.0, 1.4)
		return
	if station != want:
		pr.qs.append(0.0)
		_flash[active] = ["Yanlış adım!", Color("#ef4444"), now]
		Sfx.play("error", -8.0)
		return
	if station in C.COOKING:
		pr["cook"] = now
		Sfx.play("place", -8.0, 0.8)
		return
	pr.qs.append(1.0)
	pr["step"] = int(pr.step) + 1
	Sfx.play("place", -8.0, 1.3)
	_check_done()


func _check_done() -> void:
	var pr: Dictionary = prog[active]
	var steps: Array = C.dish_info(str(pr.dish)).get("steps", [])
	if int(pr.step) < steps.size():
		return
	var q := 0.0
	for v in pr.qs:
		q += float(v)
	q /= maxf(1.0, float(pr.qs.size()))
	if mode == "shift":
		Chef.serve(active, q)
	else:
		Chef.contest_dish(active, q)
	prog.erase(active)
	active = -1


func _process(_d: float) -> void:
	# pişirme adımı bitince (tabakla gibi) otomatik kontrol
	if active >= 0 and prog.has(active):
		_check_done()
	if mode == "shift" and not Chef.shift.get("over", false) and not Chef.shift.is_empty():
		info.text = "Kalan %d sn  ·  Servis %d  ·  Mükemmel %d  ·  Kaçan %d  ·  Kazanç %s" % [maxi(0, int(float(Chef.shift.get("left", 0)) - (Time.get_ticks_msec() / 1000.0 - _recv_t))),
			int(Chef.shift.get("served", 0)), int(Chef.shift.get("perfect", 0)), int(Chef.shift.get("missed", 0)), U.money(int(Chef.shift.get("earned", 0)))]


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var keys: Array = C.STATIONS.keys()
		for k in keys:
			if e.physical_keycode == C.STATIONS[k][1]:
				_press(k)
				get_viewport().set_input_as_handled()
				return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var lp: Vector2 = board.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, board.size).has_point(lp):
			return
		var orders := _orders()
		for i in orders.size():
			if Rect2(12 + i * 236, 12, 224, 190).has_point(lp):
				active = int(orders[i].id)
				return
		var keys: Array = C.STATIONS.keys()
		for k in keys.size():
			if Rect2(12 + k * 118, board.size.y - 62, 110, 50).has_point(lp):
				_press(keys[k])
				return
