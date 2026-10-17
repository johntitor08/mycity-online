extends Control
## Ekran üstü arayüz: para, oyuncu sıralaması, sohbet, bildirimler ve bina ipucu.

const U = preload("res://scripts/util.gd")

signal character_requested

var money_label: Label
var name_label: Label
var ranking: RichTextLabel
var chat_log: RichTextLabel
var chat_input: LineEdit
var hint_panel: PanelContainer
var hint_label: Label
var toast_box: VBoxContainer
var sound_btn: Button
var music_btn: Button
var _last_money := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	# Sol üst: isim + para + çıkış
	var top := _box(self)
	_place(top, Vector2(0, 0), Vector2(12, 12), Vector2(12, 12))
	var tv := VBoxContainer.new()
	top.add_child(tv)
	name_label = _label(tv, "", 15, Color("#aab3c9"))
	money_label = _label(tv, "", 26, Color("#86efac"))
	var btns := HBoxContainer.new()
	tv.add_child(btns)
	_small_button(btns, "Karakter", func(): character_requested.emit())
	sound_btn = _small_button(btns, "", Sfx.toggle_mute)
	music_btn = _small_button(btns, "", Sfx.toggle_music)
	_small_button(tv, "Şehirden Çık", Net.leave)
	Sfx.settings_changed.connect(_refresh_sound)
	_refresh_sound()

	# Sağ üst: zenginler listesi
	var right := _box(self)
	right.custom_minimum_size = Vector2(250, 0)
	_place(right, Vector2(1, 0), Vector2(-262, 12), Vector2(-12, 12))
	var rv := VBoxContainer.new()
	right.add_child(rv)
	_label(rv, "Şehrin Zenginleri", 16, Color("#facc15"))
	ranking = RichTextLabel.new()
	ranking.bbcode_enabled = true
	ranking.fit_content = true
	ranking.scroll_active = false
	ranking.custom_minimum_size = Vector2(230, 0)
	rv.add_child(ranking)

	# Sol alt: sohbet
	var chat := _box(self)
	_place(chat, Vector2(0, 1), Vector2(12, -232), Vector2(432, -12))
	var cv := VBoxContainer.new()
	chat.add_child(cv)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	cv.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Sohbet için Enter..."
	chat_input.max_length = 200
	chat_input.text_submitted.connect(_on_chat_submit)
	cv.add_child(chat_input)

	# Alt orta: bina ipucu
	hint_panel = _box(self)
	_place(hint_panel, Vector2(0.5, 1), Vector2(-200, -70), Vector2(200, -24))
	hint_label = _label(hint_panel, "", 20, Color("#fde68a"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.visible = false

	# Sağ alt: kontroller
	var help_box := _box(self)
	_place(help_box, Vector2(1, 1), Vector2(-12, -12), Vector2(-12, -12))
	_label(help_box, "WASD / Oklar: yürü    E: binaya gir    Esc: kapat    Enter: sohbet", 13, Color(1, 1, 1, 0.8))

	# Üst orta: bildirimler
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(toast_box)
	_place(toast_box, Vector2(0.5, 0), Vector2(-260, 14), Vector2(260, 300))

	Net.roster_changed.connect(_refresh)
	Net.chat_received.connect(_on_chat)
	Net.toast.connect(func(t, g): show_toast(t, g); Sfx.play("notify" if g else "error", -6.0))
	_refresh()
	add_chat_line("[color=#94a3b8]Şehre hoş geldin! Binalara yürü ve E'ye bas.[/color]")


func _small_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_sound() -> void:
	sound_btn.text = "Ses: Kapalı" if Sfx.muted else "Ses: Açık"
	music_btn.text = "Müzik: Açık" if Sfx.music_on else "Müzik: Kapalı"


func _place(c: Control, anchor: Vector2, top_left: Vector2, bottom_right: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = top_left.x
	c.offset_top = top_left.y
	c.offset_right = bottom_right.x
	c.offset_bottom = bottom_right.y
	if anchor.x >= 1.0:
		c.grow_horizontal = GROW_DIRECTION_BEGIN
	elif anchor.x > 0.0:
		c.grow_horizontal = GROW_DIRECTION_BOTH
	if anchor.y >= 1.0:
		c.grow_vertical = GROW_DIRECTION_BEGIN


func _box(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.82)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _refresh() -> void:
	name_label.text = Net.my_name
	var m := Net.my_money()
	money_label.text = U.money(m)
	if not Net.roster.has(Net.my_id()):
		_last_money = -1
	elif _last_money < 0:
		_last_money = m
	elif m != _last_money:
		if m > _last_money:
			Sfx.play("cash" if m - _last_money >= 1000 else "coin", -6.0)
		_last_money = m
	var list: Array = Net.roster.values()
	list.sort_custom(func(a, b): return int(a.money) > int(b.money))
	var t := ""
	for i in mini(list.size(), 10):
		var p = list[i]
		var me: bool = p.name == Net.my_name
		t += "[color=#%s]●[/color] %s%s  [color=#86efac]%s[/color]\n" % [
			Color(p.color).to_html(false), "[b]" if me else "", U.esc(p.name) + ("[/b]" if me else ""), U.money(int(p.money))]
	t += "[color=#7c859e]%d oyuncu çevrimiçi[/color]" % list.size()
	ranking.text = t


func _on_chat_submit(text: String) -> void:
	if text.strip_edges() != "":
		Net.send_chat(text)
	chat_input.clear()
	chat_input.release_focus()


func _on_chat(from_name: String, text: String, color: Color) -> void:
	add_chat_line("[color=#%s][b]%s:[/b][/color] %s" % [color.to_html(false), U.esc(from_name), U.esc(text)])


func add_chat_line(bb: String) -> void:
	chat_log.append_text(bb + "\n")


func focus_chat() -> void:
	chat_input.grab_focus()


func is_typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func set_hint(text: String) -> void:
	hint_panel.visible = text != ""
	hint_label.text = text


func show_toast(text: String, good: bool = true) -> void:
	var p := _box(toast_box)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.09, 0.32, 0.18, 0.92) if good else Color(0.45, 0.10, 0.12, 0.92)
	var l := _label(p, text, 17, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
