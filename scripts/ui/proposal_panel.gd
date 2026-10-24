extends "res://scripts/ui/game_panel.gd"
## Gelen evlenme teklifi: Kabul / Reddet.

var from_name := ""


func _ready() -> void:
	build("Evlenme Teklifi", Vector2(480, 0))
	add_label(body, "♥", 48, Color("#f472b6")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l := add_label(body, "%s diz çöktü ve pırlanta bir yüzük uzattı:\n\"Benimle evlenir misin?\"" % from_name, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	add_button(row, "Evet, evlenelim!", _answer.bind(true)).custom_minimum_size = Vector2(180, 44)
	add_button(row, "Hayır", _answer.bind(false)).custom_minimum_size = Vector2(120, 44)


func _answer(yes: bool) -> void:
	Family.answer(yes)
	close()
