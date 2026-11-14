extends RefCounted
## 2.5.1: hızlı çizim yardımcıları.
## Godot 4'te draw_circle / draw_colored_polygon her çağrıda ayrı bir GPU tamponu açar (~25 µs, toplanmaz);
## beyaz disk dokusuyla çizilen daire ise draw_rect kadar ucuzdur ve aynı dokuyla art arda çizimler tek komutta toplanır.

static var _disc: Texture2D


## Kenarı yumuşatılmış beyaz disk (mipmap'li: küçük dairelerde de düzgün görünür).
static func disc() -> Texture2D:
	if _disc == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var h := n / 2.0
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - h, y + 0.5 - h).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(h - d, 0.0, 1.0)))
		img.generate_mipmaps()
		_disc = ImageTexture.create_from_image(img)
	return _disc


## draw_circle(p, r, col) yerine (dolu daire).
static func circle(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	ci.draw_texture_rect(disc(), Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, col)
