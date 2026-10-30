extends "res://scripts/ui/game_panel.gd"
## Ayarlar: ses seviyeleri, ekran, kamera, arayüz boyutu, renk körlüğü modu, tuş atama, eğitim turu.

var _waiting := ""                 # tuş ataması bekleyen eylem
var _key_btns := {}
var world: Node2D                  # oyun içindeyse (eğitimi yeniden başlatmak için)


func _ready() -> void:
	build("Ayarlar", Vector2(760, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	body.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	add_label(left, "Ses", 18, Color("#facc15"))
	_slider(left, "Genel ses", Settings.master_vol, 0.0, 1.0, func(v): Settings.master_vol = v)
	_slider(left, "Müzik", Settings.music_vol, 0.0, 1.0, func(v): Settings.music_vol = v)
	_slider(left, "Efektler", Settings.sfx_vol, 0.0, 1.0, func(v): Settings.sfx_vol = v)
	add_label(left, "Görüntü", 18, Color("#facc15"))
	var fs := CheckBox.new()
	fs.text = "Tam ekran"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on): Settings.fullscreen = on; _changed())
	left.add_child(fs)
	_slider(left, "Kamera yakınlığı", Settings.zoom, 0.6, 2.0, func(v): Settings.zoom = v)
	_slider(left, "Arayüz ve yazı boyutu", Settings.ui_scale, 0.8, 1.5, func(v): Settings.ui_scale = v, true)
	var cb := CheckBox.new()
	cb.text = "Renk körlüğü modu (kırmızı/yeşil yerine turuncu/mavi)"
	cb.button_pressed = Settings.colorblind
	cb.toggled.connect(func(on): Settings.colorblind = on; _changed())
	left.add_child(cb)
	var th := HBoxContainer.new()
	left.add_child(th)
	add_label(th, "Dokunmatik kontroller", 14).size_flags_horizontal = SIZE_EXPAND_FILL
	var tm := OptionButton.new()
	for t in ["Otomatik (telefonda)", "Açık", "Kapalı"]:
		tm.add_item(t)
	tm.selected = ["auto", "on", "off"].find(Settings.touch_mode)
	tm.item_selected.connect(func(i):
		Settings.touch_mode = ["auto", "on", "off"][i]
		_changed()
		if world and world.has_method("refresh_touch"):
			world.refresh_touch())
	th.add_child(tm)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	add_label(right, "Tuşlar (değiştirmek için tıkla, sonra yeni tuşa bas)", 15, Color("#facc15"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for a in Settings.ACTIONS:
		add_label(grid, Settings.ACTIONS[a][1], 14).custom_minimum_size = Vector2(170, 0)
		var b := add_button(grid, "", _wait_key.bind(a))
		b.custom_minimum_size = Vector2(130, 0)
		_key_btns[a] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	right.add_child(row)
	add_button(row, "Varsayılan tuşlar", _reset_keys)
	if world != null:
		add_button(row, "Eğitimi yeniden başlat", func(): Settings.tutorial_done = false; Tutorial.start(world.ui_layer, true); close())
	add_label(right, "Esc pencereleri kapatır, Enter sohbete yazar; ok tuşları her zaman yürütür.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_keys()


func _slider(parent: Node, text: String, value: float, lo: float, hi: float, setter: Callable, on_release: bool = false) -> void:
	var r := HBoxContainer.new()
	parent.add_child(r)
	add_label(r, text, 14).custom_minimum_size = Vector2(150, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(150, 0)
	s.size_flags_vertical = SIZE_SHRINK_CENTER
	r.add_child(s)
	var l := add_label(r, "%d%%" % int(value * 100), 13, Color("#94a3b8"))
	s.value_changed.connect(func(v):
		l.text = "%d%%" % int(v * 100)
		setter.call(v)
		if not on_release:
			_changed())
	if on_release:       # arayüz boyutu değişince pencere yeniden düzenlenir: bırakınca uygula
		s.drag_ended.connect(func(_c): _changed())


func _changed() -> void:
	Settings.save()
	Settings.apply()


func _wait_key(a: String) -> void:
	_waiting = a
	_key_btns[a].text = "... bir tuşa bas"


func _input(e: InputEvent) -> void:
	if _waiting == "" or not (e is InputEventKey) or not e.pressed:
		return
	if e.physical_keycode != KEY_ESCAPE:
		Settings.keys[_waiting] = e.physical_keycode
		Settings.save()
	_waiting = ""
	_refresh_keys()
	get_viewport().set_input_as_handled()


func _reset_keys() -> void:
	for a in Settings.ACTIONS:
		Settings.keys[a] = int(Settings.ACTIONS[a][0])
	Settings.save()
	_refresh_keys()


func _refresh_keys() -> void:
	var used := {}
	for a in Settings.ACTIONS:
		used[Settings.key(a)] = int(used.get(Settings.key(a), 0)) + 1
	for a in _key_btns:
		var b: Button = _key_btns[a]
		b.text = Settings.key_name(a)
		b.modulate = Color(1, 0.6, 0.4) if int(used[Settings.key(a)]) > 1 else Color.WHITE
		b.tooltip_text = "Bu tuş başka bir eyleme de atanmış!" if int(used[Settings.key(a)]) > 1 else ""
