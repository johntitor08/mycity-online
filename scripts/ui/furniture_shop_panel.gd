extends "res://scripts/ui/game_panel.gd"
## Mobilyacı: mobilya satın al (deponuza gider; evinde yerleştirirsin).

var grid: GridContainer
var depot_label: Label


func _ready() -> void:
	build("Mobilyacı", Vector2(760, 0))
	add_label(body, "Aldığın mobilyalar deponda bekler. Evine girip E ile ev menüsünü açarak yerleştirebilirsin.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	depot_label = add_label(body, "", 14, Color("#cbd5e1"))
	depot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for k in Homes.FURNITURE:
		var f: Dictionary = Homes.FURNITURE[k]
		var icon := TextureRect.new()
		icon.texture = load("res://assets/furniture/%s.svg" % k)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(56, 32)
		grid.add_child(icon)
		var sz: Vector2i = f.size
		add_label(grid, "%s  (%dx%d)%s" % [f.name, sz.x, sz.y, ("  — " + f.desc) if f.has("desc") else ""], 15).custom_minimum_size = Vector2(470, 0)
		add_button(grid, U.money(int(f.price)), Homes.buy.bind(k))
	Homes.depot_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var parts: Array = []
	for k in Homes.depot:
		parts.append("%s ×%d" % [Homes.FURNITURE[k].name, Homes.depot[k]])
	depot_label.text = "Depon: " + (", ".join(parts) if not parts.is_empty() else "boş")
