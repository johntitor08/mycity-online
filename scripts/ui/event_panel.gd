extends "res://scripts/ui/game_panel.gd"
## Etkinlikler: şu anki etkinlik ve sıralaması, sıradaki etkinlik, yarış pisti (tur başlat, rekorlar).

const Map = preload("res://scripts/map.gd")

var at_track := false             # damalı bayrağın yanında açıldıysa yarış başlatılabilir
var cur_box: VBoxContainer
var rec_box: VBoxContainer
var race_label: Label
var start_btn: Button
var _tick := 0.0


func _ready() -> void:
	build("Etkinlikler ve Yarış Pisti", Vector2(760, 520))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(h)
	cur_box = VBoxContainer.new()
	cur_box.custom_minimum_size = Vector2(380, 0)
	cur_box.add_theme_constant_override("separation", 6)
	h.add_child(cur_box)
	h.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	add_label(right, "Yarış Pisti", 20, Color("#facc15"))
	add_label(right, "Ana yolun doğu ucundaki damalı bayraktan başla: batı ucu → güneydeki yolun sonu → doğu yolu → bitiş. Araçla daha hızlısın! Tur başına (2 dk'da bir) %s ve %d XP." % [U.money(Events.LAP_REWARD), Events.LAP_XP], 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	race_label = add_label(right, "", 16, Color("#86efac"))
	start_btn = add_button(right, "Tur Başlat", _start)
	start_btn.custom_minimum_size = Vector2(0, 40)
	add_label(right, "Pist Rekorları", 17, Color("#93c5fd"))
	rec_box = VBoxContainer.new()
	rec_box.add_theme_constant_override("separation", 2)
	right.add_child(rec_box)
	Events.changed.connect(_refresh)
	Events.race_changed.connect(_refresh_race)
	_refresh()


func _start() -> void:
	Events.race_start()
	close()


func _refresh() -> void:
	for c in cur_box.get_children():
		c.queue_free()
	var cur := Events.current
	if cur.is_empty():
		add_label(cur_box, "Şu an etkinlik yok.", 20, Color("#cbd5e1"))
		if Events.next_kind != "":
			var left := maxf(0.0, Events.next_at - Events.local_now())
			add_label(cur_box, "Sıradaki: %s — %d:%02d sonra" % [Events.KINDS[Events.next_kind].name, int(left) / 60, int(left) % 60], 16, Color("#fde68a"))
			add_label(cur_box, Events.KINDS[Events.next_kind].desc, 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var left := maxf(0.0, Events.current_ends - Events.local_now())
		add_label(cur_box, str(cur.name), 24, Color("#facc15"))
		add_label(cur_box, "Kalan süre: %d:%02d" % [int(left) / 60, int(left) % 60], 16, Color("#fde68a"))
		add_label(cur_box, str(cur.desc), 14, Color("#cbd5e1")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if cur.kind in ["race", "fish", "snow", "harvest", "beach"]:
			add_label(cur_box, "Ödüller: 1. %s · 2. %s · 3. %s (+XP, +klan puanı)" % [U.money(Events.PRIZES[0]), U.money(Events.PRIZES[1]), U.money(Events.PRIZES[2])], 13, Color("#94a3b8"))
			add_label(cur_box, "Sıralama", 17, Color("#93c5fd"))
			var st: Array = cur.get("standings", [])
			if st.is_empty():
				add_label(cur_box, "Henüz derece yok.", 14, Color("#7c859e"))
			for i in st.size():
				add_label(cur_box, "%d. %s — %s" % [i + 1, st[i].name, st[i].text], 15, Color("#86efac") if st[i].name == Net.my_name else Color.WHITE)
		elif cur.kind == "treasure":
			add_label(cur_box, "Ödül: %s. Harita üzerindeki sarı daire arama alanıdır; yaklaşınca sandık parlar." % U.money(Events.TREASURE_PRIZE), 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in rec_box.get_children():
		c.queue_free()
	if Events.records.is_empty():
		add_label(rec_box, "Henüz rekor yok.", 14, Color("#7c859e"))
	for i in Events.records.size():
		var r: Dictionary = Events.records[i]
		var ride := str(Garage.VEHICLES[r.ride].name) if Garage.VEHICLES.has(str(r.get("ride", ""))) else "yaya"
		add_label(rec_box, "%d. %s — %.2f sn (%s)" % [i + 1, r.name, float(r.time), ride], 14, Color("#facc15") if i == 0 else (Color("#86efac") if r.name == Net.my_name else Color.WHITE))
	_refresh_race()


func _refresh_race() -> void:
	var st := str(Events.race.get("state", ""))
	start_btn.disabled = not at_track or st in ["countdown", "running"]
	if not at_track:
		start_btn.text = "Başlamak için damalı bayrağa git"
	elif st in ["countdown", "running"]:
		start_btn.text = "Yarıştasın"
	else:
		start_btn.text = "Tur Başlat"
	if st == "finished":
		race_label.text = "Son tur: %.2f sn  •  En iyin: %.2f sn%s" % [float(Events.race.last), float(Events.race.best), "  — REKOR!" if Events.race.get("record", false) else ""]
	elif float(Events.race.get("best", 0.0)) > 0.0:
		race_label.text = "En iyi turun: %.2f sn" % float(Events.race.best)
	else:
		race_label.text = ""


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_refresh()
