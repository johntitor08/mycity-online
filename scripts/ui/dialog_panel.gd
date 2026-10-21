extends "res://scripts/ui/game_panel.gd"
## NPC konuşması: portre, satır satır metin, Kabul et / Ödülü al / Tamam.

const Map = preload("res://scripts/map.gd")
const Avatar = preload("res://scripts/avatar.gd")

var data: Dictionary = {}
var _line := 0
var text_label: Label
var buttons_box: HBoxContainer


class Portrait extends Control:
	var app := {}
	func _draw() -> void:
		Avatar.draw(self, size / 2.0 + Vector2(0, 58), app, "down", 0, 2.4)


func _ready() -> void:
	build(str(data.get("name", "")), Vector2(640, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	body.add_child(h)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#334155")
	sb.set_corner_radius_all(10)
	bg.add_theme_stylebox_override("panel", sb)
	bg.custom_minimum_size = Vector2(130, 170)
	h.add_child(bg)
	var por := Portrait.new()
	por.app = Map.NPCS.get(data.get("npc", ""), {}).get("app", {})
	bg.add_child(por)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	text_label = add_label(v, "", 19)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(440, 110)
	text_label.size_flags_vertical = SIZE_EXPAND_FILL
	buttons_box = HBoxContainer.new()
	buttons_box.alignment = BoxContainer.ALIGNMENT_END
	buttons_box.add_theme_constant_override("separation", 10)
	v.add_child(buttons_box)
	_show_line()


func _show_line() -> void:
	var lines: Array = data.get("lines", [])
	text_label.text = str(lines[_line]) if _line < lines.size() else ""
	for c in buttons_box.get_children():
		c.queue_free()
	if _line < lines.size() - 1:
		add_button(buttons_box, "Devam  ▸", _next).grab_focus.call_deferred()
		return
	for b in data.get("buttons", ["Tamam"]):
		var btn := add_button(buttons_box, b, _choose.bind(b))
		btn.custom_minimum_size = Vector2(120, 38)
	if buttons_box.get_child_count() > 0:
		(buttons_box.get_child(0) as Button).grab_focus.call_deferred()


func _next() -> void:
	_line += 1
	_show_line()


func _choose(b: String) -> void:
	match b:
		"Kabul et":
			Story.accept()
			Sfx.play("success", -4.0)
		"Ödülü al":
			Story.claim()
			Sfx.play("cash", -2.0)
	close()
