extends "res://scripts/ui/game_panel.gd"
## Hipodrom: yarışa katıl, bahis oyna, yarışı izle; jokeysen Boşluk = kamçı.

const Map = preload("res://scripts/map.gd")

var track: Control
var info: Label
var actions: VBoxContainer
var bet_amount: SpinBox


class Track extends Control:
	func _draw() -> void:
		var r: Dictionary = Horses.race
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7c5a3a"))
		var lanes: Array = r.get("lanes", [])
		var lh := size.y / float(Horses.LANES)
		for i in Horses.LANES:
			draw_line(Vector2(0, i * lh), Vector2(size.x, i * lh), Color(1, 1, 1, 0.35), 1)
		var fx := size.x - 30.0
		for k in int(size.y / 8.0):
			draw_rect(Rect2(fx, k * 8, 8, 8), Color.WHITE if k % 2 == 0 else Color.BLACK)
		var span: float = Map.HIPPO_FINISH_X - Map.HIPPO_START_X
		for i in lanes.size():
			var l: Dictionary = lanes[i]
			var u := clampf((float(l.x) - Map.HIPPO_START_X) / span, 0.0, 1.05)
			var p := Vector2(20 + u * (size.x - 60), i * lh + lh / 2.0)
			var col: Color = Horses.COLORS[int(l.c) % Horses.COLORS.size()]
			draw_circle(p, lh * 0.32, col)
			draw_circle(p, lh * 0.32, Color.BLACK, false, 2.0)
			if l.get("whip", false):
				draw_arc(p, lh * 0.45, 0, TAU, 16, Color("#facc15"), 2.0)
			var font := ThemeDB.fallback_font
			var tag := "%d. " % int(l.place) if int(l.place) > 0 else ""
			draw_string(font, Vector2(4, i * lh + 14), "%d  %s%s" % [i + 1, tag, l.n], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			if int(l.get("pid", 0)) == Net.my_id():
				var st := float(l.st) / maxf(1.0, float(l.stmax))
				draw_rect(Rect2(p.x - 20, p.y + lh * 0.36, 40, 4), Color(0, 0, 0, 0.5))
				draw_rect(Rect2(p.x - 20, p.y + lh * 0.36, 40 * st, 4), Color("#34d399"))


func _ready() -> void:
	build("Hipodrom", Vector2(700, 0))
	add_label(body, "Atınla yarışa katıl ya da bahis oyna. Yarışta Boşluk (ya da butona) bas: kamçı atı hızlandırır ama dayanıklılığı bitirir. Son düzlüğe güç sakla!", 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info = add_label(body, "", 17, Color("#facc15"))
	track = Track.new()
	track.custom_minimum_size = Vector2(660, 200)
	body.add_child(track)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	body.add_child(actions)
	Horses.race_changed.connect(_refresh)
	Horses.changed.connect(_refresh)
	Horses.refresh_race()
	_refresh()


func _my_lane() -> int:
	var lanes: Array = Horses.race.get("lanes", [])
	for i in lanes.size():
		if int(lanes[i].get("pid", 0)) == Net.my_id():
			return i
	return -1


var _last_state := ""


func _refresh() -> void:
	var r: Dictionary = Horses.race
	var st := str(r.get("state", "idle"))
	match st:
		"idle":
			info.text = "Şu an yarış yok. Atınla katılınca 25 sn sonra başlar."
		"lobby":
			info.text = "Yarış %d sn sonra başlıyor — katıl ya da bahis oyna!" % int(ceil(Horses.race_left()))
		"run":
			info.text = "YARIŞ!" if float(r.get("left", 0.0)) >= 3.0 else "Hazır... %d" % int(ceil(3.0 - float(r.get("left", 0.0))))
		"done":
			var lanes: Array = r.get("lanes", [])
			var win := ""
			for l in lanes:
				if int(l.place) == 1:
					win = l.n
			info.text = "Kazanan: %s!" % win
	track.queue_redraw()
	if st == _last_state and st in ["run", "lobby"]:
		return                              # butonları her karede yeniden kurma
	_last_state = st
	for c in actions.get_children():
		c.queue_free()
	if st == "idle" or st == "lobby":
		var h := Horses.active_horse()
		var row := HBoxContainer.new()
		actions.add_child(row)
		if h.is_empty():
			add_label(row, "Yarışmak için atın olmalı (Sanayi'deki Hara).", 14, Color("#94a3b8"))
		elif _my_lane() < 0:
			add_button(row, "%s ile yarışa katıl" % h.n, Horses.join_race).custom_minimum_size = Vector2(0, 38)
	if st == "lobby":
		var lanes: Array = r.get("lanes", [])
		var bets: Dictionary = r.get("bets", {})
		if bets.has(Net.my_id()):
			var b: Array = bets[Net.my_id()]
			add_label(actions, "Bahsin: kulvar %d, %s" % [int(b[0]) + 1, U.money(int(b[1]))], 15, Settings.ok_text())
		else:
			var row2 := HBoxContainer.new()
			actions.add_child(row2)
			add_label(row2, "Bahis:", 15)
			bet_amount = add_spin(row2, Horses.BET_MIN, Horses.BET_MAX, 50, 100)
			for i in Horses.LANES:
				var lbl := "Kulvar %d" % (i + 1)
				if i < lanes.size():
					lbl = "%s (×%.1f)" % [lanes[i].n.left(10), float(lanes[i].get("odds", 2.0))]
				add_button(row2, lbl, func(): Horses.bet(i, int(bet_amount.value))).disabled = i >= lanes.size()
			add_label(actions, "Boş kulvarlar yarış başlarken NPC atlarla dolar (oranları o zaman belli olur).", 12, Color("#7c859e"))
	if st == "run" and _my_lane() >= 0:
		add_button(actions, "KAMÇI! (Boşluk)", Horses.whip).custom_minimum_size = Vector2(0, 46)


func _process(_d: float) -> void:
	if str(Horses.race.get("state", "")) in ["lobby", "run"]:
		_refresh()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_SPACE and str(Horses.race.get("state", "")) == "run":
		Horses.whip()
		get_viewport().set_input_as_handled()
