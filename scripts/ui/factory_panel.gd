extends "res://scripts/ui/game_panel.gd"
## Fabrika: üretim bandındaki parçayı doğru kutuya ayır (1 Kırmızı, 2 Mavi, 3 Sarı ya da butonlar).

const COLS := [Color("#ef4444"), Color("#3b82f6"), Color("#facc15")]

var belt: Control
var info: Label
var start_btn: Button
var _item := {}                    # {id, color, window, t0}
var _earned := 0
var _sorted := 0


class Belt extends Control:
	var panel_ref
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#374151"))
		var t := Time.get_ticks_msec() / 1000.0
		for k in 14:
			var x := fposmod(k * 50.0 + t * 80.0, size.x + 50) - 25
			draw_line(Vector2(x, 6), Vector2(x, size.y - 6), Color("#4b5563"), 3)
		draw_rect(Rect2(0, 0, size.x, 6), Color("#9ca3af"))
		draw_rect(Rect2(0, size.y - 6, size.x, 6), Color("#9ca3af"))
		var it: Dictionary = panel_ref._item
		if it.is_empty():
			return
		var k := clampf((t - float(it.t0)) / float(it.window), 0.0, 1.0)
		var p := Vector2(20 + k * (size.x - 60), size.y / 2)
		var col: Color = COLS[int(it.color)]
		draw_rect(Rect2(p - Vector2(18, 18), Vector2(36, 36)), col)
		draw_rect(Rect2(p - Vector2(18, 18), Vector2(36, 36)), Color.BLACK, false, 2)
		draw_circle(p, 6, col.lightened(0.4))
		draw_rect(Rect2(size.x - 24, 6, 18, size.y - 12), Color(1, 0.3, 0.3, 0.4 * k))


func _ready() -> void:
	build("Fabrika — Üretim Bandı", Vector2(620, 0))
	add_label(body, "Parça bandın sonuna varmadan doğru kutuya ayır: 1 = Kırmızı, 2 = Mavi, 3 = Sarı. Seri yaptıkça kazanç artar, bant hızlanır.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	belt = Belt.new()
	belt.panel_ref = self
	belt.custom_minimum_size = Vector2(580, 90)
	body.add_child(belt)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	for i in 3:
		var b := add_button(row, "%d  %s" % [i + 1, Factory.COLORS[i]], _bin.bind(i))
		b.custom_minimum_size = Vector2(170, 56)
		b.modulate = COLS[i].lightened(0.3)
	info = add_label(body, "Vardiyaya başlamak için butona bas.", 18)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_btn = add_button(body, "Vardiyaya Başla", _start)
	start_btn.custom_minimum_size = Vector2(0, 40)
	Factory.item.connect(_on_item)
	Factory.result.connect(_on_result)


func _start() -> void:
	start_btn.visible = false
	Factory.start()


func _on_item(d: Dictionary) -> void:
	_item = {"id": int(d.id), "color": int(d.color), "window": float(d.window), "t0": Time.get_ticks_msec() / 1000.0}
	start_btn.visible = false


func _bin(i: int) -> void:
	if _item.is_empty():
		return
	Factory.sort(int(_item.id), i)
	_item = {}


func _on_result(d: Dictionary) -> void:
	_earned += int(d.pay)
	if d.ok:
		_sorted += 1
		Sfx.play("coin", -8.0, 1.2)
	else:
		Sfx.play("error", -8.0)
	info.text = "%s   •   Bu vardiya: %d parça, %s" % [d.text, _sorted, U.money(_earned)]
	info.add_theme_color_override("font_color", Settings.ok_text() if d.ok else Settings.bad_text())
	if d.get("stop", false):
		start_btn.visible = true


func _process(_delta: float) -> void:
	belt.queue_redraw()
	if not _item.is_empty() and Time.get_ticks_msec() / 1000.0 - float(_item.t0) > float(_item.window) + 0.3:
		Factory.sort(int(_item.id), -1)      # süre doldu
		_item = {}


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_1, KEY_KP_1:
				_bin(0)
			KEY_2, KEY_KP_2:
				_bin(1)
			KEY_3, KEY_KP_3:
				_bin(2)


func close() -> void:
	Factory.stop()
	super.close()
