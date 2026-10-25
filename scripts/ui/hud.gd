extends Control
## Ekran üstü arayüz: para, oyuncu sıralaması, sohbet, bildirimler ve bina ipucu.

const U = preload("res://scripts/util.gd")

signal character_requested
signal profile_requested
signal transfer_requested(to_name: String)
signal pet_requested
signal clan_requested
signal events_requested
signal family_requested
signal achievements_requested
signal map_requested
signal settings_requested

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
var level_label: Label
var xp_bar: ProgressBar
var energy_bar: ProgressBar
var energy_label: Label
var clock_label: Label
var quest_label: Label
var status_label: Label
var town_label: Label
var help_label: Label
var job_label: Label
var job_quit: Button
var job_row: HBoxContainer
var bail_btn: Button
var event_banner: PanelContainer
var event_label: Label
var race_label: Label
var channel_opt: OptionButton
const CHANNELS := ["all", "clan", "local"]
const CHANNEL_TAGS := {"clan": ["Klan", "#4ade80"], "local": ["Yakın", "#cbd5e1"], "pm": ["Özel", "#f9a8d4"]}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	# Sol üst: isim + para + çıkış
	var top := _box(self)
	_place(top, Vector2(0, 0), Vector2(12, 12), Vector2(12, 12))
	var tv := VBoxContainer.new()
	top.add_child(tv)
	name_label = _label(tv, "", 15, Color("#aab3c9"))
	clock_label = _label(tv, "", 14, Color("#fde68a"))
	town_label = _label(tv, "", 13, Color("#fdba74"))
	town_label.visible = false
	var jr := HBoxContainer.new()
	tv.add_child(jr)
	job_label = _label(jr, "", 13, Color("#7dd3fc"))
	job_quit = _small_button(jr, "Bırak", Work.quit_job)
	job_row = jr
	jr.visible = false
	Work.job_changed.connect(_refresh_job)
	Jobs.inventory_changed.connect(_refresh_job)
	quest_label = _label(tv, "", 13, Color("#93c5fd"))
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.custom_minimum_size = Vector2(300, 0)
	money_label = _label(tv, "", 26, Color("#86efac"))
	status_label = _label(tv, "", 15, Color("#fca5a5"))
	status_label.visible = false
	bail_btn = _small_button(tv, "", Police.bail)
	bail_btn.visible = false
	var lv := HBoxContainer.new()
	tv.add_child(lv)
	level_label = _label(lv, "Sv.1", 15, Color("#facc15"))
	level_label.custom_minimum_size = Vector2(52, 0)
	xp_bar = _bar(lv, Color("#facc15"))
	var en := HBoxContainer.new()
	tv.add_child(en)
	energy_label = _label(en, "⚡", 15, Color("#4ade80"))
	energy_label.custom_minimum_size = Vector2(52, 0)
	energy_bar = _bar(en, Color("#22c55e"))
	var btns := HBoxContainer.new()
	tv.add_child(btns)
	_small_button(btns, "Profil (C)", func(): profile_requested.emit())
	_small_button(btns, "Karakter", func(): character_requested.emit())
	_small_button(btns, "Evcil", func(): pet_requested.emit())
	_small_button(btns, "Aile", func(): family_requested.emit())
	var btns2 := HBoxContainer.new()
	tv.add_child(btns2)
	_small_button(btns2, "Klan", func(): clan_requested.emit())
	_small_button(btns2, "Etkinlik", func(): events_requested.emit())
	_small_button(btns2, "Başarım", func(): achievements_requested.emit())
	_small_button(btns2, "Harita (M)", func(): map_requested.emit())
	var btns3 := HBoxContainer.new()
	tv.add_child(btns3)
	_small_button(btns3, "Ayarlar", func(): settings_requested.emit())
	sound_btn = _small_button(btns3, "", Sfx.toggle_mute)
	music_btn = _small_button(btns3, "", Sfx.toggle_music)
	_small_button(btns3, "Şehirden Çık", Net.leave)
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
	ranking.meta_underlined = false
	ranking.meta_clicked.connect(func(meta): transfer_requested.emit(str(meta)))
	rv.add_child(ranking)
	_label(rv, "İsme tıkla: para gönder", 11, Color("#7c859e"))

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
	var ci := HBoxContainer.new()
	cv.add_child(ci)
	channel_opt = OptionButton.new()
	for t in ["Genel", "Klan", "Yakın"]:
		channel_opt.add_item(t)
	channel_opt.focus_mode = FOCUS_NONE
	channel_opt.tooltip_text = "Sohbet kanalı. Kısayollar: /k klan, /y yakın, /m isim özel mesaj"
	ci.add_child(channel_opt)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Enter: yaz  (/k klan, /y yakın, /m isim özel)"
	chat_input.max_length = 200
	chat_input.size_flags_horizontal = SIZE_EXPAND_FILL
	chat_input.text_submitted.connect(_on_chat_submit)
	ci.add_child(chat_input)

	# Alt orta: bina ipucu
	hint_panel = _box(self)
	_place(hint_panel, Vector2(0.5, 1), Vector2(-200, -70), Vector2(200, -24))
	hint_label = _label(hint_panel, "", 20, Color("#fde68a"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.visible = false

	# Sağ alt: kontroller
	var help_box := _box(self)
	_place(help_box, Vector2(1, 1), Vector2(-12, -12), Vector2(-12, -12))
	help_label = _label(help_box, "", 13, Color(1, 1, 1, 0.8))
	_refresh_help()
	Settings.changed.connect(_refresh_help)

	# Üst orta: etkinlik bandı, yarış sayacı, bildirimler
	var top_mid := VBoxContainer.new()
	top_mid.mouse_filter = MOUSE_FILTER_IGNORE
	top_mid.add_theme_constant_override("separation", 6)
	add_child(top_mid)
	_place(top_mid, Vector2(0.5, 0), Vector2(-260, 10), Vector2(260, 400))
	event_banner = _box(top_mid)
	(event_banner.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.35, 0.2, 0.05, 0.88)
	event_banner.mouse_filter = MOUSE_FILTER_STOP
	event_banner.gui_input.connect(_on_banner_input)
	event_banner.tooltip_text = "Tıkla: etkinlik ayrıntıları"
	event_label = _label(event_banner, "", 15, Color("#fde68a"))
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_banner.visible = false
	race_label = _label(top_mid, "", 30, Color("#ffffff"))
	race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_label.add_theme_constant_override("outline_size", 8)
	race_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	race_label.visible = false
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_mid.add_child(toast_box)

	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh_rpg)
	Story.changed.connect(_refresh_quest)
	Police.changed.connect(_refresh_status)
	Events.changed.connect(_refresh_event)
	_refresh_rpg()
	Net.chat_received.connect(_on_chat)
	Net.toast.connect(_on_toast)
	_refresh()
	add_chat_line("[color=#94a3b8]Şehre hoş geldin! Binalara yürü ve E'ye bas.[/color]")


func _small_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _bar(parent: Node, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(150, 10)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func _refresh_rpg() -> void:
	var s := Rpg.sheet
	if s.is_empty():
		return
	level_label.text = "Sv.%d" % s.level
	xp_bar.value = 100.0 * (int(s.xp) - int(s.cur)) / maxi(1, int(s.next) - int(s.cur))
	xp_bar.tooltip_text = "XP %d / %d" % [s.xp, s.next]
	_refresh_energy()


func _refresh_energy() -> void:
	var s := Rpg.sheet
	if s.is_empty():
		return
	var e := Rpg.energy_now()
	energy_bar.value = 100.0 * e / float(s.max_energy)
	energy_label.text = "⚡%d" % int(e)
	energy_bar.tooltip_text = "Enerji %d / %d" % [int(e), s.max_energy]


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_refresh_energy()
		clock_label.text = Env.clock_text()
		_refresh_event()
		_refresh_status()
		_refresh_town()
	_refresh_race()


func _refresh_job() -> void:
	var j := Work.job
	var parts: Array = []
	if str(j.get("text", "")) != "":
		var t := str(j.text)
		if float(j.get("left", 0.0)) > 0.0:
			t += " (%d sn)" % int(j.left)
		parts.append(t)
	if not Jobs.my_fish.is_empty():
		var val := 0
		for f in Jobs.my_fish:
			val += int(f.price)
		parts.append("Kova: %d/%d balık (%s) — Pazar'da sat" % [Jobs.my_fish.size(), Jobs.BAG_SIZE, U.money(val)])
	if Work.carrying > 0:
		parts.append("Çöp torbası: %d/%d" % [Work.carrying, Work.TRASH_CARRY])
	if Work.on_duty_fire():
		parts.append("İtfaiye görevinde (%d yangın)" % Work.fires.size())
	job_label.text = "  •  ".join(parts)
	job_quit.visible = str(j.get("kind", "")) != ""
	job_row.visible = not parts.is_empty()


func _refresh_help() -> void:
	help_label.text = "%s%s%s%s: yürü   %s: gir   %s: araç   %s: eylem   %s: harita   %s: profil   Esc: kapat   Enter: sohbet" % [
		Settings.key_name("up"), Settings.key_name("left"), Settings.key_name("down"), Settings.key_name("right"),
		Settings.key_name("interact"), Settings.key_name("vehicle"), Settings.key_name("action"), Settings.key_name("map"), Settings.key_name("profile")]


## Sağ alttaki mini harita (dünya sahnesi oluşturup verir).
func set_minimap(m: Control) -> void:
	var box := _box(self)
	(box.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(4)
	m.custom_minimum_size = Vector2(170, 170 * 3300.0 / 2800.0)
	m.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(m)
	_place(box, Vector2(1, 1), Vector2(-190, -262), Vector2(-12, -46))
	box.mouse_filter = MOUSE_FILTER_IGNORE


func _refresh_status() -> void:
	var stars := int(Police.status.get("wanted", 0))
	var jail := Police.jail_left()
	bail_btn.visible = jail > 0.0
	if jail > 0.0:
		status_label.text = "HAPİSTESİN — %d:%02d kaldı" % [int(jail) / 60, int(jail) % 60]
		status_label.add_theme_color_override("font_color", Color("#fca5a5"))
		bail_btn.text = "Kefalet öde (%s)" % U.money(int(ceil(jail)) * Police.BAIL_PER_SEC)
	elif stars > 0:
		status_label.text = "ARANIYORSUN %s" % "★".repeat(stars)
		status_label.add_theme_color_override("font_color", Color("#fca5a5"))
	elif Police.on_duty():
		status_label.text = "POLİS — görevde"
		status_label.add_theme_color_override("font_color", Color("#93c5fd"))
	elif Garage.rent_left() > 0.0:
		var rl := Garage.rent_left()
		status_label.text = "Kiralık tekne: %d:%02d" % [int(rl) / 60, int(rl) % 60]
		status_label.add_theme_color_override("font_color", Color("#7dd3fc"))
	else:
		status_label.text = ""
	status_label.visible = status_label.text != ""


func _refresh_town() -> void:
	var st := Election.state
	var ph := str(st.get("phase", ""))
	if ph == "apply" or ph == "vote":
		var left := Election.time_left()
		town_label.text = "Seçim: %s — %d:%02d (Muhtarlık)" % ["aday başvurusu" if ph == "apply" else "OYLAMA", int(left) / 60, int(left) % 60]
		town_label.visible = not (ph == "vote" and bool(st.get("voted", false)))
	else:
		town_label.visible = false


func _refresh_event() -> void:
	var cur := Events.current
	if cur.is_empty():
		event_banner.visible = false
		return
	var left := maxf(0.0, Events.current_ends - Events.local_now())
	var t := "%s — %d:%02d kaldı" % [cur.name, int(left) / 60, int(left) % 60]
	var st: Array = cur.get("standings", [])
	for i in st.size():
		if st[i].name == Net.my_name:
			t += "  ·  Sen %d. (%s)" % [i + 1, st[i].text]
	if not st.is_empty() and st[0].name != Net.my_name and cur.kind != "treasure" and cur.kind != "festival":
		t += "  ·  Lider: %s" % st[0].name
	event_label.text = t
	event_banner.visible = true


func _refresh_race() -> void:
	var r := Events.race
	match str(r.get("state", "")):
		"countdown":
			var c := int(ceil(float(r.go) - Events.local_now()))
			race_label.text = str(maxi(c, 1)) if c > 0 else "BAŞLA!"
			race_label.visible = true
		"running":
			race_label.text = "%.1f sn   •   Kontrol %d/%d" % [Events.race_time(), int(r.next) + 1, int(r.total)]
			race_label.visible = true
		_:
			race_label.visible = false


func _on_banner_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		events_requested.emit()


func _refresh_quest() -> void:
	var st := Story.state
	if st.is_empty() or st.get("finished", false):
		quest_label.text = ""
		return
	if st.get("ready", false):
		quest_label.text = "Görev hazır: %s — ödülünü al" % st.title
	elif st.get("accepted", false):
		quest_label.text = "Görev (%d/%d): %s" % [int(st.count), int(st.goal), st.hint]
	else:
		quest_label.text = "Yeni görev: başında \"!\" olan kişiyle konuş"


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
		var nm := U.esc(p.name) if me else "[url=%s]%s[/url]" % [p.name, U.esc(p.name)]
		if str(p.get("clan", "")) != "":
			nm = "[color=%s][lb]%s[rb][/color] %s" % [p.get("clan_color", "#4ade80"), U.esc(p.clan), nm]
		if bool(p.get("mayor", false)):
			nm += " [color=#facc15](Başkan)[/color]"
		if str(p.get("spouse", "")) != "":
			nm += " [color=#f9a8d4]♥[/color]"
		if int(p.get("wanted", 0)) > 0:
			nm += " [color=#f87171]%s[/color]" % "★".repeat(int(p.wanted))
		t += "[color=#%s]●[/color] %s%s [color=#facc15]Sv.%d[/color]  [color=#86efac]%s[/color]\n" % [
			Color(p.color).to_html(false), "[b]" if me else "", nm + ("[/b]" if me else ""),
			int(p.get("level", 1)), U.money(int(p.money))]
	t += "[color=#7c859e]%d oyuncu çevrimiçi[/color]" % list.size()
	ranking.text = t


func _on_chat_submit(text: String) -> void:
	text = text.strip_edges()
	if text != "":
		var ch: String = CHANNELS[channel_opt.selected]
		var to := ""
		var low := text.to_lower()
		if low.begins_with("/k "):
			ch = "clan"
			text = text.substr(3)
		elif low.begins_with("/y "):
			ch = "local"
			text = text.substr(3)
		elif low.begins_with("/m ") or low.begins_with("/f "):
			var parts := text.substr(3).strip_edges().split(" ", false, 1)
			if parts.size() < 2:
				add_chat_line("[color=#94a3b8]Özel mesaj: /m isim mesaj[/color]")
				chat_input.clear()
				return
			ch = "pm"
			to = parts[0]
			text = parts[1]
		elif low.begins_with("/g "):
			ch = "all"
			text = text.substr(3)
		Net.send_chat(text, ch, to)
	chat_input.clear()
	chat_input.release_focus()


## Özel mesaj için sohbeti hazırla (oyuncu adına tıklayınca).
func start_pm(to_name: String) -> void:
	chat_input.text = "/m %s " % to_name
	chat_input.grab_focus()
	chat_input.caret_column = chat_input.text.length()


func _on_chat(from_name: String, text: String, color: Color, channel: String = "all") -> void:
	var prefix := ""
	var body_col := ""
	if CHANNEL_TAGS.has(channel):
		prefix = "[color=%s][lb]%s[rb][/color] " % [CHANNEL_TAGS[channel][1], CHANNEL_TAGS[channel][0]]
		body_col = CHANNEL_TAGS[channel][1]
	var msg := U.esc(text) if body_col == "" else "[color=%s]%s[/color]" % [body_col, U.esc(text)]
	add_chat_line("%s[color=#%s][b]%s:[/b][/color] %s" % [prefix, color.to_html(false), U.esc(from_name), msg])


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


## Küresel sinyallere lambda değil metot bağlanır: HUD silinince bağlantı kendiliğinden kopar.
func _on_toast(text: String, good: bool) -> void:
	show_toast(text, good)
	Sfx.play("notify" if good else "error", -6.0)


func show_toast(text: String, good: bool = true) -> void:
	var p := _box(toast_box)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Settings.good_color() if good else Settings.bad_color()
	var l := _label(p, text, 17, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
