extends "res://scripts/ui/game_panel.gd"
## Ev menüsü (ev içinde E): mobilya yerleştir, kapıyı aç/kilitle, evden çık.

signal place_requested(k: String)

var focus_plot := -1
var list: VBoxContainer
var door_btn: Button


func _ready() -> void:
	var plot: Dictionary = Land.view[focus_plot] if focus_plot >= 0 and focus_plot < Land.view.size() else {}
	var mine: bool = plot.get("owner", "") == Net.my_name
	build("%s'in Evi" % plot.get("owner", "?"), Vector2(640, 0))
	_party_info(plot)
	if not mine:
		add_label(body, "Misafirsin. Ev sahibi kapıyı kilitlerse dışarı çıkarılırsın.", 15, Color("#94a3b8"))
		body.add_child(HSeparator.new())
		add_label(body, "Evi puanla (günde bir):", 15, Color("#facc15"))
		var stars := HBoxContainer.new()
		body.add_child(stars)
		for k in range(1, 6):
			add_button(stars, "★".repeat(k), func(): Party.rate(focus_plot, k); close())
		add_label(body, "Misafir defterine yaz:", 15, Color("#facc15"))
		var row := HBoxContainer.new()
		body.add_child(row)
		var note := LineEdit.new()
		note.max_length = 80
		note.placeholder_text = "ör. Çok güzel bir ev, akvaryuma bayıldım!"
		note.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(note)
		add_button(row, "Yaz", func(): Party.sign_book(focus_plot, note.text); close())
		_guestbook(plot)
		add_button(body, "Evden Çık", _exit)
		return
	add_label(body, "Yatağın üstünde durursan enerjin çok hızlı dolar. Lambader gece odayı aydınlatır.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	door_btn = add_button(row, "", _toggle_door)
	add_button(row, "Evden Çık", _exit)
	var prow := HBoxContainer.new()
	body.add_child(prow)
	var pb := add_button(prow, "Parti ver (%s, %d dk)" % [U.money(Party.COST), int(Party.DURATION / 60.0)], func(): Party.start_party(focus_plot); close())
	pb.disabled = Party.is_party(plot, Land.server_now())
	body.add_child(HSeparator.new())
	add_label(body, "Deponda bekleyenler (Yerleştir'e bas, sonra odada sol tıkla):", 16, Color("#93c5fd"))
	list = VBoxContainer.new()
	body.add_child(list)
	add_label(body, "Yerleştirilmiş bir eşyayı kaldırmak için üstüne sağ tıkla. Mobilya almak için: Mobilyacı.", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Kitchen.has_stove(plot):
		_kitchen()
	_guestbook(plot)
	Homes.depot_changed.connect(_refresh)
	Land.plots_changed.connect(_refresh)
	_refresh()


## Mutfak: tarifler ve eldeki malzemeler.
func _kitchen() -> void:
	body.add_child(HSeparator.new())
	add_label(body, "Mutfak (ocak) — tarifler", 17, Color("#facc15"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for k in Kitchen.RECIPES:
		var r: Dictionary = Kitchen.RECIPES[k]
		var parts: Array = []
		var ok := true
		for ing in r.needs:
			var have := Jobs.my_fish.size() if ing == "balik" else int(Farm.my_crops.get(ing, 0))
			ok = ok and have >= int(r.needs[ing])
			parts.append("%d %s (%d)" % [int(r.needs[ing]), Kitchen.ing_name(ing), have])
		add_label(grid, r.name, 15, Color.WHITE if ok else Color("#94a3b8"))
		var desc := "+%d enerji%s  •  %s" % [int(r.energy), (", " + Kitchen.BUFF_NAMES[r.buff[0]]) if r.has("buff") else "", ", ".join(parts)]
		var l := add_label(grid, desc, 12, Color("#cbd5e1") if ok else Color("#64748b"))
		l.custom_minimum_size = Vector2(330, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_button(grid, "Pişir", Kitchen.cook.bind(k)).disabled = not ok
	add_label(body, "Malzemeler: tarladan ekin, ahırdan yumurta/süt, kovadan balık. Yemekler çantaya girer (Profil'den ye).", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Parti durumu, dekor ve misafir puanı.
func _party_info(plot: Dictionary) -> void:
	var r: Dictionary = plot.get("rating", {})
	var t := "Dekor puanı: %d  •  Misafir puanı: %s" % [Party.decor_score(plot),
		("%.1f/5 (%d oy)" % [Party.rating_of(plot), int(r.get("n", 0))]) if int(r.get("n", 0)) > 0 else "henüz yok"]
	add_label(body, t, 14, Color("#fde68a"))
	if Party.is_party(plot, Land.server_now()):
		var left := float(plot.party_until) - Land.server_now()
		add_label(body, "♪ Parti sürüyor! %d dk kaldı — misafirler XP ve enerji kazanıyor." % int(ceil(left / 60.0)), 15, Color("#f9a8d4"))


func _guestbook(plot: Dictionary) -> void:
	var book: Array = plot.get("guestbook", [])
	if book.is_empty():
		return
	add_label(body, "Misafir defteri", 15, Color("#93c5fd"))
	for k in range(book.size() - 1, maxi(-1, book.size() - 6), -1):
		var e: Dictionary = book[k]
		add_label(body, "%s (%s): %s" % [e.n, e.d, e.t], 13, Color("#cbd5e1")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh() -> void:
	if list == null:
		return
	var plot: Dictionary = Land.view[focus_plot]
	door_btn.text = "Kapı: Açık (kilitle)" if plot.get("door_open", false) else "Kapı: Kilitli (misafire aç)"
	for c in list.get_children():
		c.queue_free()
	if Homes.depot.is_empty():
		add_label(list, "Depo boş.", 15, Color("#7c859e"))
	for k in Homes.depot:
		var row := HBoxContainer.new()
		list.add_child(row)
		add_label(row, "%s ×%d" % [Homes.FURNITURE[k].name, Homes.depot[k]], 16).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(row, "Yerleştir", func(): place_requested.emit(k))


func _toggle_door() -> void:
	Homes.set_door(focus_plot, not Land.view[focus_plot].get("door_open", false))


func _exit() -> void:
	Homes.exit_home()
	close()
