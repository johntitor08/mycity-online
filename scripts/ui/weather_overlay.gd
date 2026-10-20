extends Control
## Ekran üstü hava efektleri: yağmur çizgileri, fırtınada şimşek çakması + gök gürültüsü.
## Ev içindeyken gösterilmez. Şimşekler her oyuncuda ayrı (rastgele) çakar.

var inside := false
var _drops: Array = []
var _flash := 0.0
var _next_thunder := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in 220:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.2)))   # x, y (0..1), hız


func _process(delta: float) -> void:
	_t += delta
	var rainy := Env.is_rainy() and not inside
	if Env.weather == "storm" and not inside:
		_next_thunder -= delta
		if _next_thunder <= 0.0:
			_next_thunder = randf_range(8.0, 22.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.3, 1.5)).timeout.connect(func(): Sfx.play("thunder", -2.0, randf_range(0.85, 1.1)))
	_flash = maxf(0.0, _flash - delta * 2.5)
	visible = rainy or _flash > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var sz := size
	if Env.is_rainy() and not inside:
		var count := 220 if Env.weather == "storm" else 130
		var slant := Vector2(-6, 18) if Env.weather == "storm" else Vector2(-3, 16)
		var col := Color(0.8, 0.85, 1.0, 0.45)
		for i in count:
			var d: Vector3 = _drops[i]
			var y := fmod(d.y + _t * d.z * 1.4, 1.0) * (sz.y + 40) - 20
			var x := fmod(d.x + _t * 0.05, 1.0) * (sz.x + 60) - 30 - y * 0.2
			draw_line(Vector2(x, y), Vector2(x, y) + slant * d.z, col, 1.5)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, _flash * 0.55))
