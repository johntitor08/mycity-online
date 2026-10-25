extends "res://scripts/ui/game_panel.gd"
## Teleskop: gece gökyüzü, takımyıldızlar ve kayan yıldızlar (dilek tut).

# takımyıldızlar: ad, yıldızlar (0..1 koordinat), çizgiler
const CONSTELLATIONS := [
	["Büyük Ayı", [Vector2(0.10, 0.30), Vector2(0.17, 0.27), Vector2(0.24, 0.29), Vector2(0.30, 0.33), Vector2(0.31, 0.43), Vector2(0.40, 0.45), Vector2(0.41, 0.35)],
		[[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 3]]],
	["Kutup Yıldızı", [Vector2(0.52, 0.12)], []],
	["Kraliçe (Kassiopeia)", [Vector2(0.62, 0.20), Vector2(0.67, 0.28), Vector2(0.72, 0.22), Vector2(0.77, 0.30), Vector2(0.82, 0.23)],
		[[0, 1], [1, 2], [2, 3], [3, 4]]],
	["Avcı (Orion)", [Vector2(0.58, 0.55), Vector2(0.70, 0.56), Vector2(0.62, 0.66), Vector2(0.64, 0.67), Vector2(0.66, 0.68), Vector2(0.57, 0.80), Vector2(0.71, 0.79)],
		[[0, 2], [1, 4], [2, 3], [3, 4], [2, 5], [4, 6]]],
	["Kuğu", [Vector2(0.24, 0.62), Vector2(0.24, 0.72), Vector2(0.24, 0.84), Vector2(0.15, 0.70), Vector2(0.33, 0.73)],
		[[0, 1], [1, 2], [3, 1], [1, 4]]],
]

var sky: Control
var wish_btn: Button
var info: Label


class SkyView extends Control:
	var night := true
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		if not night:
			draw_rect(Rect2(Vector2.ZERO, size), Color("#7dd3fc"))
			draw_circle(Vector2(size.x * 0.8, size.y * 0.25), 30, Color("#fde047"))
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1026"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 160:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var tw := 0.5 + 0.5 * sin(t * rng.randf_range(1.0, 3.0) + i)
			draw_circle(p, rng.randf_range(0.6, 1.6), Color(1, 1, 1, 0.3 + 0.5 * tw))
		var font := ThemeDB.fallback_font
		for c in CONSTELLATIONS:
			var pts: Array = c[1]
			for ln in c[2]:
				draw_line(pts[ln[0]] * size, pts[ln[1]] * size, Color(0.55, 0.7, 1.0, 0.45), 1.5)
			for p in pts:
				draw_circle(p * size, 3.0, Color("#fef9c3"))
			draw_string(font, pts[0] * size + Vector2(6, -8), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.85, 1.0, 0.9))
		var s: Dictionary = Camp.star
		if not s.is_empty():
			var k := (t - float(s.t0)) / 1.4
			if k < 1.0:
				var a := Vector2(float(s.a), float(s.b)) * size
				var b := a + Vector2(size.x * 0.35, size.y * 0.25)
				var head := a.lerp(b, k)
				draw_line(a.lerp(b, maxf(0.0, k - 0.3)), head, Color(1, 1, 1, 0.8), 3.0)
				draw_circle(head, 4.0, Color.WHITE)


func _ready() -> void:
	build("Teleskop — Gece Gökyüzü", Vector2(640, 0))
	info = add_label(body, "", 14, Color("#94a3b8"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sky = SkyView.new()
	sky.custom_minimum_size = Vector2(600, 340)
	body.add_child(sky)
	wish_btn = add_button(body, "Kayan yıldız! Dilek tut", func(): Camp.wish(); wish_btn.disabled = true)
	wish_btn.custom_minimum_size = Vector2(0, 40)
	wish_btn.visible = false
	Camp.shooting_star.connect(func(_s): wish_btn.visible = true; wish_btn.disabled = false)
	var night := Env.darkness() > 0.45
	sky.night = night
	info.text = "Takımyıldızlar: Büyük Ayı, Kutup Yıldızı, Kraliçe, Avcı, Kuğu. Kayan yıldız görünce dilek tut!" if night \
		else "Gündüz yıldızlar görünmez. Gece gel (şehir saatinde 21:00 sonrası)."
	if night:
		Camp.stargaze()


func _process(_d: float) -> void:
	sky.queue_redraw()
	if wish_btn.visible and Time.get_ticks_msec() / 1000.0 - float(Camp.star.get("t0", 0.0)) > Camp.STAR_WINDOW:
		wish_btn.visible = false
