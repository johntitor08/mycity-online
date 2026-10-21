extends Control
## Ekran üstü hava efektleri: yağmur çizgileri (kışın kar taneleri), fırtınada şimşek çakması + gök gürültüsü,
## festival gecesi havai fişekler. Ev içindeyken gösterilmez. Şimşekler her oyuncuda ayrı (rastgele) çakar.

var inside := false
var _drops: Array = []
var _flash := 0.0
var _next_thunder := 0.0
var _t := 0.0
var _rockets: Array = []      # havai fişek: {pos, vel, t, col, burst}
var _next_rocket := 0.0


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
	var fireworks := Events.is_active("festival") and Env.darkness() > 0.3 and not inside
	if fireworks:
		_next_rocket -= delta
		if _next_rocket <= 0.0:
			_next_rocket = randf_range(0.4, 1.4)
			_rockets.append({"pos": Vector2(randf_range(0.1, 0.9) * size.x, size.y + 10), "vel": Vector2(randf_range(-40, 40), randf_range(-520, -380)),
				"t": 0.0, "col": Color.from_hsv(randf(), 0.7, 1.0), "burst": randf_range(0.9, 1.5)})
	for r in _rockets:
		r.t += delta
		if r.t < r.burst:
			r.pos += r.vel * delta
			r.vel.y += 160.0 * delta
	_rockets = _rockets.filter(func(r): return r.t < r.burst + 1.4)
	visible = rainy or _flash > 0.0 or not _rockets.is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	var sz := size
	for r in _rockets:
		if r.t < r.burst:
			draw_circle(r.pos, 3, Color(1, 0.9, 0.6))
		else:
			var k: float = (r.t - r.burst) / 1.4
			var col: Color = r.col
			col.a = 1.0 - k
			for j in 18:
				var a := TAU * j / 18.0
				draw_circle(r.pos + Vector2(cos(a), sin(a)) * (20.0 + 110.0 * k) + Vector2(0, 40.0 * k * k), 3.0 * (1.0 - k) + 1.0, col)
	if Env.is_snowy() and not inside:
		var count := 200 if Env.weather == "storm" else 120
		for i in count:
			var d: Vector3 = _drops[i]
			var y := fmod(d.y + _t * d.z * (0.25 if Env.weather == "rain" else 0.5), 1.0) * (sz.y + 40) - 20
			var x := fposmod(d.x + sin(_t * 0.8 + i) * 0.01 - (_t * 0.06 if Env.weather == "storm" else 0.0), 1.0) * (sz.x + 60) - 30
			draw_circle(Vector2(x, y), 1.5 + d.z * 1.5, Color(1, 1, 1, 0.8))
	elif Env.is_rainy() and not inside:
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
