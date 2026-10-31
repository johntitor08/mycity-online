extends Node
## İlk girişte eğitim turu: ekranın üstünde küçük, engellemeyen bir rehber kutusu.
## Adımlar oyuncu ilgili şeyi yaptıkça ilerler (note ile bildirilir). Ayarlar'dan yeniden başlatılabilir.

const STEPS := [
	["move", "Hoş geldin! {walk} ile yürü."],
	["panel", "Binalara yaklaşıp {interact} tuşuna bas. Hastane ve Market ana yolun kuzeyinde."],
	["map", "{map} tuşuyla haritayı aç: bir yere tıkla, kırmızı yön oku seni oraya götürsün."],
	["job", "Para kazan: Hastane'de doktorluk ya da Market'te kasiyerlik yap (ya da iskelede balık tut)."],
	["talk", "Başında \"!\" olan Muhtar Rıza'ya git, {interact} ile konuş: hikâye görevleri seni yönlendirir."],
	["done", "Harika! Takıldığında sol üstteki \"Rehber\" butonuna bas: para kazanma, ulaşım, ev ve arkadaşlarla oynama hepsi orada. İyi eğlenceler!"],
]

var step := -1
var box: PanelContainer
var label: Label


func active() -> bool:
	return step >= 0 and box != null and is_instance_valid(box)


## Dünya sahnesi açılınca çağrılır: eğitim bitmemişse kutuyu göster.
func start(layer: CanvasLayer, force: bool = false) -> void:
	if Settings.tutorial_done and not force:
		return
	step = 0
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.16, 0.32, 0.93)
	sb.border_color = Color("#facc15")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = 100
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	box.add_child(h)
	var icon := Label.new()
	icon.text = "?"
	icon.add_theme_font_size_override("font_size", 26)
	icon.add_theme_color_override("font_color", Color("#facc15"))
	h.add_child(icon)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	h.add_child(label)
	var skip := Button.new()
	skip.text = "Atla"
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(finish)
	h.add_child(skip)
	_show()


func _text(t: String) -> String:
	# 2.1: telefonda tuş yerine dokunmatik düğme adları
	var touch := Settings.touch_enabled()
	t = t.replace("{walk}", "Sol alttaki joystick" if touch else "%s%s%s%s (ya da ok tuşları)" % [Settings.key_name("up"), Settings.key_name("left"),
		Settings.key_name("down"), Settings.key_name("right")])
	for a in Settings.ACTIONS:
		var nm: String = Settings.key_name(a)
		if touch:
			nm = {"interact": "E düğmesi", "map": "Harita düğmesi", "vehicle": "F düğmesi", "action": "G düğmesi"}.get(a, nm)
		t = t.replace("{%s}" % a, nm)
	return t


func _show() -> void:
	if not active():
		return
	label.text = "Eğitim %d/%d — %s" % [step + 1, STEPS.size(), _text(STEPS[step][1])]
	if STEPS[step][0] == "done":
		get_tree().create_timer(9.0).timeout.connect(finish)


## Oyuncu bir şey yaptı: o anki adımın şartıysa ilerle.
func note(kind: String) -> void:
	if not active():
		return
	if STEPS[step][0] == kind:
		step += 1
		Sfx.play("success", -8.0)
		_show()


func finish() -> void:
	Settings.tutorial_done = true
	Settings.save()
	step = -1
	if box != null and is_instance_valid(box):
		box.queue_free()
	box = null
