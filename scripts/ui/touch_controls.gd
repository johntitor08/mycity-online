extends Control
## Dokunmatik kontroller (telefon/tablet): sol altta sanal joystick, sağ altta eylem düğmeleri.
## Düğmeler gerçek tuş olayları üretir (Settings tuş atamaları), böylece oyunun geri kalanı klavyeyle
## aynı yoldan çalışır; basılı tutulan düğme de "basılı tuş" sayılır (zıpkın, kazma).
## Joystick yönü Settings.touch_dir'e yazılır, Settings.held() bunu okur.
## Paintball maçında düğmelerin dışına dokunmak o yöne boya topu atar.
## Telefon dik tutulursa "yan çevir" uyarısı gösterilir.

var world: Node2D

const JOY_R := 86.0
const KNOB_R := 38.0
# [eylem, yazı, yarıçap, sağ alttan uzaklık]
const BUTTONS := [
	["interact", "E", 54.0, Vector2(120, 130)],
	["vehicle", "F", 40.0, Vector2(250, 92)],
	["action", "G", 40.0, Vector2(108, 268)],
	["map", "Harita", 30.0, Vector2(232, 210)],
	["phone", "Tel", 26.0, Vector2(300, 260)],
	["profile", "Profil", 26.0, Vector2(330, 160)],
	["dive", "Dal", 26.0, Vector2(196, 320)],
	["horse", "At", 26.0, Vector2(270, 340)],
]
const CHAT_BTN := Vector2(64, 300)          # sol alttan (joystick'in üstü)

var _joy_touch := -99                       # joystick'i tutan parmak
var _joy_center := Vector2.ZERO
var _knob := Vector2.ZERO
var _held := {}                              # parmak -> eylem
var _portrait_dismissed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	# masaüstünde denerken fare de parmak gibi davransın
	if not DisplayServer.is_touchscreen_available():
		Input.emulate_touch_from_mouse = true


func _exit_tree() -> void:
	_release_all()


func _active() -> bool:
	return visible and world != null and world.panel == null and not world.photo_mode


func _joy_base() -> Vector2:
	return Vector2(40 + JOY_R + 20, size.y - JOY_R - 60)


func _btn_pos(b: Array) -> Vector2:
	return Vector2(size.x, size.y) - b[3]


func _chat_pos() -> Vector2:
	return Vector2(CHAT_BTN.x, size.y - CHAT_BTN.y)


func _hit_button(p: Vector2) -> int:
	for i in BUTTONS.size():
		if p.distance_to(_btn_pos(BUTTONS[i])) < float(BUTTONS[i][2]) + 10.0:
			return i
	return -1


## Bu ekran noktası bir kontrolün üstünde mi? (dünya tıklamaları bunu sorar)
func over_control(p: Vector2) -> bool:
	if not _active():
		return false
	return _hit_button(p) >= 0 or p.distance_to(_joy_base()) < JOY_R + 40.0 or p.distance_to(_chat_pos()) < 40.0


func _key(action: String, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = Settings.key(action)
	ev.keycode = Settings.key(action)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _release_all() -> void:
	for idx in _held:
		_key(_held[idx], false)
	_held.clear()
	_joy_touch = -99
	_knob = Vector2.ZERO
	Settings.touch_dir = Vector2.ZERO


func _portrait() -> bool:
	return size.y > size.x * 1.05


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _portrait() and not _portrait_dismissed:
		if event is InputEventScreenTouch and event.pressed:
			_portrait_dismissed = true
			queue_redraw()
			get_viewport().set_input_as_handled()
		return
	if not _active():
		if not _held.is_empty() or _joy_touch != -99:
			_release_all()
			queue_redraw()
		return
	# dokunma ile üretilen fare olayları kontrollerin üstündeyse dünyaya geçmesin
	if event is InputEventMouseButton and over_control(event.position):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			var bi := _hit_button(p)
			if bi >= 0:
				_held[event.index] = BUTTONS[bi][0]
				_key(BUTTONS[bi][0], true)
				get_viewport().set_input_as_handled()
			elif p.distance_to(_chat_pos()) < 40.0:
				var ev := InputEventKey.new()
				ev.physical_keycode = KEY_ENTER
				ev.keycode = KEY_ENTER
				ev.pressed = true
				Input.parse_input_event(ev)
				get_viewport().set_input_as_handled()
			elif p.distance_to(_joy_base()) < JOY_R + 40.0 or (p.x < size.x * 0.35 and p.y > size.y * 0.45 and _joy_touch == -99):
				# joystick: sol alt bölgede herhangi bir yere dokununca orada başlar
				_joy_touch = event.index
				_joy_center = p if p.distance_to(_joy_base()) >= JOY_R + 40.0 else _joy_base()
				_update_knob(p)
				get_viewport().set_input_as_handled()
			elif world.adv.touch_tap(world.get_viewport().get_canvas_transform().affine_inverse() * p):
				get_viewport().set_input_as_handled()
			elif Paint.in_match() and not Paint.is_out(Net.my_name):
				var wp: Vector2 = world.get_viewport().get_canvas_transform().affine_inverse() * p
				Paint.fire(wp - (world.my_pos + Vector2(0, -16)))
				Sfx.play("splash_small", -10.0, randf_range(1.8, 2.2))
				get_viewport().set_input_as_handled()
		else:
			if _held.has(event.index):
				_key(_held[event.index], false)
				_held.erase(event.index)
				get_viewport().set_input_as_handled()
			if event.index == _joy_touch:
				_joy_touch = -99
				_knob = Vector2.ZERO
				Settings.touch_dir = Vector2.ZERO
				get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch:
			_update_knob(event.position)
			get_viewport().set_input_as_handled()
			queue_redraw()


func _update_knob(p: Vector2) -> void:
	var d := p - _joy_center
	if d.length() > JOY_R:
		d = d.normalized() * JOY_R
	_knob = d
	Settings.touch_dir = d / JOY_R if d.length() > 10.0 else Vector2.ZERO


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _portrait() and not _portrait_dismissed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.1, 0.92))
		var f := ThemeDB.fallback_font
		var c := size / 2.0
		draw_rect(Rect2(c + Vector2(-60, -150), Vector2(120, 200)), Color("#e5e7eb"), false, 6)
		draw_arc(c + Vector2(110, -50), 60, -PI * 0.9, -PI * 0.1, 16, Color("#facc15"), 6)
		draw_string(f, Vector2(0, c.y + 120), "Daha rahat oynamak için telefonu yan çevir", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color.WHITE)
		draw_string(f, Vector2(0, c.y + 180), "(devam etmek için dokun)", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#94a3b8"))
		return
	if not _active():
		return
	var base := _joy_center if _joy_touch != -99 else _joy_base()
	draw_circle(base, JOY_R, Color(1, 1, 1, 0.12))
	draw_arc(base, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.45), 3)
	draw_circle(base + _knob, KNOB_R, Color(1, 1, 1, 0.5 if _joy_touch != -99 else 0.32))
	var f2 := ThemeDB.fallback_font
	for b in BUTTONS:
		var p := _btn_pos(b)
		var r := float(b[2])
		var down: bool = b[0] in _held.values()
		draw_circle(p, r, Color(0.98, 0.8, 0.2, 0.55) if down else Color(0.1, 0.12, 0.18, 0.55))
		draw_arc(p, r, 0, TAU, 40, Color(1, 1, 1, 0.6), 3)
		var fs := 34 if r > 45.0 else (24 if str(b[1]).length() <= 2 else 16)
		draw_string(f2, p + Vector2(-r, fs * 0.36), str(b[1]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
	var cp := _chat_pos()
	draw_circle(cp, 32, Color(0.1, 0.12, 0.18, 0.55))
	draw_arc(cp, 32, 0, TAU, 32, Color(1, 1, 1, 0.6), 3)
	draw_string(f2, cp + Vector2(-32, 6), "Sohbet", HORIZONTAL_ALIGNMENT_CENTER, 64, 14, Color.WHITE)
	if Combat.in_combat():
		draw_string(f2, Vector2(0, 120), "Ekrana dokun: o yöne saldır  ·  G: iksir", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1, 1, 1, 0.7))
	if Paint.in_match():
		draw_string(f2, Vector2(0, 120), "Ekrana dokun: o yöne boya topu at", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1, 1, 1, 0.7))
