extends "res://scripts/ui/game_panel.gd"
## Pazar meydanı tezgâhı (1.9): boşsa kirala; seninse mal diz/kaldır, kasayı boşalt; başkasınınsa alışveriş.

var stall := 0
var box: VBoxContainer


func _ready() -> void:
	build("Tezgâh #%d" % (stall + 1), Vector2(640, 0))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Stalls.changed.connect(_refresh)
	Jobs.inventory_changed.connect(_refresh)
	Farm.crops_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _v() -> Dictionary:
	return Stalls.view[stall] if stall < Stalls.view.size() else {}


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var v := _v()
	var open := not v.is_empty() and bool(v.get("open", false))
	if not open or v.owner == Net.my_name and float(v.get("left", 0.0)) <= 0.0:
		add_label(box, "Bu tezgâh boş. Kiralayıp mallarını sat; sen oyundayken meydana gelen müşteriler de alışveriş yapar (çevrimdışıyken tezgâh satış yapmaz).", 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var mine := Stalls.my_stall()
		if mine >= 0 and mine != stall:
			add_label(box, "Zaten %d numaralı tezgâhın var." % (mine + 1), 14, Color("#fca5a5"))
		else:
			buy_button(box, int(Projects.mahalle.get("rent", Stalls.RENT)), Stalls.rent.bind(stall), 0, "1 gün kirala")
		return
	if v.owner == Net.my_name:
		_owner(v)
	else:
		_shop(v)


func _owner(v: Dictionary) -> void:
	var left := float(v.get("left", 0.0))
	add_label(box, "Kasa: %s   •   Satılan: %d   •   Kira: %d sa %d dk kaldı" % [U.money(int(v.get("till", 0))), int(v.get("sold", 0)), int(left / 3600.0), int(fmod(left, 3600.0) / 60.0)], 15, Color("#fde68a"))
	var top := HBoxContainer.new()
	box.add_child(top)
	add_button(top, "Kasayı boşalt", Stalls.collect).disabled = int(v.get("till", 0)) <= 0
	add_button(top, "Kirayı 1 gün uzat (%s)" % U.money(int(Projects.mahalle.get("rent", Stalls.RENT))), Stalls.rent.bind(stall)).disabled = left > (Stalls.MAX_DAYS - 1) * Stalls.DAY
	add_button(top, "Tezgâhı bırak", Stalls.release)
	var lr := HBoxContainer.new()
	box.add_child(lr)
	var name_edit := LineEdit.new()
	name_edit.text = str(v.name)
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(220, 0)
	lr.add_child(name_edit)
	var col := OptionButton.new()
	for i in Stalls.COLORS.size():
		col.add_item(["Kırmızı", "Turuncu", "Sarı", "Yeşil", "Mavi", "Mor", "Pembe", "Turkuaz"][i])
	col.selected = int(v.color)
	lr.add_child(col)
	add_button(lr, "Adı ve rengi kaydet", func(): Stalls.set_look(name_edit.text, col.selected))
	box.add_child(HSeparator.new())
	add_label(box, "Tezgâhtaki mallar (%d/%d çeşit)" % [v.items.size(), Stalls.MAX_ITEMS], 15)
	for idx in v.items.size():
		var it: Dictionary = v.items[idx]
		var r := HBoxContainer.new()
		box.add_child(r)
		var hint := "  (müşteri ilgisi: %s)" % _interest(int(it.price), int(it.base))
		add_label(r, "%d × %s — %s%s" % [int(it.qty), it.label, U.money(int(it.price)), hint], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(r, "Kaldır", Stalls.unstock.bind(idx))
	box.add_child(HSeparator.new())
	add_label(box, "Mal diz (fiyatı sen belirle):", 15)
	var price := add_spin(box, 1, 100000, 1, 50)
	var qty := add_spin(box, 1, 99, 1, 1)
	price.prefix = "Tanesi"
	price.suffix = "TL"
	qty.prefix = "Adet"
	for i in Jobs.my_fish.size():
		var f: Dictionary = Jobs.my_fish[i]
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, "Balık: %s (değeri %s)" % [f.name, U.money(int(f.price))], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(r, "Diz", func(): Stalls.stock("fish", i, 1, int(price.value)))
	for k in Rpg.sheet.get("items", {}):
		if Rpg.food_info(k).is_empty():
			continue
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, "Yiyecek: %s × %d (değeri %s)" % [Rpg.food_info(k).name, int(Rpg.sheet.items[k]), U.money(int(Rpg.food_info(k).get("price", 0)))], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(r, "Diz", func(): Stalls.stock("food", k, int(qty.value), int(price.value)))
	for k in Farm.my_crops:
		if int(Farm.my_crops[k]) <= 0 or Farm.item_info(k).is_empty():
			continue
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, "Ürün: %s × %d (değeri %s)" % [Farm.item_info(k).name, int(Farm.my_crops[k]), U.money(int(Farm.item_info(k).price))], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(r, "Diz", func(): Stalls.stock("crop", k, int(qty.value), int(price.value)))
	add_label(box, "Müşteriler malın değerine bakar: değerine yakın fiyatlı mal çabuk satılır, ~2,5 katından pahalıyı kimse almaz. Satıştan %%%d pazar payı kesilir." % int(Stalls.COMMISSION * 100),
		12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func _interest(price: int, base: int) -> String:
	var c := Stalls.npc_chance(price, base)
	if c <= 0.0:
		return "yok, çok pahalı"
	if c < 0.06:
		return "az"
	if c < 0.15:
		return "orta"
	return "yüksek"


func _shop(v: Dictionary) -> void:
	add_label(box, "%s — satıcı: %s" % [v.name, v.owner], 16, Color("#fde68a"))
	money_hint(box)
	if v.items.is_empty():
		add_label(box, "Tezgâh şu an boş.", 14, Color("#94a3b8"))
	for idx in v.items.size():
		var it: Dictionary = v.items[idx]
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, "%s — %d tane" % [it.label, int(it.qty)], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		buy_button(r, int(it.price), Stalls.buy.bind(stall, idx))
