extends "res://scripts/ui/game_panel.gd"
## Başka bir oyuncuya para gönder ya da özel mesaj yaz.

signal pm_requested(to_name: String)

var to_name := ""
var amount: SpinBox


func _ready() -> void:
	build("Para Gönder / Mesaj", Vector2(440, 0))
	add_label(body, "Alıcı: %s" % to_name, 20, Color("#facc15"))
	add_label(body, "Paran: %s   •   Gerekli seviye: %d" % [U.money(Net.my_money()), Bazaar.TRANSFER_MIN_LEVEL], 14, Color("#94a3b8"))
	var row := HBoxContainer.new()
	body.add_child(row)
	add_label(row, "Tutar:", 17)
	amount = add_spin(row, 1, Bazaar.TRANSFER_MAX, 10, mini(100, maxi(1, Net.my_money())))
	amount.size_flags_horizontal = SIZE_EXPAND_FILL
	add_button(body, "Gönder", _send).custom_minimum_size = Vector2(0, 40)
	body.add_child(HSeparator.new())
	add_button(body, "Özel Mesaj Yaz", func(): pm_requested.emit(to_name)).custom_minimum_size = Vector2(0, 36)
	add_button(body, "Takas teklif et (yanında olmalısın)", func(): Trade.invite(to_name); close()).custom_minimum_size = Vector2(0, 36)
	add_button(body, "Arkadaş ekle", func(): Phone.add_friend(to_name); close()).custom_minimum_size = Vector2(0, 32)
	_petrole_buttons()
	if Family.info.is_empty():
		var b := add_button(body, "Evlenme Teklif Et (yüzük: %d)" % Shops.rings, _propose)
		b.custom_minimum_size = Vector2(0, 36)
		b.disabled = Shops.rings <= 0
		if Shops.rings <= 0:
			b.tooltip_text = "Önce Çarşı'daki Kuyumcu'dan yüzük al."


## 2.4: evcil hayvan rolü: iste / sev / mama ver / bitir
func _petrole_buttons() -> void:
	body.add_child(HSeparator.new())
	var mine := PetRole.my_role()
	if str(mine.get("owner", "")) == to_name:
		add_button(body, "Evcil hayvan rolünü bitir", func(): PetRole.stop(); close()).custom_minimum_size = Vector2(0, 34)
		return
	if to_name in PetRole.my_pets():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)
		add_button(row, "♥ Sev", func(): PetRole.act("sev", to_name); close()).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(row, "Mama ver (%d TL)" % PetRole.FOOD_PRICE, func(): PetRole.act("mama", to_name); close()).size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(body, "Rolü bitir (artık evcil hayvanın olmasın)", func(): PetRole.stop(to_name); close()).custom_minimum_size = Vector2(0, 32)
		return
	if not mine.is_empty():
		return
	add_label(body, "Evcil hayvanı ol — sahibin %s olur (rol yapma, onun onayıyla):" % to_name, 14, Color("#fbcfe8"))
	for form in ["hayvan", "insan"]:
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 8)
		body.add_child(r2)
		var lb := add_label(r2, "Hayvan olarak:" if form == "hayvan" else "İnsan şeklinde\n(kulak + kuyruk):", 13, Color("#94a3b8"))
		lb.custom_minimum_size = Vector2(120, 0)
		for k in PetRole.KINDS:
			if form == "insan" and not k in PetRole.COSTUME_KINDS:
				continue
			var b := add_button(r2, str(PetRole.KINDS[k]).capitalize(), func(): PetRole.ask(to_name, k, form); close())
			b.size_flags_horizontal = SIZE_EXPAND_FILL


func _propose() -> void:
	Family.propose(to_name)
	close()


func _send() -> void:
	Bazaar.send_money(to_name, int(amount.value))
	close()
