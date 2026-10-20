extends "res://scripts/ui/game_panel.gd"
## Ev menüsü (ev içinde E): mobilya yerleştir, kapıyı aç/kilitle, evden çık.

signal place_requested(k: String)

var focus_plot := -1
var list: VBoxContainer
var door_btn: Button


func _ready() -> void:
	var plot: Dictionary = Land.view[focus_plot] if focus_plot >= 0 and focus_plot < Land.view.size() else {}
	var mine: bool = plot.get("owner", "") == Net.my_name
	build("%s'in Evi" % plot.get("owner", "?"), Vector2(560, 0))
	if not mine:
		add_label(body, "Misafirsin. Ev sahibi kapıyı kilitlerse dışarı çıkarılırsın.", 15, Color("#94a3b8"))
		add_button(body, "Evden Çık", _exit)
		return
	add_label(body, "Yatağın üstünde durursan enerjin çok hızlı dolar. Lambader gece odayı aydınlatır.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	door_btn = add_button(row, "", _toggle_door)
	add_button(row, "Evden Çık", _exit)
	body.add_child(HSeparator.new())
	add_label(body, "Deponda bekleyenler (Yerleştir'e bas, sonra odada sol tıkla):", 16, Color("#93c5fd"))
	list = VBoxContainer.new()
	body.add_child(list)
	add_label(body, "Yerleştirilmiş bir eşyayı kaldırmak için üstüne sağ tıkla. Mobilya almak için: Mobilyacı.", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Homes.depot_changed.connect(_refresh)
	Land.plots_changed.connect(_refresh)
	_refresh()


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
