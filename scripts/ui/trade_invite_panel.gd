extends "res://scripts/ui/game_panel.gd"
## Gelen takas teklifi: Kabul / Reddet.

var from_id := 0
var from_name := ""


func _ready() -> void:
	build("Takas Teklifi", Vector2(440, 0))
	var l := add_label(body, "%s seninle takas yapmak istiyor." % from_name, 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_label(body, "Takasta iki taraf da ne verdiğini görür; ikiniz de onaylamadan hiçbir şey el değiştirmez.", 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	add_button(row, "Kabul et", _answer.bind(true)).custom_minimum_size = Vector2(150, 42)
	add_button(row, "Reddet", _answer.bind(false)).custom_minimum_size = Vector2(120, 42)


func _answer(yes: bool) -> void:
	Trade.respond(from_id, yes)
	close()
