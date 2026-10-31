extends Control
## Bina pencerelerinin ortak temeli: ekranı karartır, ortada başlıklı bir panel açar.

signal closed

const U = preload("res://scripts/util.gd")

var body: VBoxContainer
var title_label: Label
var _hint_label: Label


## docked: pencere ekranın sağ yarısına yaslanır ve ekran karartılmaz (ör. balık tutarken
## karakter ve olta görünsün diye).
func build(title: String, min_size: Vector2, docked: bool = false) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE if docked else MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0 if docked else 0.35)
	dim.mouse_filter = MOUSE_FILTER_IGNORE if docked else MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if docked:
		center.anchor_left = 0.5
		center.offset_left = 0
		center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1e2230")
	sb.border_color = Color("#3d4560")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_label = add_label(head, title, 26)
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	add_label(head, "Esc", 13, Color("#7c859e"))
	add_button(head, "Kapat", close)
	v.add_child(HSeparator.new())
	body = VBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)


func close() -> void:
	closed.emit()


## Bu paneli kapatıp yerine başka bir panel aç (world üstünden).
func switch_to(p: Control) -> void:
	var world := get_parent().get_parent()
	if world != null and world.has_method("open_panel_node"):
		world.open_panel_node(p)


func add_label(parent: Node, text: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func add_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func add_rich(parent: Node, font_size: int = 16, min_height: float = 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(0, min_height)
	r.add_theme_font_size_override("normal_font_size", font_size)
	parent.add_child(r)
	return r


func add_spin(parent: Node, lo: float, hi: float, step: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(120, 0)
	parent.add_child(s)
	return s


## Satın alma butonu: para ya da seviye yetmiyorsa kapanır ve nedenini yazar.
## Paran değişince panelin _refresh'i bunu tekrar çağırmalı (bkz. watch_money).
func buy_button(parent: Node, price: int, cb: Callable, need_level: int = 0, label: String = "Al") -> Button:
	var b := add_button(parent, "", cb)
	update_buy_button(b, price, need_level, label)
	return b


func update_buy_button(b: Button, price: int, need_level: int = 0, label: String = "Al") -> void:
	var lvl := int(Rpg.sheet.get("level", 1))
	var money := Net.my_money()
	b.tooltip_text = ""
	if need_level > 0 and lvl < need_level:
		b.text = "Sv.%d gerekli" % need_level
		b.disabled = true
		b.tooltip_text = "Seviyen %d. İşlerde çalışarak XP kazan." % lvl
	elif money < price:
		b.text = "%s gerekli" % U.money(price)
		b.disabled = true
		b.tooltip_text = "Sende %s var. Hastane, market ya da balıkla para kazan." % U.money(money)
	else:
		b.text = "%s (%s)" % [label, U.money(price)]
		b.disabled = false


## Para azken bilgilendirici satır (yeni oyuncular para kazanmayı bilsin).
## (Küresel sinyale metot bağlanır; panel kapanınca bağlantı kendiliğinden kopar.)
func money_hint(parent: Node) -> Label:
	_hint_label = add_label(parent, "", 13, Color("#fde68a"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not Net.roster_changed.is_connected(_update_money_hint):
		Net.roster_changed.connect(_update_money_hint)
	_update_money_hint()
	return _hint_label


func _update_money_hint() -> void:
	_hint_label.text = "Paran: %s. Para kazanmak için: Hastane (doktorluk), Market (kasiyerlik) ya da iskelede balık tut." % U.money(Net.my_money())
	_hint_label.visible = Net.my_money() < 1500


## Bir sonraki adımı panel kapanmışsa çalıştırmadan geciktirir.
func later(seconds: float, method: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(method)
