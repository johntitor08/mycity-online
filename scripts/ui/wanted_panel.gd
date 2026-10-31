extends "res://scripts/ui/game_panel.gd"
## Alım ilanları panosu (1.9): "şunu şu fiyattan alırım" ilanı as ya da başkasının ilanını doldur.

var box: VBoxContainer


func _ready() -> void:
	build("Alım İlanları Panosu", Vector2(640, 0))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Stalls.changed.connect(_refresh)
	Farm.crops_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _have(w: Dictionary) -> int:
	if w.kind == "food":
		return int(Rpg.sheet.get("items", {}).get(w.key, 0))
	return int(Farm.my_crops.get(w.key, 0))


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	if Stalls.wanted.is_empty():
		add_label(box, "Panoda ilan yok.", 14, Color("#94a3b8"))
	for w in Stalls.wanted:
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, "%s alıyor: %d %s — tanesi %s" % [w.buyer, int(w.qty), w.label, U.money(int(w.price))], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		if w.buyer == Net.my_name:
			add_button(r, "Kaldır (para iade)", Stalls.cancel_wanted.bind(int(w.id)))
		else:
			var n := mini(_have(w), int(w.qty))
			add_button(r, "%d tane sat" % n if n > 0 else "Sende yok", Stalls.fulfill.bind(int(w.id), n)).disabled = n <= 0
	box.add_child(HSeparator.new())
	add_label(box, "Yeni alım ilanı (para emanete alınır):", 15)
	var row := HBoxContainer.new()
	box.add_child(row)
	var pick := OptionButton.new()
	var keys: Array = []
	for k in Rpg.FOODS:
		keys.append(["food", k])
		pick.add_item("Yiyecek: " + Rpg.FOODS[k].name)
	for k in Farm.CROPS.keys() + Farm.PRODUCTS.keys():
		keys.append(["crop", k])
		pick.add_item("Ürün: " + Farm.item_info(k).name)
	row.add_child(pick)
	var qty := add_spin(row, 1, 99, 1, 5)
	qty.prefix = "Adet"
	var price := add_spin(row, 1, 10000, 1, 20)
	price.prefix = "Tanesi"
	price.suffix = "TL"
	add_button(box, "İlanı as", func(): Stalls.post_wanted(keys[pick.selected][0], keys[pick.selected][1], int(qty.value), int(price.value)))
