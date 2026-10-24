extends "res://scripts/ui/game_panel.gd"
## Muhtarlık: hikâye görev günlüğü (tamamlanan, şu anki ve sıradaki görevler) ve belediye seçimi.

const Map = preload("res://scripts/map.gd")

var list: VBoxContainer
var quests: VBoxContainer
var town: VBoxContainer
var slogan: LineEdit
var tax_spin: SpinBox
var _tick := 0.0
var _tab := "quests"


func _ready() -> void:
	build("Muhtarlık", Vector2(700, 520))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	add_button(tabs, "Görev Günlüğü", _show.bind("quests")).custom_minimum_size = Vector2(160, 36)
	add_button(tabs, "Belediye Seçimi", _show.bind("town")).custom_minimum_size = Vector2(160, 36)
	body.add_child(HSeparator.new())
	quests = VBoxContainer.new()
	quests.add_theme_constant_override("separation", 6)
	body.add_child(quests)
	town = VBoxContainer.new()
	town.add_theme_constant_override("separation", 8)
	body.add_child(town)
	add_label(quests, "Görevleri şehirdeki kişiler verir; başlarında \"!\" olanla konuş (yanına git, E). \"?\" ödülün hazır demek.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	quests.add_child(list)
	Story.changed.connect(_refresh)
	Election.changed.connect(_refresh_town)
	_refresh()
	_show(_tab)


func _show(t: String) -> void:
	_tab = t
	quests.visible = t == "quests"
	town.visible = t == "town"
	_refresh_town()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0 and town.visible:
		_tick = 0.0
		_refresh_town(true)


const PHASES := {"apply": "Aday başvuruları", "vote": "Oylama", "term": "Görev dönemi (yeni seçime kadar)"}


## soft: sadece süreyi güncelle (yazılan sloganı silme)
func _refresh_town(soft: bool = false) -> void:
	var st := Election.state
	if soft and town.get_child_count() > 0:
		var lbl := town.get_child(0) as Label
		if lbl:
			var left := Election.time_left()
			lbl.text = "%s — %d:%02d kaldı" % [PHASES.get(st.get("phase", ""), ""), int(left) / 60, int(left) % 60]
		return
	for c in town.get_children():
		c.queue_free()
	if st.is_empty():
		add_label(town, "...", 16)
		return
	var left := Election.time_left()
	add_label(town, "%s — %d:%02d kaldı" % [PHASES.get(st.phase, ""), int(left) / 60, int(left) % 60], 20, Color("#facc15"))
	var mayor: String = st.mayor if str(st.mayor) != "" else "%s (vekil)" % Election.ACTING
	add_label(town, "Belediye Başkanı: %s  •  Vergi: %%%d  •  Belediye kasası: %s" % [mayor, int(st.tax), U.money(int(st.treasury))], 15, Color("#cbd5e1"))
	add_label(town, "Vergi kira ve işletme satışlarından kesilir. Başkan vergiyi belirler, dönemde bir kez kasayı herkese hibe olarak dağıtır, etkinlik başlatır ve kasadan maaş alır. Seçim 90 dakikada bir yapılır.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	town.add_child(HSeparator.new())
	var cands: Array = st.get("candidates", [])
	match str(st.phase):
		"apply":
			if not st.candidate:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				town.add_child(row)
				slogan = LineEdit.new()
				slogan.placeholder_text = "Seçim sloganın (ör. Her eve bir tekne!)"
				slogan.max_length = 60
				slogan.size_flags_horizontal = SIZE_EXPAND_FILL
				row.add_child(slogan)
				buy_button(row, Election.CANDIDATE_FEE, func(): Election.apply(slogan.text), Election.CANDIDATE_LEVEL, "Aday Ol")
			else:
				add_label(town, "Adaysın! Oylama başlayınca oy iste.", 15, Color("#86efac"))
			add_label(town, "Adaylar (%d)" % cands.size(), 17, Color("#93c5fd"))
			for c in cands:
				add_label(town, "• %s — \"%s\"" % [c.name, c.slogan], 15)
		"vote":
			add_label(town, "Oyunu kullan%s" % (" (kullandın, teşekkürler!)" if st.voted else ":"), 17, Color("#93c5fd"))
			if cands.is_empty():
				add_label(town, "Bu seçimde aday yok; mevcut başkan görevine devam edecek.", 14, Color("#7c859e"))
			for c in cands:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				town.add_child(row)
				var l := add_label(row, "%s — \"%s\"" % [c.name, c.slogan], 15)
				l.size_flags_horizontal = SIZE_EXPAND_FILL
				var b := add_button(row, "Oy ver", Election.vote.bind(str(c.name)))
				b.disabled = bool(st.voted) or int(Rpg.sheet.get("level", 1)) < Election.VOTE_LEVEL
		"term":
			add_label(town, "Yeni seçim döneminde aday olabilirsin (Sv.%d, %s)." % [Election.CANDIDATE_LEVEL, U.money(Election.CANDIDATE_FEE)], 14, Color("#94a3b8"))
	if Election.is_mayor():
		town.add_child(HSeparator.new())
		add_label(town, "Başkanlık Makamı", 19, Color("#facc15"))
		var r1 := HBoxContainer.new()
		r1.add_theme_constant_override("separation", 8)
		town.add_child(r1)
		add_label(r1, "Vergi oranı %:", 15)
		tax_spin = add_spin(r1, 0, Election.MAX_TAX, 1, int(st.tax))
		add_button(r1, "Uygula", func(): Election.set_tax(int(tax_spin.value)))
		var g := add_button(r1, "Hibe dağıt (kasa ÷ çevrimiçi)", Election.give_grant)
		g.disabled = bool(st.grant_used) or int(st.treasury) <= 0
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 8)
		town.add_child(r2)
		var wait := float(st.get("event_in", 0.0))
		add_label(r2, "Etkinlik başlat:" if wait <= 0.0 else "Etkinlik (%d dk sonra):" % int(ceil(wait / 60.0)), 15)
		for k in Events.KINDS:
			add_button(r2, Events.KINDS[k].name, Election.start_event.bind(k)).disabled = wait > 0.0


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
