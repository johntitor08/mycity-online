extends "res://scripts/ui/game_panel.gd"
## Silahçı (1.8): mağara yanındaki çadır ve zombi gecesinde karakol önündeki savunma merkezi.

var box: VBoxContainer


func _ready() -> void:
	build("Silahçı", Vector2(560, 0))
	money_hint(body)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)
	Combat.changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in box.get_children():
		c.queue_free()
	var me: Dictionary = Combat.my
	var owned: Array = me.get("owned", ["yumruk"])
	add_label(box, "Silahlar", 16, Color("#fde68a"))
	for k in Combat.WEAPONS:
		var w: Dictionary = Combat.WEAPONS[k]
		var row := HBoxContainer.new()
		box.add_child(row)
		add_label(row, "%s — hasar %d%s, %s" % [w.name, int(w.dmg), " (menzilli)" if w.ranged else "", "%.2f sn" % float(w.cd)], 14).size_flags_horizontal = SIZE_EXPAND_FILL
		if k in owned:
			if str(me.get("cur", "")) == k:
				add_label(row, "Elinde ✓", 14, Settings.ok_text())
			else:
				add_button(row, "Kuşan", Combat.equip.bind(k))
		else:
			buy_button(row, int(w.price), Combat.buy.bind(k), int(w.level))
	box.add_child(HSeparator.new())
	var lvl := int(me.get("armor", 0))
	var ar := HBoxContainer.new()
	box.add_child(ar)
	add_label(ar, "Zırh: %s (hasar −%%%d)" % [Combat.ARMOR[lvl].name, lvl * 20], 14).size_flags_horizontal = SIZE_EXPAND_FILL
	if lvl + 1 < Combat.ARMOR.size():
		buy_button(ar, int(Combat.ARMOR[lvl + 1].price), Combat.buy.bind("armor"), 0, Combat.ARMOR[lvl + 1].name)
	var pr := HBoxContainer.new()
	box.add_child(pr)
	add_label(pr, "Can iksiri: %d / %d (+%d can)" % [int(me.get("potions", 0)), Combat.POTION_MAX, int(Combat.POTION_HEAL)], 14).size_flags_horizontal = SIZE_EXPAND_FILL
	if int(me.get("potions", 0)) < Combat.POTION_MAX:
		buy_button(pr, Combat.POTION_PRICE, Combat.buy.bind("potion"))
