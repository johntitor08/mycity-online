extends Control
## Okyanus haritası: keşfedilen hücreler, adalar (tip renginde), fenerler, yakıt iskeleleri, fırtınalar,
## Kraken ve oyuncular. Büyük haritada tıklayınca hedef seçilir. Mini haritada da kullanılır (draw_chart).

signal picked(world_pos: Vector2)

const OM = preload("res://scripts/ocean_map.gd")

var world: Node2D
var big := true
var _acc := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP if big else MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.2:
		_acc = 0.0
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if big and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var k := minf(size.x / OM.OCEAN.size.x, size.y / OM.OCEAN.size.y)
		picked.emit(OM.OCEAN.position + e.position / k)
		accept_event()


func _draw() -> void:
	draw_chart(self, Rect2(Vector2.ZERO, size), big, world)


static func draw_chart(ci: CanvasItem, area: Rect2, big: bool, world: Node2D) -> void:
	var k := minf(area.size.x / OM.OCEAN.size.x, area.size.y / OM.OCEAN.size.y)
	var to := func(p: Vector2) -> Vector2: return area.position + (p - OM.OCEAN.position) * k
	var full := Rect2(area.position, OM.OCEAN.size * k)
	var font := ThemeDB.fallback_font
	ci.draw_rect(full.grow(2), Color(0, 0, 0, 0.6))
	ci.draw_rect(full, Color("#12558c"))
	var seen: PackedByteArray = Ocean.seen
	for isl in OM.islands():
		var cell := OM.cell_of(isl.c)
		if cell >= seen.size() or seen[cell] == 0:
			continue
		var pts := PackedVector2Array()
		for i in range(0, isl.shape.size(), 2):
			pts.append(to.call(isl.shape[i]))
		ci.draw_colored_polygon(pts, OM.TYPES[isl.type].sand)
		if big:
			var c: Vector2 = to.call(isl.c)
			if isl.lighthouse:
				ci.draw_circle(c + Vector2(6, -6), 3.5, Color("#fde68a") if int(isl.id) in Ocean.my.lit else Color("#94a3b8"))
			if isl.fuel:
				ci.draw_rect(Rect2(c + Vector2(-10, -9), Vector2(5, 7)), Color("#ef4444"))
			if isl.shipyard:
				ci.draw_rect(Rect2(c + Vector2(-4, 6), Vector2(8, 5)), Color("#f59e0b"))
			var last := float(Ocean.my.chest.get(str(int(isl.id)), 0.0))
			var full_chest := Time.get_unix_time_from_system() - last >= Ocean.CHEST_COOLDOWN
			var name_col := Color("#fde68a") if full_chest else Color("#cbd5e1")
			ci.draw_string_outline(font, c + Vector2(-70, 18), str(isl.name), HORIZONTAL_ALIGNMENT_CENTER, 140, 11, 3, Color(0, 0, 0, 0.8))
			ci.draw_string(font, c + Vector2(-70, 18), str(isl.name), HORIZONTAL_ALIGNMENT_CENTER, 140, 11, name_col)
	# sis: görülmemiş hücreler
	var fog := Color(0.82, 0.86, 0.9, 0.92) if big else Color(0.55, 0.6, 0.66, 0.92)
	for i in OM.COLS * OM.ROWS:
		if i >= seen.size() or seen[i] == 0:
			var r := OM.cell_rect(i)
			ci.draw_rect(Rect2(to.call(r.position), r.size * k + Vector2(0.6, 0.6)), fog)
	for s in Ocean.storm_positions():
		ci.draw_circle(to.call(s[0]), float(s[1]) * k, Color(0.1, 0.1, 0.2, 0.45))
	if not Ocean.kraken.is_empty():
		var kp: Vector2 = to.call(Vector2(float(Ocean.kraken.x), float(Ocean.kraken.y)))
		ci.draw_circle(kp, 7.0 if big else 4.0, Color("#a855f7"))
		if big:
			ci.draw_string(font, kp + Vector2(9, 5), "KRAKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e9d5ff"))
	for id in Net.pos_view:
		if id != Net.my_id() and OM.in_ocean(Net.pos_view[id]):
			ci.draw_circle(to.call(Net.pos_view[id]), 3.0, Color("#60a5fa"))
	if world:
		var mp: Vector2 = to.call(world.my_pos)
		ci.draw_circle(mp, 5.0 if big else 3.5, Color.WHITE)
		ci.draw_circle(mp, 3.5 if big else 2.2, Color("#ef4444"))
		if world.nav_target != null and OM.in_ocean(world.nav_target):
			var np: Vector2 = to.call(world.nav_target)
			ci.draw_line(np + Vector2(-5, -5), np + Vector2(5, 5), Color("#facc15"), 2)
			ci.draw_line(np + Vector2(-5, 5), np + Vector2(5, -5), Color("#facc15"), 2)
