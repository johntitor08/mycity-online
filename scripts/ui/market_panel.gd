extends "res://scripts/ui/game_panel.gd"
## Market kasiyeri: sepeti hesapla, müşteriye doğru para üstünü ver.

var receipt: RichTextLabel
var paid_label: Label
var change_edit: LineEdit
var give_btn: Button
var bar: ProgressBar
var result_label: Label
var stats_label: Label
var start_btn: Button
var _deadline := 0.0
var _total := 1.0
var _active := false
var _earned := 0
var _served := 0


func _ready() -> void:
	build("Market — Kasiyer", Vector2(620, 520))
	add_label(body, "Ürünleri kafandan topla, müşterinin verdiği paradan çıkar ve para üstünü gir.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	receipt = add_rich(body, 20, 130)
	paid_label = add_label(body, "", 22, Color("#facc15"))
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	body.add_child(bar)
	var row := HBoxContainer.new()
	body.add_child(row)
	add_label(row, "Para üstü:", 18)
	change_edit = LineEdit.new()
	change_edit.placeholder_text = "TL"
	change_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	change_edit.text_submitted.connect(func(_t): _give())
	change_edit.editable = false
	row.add_child(change_edit)
	give_btn = add_button(row, "Para Üstünü Ver", _give)
	give_btn.disabled = true
	result_label = add_label(body, "", 18)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label = add_label(body, "", 15, Color("#94a3b8"))
	start_btn = add_button(body, "Kasaya Geç", _next)
	Jobs.market_case.connect(_on_case)
	Jobs.job_result.connect(_on_result)


func _next() -> void:
	start_btn.visible = false
	Jobs.ask_market()


func _on_case(d: Dictionary) -> void:
	start_btn.visible = false
	var t := "[b]Müşterinin sepeti:[/b]\n"
	for it in d.items:
		t += "  %d × %s  [color=#94a3b8](tanesi %d TL)[/color]\n" % [it.qty, it.name, it.price]
	receipt.text = t
	paid_label.text = "Müşteri %s verdi." % U.money(int(d.paid))
	result_label.text = ""
	change_edit.text = ""
	change_edit.editable = true
	give_btn.disabled = false
	change_edit.grab_focus()
	_total = float(d.time)
	_deadline = Time.get_ticks_msec() / 1000.0 + _total
	_active = true


func _give() -> void:
	if not _active:
		return
	var txt := change_edit.text.strip_edges()
	if not txt.is_valid_int():
		result_label.text = "Sadece sayı gir."
		result_label.add_theme_color_override("font_color", Color("#fde68a"))
		return
	_send(int(txt))


func _send(value: int) -> void:
	_active = false
	change_edit.editable = false
	give_btn.disabled = true
	Jobs.answer_market(value)


func _process(_delta: float) -> void:
	if not _active:
		return
	var left := _deadline - Time.get_ticks_msec() / 1000.0
	bar.value = clampf(left / _total * 100.0, 0.0, 100.0)
	if left <= 0.0:
		_send(-1)


func _on_result(d: Dictionary) -> void:
	if d.job != "market":
		return
	result_label.text = d.text
	result_label.add_theme_color_override("font_color", Color("#86efac") if d.ok else Color("#fca5a5"))
	Sfx.play("success" if d.ok else "error", -4.0)
	_earned += int(d.pay)
	if d.ok:
		_served += 1
	stats_label.text = "Bu vardiya: %d müşteri, net kazanç %s" % [_served, U.money(_earned)]
	later(1.8, _next)
