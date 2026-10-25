extends "res://scripts/ui/game_panel.gd"
## Okul: kurslar, sınav ve diplomalar.

var box: VBoxContainer
var _answers: Array = []


func _ready() -> void:
	build("Okul — Kurslar", Vector2(660, 0))
	add_label(body, "Kurs ücretini öde, 5 soruluk sınavda en az %d doğru yap, diplomanı al. Diplomalar kalıcı bonus verir." % School.PASS, 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	School.changed.connect(_list)
	School.exam.connect(_show_exam)
	School.result.connect(_show_result)
	_list()


func _list() -> void:
	if not School.current.is_empty():
		return
	for c in box.get_children():
		c.queue_free()
	add_label(box, "Diplomaların: %d / %d" % [School.diplomas.size(), School.COURSES.size()], 16, Color("#facc15"))
	for k in School.COURSES:
		var c: Dictionary = School.COURSES[k]
		var r := HBoxContainer.new()
		box.add_child(r)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		r.add_child(v)
		add_label(v, ("🎓 " if School.has(k) else "") + c.name, 16, Settings.ok_text() if School.has(k) else Color.WHITE)
		add_label(v, "Bonus: " + c.perk, 13, Color("#94a3b8"))
		if School.has(k):
			add_label(r, "Diploma ✓", 14, Settings.ok_text())
		else:
			buy_button(r, int(c.fee), School.start_exam.bind(k), 0, "Sınava gir")


func _show_exam(d: Dictionary) -> void:
	for c in box.get_children():
		c.queue_free()
	_answers = []
	add_label(box, "%s — Sınav" % d.name, 19, Color("#facc15"))
	for i in d.qs.size():
		_answers.append(-1)
		var q: Dictionary = d.qs[i]
		add_label(box, "%d. %s" % [i + 1, q.q], 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var group := ButtonGroup.new()
		for j in q.opts.size():
			var cb := CheckBox.new()
			cb.text = str(q.opts[j])
			cb.button_group = group
			cb.toggled.connect(func(on): if on: _answers[i] = j)
			box.add_child(cb)
	add_button(box, "Sınavı bitir", func(): School.answer(_answers)).custom_minimum_size = Vector2(0, 40)


func _show_result(d: Dictionary) -> void:
	for c in box.get_children():
		c.queue_free()
	var l := add_label(box, str(d.text), 17, Settings.ok_text() if d.ok else Settings.bad_text())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Sfx.play("success" if d.ok else "error")
	add_button(box, "Kurslara dön", _list)
