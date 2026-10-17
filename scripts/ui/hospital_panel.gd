extends "res://scripts/ui/game_panel.gd"
## Hastane acil servisi: hastanın belirtisine göre doğru tedaviyi seç.

var patient_label: Label
var symptom_label: Label
var options: GridContainer
var bar: ProgressBar
var result_label: Label
var stats_label: Label
var start_btn: Button
var _deadline := 0.0
var _total := 1.0
var _active := false
var _earned := 0
var _treated := 0


func _ready() -> void:
	build("Hastane — Acil Servis", Vector2(700, 480))
	add_label(body, "Doktor olarak çalış: belirtileri oku, doğru tedaviyi seç. Hızlı olursan daha çok kazanırsın, yanlış tedavi ceza getirir.", 15, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	patient_label = add_label(body, "", 18, Color("#facc15"))
	symptom_label = add_label(body, "Vardiyaya başlamak için butona bas.", 24)
	symptom_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	symptom_label.custom_minimum_size = Vector2(0, 70)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	body.add_child(bar)
	options = GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 10)
	options.add_theme_constant_override("v_separation", 10)
	body.add_child(options)
	result_label = add_label(body, "", 18)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label = add_label(body, "", 15, Color("#94a3b8"))
	start_btn = add_button(body, "Vardiyaya Başla", _next)
	Jobs.hospital_case.connect(_on_case)
	Jobs.job_result.connect(_on_result)


func _next() -> void:
	start_btn.visible = false
	Jobs.ask_hospital()


func _on_case(d: Dictionary) -> void:
	start_btn.visible = false
	patient_label.text = "Hasta: %s" % d.patient
	symptom_label.text = d.symptom
	result_label.text = ""
	for c in options.get_children():
		c.queue_free()
	for i in d.options.size():
		var b := add_button(options, d.options[i], _answer.bind(i))
		b.custom_minimum_size = Vector2(320, 52)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_total = float(d.time)
	_deadline = Time.get_ticks_msec() / 1000.0 + _total
	_active = true


func _answer(i: int) -> void:
	if not _active:
		return
	_active = false
	for c in options.get_children():
		c.disabled = true
	Jobs.answer_hospital(i)


func _process(_delta: float) -> void:
	if not _active:
		return
	var left := _deadline - Time.get_ticks_msec() / 1000.0
	bar.value = clampf(left / _total * 100.0, 0.0, 100.0)
	if left <= 0.0:
		_answer(-1)


func _on_result(d: Dictionary) -> void:
	if d.job != "hospital":
		return
	result_label.text = d.text
	result_label.add_theme_color_override("font_color", Color("#86efac") if d.ok else Color("#fca5a5"))
	Sfx.play("success" if d.ok else "error", -4.0)
	_earned += int(d.pay)
	if d.ok:
		_treated += 1
	stats_label.text = "Bu vardiya: %d hasta iyileştirdin, net kazanç %s" % [_treated, U.money(_earned)]
	later(1.6, _next)
