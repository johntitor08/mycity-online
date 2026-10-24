extends "res://scripts/ui/game_panel.gd"
## Klan penceresi: klan kur / katıl, üyeler, başvurular, ortak kasa ve klanlar arası sıralama.

var mine_box: VBoxContainer
var rank_box: VBoxContainer
var name_edit: LineEdit
var tag_edit: LineEdit
var amount: SpinBox
var create_btn: Button


func _ready() -> void:
	build("Klanlar", Vector2(940, 560))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(h)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(440, 470)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(left_scroll)
	mine_box = VBoxContainer.new()
	mine_box.add_theme_constant_override("separation", 8)
	mine_box.size_flags_horizontal = SIZE_EXPAND_FILL
	left_scroll.add_child(mine_box)
	h.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(right)
	add_label(right, "Klan Sıralaması", 19, Color("#facc15"))
	add_label(right, "Puan: üyelerin kazandığı XP'nin onda biri + etkinlik ödülleri.", 12, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rs := ScrollContainer.new()
	rs.size_flags_vertical = SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	rank_box = VBoxContainer.new()
	rank_box.size_flags_horizontal = SIZE_EXPAND_FILL
	rank_box.add_theme_constant_override("separation", 4)
	rs.add_child(rank_box)
	Clans.changed.connect(_refresh)
	Net.roster_changed.connect(_update_create)
	_refresh()


func _refresh() -> void:
	_refresh_mine()
	for c in rank_box.get_children():
		c.queue_free()
	if Clans.ranking.is_empty():
		add_label(rank_box, "Henüz klan yok. İlkini sen kur!", 15, Color("#7c859e"))
	var my_tag := str(Clans.mine.get("tag", ""))
	for i in Clans.ranking.size():
		var c: Dictionary = Clans.ranking[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rank_box.add_child(row)
		var col := Color("#facc15") if i == 0 else (Color("#86efac") if c.tag == my_tag else Color.WHITE)
		var l := add_label(row, "%d. [%s] %s" % [i + 1, c.tag, c.name], 15, col)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		l.clip_text = true
		add_label(row, "Sv.%d · %d üye · %d puan" % [int(c.level), int(c.members), int(c.points)], 13, Color("#94a3b8"))
		if my_tag == "":
			var b := add_button(row, "Katıl" if c.open else "Başvur", Clans.join.bind(str(c.tag)))
			b.disabled = int(c.members) >= Clans.MAX_MEMBERS


## Para/seviye değişince sadece "Kur" butonunu güncelle (yazılan isim silinmesin).
func _update_create() -> void:
	if create_btn != null and is_instance_valid(create_btn):
		update_buy_button(create_btn, Clans.CREATE_COST, Clans.CREATE_LEVEL, "Klanı Kur")


func _refresh_mine() -> void:
	var m := Clans.mine
	if m.is_empty() and create_btn != null and is_instance_valid(create_btn):
		_update_create()
		return
	for c in mine_box.get_children():
		c.queue_free()
	create_btn = null
	if m.is_empty():
		_build_create()
		return
	add_label(mine_box, "[%s] %s" % [m.tag, m.name], 24, Color(m.color))
	add_label(mine_box, "Klan seviyesi %d  •  %d puan  •  Üyelere maaş bonusu +%%%d" % [int(m.level), int(m.points),
		int(round(Clans.level_bonus(int(m.level)) * 100))], 14, Color("#cbd5e1"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.value = 100.0 * (int(m.points) - int(m.cur)) / maxi(1, int(m.next) - int(m.cur))
	mine_box.add_child(bar)
	var leader: bool = m.leader == Net.my_name
	# kasa
	add_label(mine_box, "Ortak kasa: %s" % U.money(int(m.bank)), 18, Color("#86efac"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	mine_box.add_child(row)
	amount = add_spin(row, 0, 1000000, 50, 500)
	add_button(row, "Yatır", func(): Clans.deposit(int(amount.value)))
	if leader:
		add_button(row, "Çek", func(): Clans.withdraw(int(amount.value)))
	# üyeler
	add_label(mine_box, "Üyeler (%d/%d)" % [m.members.size(), Clans.MAX_MEMBERS], 17, Color("#93c5fd"))
	for mem in m.members:
		var r := HBoxContainer.new()
		mine_box.add_child(r)
		var l := add_label(r, "%s %s%s" % ["●" if mem.online else "○", mem.name, "  (lider)" if mem.leader else ""], 15,
			Color("#86efac") if mem.online else Color("#94a3b8"))
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		if leader and not mem.leader:
			add_button(r, "Çıkar", Clans.kick.bind(str(mem.name)))
	if leader:
		var o := CheckBox.new()
		o.text = "Herkes başvurusuz katılabilsin"
		o.button_pressed = bool(m.open)
		o.toggled.connect(Clans.set_open)
		mine_box.add_child(o)
		if not m.requests.is_empty():
			add_label(mine_box, "Başvurular", 17, Color("#fde68a"))
			for req in m.requests:
				var r := HBoxContainer.new()
				mine_box.add_child(r)
				add_label(r, str(req), 15).size_flags_horizontal = SIZE_EXPAND_FILL
				add_button(r, "Kabul", Clans.accept.bind(str(req), true))
				add_button(r, "Reddet", Clans.accept.bind(str(req), false))
	add_label(mine_box, "Klan sohbeti: mesajın başına /k yaz ya da sohbet kanalını \"Klan\" yap.", 13, Color("#7c859e")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_button(mine_box, "Klandan Ayrıl", Clans.leave)


func _build_create() -> void:
	add_label(mine_box, "Bir klanda değilsin.", 20, Color("#cbd5e1"))
	add_label(mine_box, "Sağdaki listeden bir klana katıl ya da kendi klanını kur. Klan üyeleri ortak kasa kullanır, klan seviyesi atladıkça herkesin iş maaşı artar.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mine_box.add_child(HSeparator.new())
	add_label(mine_box, "Yeni klan kur", 18, Color("#facc15"))
	var r1 := HBoxContainer.new()
	mine_box.add_child(r1)
	add_label(r1, "İsim:", 15).custom_minimum_size = Vector2(70, 0)
	name_edit = LineEdit.new()
	name_edit.max_length = 20
	name_edit.placeholder_text = "ör. Boğaz Kartalları"
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	r1.add_child(name_edit)
	var r2 := HBoxContainer.new()
	mine_box.add_child(r2)
	add_label(r2, "Etiket:", 15).custom_minimum_size = Vector2(70, 0)
	tag_edit = LineEdit.new()
	tag_edit.max_length = 4
	tag_edit.placeholder_text = "2-4 harf, ör. BGZ"
	tag_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	r2.add_child(tag_edit)
	create_btn = buy_button(mine_box, Clans.CREATE_COST, func(): Clans.create(name_edit.text, tag_edit.text), Clans.CREATE_LEVEL, "Klanı Kur")
