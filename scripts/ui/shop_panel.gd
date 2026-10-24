extends "res://scripts/ui/game_panel.gd"
## Çarşı: Kuaför, Aksesuarcı, Kuyumcu. Satın al, hemen giy; solda karakter önizlemesi.

const Avatar = preload("res://scripts/avatar.gd")

var shop := "aksesuar"
var list: VBoxContainer
var preview: Control
var rings_label: Label
var _try: Dictionary = {}          # denenen görünüm (önizleme)


class Preview extends Control:
	var app := {}
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, 80)
		draw_set_transform(c + Vector2(0, 30), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 46, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		var facing: String = ["down", "right", "down", "left"][int(t / 1.8) % 4]
		Avatar.draw(self, c, app, facing, 0, 3.2)


func _ready() -> void:
	build("Çarşı", Vector2(860, 540))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for k in ["kuafor", "aksesuar", "kuyumcu"]:
		add_button(tabs, Shops.SHOP_NAMES[k], _show.bind(k)).custom_minimum_size = Vector2(130, 36)
	rings_label = add_label(tabs, "", 14, Color("#fde68a"))
	rings_label.size_flags_horizontal = SIZE_EXPAND_FILL
	rings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	body.add_child(h)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3f3a52")
	sb.set_corner_radius_all(12)
	bg.add_theme_stylebox_override("panel", sb)
	bg.custom_minimum_size = Vector2(230, 380)
	h.add_child(bg)
	preview = Preview.new()
	bg.add_child(preview)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	money_hint(body)
	Shops.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _show(k: String) -> void:
	shop = k
	_try = {}
	_refresh()


func _my_app() -> Dictionary:
	return Net.roster.get(Net.my_id(), {}).get("appearance", Net.my_appearance)


func _refresh() -> void:
	title_label.text = "Çarşı — %s" % Shops.SHOP_NAMES[shop]
	rings_label.text = "Yüzüğün: %d" % Shops.rings if Shops.rings > 0 else ""
	var app: Dictionary = _my_app().duplicate()
	for k in _try:
		app[k] = _try[k]
	(preview as Preview).app = app
	for c in list.get_children():
		c.queue_free()
	var desc := {"kuafor": "Özel saç boyaları. Aldığın renk karakter penceresinde de seçilebilir.",
		"aksesuar": "Şapka, gözlük ve boyun aksesuarları. \"Dene\" ile önizle, aldıktan sonra \"Giy\".",
		"kuyumcu": "Yüzük ile sevdiğine evlenme teklif edebilirsin (ismine tıkla). Altın kolye ve taç da burada."}
	add_label(list, desc[shop], 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for k in Shops.ITEMS:
		var it: Dictionary = Shops.ITEMS[k]
		if it.shop != shop:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		if it.get("slot", "") == "hair_color":
			var sw := ColorRect.new()
			sw.color = Avatar.HAIR_COLORS[int(it.idx)]
			sw.custom_minimum_size = Vector2(22, 22)
			sw.size_flags_vertical = SIZE_SHRINK_CENTER
			row.add_child(sw)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(v)
		add_label(v, it.name, 16)
		if it.has("desc"):
			add_label(v, it.desc, 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var slot := str(it.get("slot", ""))
		if slot != "":
			add_button(row, "Dene", _try_on.bind(slot, int(it.idx)))
		var owned: bool = Shops.owned.has(k)
		if owned:
			var worn: bool = int(_my_app().get(slot, 0)) == int(it.idx)
			if worn:
				add_button(row, "Çıkar", Shops.wear.bind(slot, 0))
			else:
				add_button(row, "Giy", Shops.wear.bind(slot, int(it.idx)))
		else:
			buy_button(row, int(it.price), Shops.buy.bind(k), int(it.get("level", 0)), "Satın Al")


func _try_on(slot: String, idx: int) -> void:
	_try = {slot: idx}
	_refresh()
