extends "res://scripts/ui/game_panel.gd"
## Plaj sahası: takım seç, skor ve kurallar.


func _ready() -> void:
	build("Plaj Sahası — Futbol", Vector2(520, 0), true)
	var sc := add_label(body, "", 28, Color("#fde68a"))
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.text = "Kırmızı  %d : %d  Mavi" % [int(Football.score.red), int(Football.score.blue)]
	var t := add_label(body, "Maç süresi: %d:%02d  •  %d gole ulaşan kazanır" % [int(Football.time_left) / 60, int(Football.time_left) % 60, Football.WIN_GOALS], 14, Color("#94a3b8"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var my_team := str(Net.roster.get(Net.my_id(), {}).get("team", ""))
	var r := add_button(row, "Kırmızı takım", _join.bind("red"))
	r.modulate = Color("#fca5a5")
	r.disabled = my_team == "red"
	var b := add_button(row, "Mavi takım", _join.bind("blue"))
	b.modulate = Color("#93c5fd")
	b.disabled = my_team == "blue"
	add_button(row, "Takımdan ayrıl", _join.bind("")).disabled = my_team == ""
	add_label(body, "Topa doğru yürü: değince vurursun (yaya vuruş daha sert). Kırmızı soldaki kaleyi, Mavi sağdakini korur. Kazanan takımdakilere %s. Yazın Plaj Kupası etkinliğinde goller ayrıca sayılır." % U.money(Football.WIN_PRIZE), 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _join(team: String) -> void:
	Football.join(team)
	close()
