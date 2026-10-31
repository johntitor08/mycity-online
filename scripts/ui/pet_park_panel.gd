extends "res://scripts/ui/game_panel.gd"
## Evcil Hayvan Parkı (1.9): hayvanının durumu, kupaları ve aksesuarlar. mode = "show_result": şov sonucu.

var mode := "kiosk"
var box: VBoxContainer


func _ready() -> void:
	build("Güzellik Şovu Sonucu" if mode == "show_result" else "Evcil Hayvan Parkı", Vector2(620, 0))
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	PetShow.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	if mode == "show_result":
		_result()
		return
	var me: Dictionary = PetShow.my
	if me.is_empty():
		add_label(box, "Bir evcil hayvanın yok. Şehirdeki Pet Shop'tan kedi, köpek ya da papağan alabilirsin.", 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var pet: Dictionary = Pets.my_pet
	add_label(box, "%s (%s)" % [pet.get("name", ""), Pets.PETS.get(pet.get("kind", ""), {}).get("name", "")], 20, Color("#fde68a"))
	for st in [["speed", "Hız"], ["agility", "Çeviklik"], ["charm", "Çekicilik"]]:
		var r := HBoxContainer.new()
		box.add_child(r)
		add_label(r, st[1], 15).custom_minimum_size = Vector2(110, 0)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = int(me.get(st[0], 0))
		bar.custom_minimum_size = Vector2(300, 18)
		r.add_child(bar)
	var cups: Dictionary = me.get("cups", {})
	add_label(box, "Kupalar: Altın %d · Gümüş %d · Bronz %d   •   Bugün kalan eğitim: %d" % [int(cups.get("gold", 0)), int(cups.get("silver", 0)), int(cups.get("bronze", 0)), int(me.get("trains_left", 0))], 15)
	add_label(box, "Aksesuar çekiciliği: +%d" % PetShow.wear_charm(me.get("wear", {})), 14, Color("#f9a8d4"))
	box.add_child(HSeparator.new())
	money_hint(box)
	var owned: Array = me.get("acc", [])
	var wear: Dictionary = me.get("wear", {})
	for k in PetShow.ACCESSORIES:
		var a: Dictionary = PetShow.ACCESSORIES[k]
		var r := HBoxContainer.new()
		box.add_child(r)
		var slot_name: String = {"head": "baş", "neck": "boyun", "eyes": "göz"}[a.slot]
		add_label(r, "%s (%s, çekicilik +%d)" % [a.name, slot_name, int(a.charm)], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		if k in owned:
			add_button(r, "Çıkar" if str(wear.get(a.slot, "")) == k else "Tak", PetShow.wear.bind(k))
		else:
			buy_button(r, int(a.price), PetShow.buy_acc.bind(k))
	add_label(box, "Eğitim: koşu bandı (hız), slalom (çeviklik), bakım masası (çekicilik). Parkur yarışında hız ve çeviklik, şovda çekicilik ve aksesuarlar önemli.",
		12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _result() -> void:
	var d: Dictionary = PetShow.last_show
	var place := int(d.get("place", 3))
	add_label(box, ["BİRİNCİ! Altın kupa", "İkinci — gümüş kupa", "Üçüncü — bronz kupa", "Dördüncü"][mini(place, 3)] + ("  +%s" % U.money(int(d.prize)) if int(d.get("prize", 0)) > 0 else ""), 22, Color("#fde68a"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	box.add_child(grid)
	for h in ["Yarışmacı", "Jüri 1", "Jüri 2", "Jüri 3", "Toplam"]:
		add_label(grid, h, 14, Color("#94a3b8"))
	for e in d.get("entries", []):
		var mine: bool = str(e[1]) == Net.my_name
		var col := Color("#86efac") if mine else Color.WHITE
		add_label(grid, "%s%s" % [e[0], " (%s)" % e[1] if str(e[1]) != "" else ""], 15, col)
		var tot := 0.0
		for s in e[3]:
			add_label(grid, "%.1f" % float(s), 15, col)
			tot += float(s)
		add_label(grid, "%.1f" % tot, 15, col)
