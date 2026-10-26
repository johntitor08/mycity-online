extends "res://scripts/ui/game_panel.gd"
## Okyanus limanı (1.7): yakıt ve ticaret. port = -1: kendi adandaki pompa (sadece yakıt).

const OM = preload("res://scripts/ocean_map.gd")

var port := -1
var box: VBoxContainer
var _acc := 0.0


func _ready() -> void:
	build("Liman — %s" % (OM.islands()[port].name if port >= 0 else "Kendi iskelen"), Vector2(620, 0))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Ocean.changed.connect(_refresh)
	Cargo.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_acc += delta
	if _acc > 5.0:
		_acc = 0.0
		_refresh()           # fiyatlar dalgalanır


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var o: Dictionary = Ocean.my
	var need := int(ceil(Ocean.max_fuel(o.up) - float(o.fuel)))
	var fr := HBoxContainer.new()
	box.add_child(fr)
	add_label(fr, "Yakıt %d / %d L" % [int(o.fuel), int(Ocean.max_fuel(o.up))], 16, Color("#facc15")).size_flags_horizontal = SIZE_EXPAND_FILL
	if need >= 1:
		add_button(fr, "Depoyu doldur (%s)" % U.money(need * Ocean.FUEL_PRICE), Ocean.refuel)
	else:
		add_label(fr, "Depo dolu ✓", 14, Settings.ok_text())
	if port < 0:
		return
	box.add_child(HSeparator.new())
	var cap := Cargo.capacity(o.up)
	add_label(box, "Ambar: %d / %d sandık   •   Toplam ticaret kârın: %s" % [Cargo.used(), cap, U.money(Cargo.profit)], 15, Color("#7dd3fc"))
	var t := Land.server_now()
	var local := Cargo.local_good(port)
	var g: Dictionary = Cargo.GOODS[local]
	var p := Cargo.price(port, local, t)
	var br := HBoxContainer.new()
	box.add_child(br)
	add_label(br, "SATILIK: %s — %s / sandık" % [g.name, U.money(p)], 15, Color("#86efac")).size_flags_horizontal = SIZE_EXPAND_FILL
	var room := cap - Cargo.used()
	for n in [1, 5, room]:
		if n > 0 and (n != room or room > 5):
			var b := add_button(br, "%s %d" % ["Al" if n != room else "Doldur", n], Cargo.buy.bind(local, n))
			b.disabled = Net.my_money() < p * mini(n, 1)
	add_label(box, "Bu limanın aldığı mallar (satış fiyatı):", 14, Color("#94a3b8"))
	for k in Cargo.GOODS:
		if k == local:
			continue
		var sp := int(round(Cargo.price(port, k, t) * Cargo.SELL_CUT))
		var r := HBoxContainer.new()
		box.add_child(r)
		var have := int(Cargo.cargo.get(k, 0))
		add_label(r, "%s: %s%s" % [Cargo.GOODS[k].name, U.money(sp), "   (ambarda %d)" % have if have > 0 else ""], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		if have > 0:
			add_button(r, "Hepsini sat", Cargo.sell.bind(k, have))
	add_label(box, "İpucu: Her ada kendi malını ucuza satar. Uzak limanlar daha iyi öder. Kargo taşırken korsanlara dikkat!",
		12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
