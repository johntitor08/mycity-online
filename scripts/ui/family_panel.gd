extends "res://scripts/ui/game_panel.gd"
## Aile: eşin, aile kasası (ikiniz de yatırır/çeker), evlilik bonusları ve boşanma.

var box: VBoxContainer
var amount: SpinBox


func _ready() -> void:
	build("Aile", Vector2(560, 0))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	body.add_child(box)
	Family.changed.connect(_refresh)
	Shops.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var f := Family.info
	if f.is_empty():
		add_label(box, "Bekârsın.", 22, Color("#cbd5e1"))
		add_label(box, "Evlenmek için: Çarşı'daki Kuyumcu'dan yüzük al (%s), sevdiğin kişinin yanına git, sağ üstteki listede ismine tıklayıp \"Evlenme Teklif Et\" de. İkinizin de en az seviye %d olması gerekir." % [U.money(int(Shops.ITEMS.ring.price)), Family.LEVEL], 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_label(box, "Yüzüğün: %d" % Shops.rings, 15, Color("#fde68a"))
		add_label(box, "Evliliğin faydaları: ortak aile kasası, eşinin evine her zaman girebilme, birlikteyken %%%d fazla XP, eşinin mutlu evcil hayvanının bonusu." % int(round((Family.XP_BONUS - 1.0) * 100)), 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	add_label(box, "♥  %s ile evlisin" % f.spouse, 24, Color("#f9a8d4"))
	add_label(box, "Evlilik tarihi: %s  •  Eşin şu an %s" % [f.since, "çevrimiçi" if f.online else "çevrimdışı"], 14, Color("#94a3b8"))
	add_label(box, "Aile kasası: %s" % U.money(int(f.bank)), 20, Color("#86efac"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	amount = add_spin(row, 0, 10000000, 100, 500)
	add_button(row, "Yatır", func(): Family.deposit(int(amount.value)))
	add_button(row, "Çek", func(): Family.withdraw(int(amount.value)))
	add_label(box, "Birlikteyken %%%d fazla XP kazanırsınız; birbirinizin evine kapı kapalıyken de girebilirsiniz." % int(round((Family.XP_BONUS - 1.0) * 100)), 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(HSeparator.new())
	buy_button(box, Family.DIVORCE_COST, Family.divorce, 0, "Boşan")
