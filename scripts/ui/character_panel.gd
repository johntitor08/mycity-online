extends "res://scripts/ui/game_panel.gd"
## Karakter düzenleyici: ten, saç modeli/rengi, tişört ve pantolon rengi.
## Menüde (offline) ya da oyun içinde açılır; önizleme karakteri döner ve yürür.

signal applied(appearance: Dictionary)

const Avatar = preload("res://scripts/avatar.gd")
const ROWS := [["skin", "Ten rengi"], ["hair", "Saç modeli"], ["hair_color", "Saç rengi"],
	["shirt", "Tişört"], ["pants", "Pantolon"]]

var appearance := {}
var offline := false        # true: sadece görünümü döndürür, sunucuya göndermez
var _value_widgets := {}


class Preview extends Control:
	var app := {}
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, 70)
		draw_set_transform(c + Vector2(0, 30), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 50, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		var facing: String = ["down", "right", "up", "left"][int(t / 1.6) % 4]
		var frame: int = [1, 0, 2, 0][int(t * 8.0) % 4]
		Avatar.draw(self, c, app, facing, frame, 3.2)


var preview: Preview


func _ready() -> void:
	if appearance.is_empty():
		appearance = Avatar.default_for(Net.my_name)
	appearance = Avatar.sanitize(appearance)
	build("Karakterini Düzenle", Vector2(640, 420))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	body.add_child(h)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#5d9c4a")
	sb.set_corner_radius_all(12)
	bg.add_theme_stylebox_override("panel", sb)
	bg.custom_minimum_size = Vector2(240, 320)
	h.add_child(bg)
	preview = Preview.new()
	preview.app = appearance
	bg.add_child(preview)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(grid)
	for r in ROWS:
		var key: String = r[0]
		add_label(grid, r[1], 18)
		add_button(grid, "  <  ", _step.bind(key, -1))
		var w: Control
		if key == "hair":
			w = add_label(grid, "", 18, Color("#facc15"))
			w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			w = ColorRect.new()
			grid.add_child(w)
		w.custom_minimum_size = Vector2(110, 34)
		_value_widgets[key] = w
		add_button(grid, "  >  ", _step.bind(key, 1))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	add_button(row, "Rastgele", _randomize)
	var save := add_button(row, "Kaydet", _apply)
	save.custom_minimum_size = Vector2(140, 40)
	_refresh()


func _step(key: String, d: int) -> void:
	var n: int = Avatar.OPTIONS[key].size()
	appearance[key] = (int(appearance[key]) + d + n) % n
	_refresh()


func _randomize() -> void:
	appearance = Avatar.random()
	_refresh()


func _refresh() -> void:
	preview.app = appearance
	for key in _value_widgets:
		var w = _value_widgets[key]
		if key == "hair":
			w.text = Avatar.HAIR_STYLE_NAMES[appearance.hair]
		else:
			w.color = Avatar.OPTIONS[key][appearance[key]]


func _apply() -> void:
	# Bir sonraki girişte de kullanılsın diye yerel ayarlara kaydet.
	var cfg := ConfigFile.new()
	cfg.load("user://ayarlar.cfg")
	cfg.set_value("karakter", "gorunum", appearance)
	cfg.save("user://ayarlar.cfg")
	if not offline:
		Net.set_appearance(appearance)
		Sfx.play("success")
	applied.emit(appearance)
	close()
