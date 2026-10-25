extends "res://scripts/ui/game_panel.gd"
## Karakter Kartı: seviye, enerji, meslek yetenekleri, günlük görevler, çanta ve aletler.

var head: Label
var xp_bar: ProgressBar
var xp_label: Label
var energy_bar: ProgressBar
var energy_label: Label
var skills_grid: GridContainer
var quests_box: VBoxContainer
var items_box: HFlowContainer
var tools_label: RichTextLabel


func _ready() -> void:
	build("Karakter Kartı", Vector2(860, 560))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	body.add_child(top)
	head = add_label(top, "", 30, Color("#facc15"))
	head.custom_minimum_size = Vector2(170, 0)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(bars)
	xp_label = add_label(bars, "", 14, Color("#cbd5e1"))
	xp_bar = _bar(bars, Color("#facc15"))
	energy_label = add_label(bars, "", 14, Color("#cbd5e1"))
	energy_bar = _bar(bars, Color("#22c55e"))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(left)
	add_label(left, "Meslek Yetenekleri", 19, Color("#93c5fd"))
	skills_grid = GridContainer.new()
	skills_grid.columns = 3
	skills_grid.add_theme_constant_override("h_separation", 12)
	skills_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(skills_grid)
	left.add_child(HSeparator.new())
	add_label(left, "Günlük Görevler (her biri +%s, +%d XP)" % [U.money(Rpg.QUEST_MONEY), Rpg.QUEST_XP], 19, Color("#93c5fd"))
	quests_box = VBoxContainer.new()
	left.add_child(quests_box)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(290, 0)
	cols.add_child(right)
	add_label(right, "Çanta (tıkla: ye)", 19, Color("#93c5fd"))
	items_box = HFlowContainer.new()
	right.add_child(items_box)
	right.add_child(HSeparator.new())
	add_label(right, "Aletler", 19, Color("#93c5fd"))
	tools_label = add_rich(right, 14)
	right.add_child(HSeparator.new())
	add_label(right, "Kilitler: deniz balıkçılığı Sv.%d, villa Sv.%d, gökdelen Sv.%d" % [
		Rpg.LEVEL_GATES.sea, Rpg.LEVEL_GATES.villa, Rpg.LEVEL_GATES.tower], 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	Rpg.sheet_changed.connect(_refresh)
	Rpg.refresh()
	_refresh()


func _bar(parent: Node, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func _refresh() -> void:
	var s := Rpg.sheet
	if s.is_empty():
		head.text = "..."
		return
	head.text = "Seviye %d" % s.level
	var span := maxi(1, int(s.next) - int(s.cur))
	xp_bar.value = 100.0 * (int(s.xp) - int(s.cur)) / span
	xp_label.text = "XP: %d / %d  (sonraki seviyeye %d)" % [s.xp, s.next, int(s.next) - int(s.xp)]
	energy_bar.value = 100.0 * float(s.energy) / float(s.max_energy)
	energy_label.text = "Enerji: %d / %d  %s" % [int(s.energy), s.max_energy,
		"(plajda: 3 kat hızlı doluyor)" if s.get("regen_beach", false) else "(20 sn'de 1 dolar, plajda 3 kat)"]

	for c in skills_grid.get_children():
		c.queue_free()
	for k in Rpg.SKILLS:
		var sk: Dictionary = s.skills[k]
		add_label(skills_grid, "%s  Sv.%d" % [Rpg.SKILLS[k], sk.level], 16)
		var b := _bar(skills_grid, Color("#60a5fa"))
		b.custom_minimum_size = Vector2(110, 10)
		b.size_flags_vertical = SIZE_SHRINK_CENTER
		b.value = 100.0 * (int(sk.xp) - int(sk.cur)) / maxi(1, int(sk.next) - int(sk.cur))
		add_label(skills_grid, Rpg.SKILL_PERKS[k], 12, Color("#94a3b8"))

	for c in quests_box.get_children():
		c.queue_free()
	for q in s.quests:
		var done: bool = q.done
		add_label(quests_box, "%s  %s  (%d/%d)" % ["✓" if done else "•", q.name, q.progress, q.goal], 16,
			Color("#86efac") if done else Color.WHITE)

	for c in items_box.get_children():
		c.queue_free()
	if s.items.is_empty():
		add_label(items_box, "Çanta boş. Marketten yiyecek alabilirsin.", 14, Color("#7c859e"))
	for item in s.items:
		var f: Dictionary = Rpg.food_info(item)
		if f.is_empty():
			continue
		add_button(items_box, "%s ×%d (+%d)" % [f.name, s.items[item], f.energy], Rpg.use.bind(item))

	var t := ""
	for tool in Rpg.TOOLS:
		var owned: bool = s.tools.has(tool)
		t += "[color=%s]%s %s[/color] — %s\n" % ["#86efac" if owned else "#64748b", "✓" if owned else "✗",
			Rpg.TOOLS[tool].name, Rpg.TOOLS[tool].desc]
	tools_label.text = t + "[color=#7c859e]Aletler markette satılır.[/color]"
