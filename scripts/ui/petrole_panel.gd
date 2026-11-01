extends "res://scripts/ui/game_panel.gd"
## 2.4: gelen evcil hayvan rolü isteği: Kabul / Reddet.

var from_name := ""
var kind := "cat"
var form := "hayvan"


func _ready() -> void:
	build("Evcil Hayvan Rolü", Vector2(480, 0))
	add_label(body, "♥", 48, Color("#f472b6")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var how := "kulak ve kuyruk takarak, insan şeklinde" if form == "insan" else "hayvan olarak görünecek"
	var l := add_label(body, "%s senin evcil hayvanın olmak istiyor (%s, %s)!\nKabul edersen, seni takip edebilir; onu sevebilir ve mama verebilirsin.\nİkiniz de rolü istediğiniz an bitirebilirsiniz." % [from_name, str(PetRole.KINDS.get(kind, "hayvan")), how], 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	add_button(row, "Kabul et", _answer.bind(true)).custom_minimum_size = Vector2(160, 44)
	add_button(row, "Hayır", _answer.bind(false)).custom_minimum_size = Vector2(120, 44)


func _answer(yes: bool) -> void:
	PetRole.answer(yes)
	close()
