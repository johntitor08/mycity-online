extends "res://scripts/ui/game_panel.gd"
## Evcil hayvan: Pet Shop'ta satın al ve mama al; besleme ve isim değiştirme her yerden.

var mine_box: VBoxContainer
var shop_box: VBoxContainer
var name_edit: LineEdit
var _buy_buttons := {}


func _ready() -> void:
	build("Pet Shop — Evcil Hayvanlar", Vector2(700, 0))
	mine_box = VBoxContainer.new()
	mine_box.add_theme_constant_override("separation", 8)
	body.add_child(mine_box)
	body.add_child(HSeparator.new())
	add_label(body, "Sahiplen (Pet Shop'ta). Mutlu (tok) hayvan bonus verir; aç kalırsa bonus durur.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money_hint(body)
	var row := HBoxContainer.new()
	body.add_child(row)
	add_label(row, "İsim:", 16)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "ör. Pamuk"
	name_edit.max_length = 14
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_edit)
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 6)
	body.add_child(shop_box)
	for k in Pets.PETS:
		var p: Dictionary = Pets.PETS[k]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		shop_box.add_child(h)
		var icon := TextureRect.new()
		var at := AtlasTexture.new()       # sayfanın sadece ilk karesi
		at.atlas = load("res://assets/pets/%s.svg" % k)
		at.region = Rect2(0, 0, 80, 64)
		icon.texture = at
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(80, 32)
		h.add_child(icon)
		var l := add_label(h, "%s — %s" % [p.name, p.desc], 15)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		_buy_buttons[k] = buy_button(h, int(p.price), func(): Pets.buy(k, name_edit.text), int(p.level), "Sahiplen")
	Pets.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	Rpg.sheet_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in mine_box.get_children():
		c.queue_free()
	var pet := Pets.my_pet
	if pet.is_empty():
		add_label(mine_box, "Henüz bir evcil hayvanın yok.", 17, Color("#cbd5e1"))
	else:
		var info: Dictionary = Pets.PETS[pet.kind]
		var happy := float(pet.food) >= Pets.HAPPY_AT
		add_label(mine_box, "%s (%s) — %s" % [pet.name, info.name, "mutlu, bonus aktif" if happy else "aç! bonus durdu"], 19,
			Color("#86efac") if happy else Color("#fca5a5"))
		var bar := ProgressBar.new()
		bar.value = float(pet.food)
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		mine_box.add_child(bar)
		add_label(mine_box, "Tokluk %d/100  •  Mama: %d kutu  •  %s" % [int(pet.food), int(pet.cans), info.desc], 14, Color("#94a3b8"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		mine_box.add_child(h)
		add_button(h, "Mama ver (+%d)" % Pets.FOOD_PER_CAN, func(): Pets.feed(false)).disabled = int(pet.cans) <= 0
		if info.fish:
			add_button(h, "Balık ver (+%d)" % Pets.FOOD_PER_FISH, func(): Pets.feed(true)).disabled = Jobs.my_fish.is_empty()
		buy_button(h, Pets.FOOD_PRICE * 5, func(): Pets.buy_food(5), 0, "5 mama al")
		add_button(h, "İsmi değiştir", func(): Pets.rename(name_edit.text))
		add_button(h, "Sahiplendir", Pets.release)
	for k in _buy_buttons:
		update_buy_button(_buy_buttons[k], int(Pets.PETS[k].price), int(Pets.PETS[k].level), "Sahiplen")
		_buy_buttons[k].disabled = _buy_buttons[k].disabled or not pet.is_empty()
