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


func _send() -> void:
	Bazaar.send_money(to_name, int(amount.value))
	close()
