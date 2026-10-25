extends "res://scripts/ui/game_panel.gd"
## Şehir Müzesi: koleksiyonlar, kimin bağışladığı ve elindeki eksik parçaları bağışlama.

var tabs: HBoxContainer
var grid: GridContainer
var head: Label
var cur := "balik"


func _ready() -> void:
	build("Şehir Müzesi", Vector2(820, 0))
	add_label(body, "Bir parçayı müzeye ilk bağışlayan %s ve XP kazanır, adı vitrine yazılır. Bir koleksiyon tamamlanınca katkı veren herkes %s alır." % [
		U.money(Museum.DONATE_MONEY), U.money(Museum.SET_REWARD)], 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head = add_label(body, "", 17, Color("#facc15"))
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	Museum.changed.connect(_refresh)
	Jobs.inventory_changed.connect(_refresh)
	Farm.crops_changed.connect(_refresh)
	Museum.refresh()
	_refresh()


func _show(id: String) -> void:
	cur = id
	_refresh()


func _refresh() -> void:
	var pr := Museum.progress()
	head.text = "Müze koleksiyonu: %d / %d parça" % [pr.x, pr.y]
	for c in tabs.get_children():
		c.queue_free()
	for c in grid.get_children():
		c.queue_free()
	for s in Museum.sets():
		var got := 0
		for it in s[2]:
			if Museum.view.has(it[0]):
				got += 1
		var done: bool = got == s[2].size()
		var b := add_button(tabs, "%s%s %d/%d" % ["✓ " if done else "", s[1], got, s[2].size()], _show.bind(s[0]))
		b.custom_minimum_size = Vector2(150, 34)
		if s[0] == cur:
			b.modulate = Color("#facc15")
		if s[0] != cur:
			continue
		for it in s[2]:
			_card(str(it[0]), str(it[1]))


func _card(key: String, label: String) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var have: bool = Museum.view.has(key)
	sb.bg_color = Color("#1f3b2d") if have else Color("#262b3b")
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(250, 74)
	grid.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	add_label(v, label, 16, Color.WHITE if have else Color("#cbd5e1"))
	if have:
		var e: Dictionary = Museum.view[key]
		add_label(v, "✓ Bağışlayan: %s  (%s)" % [e.get("by", "?"), e.get("d", "")], 13, Settings.ok_text())
	elif Museum.i_have(key):
		add_button(v, "Bağışla", Museum.donate.bind(key))
	else:
		add_label(v, "Eksik", 13, Color("#7c859e"))
