extends "res://scripts/ui/game_panel.gd"
## Muhtarlık: hikâye görev günlüğü (tamamlanan, şu anki ve sıradaki görevler).

const Map = preload("res://scripts/map.gd")

var list: VBoxContainer


func _ready() -> void:
	build("Muhtarlık — Görev Günlüğü", Vector2(660, 0))
	add_label(body, "Görevleri şehirdeki kişiler verir; başlarında \"!\" olanla konuş (yanına git, E). \"?\" ödülün hazır demek.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	body.add_child(list)
	Story.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var st := Story.state
	var cur := Story.STEPS.size() if st.get("finished", false) else int(st.get("step", 1)) - 1
	for i in Story.STEPS.size():
		var step: Dictionary = Story.STEPS[i]
		var who: String = Map.NPCS[step.npc].name
		var line := ""
		var col := Color("#64748b")
		if i < cur:
			line = "✓  %s  (%s)" % [step.title, who]
			col = Color("#86efac")
		elif i == cur:
			var prog := ""
			if st.get("accepted", false):
				prog = "  —  %d/%d" % [int(st.get("count", 0)), int(st.get("goal", 1))]
				if st.get("ready", false):
					prog += "  (ödül hazır!)"
			else:
				prog = "  —  %s ile konuş" % who
			line = "▸  %s%s\n     %s" % [step.title, prog, step.hint]
			col = Color("#facc15")
		else:
			line = "•  %s" % step.title
		add_label(list, line, 16, col)
	if st.get("finished", false):
		add_label(list, "Tüm görevleri bitirdin — Şehrin Gururu!", 18, Color("#facc15"))
