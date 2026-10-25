extends "res://scripts/ui/game_panel.gd"
## İskele: oltayı at, balık vurunca hemen çek, balıkları sat.

var status: Label
var action_btn: Button
var inv_label: RichTextLabel
var sell_btn: Button
var state := "idle"   # idle, waiting, bite
var spot := "lake"    # dünya sahnesi açarken ayarlar


func _ready() -> void:
	if spot == "island":
		build("Martı Adası İskelesi — Balık Tutma", Vector2(520, 470), true)
		add_label(body, "Açık denizin ortasında: nadir balıkların (orkinos, kılıç balığı, köpekbalığı, hazine sandığı) en çok çıktığı yer!", 15, Color("#fde68a")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif spot == "sea":
		build("Deniz İskelesi — Balık Tutma", Vector2(520, 470), true)
		add_label(body, "Denizde palamut, lüfer, orkinos, kılıç balığı... Şanslıysan köpekbalığı ya da hazine sandığı!", 15, Color("#7dd3fc")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		build("Göl İskelesi — Balık Tutma", Vector2(520, 470), true)
		add_label(body, "Gölde sazan, alabalık, turna, yayın balığı... ve çok nadir Altın Balık.", 15, Color("#86efac")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_label(body, "Oltayı at, mantar batınca (BALIK VURDU!) hemen ÇEK. Erken çekersen balık ürker.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status = add_label(body, "Olta hazır.", 26, Color("#e2e8f0"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size = Vector2(0, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_btn = add_button(body, "Olta At  (Boşluk)", _on_action)
	action_btn.custom_minimum_size = Vector2(0, 60)
	action_btn.add_theme_font_size_override("font_size", 24)
	body.add_child(HSeparator.new())
	add_label(body, "Kova (en fazla %d balık)" % Jobs.BAG_SIZE, 17, Color("#facc15"))
	inv_label = add_rich(body, 15, 90)
	sell_btn = add_button(body, "Hepsini Sat", Jobs.sell_fish)
	Jobs.fish_event.connect(_on_fish)
	Jobs.inventory_changed.connect(_refresh_inv)
	_refresh_inv()
	action_btn.grab_focus.call_deferred()


func _on_action() -> void:
	if state == "idle":
		Jobs.cast()
	else:
		Jobs.reel()


func _set_state(s: String, text: String, color: Color) -> void:
	state = s
	status.text = text
	status.add_theme_color_override("font_color", color)
	match s:
		"idle":
			action_btn.text = "Olta At  (Boşluk)"
		"waiting":
			action_btn.text = "Bekle..."
		"bite":
			action_btn.text = "ÇEK!"


func _process(_delta: float) -> void:
	if state == "bite":
		action_btn.modulate = Color(1, 0.4, 0.4) if int(Time.get_ticks_msec() / 150.0) % 2 == 0 else Color.WHITE
	elif state == "waiting":
		var dots := int(Time.get_ticks_msec() / 400.0) % 4
		status.text = "Olta suda, bekle" + ".".repeat(dots)
		action_btn.modulate = Color.WHITE
	else:
		action_btn.modulate = Color.WHITE


func _on_fish(d: Dictionary) -> void:
	match d.state:
		"cast":
			_set_state("waiting", "Olta suda, bekle", Color("#93c5fd"))
			Sfx.play("splash_small")
		"bite":
			_set_state("bite", "BALIK VURDU! ÇEK!", Color("#f87171"))
			Sfx.play("bite")
		"caught":
			_set_state("idle", "%s yakaladın! (%s)" % [d.fish, U.money(int(d.price))], Color("#86efac"))
			Sfx.play("cash" if int(d.price) >= 500 else "catch")
		"escaped":
			_set_state("idle", "Geç kaldın, balık kaçtı...", Color("#fca5a5"))
			Sfx.play("error", -6.0)
		"early":
			_set_state("idle", "Çok erken çektin, balık ürktü.", Color("#fca5a5"))
			Sfx.play("error", -6.0)


func _refresh_inv() -> void:
	var counts := {}
	var total := 0
	for f in Jobs.my_fish:
		counts[f.name] = counts.get(f.name, 0) + 1
		total += int(f.price)
	if counts.is_empty():
		inv_label.text = "[color=#7c859e]Kova boş.[/color]"
	else:
		var parts: Array = []
		for n in counts:
			parts.append("%s ×%d" % [n, counts[n]])
		inv_label.text = ", ".join(parts) + "\n[color=#86efac]Toplam değer: %s[/color]" % U.money(total)
	sell_btn.text = "Hepsini Sat (%s)" % U.money(total)
	sell_btn.disabled = total == 0
