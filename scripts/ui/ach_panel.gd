extends "res://scripts/ui/game_panel.gd"
## Başarımlar: açılanlar, ilerleme çubukları ve unvan seçimi.

var list: VBoxContainer
var head: Label
var title_opt: OptionButton
var _titles: Array = []


func _ready() -> void:
	build("Başarımlar ve Unvanlar", Vector2(760, 560))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	head = add_label(top, "", 18, Color("#facc15"))
	head.size_flags_horizontal = SIZE_EXPAND_FILL
	add_label(top, "Unvan:", 15)
	title_opt = OptionButton.new()
	title_opt.custom_minimum_size = Vector2(200, 0)
	title_opt.item_selected.connect(func(i): Ach.set_title(_titles[i]))
	top.add_child(title_opt)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	Ach.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var got: Dictionary = Ach.data.get("got", {})
	var c: Dictionary = Ach.data.get("c", {})
	head.text = "%d / %d başarım" % [got.size(), Ach.LIST.size()]
	title_opt.clear()
	_titles = [""]
	title_opt.add_item("(unvan yok)")
	for k in Ach.LIST:
		if got.has(k) and Ach.title_name(k) != "":
			_titles.append(k)
			title_opt.add_item("«%s»" % Ach.title_name(k))
	title_opt.selected = maxi(0, _titles.find(str(Ach.data.get("title", ""))))
	for ch in list.get_children():
		ch.queue_free()
	# önce açılanlar, sonra ilerlemeye göre
	var keys: Array = Ach.LIST.keys()
	keys.sort_custom(func(a, b):
		var ga := got.has(a)
		var gb := got.has(b)
		if ga != gb:
			return ga
		return float(c.get(Ach.LIST[a][0], 0)) / float(Ach.LIST[a][1]) > float(c.get(Ach.LIST[b][0], 0)) / float(Ach.LIST[b][1]))
	for k in keys:
		var d: Array = Ach.LIST[k]
		var have := got.has(k)
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1f3b2a") if have else Color("#262b3b")
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(6)
		row.add_theme_stylebox_override("panel", sb)
		list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		add_label(h, "★" if have else "☆", 20, Color("#facc15") if have else Color("#64748b"))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(v)
		add_label(v, "%s%s" % [d[2], ("   «%s»" % d[5]) if str(d[5]) != "" else ""], 16, Color.WHITE if have else Color("#cbd5e1"))
		add_label(v, d[3], 12, Color("#94a3b8"))
		if not have and int(d[1]) > 1:
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 6)
			bar.value = 100.0 * minf(1.0, float(c.get(d[0], 0)) / float(d[1]))
			v.add_child(bar)
		var right := "Ödül %s" % U.money(int(d[4])) if int(d[4]) > 0 else ""
		if not have and int(d[1]) > 1:
			right = "%d / %d   %s" % [mini(int(c.get(d[0], 0)), int(d[1])), int(d[1]), right]
		add_label(h, right, 13, Color("#86efac") if have else Color("#94a3b8"))
