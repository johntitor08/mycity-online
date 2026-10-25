extends "res://scripts/ui/game_panel.gd"
## Mobilyacı: mobilya satın al (deponuza gider; evinde yerleştirirsin) ya da kullanılmayanı geri sat.

var grid: GridContainer
var depot_box: VBoxContainer
var _buttons := {}


func _ready() -> void:
	build("Mobilyacı", Vector2(780, 0))
	add_label(body, "Aldığın mobilyalar deponda bekler. Evine girip E ile ev menüsünü açarak yerleştirebilirsin.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for k in Homes.FURNITURE.keys().filter(func(x): return not Homes.FURNITURE[x].get("prize", false)):
		var f: Dictionary = Homes.FURNITURE[k]
		var icon := TextureRect.new()
		icon.texture = load("res://assets/furniture/%s.svg" % k)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(56, 32)
		grid.add_child(icon)
		var sz: Vector2i = f.size
		add_label(grid, "%s  (%dx%d)%s" % [f.name, sz.x, sz.y, ("  — " + f.desc) if f.has("desc") else ""], 15).custom_minimum_size = Vector2(470, 0)
		_buttons[k] = buy_button(grid, int(f.price), Homes.buy.bind(k))
	body.add_child(HSeparator.new())
	add_label(body, "Deponda (kullanılmayan mobilyayı yarı fiyatına geri satabilirsin):", 16, Color("#93c5fd"))
	depot_box = VBoxContainer.new()
	body.add_child(depot_box)
	Homes.depot_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for k in _buttons:
		update_buy_button(_buttons[k], int(Homes.FURNITURE[k].price))
	for c in depot_box.get_children():
		c.queue_free()
	if Homes.depot.is_empty():
		add_label(depot_box, "Depo boş.", 14, Color("#7c859e"))
	for k in Homes.depot:
		var row := HBoxContainer.new()
		depot_box.add_child(row)
		add_label(row, "%s ×%d" % [Homes.FURNITURE[k].name, Homes.depot[k]], 15).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(row, "Geri sat (+%s)" % U.money(int(int(Homes.FURNITURE[k].price) * Homes.SELL_BACK)), Homes.sell_back.bind(k))
